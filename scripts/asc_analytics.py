#!/usr/bin/env python3
"""Read-only RoastMate readout from the App Store Connect Analytics API.

Why this exists: every decision gate in docs/DEV_PLAN_v1.7_2026-10.md is a
number from these reports, and the old handoff only had a recipe. Pulls the
ONGOING report request's DAILY instances since --since, de-duplicates rows
(processing dates repeat the same underlying day, so summing raw rows
double-counts), and prints:

  - first-time downloads by date / territory / source
  - purchases (IAP + subscriptions) with proceeds
  - subscription events (starts, renewals, cancellations, offer redemptions)
  - store impressions / page views / taps by territory

Nothing is written to App Store Connect. Usage:
  python3 scripts/asc_analytics.py --since 2026-09-27
"""
import argparse
import collections
import csv
import gzip
import io
import json
import time
import urllib.request
from pathlib import Path

import jwt

ISSUER = "c5671c11-49ec-47d9-bd38-5e3c1a249416"
KEY_ID = "DMMFP6XTXX"
KEY_PATH = Path.home() / "private_keys" / f"AuthKey_{KEY_ID}.p8"
# The ONGOING analytics report request for app 6769317103 (created 2026-05).
REQUEST_ID = "53b320a6-68d1-4796-930f-62521ea5e749"
BASE = "https://api.appstoreconnect.apple.com"

REPORTS = {
    "downloads": "App Downloads Standard",
    "purchases": "App Store Purchases Standard",
    "subscriptions": "App Store Subscription Event Report Standard",
    "discovery": "App Store Discovery and Engagement Standard",
}


def token() -> str:
    now = int(time.time())
    return jwt.encode(
        {"iss": ISSUER, "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
        KEY_PATH.read_text(),
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def get(url: str, tok: str):
    if not url.startswith("http"):
        url = BASE + url
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {tok}"})
    return json.load(urllib.request.urlopen(req, timeout=60))


def fetch(name: str, report_ids: dict, since: str, tok: str) -> list[dict]:
    rid = report_ids[name]
    insts = get(f"/v1/analyticsReports/{rid}/instances?filter[granularity]=DAILY&limit=200", tok)["data"]
    rows, header = set(), None
    for inst in insts:
        if inst["attributes"]["processingDate"] < since:
            continue
        for seg in get(f"/v1/analyticsReportInstances/{inst['id']}/segments", tok)["data"]:
            raw = urllib.request.urlopen(seg["attributes"]["url"], timeout=60).read()
            table = list(csv.reader(io.StringIO(gzip.decompress(raw).decode()), delimiter="\t"))
            header = table[0]
            rows.update(tuple(r) for r in table[1:])
    out = [dict(zip(header, r)) for r in rows] if header else []
    date_key = "Event Date" if out and "Event Date" in out[0] else "Date"
    return sorted((r for r in out if r.get(date_key, "") >= since), key=lambda r: r.get(date_key, ""))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", required=True, help="YYYY-MM-DD, inclusive")
    args = ap.parse_args()
    tok = token()
    report_ids = {
        r["attributes"]["name"]: r["id"]
        for r in get(f"/v1/analyticsReportRequests/{REQUEST_ID}/reports?limit=200", tok)["data"]
    }

    dl = fetch(REPORTS["downloads"], report_ids, args.since, tok)
    first = [r for r in dl if r["Download Type"] == "First-time download"]
    print(f"== first-time downloads since {args.since}: {sum(int(r['Counts']) for r in first)}")
    for r in first:
        print(f"  {r['Date']}  {r['Territory']}  {r['Device']:<8} {r['Source Type']:<18} v{r['App Version']}  x{r['Counts']}")

    pur = fetch(REPORTS["purchases"], report_ids, args.since, tok)
    total = sum(float(r["Proceeds in USD"] or 0) for r in pur)
    print(f"== purchases: {len(pur)} rows, proceeds ${total:.2f}")
    for r in pur:
        print(f"  {r['Date']}  {r['Territory']}  {r['Content Name']:<24} x{r['Purchases']}  ${r['Proceeds in USD']}"
              f"  (downloaded {r['App Download Date']}, via {r['Source Type']})")

    subs = fetch(REPORTS["subscriptions"], report_ids, args.since, tok)
    print(f"== subscription events: {len(subs)}")
    for r in subs:
        offer = f" offer={r['Offer Type']}/{r['Offer Name']}" if r.get("Offer Type") else ""
        print(f"  {r['Event Date']}  {r['Territory']}  {r['Event Name']}  [{r['Subscription Name']}]{offer}  x{r['Counts']}")

    disc = fetch(REPORTS["discovery"], report_ids, args.since, tok)
    agg = collections.defaultdict(lambda: collections.Counter())
    for r in disc:
        agg[r["Event"]][r["Territory"]] += int(r["Counts"] or 0)
    print("== store discovery (top territories)")
    for event, by_terr in sorted(agg.items()):
        top = ", ".join(f"{t} {n}" for t, n in by_terr.most_common(6))
        print(f"  {event:<11} total {sum(by_terr.values()):>4}   {top}")


if __name__ == "__main__":
    main()
