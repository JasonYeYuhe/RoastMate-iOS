#!/usr/bin/env python3
"""Submit an iOS / macOS appStoreVersion for App Review via the REST API.

Discovered 2026-05-28 with iOS v1.0.4: `PATCH /v1/reviewSubmissions/{id}`
with `{attributes:{submitted:true}}` returns 200 + state transitions
READY_FOR_REVIEW → WAITING_FOR_REVIEW. Supersedes the prior assumption
that Submit requires the ASC web UI.

Idempotent: re-runs reuse any open draft reviewSubmission. Fails fast
if the target version isn't in PREPARE_FOR_SUBMISSION (run
asc_bind_version.py first).

Usage:
    python3 scripts/asc_submit_review.py --version 1.0.4
"""
import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

API_BASE = "https://api.appstoreconnect.apple.com"


def mint_jwt(issuer: str, key_id: str, key_path: Path) -> str:
    key = key_path.read_text()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"alg": "ES256", "kid": key_id, "typ": "JWT"},
    )


def api(method: str, path: str, token: str, body=None):
    url = f"{API_BASE}{path}" if path.startswith("/") else path
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
    req = urllib.request.Request(url, method=method, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req) as resp:
            txt = resp.read().decode()
            return resp.status, (json.loads(txt) if txt else {})
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode() or "{}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="e.g. 1.0.4")
    ap.add_argument("--app-id", default="6769317103")
    ap.add_argument("--platform", default="IOS", choices=("IOS", "MAC_OS"))
    ap.add_argument("--issuer", default="c5671c11-49ec-47d9-bd38-5e3c1a249416")
    ap.add_argument("--key-id", default="DMMFP6XTXX")
    ap.add_argument("--key-path",
                    default="/Users/jason/private_keys/AuthKey_DMMFP6XTXX.p8",
                    type=Path)
    args = ap.parse_args()

    token = mint_jwt(args.issuer, args.key_id, args.key_path)

    # Resolve appStoreVersion id from version string.
    status, body = api("GET", token=token,
                       path=f"/v1/apps/{args.app_id}/appStoreVersions?filter[platform]={args.platform}&limit=20")
    versions = {v["attributes"]["versionString"]: v for v in body.get("data", [])}
    if args.version not in versions:
        print(f"✗ v{args.version} not found on {args.platform}.")
        return 1
    version_obj = versions[args.version]
    state = version_obj["attributes"]["appStoreState"]
    version_id = version_obj["id"]
    print(f"=== Submit {args.platform} v{args.version} (id={version_id}, state={state}) ===")
    if state in ("READY_FOR_SALE", "PENDING_DEVELOPER_RELEASE", "WAITING_FOR_REVIEW", "IN_REVIEW"):
        print(f"  Already past submit (state={state}). Nothing to do.")
        return 0
    if state != "PREPARE_FOR_SUBMISSION":
        print(f"  Unexpected state={state}. Bind a build via asc_bind_version.py first.")
        return 2

    # Find an existing draft sub or create one.
    status, body = api("GET", token=token,
                       path=f"/v1/reviewSubmissions?filter[app]={args.app_id}&filter[platform]={args.platform}&filter[state]=READY_FOR_REVIEW,COMPLETING&limit=10")
    sub_id = None
    for s in body.get("data", []):
        if s["attributes"]["state"] == "READY_FOR_REVIEW":
            sub_id = s["id"]
            print(f"✓ Re-using draft sub {sub_id}")
            break

    if sub_id is None:
        print("Creating new reviewSubmission...")
        status, body = api("POST", token=token, path="/v1/reviewSubmissions", body={
            "data": {
                "type": "reviewSubmissions",
                "attributes": {"platform": args.platform},
                "relationships": {"app": {"data": {"type": "apps", "id": args.app_id}}},
            }
        })
        if status >= 300:
            print(f"✗ create failed: {status} {body}")
            return 1
        sub_id = body["data"]["id"]
        print(f"✓ Created sub {sub_id}")

    # Add the version as an item (skip if already attached).
    status, body = api("GET", token=token,
                       path=f"/v1/reviewSubmissions/{sub_id}/items?limit=10")
    has_target = False
    for it in body.get("data", []):
        s, b = api("GET", token=token,
                   path=f"/v1/reviewSubmissionItems/{it['id']}?include=appStoreVersion")
        rel = b.get("data", {}).get("relationships", {}).get("appStoreVersion", {}).get("data") or {}
        if rel.get("id") == version_id:
            has_target = True
            print(f"✓ v{args.version} already attached as item {it['id']}")
            break

    if not has_target:
        print(f"Adding v{args.version} as item on sub {sub_id}...")
        status, body = api("POST", token=token, path="/v1/reviewSubmissionItems", body={
            "data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                },
            }
        })
        if status >= 300:
            print(f"✗ add item failed: {status} {body}")
            return 1
        print(f"✓ Added item {body['data']['id']}")

    # Submit. The documented endpoint is PATCH with submitted=true.
    print(f"\n=== Submit sub {sub_id} ===")
    status, body = api("PATCH", token=token,
                       path=f"/v1/reviewSubmissions/{sub_id}",
                       body={"data": {
                           "type": "reviewSubmissions",
                           "id": sub_id,
                           "attributes": {"submitted": True},
                       }})
    if status >= 300:
        print(f"✗ submit failed: HTTP {status} {body}")
        return 1
    attrs = body.get("data", {}).get("attributes", {})
    print(f"✓ Submitted. state={attrs.get('state')}, submittedDate={attrs.get('submittedDate')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
