#!/usr/bin/env python3
"""Read-only: does ASC hold the 1.8.0 store text and the new Pro subscription
descriptions? Run before and after 1.8.0 goes live.

- Version localizations (iOS + macOS x 4 locales): description and promotional
  text compared byte-for-byte (stripped) with metadata/<locale>/*.txt.
- Subscription localizations: every row printed with its state. Before approval
  the new text is PREPARE_FOR_SUBMISSION and the old "Unlimited generations"
  rows are APPROVED (still what the StoreKit sheet shows). After approval only
  the new text should remain, APPROVED. Expected text: subscription_descriptions.md.

App id is fixed (never from $ASC_APP_ID). Usage, from the repo root:
    python3 docs/evidence/2026-10-27-v18-plan/release-1.8.0/check_live_text.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / "scripts"))
from asc_submit_review import api, mint_jwt  # noqa: E402

APP_ID = "6769317103"
VERSION = "1.8.0"
OLD_MARKERS = ("Unlimited", "无限", "無限", "無制限")


def main() -> int:
    tok = mint_jwt("c5671c11-49ec-47d9-bd38-5e3c1a249416", "DMMFP6XTXX",
                   Path.home() / "private_keys/AuthKey_DMMFP6XTXX.p8")
    bad = 0
    s, j = api("GET", f"/v1/apps/{APP_ID}/appStoreVersions?filter[versionString]={VERSION}&limit=4", tok)
    for v in j.get("data", []):
        plat, state = v["attributes"]["platform"], v["attributes"]["appStoreState"]
        _, locs = api("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations?limit=20", tok)
        for loc in locs.get("data", []):
            a = loc["attributes"]
            d = ROOT / "metadata" / a["locale"]
            row = []
            for field, fn in (("description", "description.txt"), ("promotionalText", "promotional_text.txt")):
                f = d / fn
                ok = f.exists() and f.read_text().strip() == (a.get(field) or "").strip()
                bad += not ok
                row.append(f"{field}={'MATCH' if ok else 'DIFF'}")
            print(plat, state, a["locale"], " ".join(row))
    _, g = api("GET", f"/v1/apps/{APP_ID}/subscriptionGroups?include=subscriptions&limit=10", tok)
    for sub in [x for x in g.get("included", []) if x["type"] == "subscriptions"]:
        _, sl = api("GET", f"/v1/subscriptions/{sub['id']}/subscriptionLocalizations?limit=20", tok)
        for loc in sl.get("data", []):
            a = loc["attributes"]
            old = any(m in (a.get("description") or "") for m in OLD_MARKERS)
            flag = "  <- old text" if old and a.get("state") == "APPROVED" else ""
            print("SUB", sub["attributes"]["productId"], a["locale"], a.get("state"), "|", a.get("description"), flag)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
