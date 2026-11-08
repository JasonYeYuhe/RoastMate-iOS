#!/usr/bin/env python3
"""Read-only weekly readout for RoastMate (path A item A5, kept under path D for the
v1.8 §2.3 weekly leading signals; docs/NEXT_PHASE_PLAN_2026-11.md).

Prints, from the App Store Connect APIs and the outreach log:
  - per week (Monday start, report dates): first-time downloads, product page
    views, TW impressions / page views / downloads, TW page views by Source Type.
    These come from Analytics DAILY instances, which Apple keeps for only about
    35 days, so the table and its totals are a TRAILING window (context only).
  - every Analytics subscription event in that trailing window
  - the latest published Sales SUBSCRIPTION snapshot for this app
    (active paid / free trial / billing retry / grace period)
  - the v1.8 §2.3 window since 1.8.0 went live (V18_FROM), from Sales reports
    that Apple keeps for a year (scripts/payer_read.py): first-time units, new
    starts with their 3-day-cancel and second-period flags, start-like events
    not counted, and the interim verdict
  - Retention Messaging (r320, cancel-sheet events): rows Apple still holds,
    appended to ~/Documents/RoastMate-research/retention-messaging-log.tsv (new
    rows only) before they expire; payer_read.py reads that log
  - the newest App Store customer reviews (the only user-report channel under
    path D; v1.8 §2.4's same-day kill switch depends on noticing one)
  - this Mac's macOS version (a 27.x point release means the refusal probe is due)
  - P2.1 posts logged in ~/Documents/RoastMate-research/creator-outreach-log.tsv
    (rows whose handle column starts with "post:"); path A ended 2026-11-08
  - a last line `FINGERPRINT {json}` for "report only on change". It holds only
    values that don't shrink as Apple drops old days.

The only file written is the r320 log above; the scheduled task keeps its own
history file. Apple suppresses small counts, so every number is a lower bound.
Subscription reports lag Sales by about a day: a 404 there does not mean "no
events".

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

sys.dont_write_bytecode = True  # no __pycache__ in the repo from scheduled runs
sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_analytics as A  # noqa: E402  (token(), get(), fetch(), REPORTS, REQUEST_ID)
import payer_read as P  # noqa: E402  (collect(), verdict(), R320_LOG)
import platform  # noqa: E402
import subprocess  # noqa: E402

APP_ID = "6769317103"  # never from $ASC_APP_ID: that may be another app
VENDOR = "94126306"
V18_FROM = "2026-11-05"  # iOS 1.8.0 live 11-05 (macOS 11-02); v1.8 §2.3 counts from here
V18_TO = "2027-01-31"  # §2.3 window end: later starts are not §2.3 starts
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
                if e.code in (400, 410):
                    continue  # wrong version: try the other one
                return "FAILED", []  # outage / rate limit: don't report zeros as a state
            except (urllib.error.URLError, TimeoutError, OSError):
                return "FAILED", []
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
    print("trailing ~35 days only (Apple drops older Analytics days); context, not tracked for change:")
    print("week of     dl  pv | TW imp  pv  dl | TW page views by source")
    weeks = sorted(wk)[-args.weeks:]
    for w in weeks:
        c = wk[w]
        src = ", ".join(f"{s} {n}" for s, n in tw_src[w].most_common()) or "-"
        print(f"{w}  {c['dl']:>3} {c['pv']:>3} | {c['tw_imp']:>6} {c['tw_pv']:>3} {c['tw_dl']:>3} | {src}")

    starts = [r for r in subs if re.search(r"start|activation", r["Event Name"], re.I)]
    print(f"Analytics subscription events in the trailing window: {len(subs)} "
          f"(starts {sum(int(r['Counts'] or 0) for r in starts)})")
    for r in subs:
        print(f"  {r['Event Date']} {r['Territory']} {r['Event Name']} [{r['Subscription Name']}] x{r['Counts']}")

    snap_day, snap = sales_snapshot(tok, today)
    keys = ["Active Standard Price Subscriptions", "Active Free Trial Introductory Offer Subscriptions",
            "Free Trial Offer Code Subscriptions", "Billing Retry", "Grace Period"]
    totals = collections.Counter()
    for r in snap:
        for k in keys:
            totals[k] += int(r.get(k) or 0)
    if snap_day == "FAILED":
        print("subscription snapshot: FAILED (ASC error, not 404): state unknown this run")
    elif snap_day:
        print(f"subscription snapshot {snap_day}: active paid {totals[keys[0]]}, free trial {totals[keys[1]]}, "
              f"offer-code trial {totals[keys[2]]}, billing retry {totals['Billing Retry']}, "
              f"grace period {totals['Grace Period']}")
        for r in snap:
            nz = {k: r.get(k) for k in keys if (r.get(k) or "0") != "0"}
            print(f"  {r['Country']} {r['Subscription Name']} {nz}")
    else:
        print("subscription snapshot: none published in the last 6 days")

    r320 = A.fetch("Retention Messaging", ids, "2026-09-01", tok) if "Retention Messaging" in ids else []
    known = set()
    if P.R320_LOG.exists():
        known = {ln.rstrip("\n").split("\t", 1)[-1] for ln in P.R320_LOG.open()}
    new_rows = [json.dumps(r, sort_keys=True, ensure_ascii=False) for r in r320]
    new_rows = [j for j in new_rows if j not in known]
    if new_rows:
        P.R320_LOG.parent.mkdir(parents=True, exist_ok=True)
        fresh = not P.R320_LOG.exists()
        with P.R320_LOG.open("a") as f:
            if fresh:
                f.write("first_seen\trow_json\n")
            for j in new_rows:
                f.write(f"{today.isoformat()}\t{j}\n")
    r320_total = len(known - {"row_json"}) + len(new_rows)
    print(f"Retention Messaging (r320): {len(r320)} rows held by Apple, {len(new_rows)} new, {r320_total} in the local log")
    for j in new_rows:
        print(f"  NEW {j}")

    c = P.collect(tok, dt.date.fromisoformat(V18_FROM), min(today, dt.date.fromisoformat(V18_TO)), today)
    v18_starts = sum(s["qty"] for s in c["starts"].values())
    v18_cancel3 = sum(s["cancel3"] for s in c["starts"].values())
    v18_unknown = sum(s["unknown"] for s in c["starts"].values())
    v18_second = sum(s["second"] for s in c["starts"].values())
    print(f"v1.8 §2.3 window {V18_FROM} .. {V18_TO} (Sales, data reaches {c['through'] or 'none'}): "
          f"first-time units {c['units']}, new starts {v18_starts} (cancelled within 3 days {v18_cancel3}, "
          f"unknown {v18_unknown}, second paid period {v18_second}), events {len(c['events'])}, "
          f"start-like events not counted {len(c['excluded'])}")
    for e in c["events"]:
        print(f"  {e['Event Date']} {e['Country']} {e['Event']} [{e['Subscription Name']}] start={e['Original Start Date']} "
              f"days_before_canceling={e.get('Days Before Canceling') or '-'} qty={e.get('Quantity')}")
    for e in c["excluded"]:
        print(f"  NOT COUNTED as a new start: {e['Event Date']} {e['Country']} {e['Event']} "
              f"start={e['Original Start Date']} qty={e.get('Quantity')}")
    if c["failed"]:
        print(f"  FAILED report days (not 404): {', '.join(c['failed'])}")
    else:
        print("  interim " + P.verdict(c["starts"], c["units"]))

    rv = A.get(f"/v1/apps/{APP_ID}/customerReviews?sort=-createdDate&limit=3", tok)
    reviews_total = rv.get("meta", {}).get("paging", {}).get("total", len(rv.get("data", [])))
    latest_review = rv["data"][0]["id"] if rv.get("data") else ""
    print(f"App Store customer reviews: {reviews_total} in total; newest:")
    for r in rv.get("data", []):
        a = r["attributes"]
        print(f"  {a.get('createdDate', '')[:10]} {a.get('territory', '')} {a.get('rating')}★ "
              f"{a.get('title', '')!r}: {(a.get('body') or '')[:160]!r}")

    try:
        macos = subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True, timeout=10).stdout.strip()
        build = subprocess.run(["sw_vers", "-buildVersion"], capture_output=True, text=True, timeout=10).stdout.strip()
        macos = f"{macos} ({build})"
    except (OSError, subprocess.SubprocessError):
        macos = platform.mac_ver()[0]
    print(f"this Mac: macOS {macos} (a change means a point release: rerun the refusal probe)")

    posts = posts_logged()
    print(f"P2.1 posts logged: {len(posts)} (path A ended 2026-11-08; path D since)")
    for p in posts:
        print(f"  {p[0]} {p[1]} {p[2]}")

    fp = {  # only values that don't shrink as Apple drops old Analytics days
        "last_data_day": last_data_day,
        # None when no snapshot could be read: unknown, never "0 subscribers"
        "snapshot": ({"day": snap_day, "paid": totals[keys[0]], "trial": totals[keys[1]] + totals[keys[2]],
                      "billing_retry": totals["Billing Retry"], "grace": totals["Grace Period"]}
                     if snap_day and snap_day != "FAILED" else None),
        "posts": len(posts),
        "v18_units": c["units"],
        "v18_starts": v18_starts,
        "v18_cancel3": v18_cancel3,
        "v18_second": v18_second,
        "v18_unknown": v18_unknown,
        "v18_events": len(c["events"]),
        "r320_rows": r320_total,
        "reviews_total": reviews_total,
        "latest_review": latest_review,
        "macos": macos,
    }
    if c["failed"]:
        print("No FINGERPRINT: some Sales days failed, so the v1.8 counts are incomplete. Rerun later.")
        sys.exit(2)
    print("FINGERPRINT " + json.dumps(fp, sort_keys=True))


if __name__ == "__main__":
    main()
