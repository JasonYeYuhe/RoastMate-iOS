#!/usr/bin/env python3
"""Bind a build to an iOS / macOS appStoreVersion + write per-locale What's New.

Idempotent: re-running just updates the localization rows.

Usage:
    python3 scripts/asc_bind_version.py \
        --version 1.0.4 \
        --build 11 \
        --notes build/v1.0.4-release-notes-draft.md

Notes file format: GitHub-flavored Markdown with `## <locale>` headings
(en-US / zh-Hans / zh-Hant / ja). The first non-blank paragraph under
each heading is the What's New body for that locale.

Auth: requires the ASC API .p8 key at /Users/jason/private_keys/
AuthKey_<KEY_ID>.p8 (default DMMFP6XTXX, RoastMate's). Override with
--key-id / --issuer / --key-path. App id default is 6769317103."""
import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

import jwt

API_BASE = "https://api.appstoreconnect.apple.com"
LOCALES = ("en-US", "zh-Hans", "zh-Hant", "ja")


def parse_notes(md_path: Path) -> dict:
    """Pull each locale's body from a release-notes markdown file."""
    text = md_path.read_text()
    out: dict = {}
    current: str | None = None
    buf: list[str] = []
    locale_pattern = re.compile(r"^##\s+(\S+)\s*$")
    for line in text.splitlines():
        m = locale_pattern.match(line)
        if m:
            if current and current in LOCALES:
                body = "\n".join(buf).strip()
                if body:
                    out[current] = body
            current = m.group(1)
            buf = []
        elif current and current in LOCALES:
            buf.append(line)
    if current and current in LOCALES:
        body = "\n".join(buf).strip()
        if body:
            out[current] = body
    missing = [loc for loc in LOCALES if loc not in out]
    if missing:
        sys.exit(f"notes file missing locale section(s): {missing}")
    return out


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
    ap.add_argument("--build", required=True, help="numeric build number, e.g. 11")
    ap.add_argument("--notes", required=True, type=Path,
                    help="release-notes markdown with ## en-US / ## zh-Hans / ## zh-Hant / ## ja")
    ap.add_argument("--app-id", default="6769317103", help="RoastMate ASC app id")
    ap.add_argument("--platform", default="IOS", choices=("IOS", "MAC_OS"))
    ap.add_argument("--issuer", default="c5671c11-49ec-47d9-bd38-5e3c1a249416")
    ap.add_argument("--key-id", default="DMMFP6XTXX")
    ap.add_argument("--key-path",
                    default="/Users/jason/private_keys/AuthKey_DMMFP6XTXX.p8",
                    type=Path)
    args = ap.parse_args()

    notes = parse_notes(args.notes)
    token = mint_jwt(args.issuer, args.key_id, args.key_path)

    print(f"=== Bind {args.platform} v{args.version} ===")

    # 1. Find or create appStoreVersion.
    status, body = api("GET", token=token,
                       path=f"/v1/apps/{args.app_id}/appStoreVersions?filter[platform]={args.platform}&limit=20")
    existing = {v["attributes"]["versionString"]: v for v in body.get("data", [])}

    if args.version in existing:
        version_obj = existing[args.version]
        print(f"✓ v{args.version} exists (id={version_obj['id']}, state={version_obj['attributes']['appStoreState']})")
    else:
        print(f"Creating new v{args.version}...")
        status, body = api("POST", path="/v1/appStoreVersions", token=token, body={
            "data": {
                "type": "appStoreVersions",
                "attributes": {
                    "versionString": args.version,
                    "platform": args.platform,
                    "releaseType": "AFTER_APPROVAL",
                },
                "relationships": {"app": {"data": {"type": "apps", "id": args.app_id}}},
            }
        })
        if status >= 300:
            print(f"✗ create failed: {status} {body}")
            return 1
        version_obj = body["data"]
        print(f"✓ Created v{args.version} (id={version_obj['id']})")

    version_id = version_obj["id"]

    # 2. Find the build.
    print(f"\n=== Find build {args.build} ===")
    status, body = api(
        "GET", token=token,
        path=f"/v1/builds?filter[app]={args.app_id}&filter[preReleaseVersion.platform]={args.platform}&sort=-uploadedDate&limit=10",
    )
    build_id = None
    for b in body.get("data", []):
        attrs = b["attributes"]
        if attrs["version"] == args.build and attrs["processingState"] == "VALID":
            build_id = b["id"]
            print(f"✓ Build {args.build} VALID (id={build_id})")
            break
    if not build_id:
        print(f"✗ Build {args.build} not yet VALID — wait + re-run.")
        for b in body.get("data", []):
            a = b["attributes"]
            print(f"   build {a['version']}: state={a['processingState']} uploaded={a['uploadedDate']}")
        return 2

    # 3. Attach build → version.
    print(f"\n=== Attach build {args.build} → v{args.version} ===")
    status, _ = api("PATCH", token=token,
                    path=f"/v1/appStoreVersions/{version_id}/relationships/build",
                    body={"data": {"type": "builds", "id": build_id}})
    print(f"  PATCH build relationship: HTTP {status}")

    # 4. Write 4-locale What's New.
    print(f"\n=== Write 4-locale What's New ===")
    status, body = api("GET", token=token,
                       path=f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=20")
    locs_by_locale = {l["attributes"]["locale"]: l for l in body.get("data", [])}

    for locale, whats_new in notes.items():
        if locale in locs_by_locale:
            loc_id = locs_by_locale[locale]["id"]
            s, _ = api("PATCH", token=token,
                       path=f"/v1/appStoreVersionLocalizations/{loc_id}",
                       body={"data": {
                           "type": "appStoreVersionLocalizations",
                           "id": loc_id,
                           "attributes": {"whatsNew": whats_new},
                       }})
            print(f"  PATCH {locale}: HTTP {s}")
        else:
            s, _ = api("POST", token=token,
                       path="/v1/appStoreVersionLocalizations",
                       body={"data": {
                           "type": "appStoreVersionLocalizations",
                           "attributes": {"locale": locale, "whatsNew": whats_new},
                           "relationships": {
                               "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                           },
                       }})
            print(f"  POST {locale}: HTTP {s}")

    print(f"\n=== DONE ===")
    print(f"{args.platform} v{args.version} (id {version_id}) ready. Build {args.build} attached + 4-locale What's New.")
    print(f"Next: scripts/asc_submit_review.py --version {args.version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
