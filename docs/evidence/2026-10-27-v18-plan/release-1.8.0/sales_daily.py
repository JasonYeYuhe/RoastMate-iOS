# Read-only: daily SALES SUMMARY rows for app 6769317103 (and its IAPs).
import sys, gzip, csv, io, urllib.request, urllib.error
sys.path.insert(0, "scripts")
import asc_submit_review as a
from pathlib import Path
t = a.mint_jwt("c5671c11-49ec-47d9-bd38-5e3c1a249416", "DMMFP6XTXX", Path.home()/"private_keys/AuthKey_DMMFP6XTXX.p8")
for d in sys.argv[1:]:
    url = ("https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]=DAILY"
           f"&filter[reportDate]={d}&filter[reportSubType]=SUMMARY&filter[reportType]=SALES"
           "&filter[vendorNumber]=94126306&filter[version]=1_1")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {t}", "Accept": "application/a-gzip"})
    try:
        rows = list(csv.reader(io.StringIO(gzip.decompress(urllib.request.urlopen(req, timeout=60).read()).decode()), delimiter="\t"))
    except urllib.error.HTTPError as e:
        print(d, e.code); continue
    h = rows[0]; ix = {c: i for i, c in enumerate(h)}
    mine = [r for r in rows[1:] if r[ix["Apple Identifier"]] == "6769317103" or r[ix["Parent Identifier"]] == "roastmate-1" or "roastmate" in r[ix["SKU"]].lower()]
    print(d, "published,", len(rows) - 1, "rows total,", len(mine), "RoastMate")
    for r in mine:
        print("  ", r[ix["SKU"]], r[ix["Product Type Identifier"]], r[ix["Units"]], r[ix["Country Code"]], r[ix["Customer Price"]], r[ix.get("Subscription", 0)] if "Subscription" in ix else "", r[ix.get("Period", 0)] if "Period" in ix else "")
