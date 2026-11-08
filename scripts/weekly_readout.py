#!/usr/bin/env python3
"""Read-only weekly readout for RoastMate (path A, item A5; docs/NEXT_PHASE_PLAN_2026-11.md).

Prints, from the App Store Connect APIs and the outreach log:
  - per week (Monday start, report dates): first-time downloads, product page
    views, TW impressions / page views / downloads, TW page views by Source Type
  - every subscription event since --since (starts, churn, billing retry, ...)
  - the latest published Sales SUBSCRIPTION snapshot for this app
    (active paid / free trial / billing retry / grace period)
  - P2.1 posts logged in ~/Documents/RoastMate-research/creator-outreach-log.tsv
    (rows whose handle column starts with "post:"), and T = the third post's date
  - a last line `FINGERPRINT {json}` for "report only on change"

Nothing is written anywhere; the scheduled task keeps its own history file.
Apple suppresses small counts, so every number is a lower bound. Subscription
reports lag Sales by about a day: a 404 there does not mean "no events".

Usage (from the repo root):
  python3 scripts/weekly_readout.py [--since 2026-10-01] [--weeks 8]
"""
import argparse
import collections
import csv
import datetime as dt
import gzip
import io
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_analytics as A  # noqa: E402  (token(), get(), fetch(), REPORTS, REQUEST_ID)

APP_ID = "6769317103"  # never from $ASC_APP_ID: that may be another app
VENDOR = "94126306"
OUTREACH_LOG = Path.home() / "Documents" / "RoastMate-research" / "creator-outreach-log.tsv"


def week_start(day: str) -> str:
    d = dt.date.fromisoformat(day[:10])
    return (d - dt.timedelta(days=d.weekday())).isoformat()


def sales_snapshot(tok: str, today: dt.date):
    """Newest published SUBSCRIPTION (snapshot) report within 6 days, this app's rows only."""
    for back in range(1, 7):
        day = (today - dt.timedelta(days=back)).isoformat()
        for ver in ("1_4", "1_3"):
            url = ("https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]=DAILY"
                   f"&filter[reportDate]={day}&filter[reportSubType]=SUMMARY&filter[reportType]=SUBSCRIPTION"
                   f"&filter[vendorNumber]={VENDOR}&filter[version]={ver}")
            req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}",
                                                       "Accept": "application/a-gzip"})
            try:
                raw = urllib.request.urlopen(req, timeout=60).read()
            except urllib.error.HTTPError as e:
                if e.code == 404:
                    break  # not published yet (or no rows): try the day before
                continue  # wrong version: try the other one
            rows = list(csv.reader(io.StringIO(gzip.decompress(raw).decode()), delimiter="\t"))
            hdr = rows[0]
            mine = [dict(zip(hdr, r)) for r in rows[1:] if dict(zip(hdr, r)).get("App Apple ID") == APP_ID]
            return day, mine
    return None, []


def posts_logged():
    if not OUTREACH_LOG.exists():
        return []
    out = []
    with OUTREACH_LOG.open() as f:
        for row in csv.reader(f, delimiter="\t"):
            if len(row) > 1 and row[1].startswith("post:"):
                out.append((row[0], row[1], row[2] if len(row) > 2 else ""))
    return sorted(out)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", default="2026-10-01")
    ap.add_argument("--weeks", type=int, default=8)
    args = ap.parse_args()
    today = dt.date.today()
    tok = A.token()
    ids = {r["attributes"]["name"]: r["id"]
           for r in A.get(f"/v1/analyticsReportRequests/{A.REQUEST_ID}/reports?limit=200", tok)["data"]}

    dl = A.fetch(A.REPORTS["downloads"], ids, args.since, tok)
    disc = A.fetch(A.REPORTS["discovery"], ids, args.since, tok)
    subs = A.fetch(A.REPORTS["subscriptions"], ids, args.since, tok)

    wk = collections.defaultdict(collections.Counter)
    tw_src = collections.defaultdict(collections.Counter)
    last_data_day = ""
    for r in dl:
        if r["Download Type"] != "First-time download":
            continue
        n = int(r["Counts"] or 0)
        w = week_start(r["Date"])
        wk[w]["dl"] += n
        if r["Territory"] == "TW":
            wk[w]["tw_dl"] += n
        last_data_day = max(last_data_day, r["Date"])
    for r in disc:
        n = int(r["Counts"] or 0)
        w = week_start(r["Date"])
        last_data_day = max(last_data_day, r["Date"])
        if r["Event"] == "Page view":
            wk[w]["pv"] += n
            if r["Territory"] == "TW":
                wk[w]["tw_pv"] += n
                tw_src[w][r["Source Type"]] += n
        elif r["Event"] == "Impression" and r["Territory"] == "TW":
            wk[w]["tw_imp"] += n

    print(f"RoastMate weekly readout, run {today.isoformat()} (latest analytics row {last_data_day or 'none'})")
    print("week of     dl  pv | TW imp  pv  dl | TW page views by source")
    weeks = sorted(wk)[-args.weeks:]
    for w in weeks:
        c = wk[w]
        src = ", ".join(f"{s} {n}" for s, n in tw_src[w].most_common()) or "-"
        print(f"{w}  {c['dl']:>3} {c['pv']:>3} | {c['tw_imp']:>6} {c['tw_pv']:>3} {c['tw_dl']:>3} | {src}")

    starts = [r for r in subs if re.search(r"start|activation", r["Event Name"], re.I)]
    print(f"subscription events since {args.since}: {len(subs)} (starts {sum(int(r['Counts'] or 0) for r in starts)})")
    for r in subs:
        print(f"  {r['Event Date']} {r['Territory']} {r['Event Name']} [{r['Subscription Name']}] x{r['Counts']}")

    snap_day, snap = sales_snapshot(tok, today)
    keys = ["Active Standard Price Subscriptions", "Active Free Trial Introductory Offer Subscriptions",
            "Free Trial Offer Code Subscriptions", "Billing Retry", "Grace Period"]
    totals = collections.Counter()
    for r in snap:
        for k in keys:
            totals[k] += int(r.get(k) or 0)
    if snap_day:
        print(f"subscription snapshot {snap_day}: active paid {totals[keys[0]]}, free trial {totals[keys[1]]}, "
              f"offer-code trial {totals[keys[2]]}, billing retry {totals['Billing Retry']}, "
              f"grace period {totals['Grace Period']}")
        for r in snap:
            nz = {k: r.get(k) for k in keys if (r.get(k) or "0") != "0"}
            print(f"  {r['Country']} {r['Subscription Name']} {nz}")
    else:
        print("subscription snapshot: none published in the last 6 days")

    posts = posts_logged()
    t_day = posts[2][0] if len(posts) >= 3 else None
    print(f"P2.1 posts logged: {len(posts)} of 3 (T = {t_day or 'not yet'}; fewer than 3 by 2026-11-22 -> path D)")
    for p in posts:
        print(f"  {p[0]} {p[1]} {p[2]}")

    fp = {
        "last_data_day": last_data_day,
        "dl_total": sum(c["dl"] for c in wk.values()),
        "pv_total": sum(c["pv"] for c in wk.values()),
        "tw_pv_total": sum(c["tw_pv"] for c in wk.values()),
        "tw_dl_total": sum(c["tw_dl"] for c in wk.values()),
        "sub_events": len(subs),
        "snapshot": {"day": snap_day, "paid": totals[keys[0]], "trial": totals[keys[1]] + totals[keys[2]],
                     "billing_retry": totals["Billing Retry"], "grace": totals["Grace Period"]},
        "posts": len(posts),
    }
    print("FINGERPRINT " + json.dumps(fp, sort_keys=True))


if __name__ == "__main__":
    main()
