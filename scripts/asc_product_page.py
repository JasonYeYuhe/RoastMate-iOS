#!/usr/bin/env python3
"""Put RoastMate's product page into App Store Connect: screenshots + text.

Three subcommands, each for ONE appStoreVersion picked by --version/--platform:

  status       Read-only. Version state, per-locale text (lengths + current
               values), every appInfo's name/subtitle, and the screenshot
               placements per placement group (count + filenames in order).
  text         keywords / description / promotionalText on the version's
               localizations, and name / subtitle on the EDITABLE appInfo, from
               metadata/<locale>/{keywords,description,promotional_text,name,
               subtitle}.txt (en-US, zh-Hans, zh-Hant, ja; trailing newline
               stripped). whatsNew is NOT this script's job: asc_bind_version.py
               writes it.
  screenshots  iPhone screenshots through the App Asset Library, from
               <src-root>/<en_US|zh_Hans|zh_Hant|ja_JP>/<device>/NN-name.png,
               device iPhone_17_Pro_Max = 6.9" (IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE)
               or iPhone_17_Pro = 6.3" (IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE).
               Display order = filename order. A misfiled image fails the gate
               (see below); other files are ignored and listed.

Every write is behind --apply. Without it the script prints what would change
(field-level old -> new for text; a per-locale placement plan for screenshots)
and exits 0.

Usage:
    python3 scripts/asc_product_page.py status      --version 1.7.0
    python3 scripts/asc_product_page.py text        --version 1.7.0 [--apply]
    python3 scripts/asc_product_page.py screenshots --version 1.7.0 [--apply]
    # promotionalText ONLY, on the live version (Apple allows it without review):
    python3 scripts/asc_product_page.py text --version 1.6.0 --live-promo [--apply]

Refusals (checked before the first write; no flag overrides them):
  * The version must be editable: PREPARE_FOR_SUBMISSION, DEVELOPER_REJECTED,
    REJECTED, METADATA_REJECTED or INVALID_BINARY (WAITING_FOR_REVIEW is not).
    The one exception is `text --live-promo`: it needs a READY_FOR_SALE version
    and then writes ONLY promotionalText.
  * name/subtitle go only to the appInfo in an editable state. While a new
    version is being prepared there are two appInfos; the live
    READY_FOR_DISTRIBUTION one is never written.
  * Screenshots never DELETE an appAssetLibraryImage (images back the LIVE
    version's placements), nor an appScreenshot (Apple maps that deprecated
    DELETE onto the image delete). The only delete is DELETE
    /v1/appAssetLibraryPlacements/{id}, also with --legacy-sets, and only for a
    placement that (a) was listed from the TARGET version's localization, (b)
    names that localization in its own relationship, and (c) is not among the
    LIVE version's placements (listed fresh on every run; LIVE = the highest
    other version in READY_FOR_SALE, since superseded versions keep that state).
    The dry run puts every planned removal through the same checks. With
    --legacy-sets the set reorder (a PATCH Apple titles "Replace all app
    screenshots") goes out only if the set holds exactly this run's uploads.
  * Screenshot gate, refuses the whole run: two PNGs with the same md5, a size
    the placement group does not accept (read from GET /v1/appAssetLibraryRefData),
    an alpha channel, or more files in a group than its limit (10). Also any
    misfiled image inside the tree: a .png/.jpg/.heic in a device folder that is
    not NN-name.png (03-c.PNG, 02_b.png, 4-d.png), two files with the same NN, an
    unknown folder inside a locale or device folder (iPhone_17_ProMax), an image
    loose in a locale folder, or a folder at the top that looks like a locale or
    device folder but is not one (en-US, ja, zh_hans, iPhone_17_Pro_Max).
    contact_sheet.png and anything else outside the locale folders is ignored
    (and listed).

Network: every API request times out after 60 s; GETs are retried 3 times on
a timeout, 429 or 5xx. Writes are never retried (a timed-out POST may have
landed), so a failed --apply run stops at that write, leaving the editable
target version partly updated; re-running repairs it.

Exit codes: 0 ok or dry run; 1 bad input, gate failure or API error;
2 write refused by state (--apply); 3 read-back differs from the local set.

Auth: the ASC API .p8 key, via mint_jwt()/api() from asc_bind_version.py.
Defaults: key DMMFP6XTXX at ~/private_keys/AuthKey_<KEY_ID>.p8, issuer
c5671c11-49ec-47d9-bd38-5e3c1a249416, app 6769317103. Override with
--key-id/--issuer/--key-path/--app-id or ASC_KEY_ID/ASC_ISSUER_ID/ASC_KEY_PATH/
ASC_APP_ID."""
import argparse
import difflib
import hashlib
import http.client
import json
import os
import re
import socket
import struct
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import NamedTuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from asc_bind_version import LOCALES, api, mint_jwt  # noqa: E402

REPO = Path(__file__).resolve().parent.parent

EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "INVALID_BINARY"}
# appStoreState says READY_FOR_SALE; appVersionState / appInfo.state say READY_FOR_DISTRIBUTION.
LIVE = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION"}

# (local file stem, ASC attribute, max chars, resource that holds it)
TEXT_FIELDS = (
    ("keywords", "keywords", 100, "version"),
    ("description", "description", 4000, "version"),
    ("promotional_text", "promotionalText", 170, "version"),
    ("name", "name", 30, "appinfo"),
    ("subtitle", "subtitle", 30, "appinfo"),
)

LOCALE_DIRS = {"en_US": "en-US", "zh_Hans": "zh-Hans", "zh_Hant": "zh-Hant", "ja_JP": "ja"}
# Group ids are verified against the ref data at runtime (Apple's docs say not to
# trust a hard-coded table); the run refuses if one has disappeared.
LARGE = "IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE"
MEDIUM = "IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE"
DEVICE_GROUPS = {"iPhone_17_Pro_Max": LARGE, "iPhone_17_Pro": MEDIUM}
LEGACY_65_GROUP = "IPHONE_FACE_ID_LARGE_PROFILE"   # the inherited 6.5" Simplified set
SHOT_RE = re.compile(r"^\d\d-[A-Za-z0-9-]+\.png$")
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg", ".heic"}   # inside the tree, these must be NN-name.png
CONTACT_SHEET = "contact_sheet.png"
PLACEMENT_TYPE = "APP_SCREENSHOT"
ASSET_CATEGORY = "APP_SCREENSHOTS_AND_PREVIEWS"

IMAGE_PENDING = {"AWAITING_UPLOAD", "UPLOAD_COMPLETE"}
# Docs: a processed image is PREPARE_FOR_SUBMISSION. The AppAssetLibraryAssetState
# enum also lists COMPLETE and the review states, so accept those as "processed" too.
IMAGE_READY = {"PREPARE_FOR_SUBMISSION", "COMPLETE", "READY_FOR_REVIEW",
               "WAITING_FOR_REVIEW", "IN_REVIEW", "ACCEPTED", "APPROVED"}
POLL_SECONDS, POLL_TIMEOUT = 3, 600
# asc_bind_version.api() calls urlopen with no timeout (a stalled TLS read hung a
# GET for 5+ min on 2026-10-07); main() sets this as the socket default instead.
API_TIMEOUT = 60
GET_ATTEMPTS = 4   # waits 2, 4, 8 s between tries

# --legacy-sets only (deprecated appScreenshotSets model). The ScreenshotDisplayType
# enum has APP_IPHONE_67 and APP_IPHONE_61 (no _69/_63) and Apple's docs give no
# group <-> display-type table. FACE_ID_LARGE <-> APP_IPHONE_65 is measured (the
# live en-US 6.5" set shows up as that placement group); the other two are by analogy.
# Only UPLOADS use this model. Removal never does: Apple's deprecation notes map
# DELETE /v1/appScreenshots/{id} to DELETE /v1/appAssetLibraryImages/{id} (an image
# delete, forbidden here) and DELETE /v1/appScreenshotSets/{id} to a placement
# delete with undocumented compatibility semantics (both checked against the live
# docs 2026-10-14). So --legacy-sets removes superseded screenshots with the same
# guarded placement DELETE as the default path, and needs the placement GET/DELETE
# endpoints for that; if those are down too, remove the old set in the ASC web UI.
# The set reorder (PATCH .../relationships/appScreenshots, titled "Replace all app
# screenshots") goes out only once the set holds exactly this run's uploads.
LEGACY_DISPLAY_TYPES = {LARGE: "APP_IPHONE_67", MEDIUM: "APP_IPHONE_61"}
# Used only with --legacy-sets AND only if the ref data cannot be read.
FALLBACK_SIZES = {LARGE: (1320, 2868), MEDIUM: (1206, 2622)}


def die(msg: str, code: int = 1):
    print(f"ERROR: {msg}", file=sys.stderr)
    sys.exit(code)


# ---------------------------------------------------------------- API client

class ASC:
    """asc_bind_version.api() plus: JWT re-mint (they last 20 min; a full upload
    can take longer), paging, and a hard refusal of every write without --apply."""

    def __init__(self, args, apply: bool = False):
        self.issuer, self.key_id = args.issuer, args.key_id
        self.key_path = Path(args.key_path or Path.home() / "private_keys" / f"AuthKey_{args.key_id}.p8").expanduser()
        self.apply = apply
        self._token, self._minted = None, 0.0

    def token(self) -> str:
        if time.time() - self._minted > 900:
            if not self.key_path.exists():
                die(f"ASC key not found: {self.key_path}")
            self._token, self._minted = mint_jwt(self.issuer, self.key_id, self.key_path), time.time()
        return self._token

    def _call(self, method, path, body=None, soft=False):
        # GETs retry on a network error/timeout (status 0), 429 or 5xx. Writes do not:
        # a POST that timed out may still have landed, and a rerun is the repair.
        attempts = GET_ATTEMPTS if method == "GET" else 1
        for attempt in range(1, attempts + 1):
            try:
                status, data = api(method, path, self.token(), body)
            except (OSError, http.client.HTTPException, json.JSONDecodeError) as e:  # URLError, TimeoutError
                status, data = 0, {"error": f"{type(e).__name__}: {e}"}
            if attempt < attempts and (status == 0 or status == 429 or status >= 500):
                print(f"  retry {attempt}/{attempts - 1} in {2 ** attempt}s: {method} {path} -> HTTP {status}",
                      file=sys.stderr)
                time.sleep(2 ** attempt)
                continue
            break
        if status >= 300 or status == 0:
            if soft:
                return None
            die(f"{method} {path}: HTTP {status} {json.dumps(data, ensure_ascii=False)[:800]}")
        return data

    def get(self, path, soft=False):
        return self._call("GET", path, soft=soft)

    def get_all(self, path):
        """Every page of a collection -> (rows, {(type, id): included row})."""
        rows, included, url = [], {}, path
        while url:
            page = self.get(url)
            rows += page.get("data", [])
            for inc in page.get("included", []):
                included[(inc["type"], inc["id"])] = inc
            url = (page.get("links") or {}).get("next")
        return rows, included

    def write(self, method, path, body=None):
        if not self.apply:  # unreachable unless there is a bug; never let it through
            raise RuntimeError(f"refusing {method} {path}: not in --apply mode")
        return self._call(method, path, body)

    def upload_parts(self, ops, data: bytes):
        """Send each upload operation. Presigned URLs: no JWT."""
        if not self.apply:
            raise RuntimeError("refusing upload: not in --apply mode")
        for op in ops:
            chunk = data[op["offset"]:op["offset"] + op["length"]]
            headers = {h["name"]: h["value"] for h in op.get("requestHeaders") or []}
            req = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers=headers)
            try:
                with urllib.request.urlopen(req, timeout=300) as resp:
                    status = resp.status
            except urllib.error.HTTPError as e:
                status = e.code
            except (OSError, http.client.HTTPException) as e:
                die(f"upload part offset {op['offset']}: {type(e).__name__}: {e}")
            if status >= 300:
                die(f"upload part offset {op['offset']}: HTTP {status}")


# ------------------------------------------------------- shared lookups

def states_of(row) -> set:
    """appStoreVersion: appStoreState + appVersionState; appInfo: state + appStoreState."""
    a = row["attributes"]
    return {s for s in (a.get("appStoreState"), a.get("appVersionState"), a.get("state")) if s}


def is_editable(states: set) -> bool:
    return bool(states) and states <= EDITABLE


def is_live(states: set) -> bool:
    return bool(states) and states <= LIVE


def find_version(c: ASC, args):
    rows, _ = c.get_all(f"/v1/apps/{args.app_id}/appStoreVersions?filter[platform]={args.platform}"
                        f"&filter[versionString]={args.version}&limit=10")
    rows = [r for r in rows if r["attributes"]["versionString"] == args.version]
    if len(rows) != 1:
        die(f"{args.platform} {args.version}: found {len(rows)} appStoreVersions "
            f"(this script never creates one; asc_bind_version.py does)")
    v = rows[0]
    a, st = v["attributes"], states_of(v)
    verdict = ("EDITABLE" if is_editable(st)
               else "LIVE: not editable except promotionalText via `text --live-promo`" if is_live(st)
               else "NOT editable")
    print(f"=== {args.platform} {args.version}  id={v['id']}  appStoreState={a.get('appStoreState')}  "
          f"appVersionState={a.get('appVersionState')}  -> {verdict}")
    return v


def version_locs(c: ASC, version_id) -> dict:
    rows, _ = c.get_all(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")
    return {r["attributes"]["locale"]: r for r in rows}


def app_infos(c: ASC, app_id) -> list:
    rows, _ = c.get_all(f"/v1/apps/{app_id}/appInfos?limit=10")
    return rows


def app_info_locs(c: ASC, info_id) -> dict:
    rows, _ = c.get_all(f"/v1/appInfos/{info_id}/appInfoLocalizations?limit=50")
    return {r["attributes"]["locale"]: r for r in rows}


def ordered_locales(locs) -> list:
    return [l for l in LOCALES if l in locs] + sorted(l for l in locs if l not in LOCALES)


def preview(value, width=70) -> str:
    value = value or ""
    return repr(value if len(value) <= width else value[:width] + "...")


class Placed(NamedTuple):
    id: str
    name: str            # the image's fileName
    loc_id: str | None   # from the placement's OWN appStoreVersionLocalization relationship


def current_placements(c: ASC, loc_id, group=None) -> dict:
    """{placementGroup: [Placed]} in display order. Pass `group` when the order
    matters: placementGroupPosition is a per-group sort key. Docs: this endpoint
    takes include=appStoreVersionLocalization, which puts each placement's own
    localization link in its row; DeleteGuard checks it."""
    rows, inc = c.get_all(
        f"/v1/appStoreVersionLocalizations/{loc_id}/placements?filter[placementType]={PLACEMENT_TYPE}"
        + (f"&filter[placementGroup]={group}" if group else "")
        + "&sort=placementGroupPosition&include=image,appStoreVersionLocalization"
        "&fields[appAssetLibraryImages]=fileName,referenceName,state,specId,imageAsset"
        "&fields[appStoreVersionLocalizations]=locale&limit=50")
    out = {}
    for r in rows:
        rel = r.get("relationships") or {}
        img_ref = (rel.get("image") or {}).get("data") or {}
        loc_ref = (rel.get("appStoreVersionLocalization") or {}).get("data") or {}
        img = inc.get(("appAssetLibraryImages", img_ref.get("id")))
        name = img["attributes"].get("fileName") if img else "?"
        out.setdefault(r["attributes"]["placementGroup"], []).append(Placed(r["id"], name, loc_ref.get("id")))
    return out


def version_key(row):
    return [int(x) if x.isdigit() else -1 for x in row["attributes"]["versionString"].split(".")]


@dataclass
class DeleteGuard:
    """Asked before every placement DELETE, and for every planned removal in the
    dry run. Listing from the target localization's /placements already scopes the
    ids (docs: a placement links one asset to one surface); the guard does not
    rest on that alone."""
    target_loc_ids: set
    live: str        # "LIVE 1.6.0", or "" when there is no other READY_FOR_SALE version
    live_ids: dict   # placement id -> "LIVE 1.6.0 en-US"

    def problem(self, p: Placed, loc_id):
        if loc_id not in self.target_loc_ids:
            return f"placement {p.id} ({p.name}) was listed from {loc_id}, not a target localization"
        if p.loc_id != loc_id:
            return (f"placement {p.id} ({p.name}) names localization {p.loc_id} in its own relationship, "
                    f"not the target's {loc_id}")
        if p.id in self.live_ids:
            return f"placement {p.id} ({p.name}) is also on {self.live_ids[p.id]}"
        return None


def build_guard(c: ASC, args, v, vlocs) -> DeleteGuard:
    """List the LIVE version's placements now. Every superseded version still reports
    READY_FOR_SALE / READY_FOR_DISTRIBUTION (measured on iOS 1.5.0, 2026-10-14), so
    the LIVE one is the highest versionString in those states, other than the target.
    Measured the same day: 1.6.0 inherited 1.5.0's en-US 6.5" set as 4 NEW placement
    ids on the SAME 4 image ids, so a new version's placements are its own records;
    this guard is the backstop in case that ever stops holding."""
    rows, _ = c.get_all(f"/v1/apps/{args.app_id}/appStoreVersions?filter[platform]={args.platform}&limit=200")
    others = [r for r in rows if r["id"] != v["id"] and is_live(states_of(r))]
    guard = DeleteGuard({row["id"] for row in vlocs.values()}, "", {})
    if not others:
        print(f"  delete guard: no other READY_FOR_SALE {args.platform} version to protect")
        return guard
    live = max(others, key=version_key)
    vs = live["attributes"]["versionString"]
    # When the target is itself the newest READY_FOR_SALE version, it is the LIVE one
    # (the state check refuses every write); the guard still cross-checks the next one.
    target_is_live = is_live(states_of(v)) and version_key(v) > version_key(live)
    guard.live = f"{vs} (previous; the target is LIVE)" if target_is_live else f"LIVE {vs}"
    for locale, row in version_locs(c, live["id"]).items():
        for items in current_placements(c, row["id"]).values():
            guard.live_ids.update({p.id: f"{guard.live} {locale}" for p in items})
    print(f"  delete guard: {args.platform} {guard.live} has {len(guard.live_ids)} placement(s) "
          f"(listed now); none of them may be deleted")
    return guard


# ------------------------------------------------------------------- status

def cmd_status(c: ASC, args) -> int:
    v = find_version(c, args)
    locs = version_locs(c, v["id"])
    print("\n--- version localizations (chars/limit, current value)")
    for locale in ordered_locales(locs):
        a = locs[locale]["attributes"]
        print(f"[{locale}] loc={locs[locale]['id']}")
        for _, attr, limit, target in TEXT_FIELDS:
            if target == "version":
                val = a.get(attr) or ""
                print(f"    {attr:<16}{len(val):>5}/{limit:<5} {preview(val)}")
        wn = a.get("whatsNew") or ""
        print(f"    {'whatsNew':<16}{len(wn):>5}/4000  (asc_bind_version.py owns it)")

    print("\n--- appInfos (name / subtitle)")
    for info in app_infos(c, args.app_id):
        st = states_of(info)
        tag = "EDITABLE" if is_editable(st) else "live, never written" if is_live(st) else "not editable"
        print(f"appInfo {info['id']}  state={sorted(st)}  ({tag})")
        ilocs = app_info_locs(c, info["id"])
        for locale in ordered_locales(ilocs):
            a = ilocs[locale]["attributes"]
            n, s = a.get("name") or "", a.get("subtitle") or ""
            print(f"    [{locale}] name {len(n)}/30 {n!r}  |  subtitle {len(s)}/30 {s!r}")

    print(f"\n--- screenshot placements ({PLACEMENT_TYPE}, display order)")
    for locale in ordered_locales(locs):
        groups = current_placements(c, locs[locale]["id"])
        if not groups:
            print(f"[{locale}] none (the store falls back to the primary locale's screenshots)")
        for group, items in groups.items():
            print(f"[{locale}] {group}: {len(items)}  {', '.join(p.name for p in items)}")
    return 0


# --------------------------------------------------------------------- text

@dataclass
class Change:
    target: str     # "version" | "appinfo"
    locale: str
    row_id: str
    attr: str
    old: str
    new: str


def load_local_text(root: Path, stems) -> dict:
    """{locale: {stem: value}}. A missing file leaves that field alone."""
    out = {}
    for locale in LOCALES:
        for stem in stems:
            p = root / locale / f"{stem}.txt"
            if p.exists():
                out.setdefault(locale, {})[stem] = p.read_text(encoding="utf-8").rstrip("\r\n")
            else:
                print(f"  note: {p} missing; {stem} left alone for {locale}")
    return out


def validate_text(local, fields) -> list:
    errors = []
    print("--- local text (chars/limit)")
    for locale in LOCALES:
        cells = []
        for stem, attr, limit, _ in fields:
            if stem not in local.get(locale, {}):
                continue
            val = local[locale][stem]
            cell = f"{attr} {len(val)}/{limit}"
            if attr == "keywords":
                cell += f" ({len(val.encode())} UTF-8 bytes)"
            if len(val) > limit:
                errors.append(f"{locale} {attr}: {len(val)} chars > {limit}")
                cell += " OVER"
            if not val:
                errors.append(f"{locale} {attr}: empty file; refusing to blank the field")
            cells.append(cell)
        print(f"  [{locale}] " + "  ".join(cells))
    return errors


def plan_text(local, fields, vlocs, ilocs):
    changes, problems, same = [], [], []
    for locale in LOCALES:
        for stem, attr, _, target in fields:
            if stem not in local.get(locale, {}):
                continue
            row = (vlocs if target == "version" else ilocs).get(locale)
            if row is None:
                problems.append(f"{locale}: the target has no {target} localization (this script does not create one)")
                continue
            old, new = row["attributes"].get(attr) or "", local[locale][stem]
            if old == new:
                same.append(f"{locale}.{attr}")
            else:
                changes.append(Change(target, locale, row["id"], attr, old, new))
    return changes, problems, same


def print_change(ch: Change):
    label = f"[{ch.locale}] {ch.target}.{ch.attr}"
    if ch.attr == "description":
        print(f"{label}: {len(ch.old)} → {len(ch.new)} chars")
        for line in difflib.unified_diff(ch.old.splitlines(), ch.new.splitlines(),
                                         "current", "local", lineterm="", n=0):
            print(f"      {line}")
    else:
        print(f"{label}: {ch.old!r} → {ch.new!r}")


def text_targets(c: ASC, args, fields, refusals) -> dict:
    """appInfo localizations to diff against: the single editable appInfo, else
    (for display only, with a refusal recorded) the live one."""
    if not any(f[3] == "appinfo" for f in fields):
        return {}
    infos = app_infos(c, args.app_id)
    editable = [i for i in infos if is_editable(states_of(i))]
    if len(editable) == 1:
        print(f"appInfo target: {editable[0]['id']} {sorted(states_of(editable[0]))}")
        return app_info_locs(c, editable[0]["id"])
    refusals.append(f"name/subtitle: {len(editable)} appInfos in an editable state (need exactly 1); "
                    f"the live appInfo is never written")
    live = [i for i in infos if is_live(states_of(i))]
    if not live:
        return {}
    print(f"(name/subtitle diffed against the LIVE appInfo {live[0]['id']}, for information only)")
    return app_info_locs(c, live[0]["id"])


def cmd_text(c: ASC, args) -> int:
    v = find_version(c, args)
    st = states_of(v)
    fields = [f for f in TEXT_FIELDS if f[1] == "promotionalText"] if args.live_promo else list(TEXT_FIELDS)
    refusals = []
    if args.live_promo and not is_live(st):
        refusals.append(f"--live-promo needs a READY_FOR_SALE version; {args.version} is {sorted(st)}"
                        + (" (it is editable: drop --live-promo)" if is_editable(st) else ""))
    elif not args.live_promo and not is_editable(st):
        refusals.append(f"{args.version} is {sorted(st)}, not editable ({', '.join(sorted(EDITABLE))})"
                        + ("; promotionalText alone can go to it with --live-promo" if is_live(st) else ""))

    local = load_local_text(Path(args.metadata_root), [f[0] for f in fields])
    errors = validate_text(local, fields)
    ilocs = text_targets(c, args, fields, refusals)
    changes, problems, same = plan_text(local, fields, version_locs(c, v["id"]), ilocs)
    errors += problems

    print(f"\n--- changes ({len(changes)}; unchanged: {', '.join(same) or 'none'})")
    for ch in changes:
        print_change(ch)
    if errors:
        print("\nINVALID (nothing written):")
        for e in errors:
            print(f"  - {e}")
        return 1
    if refusals:
        print(f"\nWRITES {'REFUSED' if args.apply else 'WOULD BE REFUSED'}:")
        for r in refusals:
            print(f"  - {r}")
        return 2 if args.apply else 0
    if not changes:
        print("\nnothing to change")
        return 0
    if not args.apply:
        print("\ndry run: re-run with --apply to write")
        return 0
    if args.live_promo and any(ch.target != "version" or ch.attr != "promotionalText" for ch in changes):
        die("internal: --live-promo plan contains more than promotionalText")
    return apply_text(c, changes)


def apply_text(c: ASC, changes) -> int:
    rtype = {"version": "appStoreVersionLocalizations", "appinfo": "appInfoLocalizations"}
    by_row = {}
    for ch in changes:
        by_row.setdefault((ch.target, ch.row_id), {})[ch.attr] = ch.new
    print("\n--- writing")
    for (target, rid), attrs in by_row.items():
        c.write("PATCH", f"/v1/{rtype[target]}/{rid}",
                {"data": {"type": rtype[target], "id": rid, "attributes": attrs}})
        print(f"  PATCH {rtype[target]}/{rid}: {', '.join(attrs)}")
    print("\n--- read-back")
    bad = 0
    for (target, rid), attrs in by_row.items():
        got = c.get(f"/v1/{rtype[target]}/{rid}")["data"]["attributes"]
        for attr, want in attrs.items():
            ok = (got.get(attr) or "") == want
            bad += not ok
            print(f"  {'OK  ' if ok else 'DIFF'} {got.get('locale')} {target}.{attr}")
    return 3 if bad else 0


# -------------------------------------------------------------- screenshots

@dataclass
class Shot:
    locale: str
    group: str
    devdir: str
    path: Path
    size: int
    md5: str
    width: int | None
    height: int | None
    color_type: int | None
    has_trns: bool

    @property
    def has_alpha(self) -> bool:
        return self.color_type in (4, 6) or self.has_trns


def png_header(data: bytes):
    """(width, height, color type, has tRNS) or None if not a PNG."""
    if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    width, height = struct.unpack(">II", data[16:24])
    color_type, has_trns, pos = data[25], False, 8
    while pos + 8 <= len(data):  # tRNS must precede IDAT
        length, kind = struct.unpack(">I", data[pos:pos + 4])[0], data[pos + 4:pos + 8]
        if kind == b"tRNS":
            has_trns = True
        if kind in (b"IDAT", b"IEND"):
            break
        pos += 12 + length
    return width, height, color_type, has_trns


def read_shot(locale, devdir, path: Path) -> Shot:
    data = path.read_bytes()
    w, h, ct, trns = png_header(data) or (None, None, None, False)
    return Shot(locale, DEVICE_GROUPS[devdir], devdir, path, len(data),
                hashlib.md5(data).hexdigest(), w, h, ct, trns)


def visible(d: Path) -> list:
    return sorted(p for p in d.iterdir() if not p.name.startswith("."))


def is_image(p: Path) -> bool:
    return p.is_file() and p.suffix.lower() in IMAGE_SUFFIXES and p.name != CONTACT_SHEET


LOCALE_LIKE = {n.lower().replace("-", "_") for n in (*LOCALE_DIRS, *LOCALE_DIRS.values())}
DEVICE_LIKE = {n.lower() for n in DEVICE_GROUPS}


def scan_local(src_root: Path):
    """{(locale, group): [Shot] in filename order}, what was ignored, and what is
    misfiled. A misfiled image would silently shrink the set (and read_back compares
    against the same shrunken set), so misfiles fail the gate instead of being skipped."""
    if not src_root.is_dir():
        die(f"--src-root {src_root} is not a directory")
    sets, ignored, misfiled = {}, [], []
    for locdir in visible(src_root):
        if locdir.name not in LOCALE_DIRS or not locdir.is_dir():
            if locdir.is_dir() and locdir.name.lower() in DEVICE_LIKE:
                misfiled.append(f"{locdir.name}/: device folder with no locale folder above it")
            elif locdir.is_dir() and (locdir.name.lower().replace("-", "_") in LOCALE_LIKE
                                      or any(d.name.lower() in DEVICE_LIKE for d in visible(locdir) if d.is_dir())):
                misfiled.append(f"{locdir.name}/: looks like a locale folder but is not one of {', '.join(LOCALE_DIRS)}")
            else:
                ignored.append(locdir.name)
            continue
        for devdir in visible(locdir):
            rel = f"{locdir.name}/{devdir.name}"
            if devdir.is_dir() and devdir.name not in DEVICE_GROUPS:
                misfiled.append(f"{rel}/: unknown folder in a locale folder (expected {', '.join(DEVICE_GROUPS)})")
            elif is_image(devdir):
                misfiled.append(f"{rel}: image loose in a locale folder (it belongs in a device folder)")
            elif not devdir.is_dir():
                ignored.append(rel)
            else:
                misfiled += scan_device_dir(sets, ignored, locdir.name, devdir)
    return sets, ignored, misfiled


def scan_device_dir(sets, ignored, locname, devdir: Path) -> list:
    misfiled, first_of = [], {}
    key = (LOCALE_DIRS[locname], DEVICE_GROUPS[devdir.name])
    for f in visible(devdir):
        rel = f"{locname}/{devdir.name}/{f.name}"
        if f.is_dir():
            misfiled.append(f"{rel}/: folder inside a device folder")
        elif not is_image(f):
            ignored.append(rel)
        elif not SHOT_RE.match(f.name):
            misfiled.append(f"{rel}: not NN-name.png (two digits, '-', [A-Za-z0-9-], lower-case .png)")
        elif f.name[:2] in first_of:
            misfiled.append(f"{rel}: same NN as {first_of[f.name[:2]]}")
        else:
            first_of[f.name[:2]] = f.name
            sets.setdefault(key, []).append(read_shot(key[0], devdir.name, f))
    return misfiled


def load_rules(c: ASC, groups, legacy_sets: bool) -> dict:
    """{group: {"specs": [imageSpec], "max": n}} from GET /v1/appAssetLibraryRefData:
    features -> placementPolicies -> groupLimits for the cap, placementTypes ->
    specMappings for the accepted specs, placementProfileGroups to confirm the id."""
    body = c.get("/v1/appAssetLibraryRefData?fields[appAssetLibraryRefData]="
                 "features,placementTypes,placementProfileGroups,imageSpecs", soft=legacy_sets)
    if body is None:  # only reachable with --legacy-sets
        print("  WARNING: ref data unreadable; --legacy-sets falls back to the built-in sizes")
        return {g: {"max": 10, "specs": [{
            "specId": None, "shortName": f"i{w}x{h}a0 (built-in)", "alphaAllowed": False,
            "fileExtensions": [".png"], "maxFileSize": None,
            "dimensions": {"minWidth": w, "maxWidth": w, "minHeight": h, "maxHeight": h}}]}
            for g, (w, h) in FALLBACK_SIZES.items() if g in groups}
    attrs = body["data"][0]["attributes"]
    specs = {s["specId"]: s for s in attrs.get("imageSpecs", [])}
    known = {g["placementProfileGroupId"]: g for g in attrs.get("placementProfileGroups", [])}
    mapping = {}
    for pt in attrs.get("placementTypes", []):
        if pt["placementTypeId"] == PLACEMENT_TYPE:
            if ASSET_CATEGORY not in pt.get("acceptsAssetCategories", []):
                die(f"ref data: {PLACEMENT_TYPE} no longer accepts {ASSET_CATEGORY}")
            mapping = {m["placementGroupId"]: m["specs"] for m in pt["specMappings"]}
    limits = {}
    for feat in attrs.get("features", []):
        if feat["featureId"] == "APP_STORE_VERSIONS":
            for pol in feat["placementPolicies"]:
                if pol["placementType"] == PLACEMENT_TYPE:
                    for gl in pol["groupLimits"]:
                        limits.update({gid: gl["maxCount"] for gid in gl["groupIds"]})
    rules = {}
    for g in groups:
        if g not in mapping or g not in limits or known.get(g, {}).get("platform") != "IPHONE_APP_STORE":
            die(f"ref data has no iPhone {PLACEMENT_TYPE} group {g} (renamed by Apple? update DEVICE_GROUPS)")
        rules[g] = {"max": limits[g], "specs": [specs[s] for s in mapping[g] if s in specs]}
    return rules


def spec_for(shot: Shot, rule):
    for s in rule["specs"]:
        d = s["dimensions"]
        if (d["minWidth"] <= shot.width <= d["maxWidth"] and d["minHeight"] <= shot.height <= d["maxHeight"]
                and shot.path.suffix.lower() in s.get("fileExtensions", [".png"])):
            return s
    return None


def run_gate(sets, rules, src_root: Path) -> list:
    errors, by_md5 = [], {}
    rel = lambda s: str(s.path.relative_to(src_root))  # noqa: E731
    for (locale, group), shots in sorted(sets.items(), key=lambda kv: (LOCALES.index(kv[0][0]), kv[0][1])):
        rule = rules[group]
        if len(shots) > rule["max"]:
            errors.append(f"{locale} {group}: {len(shots)} files > limit {rule['max']}")
        matched = set()
        for s in shots:
            by_md5.setdefault(s.md5, []).append(s)
            if s.width is None:
                errors.append(f"{rel(s)}: not a PNG")
                continue
            spec = spec_for(s, rule)
            if spec is None:
                errors.append(f"{rel(s)}: {s.width}x{s.height} not accepted by {group} "
                              f"({', '.join(x['shortName'] for x in rule['specs'])})")
                continue
            matched.add(spec["shortName"])
            if s.has_alpha and not spec.get("alphaAllowed"):
                errors.append(f"{rel(s)}: alpha channel (PNG color type {s.color_type}"
                              f"{', tRNS' if s.has_trns else ''}); {spec['shortName']} forbids alpha")
            if spec.get("maxFileSize") and s.size > spec["maxFileSize"]:
                errors.append(f"{rel(s)}: {s.size} bytes > {spec['maxFileSize']}")
        print(f"  [{locale}] {group}: {len(shots)}/{rule['max']}  spec {', '.join(sorted(matched)) or '-'}  "
              f"{', '.join(s.path.name for s in shots)}")
    for md5, dup in by_md5.items():
        if len(dup) > 1:
            errors.append(f"identical files (md5 {md5}): {', '.join(rel(s) for s in dup)}")
    return errors


def print_plan(c: ASC, sets, vlocs, replace_65: bool, legacy_sets: bool, guard: DeleteGuard) -> list:
    """Per-locale placement plan against the target version. Every placement it
    would remove goes through the delete guard now, before any write. Returns problems."""
    problems, doomed_total = [], 0
    for locale in [l for l in LOCALES if l in vlocs or any(k[0] == l for k in sets)]:
        local_groups = [g for g in DEVICE_GROUPS.values() if (locale, g) in sets]
        if locale not in vlocs:
            problems.append(f"{locale}: local screenshots but no localization on the target version")
            continue
        loc_id = vlocs[locale]["id"]
        cur, doomed = current_placements(c, loc_id), []
        print(f"[{locale}] loc={loc_id}")
        for group in DEVICE_GROUPS.values():
            have = cur.get(group, [])
            if (locale, group) in sets:
                shots = sets[(locale, group)]
                how = f"into a {LEGACY_DISPLAY_TYPES[group]} set" if legacy_sets else "place+order"
                print(f"    {group}: now {len(have)} [{', '.join(p.name for p in have)}]"
                      f" -> upload {len(shots)}, {how} [{', '.join(s.path.name for s in shots)}],"
                      f" remove {len(have)} superseded placement(s)")
                doomed += have
            else:
                print(f"    {group}: no local files -> untouched (now {len(have)})")
        old65 = cur.get(LEGACY_65_GROUP, [])
        if replace_65 and LARGE in local_groups:
            print(f"    {LEGACY_65_GROUP} (6.5\"): remove {len(old65)} placement(s); their images stay in the library")
            doomed += old65
        elif old65:
            why = "--no-replace-legacy-65" if not replace_65 else f"no local {LARGE} files for {locale}"
            print(f"    {LEGACY_65_GROUP} (6.5\"): {len(old65)} kept ({why})")
        for group in sorted(set(cur) - set(DEVICE_GROUPS.values()) - {LEGACY_65_GROUP}):
            print(f"    {group}: {len(cur[group])} untouched (not managed here)")
        problems += [f"{locale}: would refuse to delete: {why}" for why in
                     (guard.problem(p, loc_id) for p in doomed) if why]
        doomed_total += len(doomed)
    print(f"  delete guard: {doomed_total} planned removal(s) checked (target localization, the placement's "
          f"own localization link, not on {guard.live or 'another READY_FOR_SALE version: none'})")
    return problems


def cmd_screenshots(c: ASC, args) -> int:
    if args.platform != "IOS":
        die("screenshots manages iPhone placement groups only; use --platform IOS")
    replace_65 = True if args.replace_legacy_65 is None else args.replace_legacy_65
    v = find_version(c, args)
    src_root = Path(args.src_root).resolve()
    sets, ignored, errors = scan_local(src_root)
    if ignored:
        print(f"  ignored under {src_root}: {', '.join(ignored)}")
    if not sets and not errors:
        die(f"no NN-name.png screenshots under {src_root}/<locale dir>/<device dir>/")

    print("\n--- pre-upload gate")
    if sets:
        rules = load_rules(c, sorted({g for _, g in sets}), args.legacy_sets)
        errors += run_gate(sets, rules, src_root)
    if errors:
        print("\nGATE FAILED (nothing written):")
        for e in errors:
            print(f"  - {e}")
        return 1
    print("  gate passed: tree well-formed, md5 distinct, sizes accepted, no alpha, within limits")

    print(f"\n--- plan ({'deprecated appScreenshotSets uploads' if args.legacy_sets else 'App Asset Library'}"
          f"; removal = placement DELETE only)")
    vlocs = version_locs(c, v["id"])
    guard = build_guard(c, args, v, vlocs)
    problems = print_plan(c, sets, vlocs, replace_65, args.legacy_sets, guard)
    if problems:
        print("\nINVALID (nothing written):")
        for p in problems:
            print(f"  - {p}")
        return 1
    if not is_editable(states_of(v)):
        print(f"\nWRITES {'REFUSED' if args.apply else 'WOULD BE REFUSED'}: {args.version} is "
              f"{sorted(states_of(v))}, not editable ({', '.join(sorted(EDITABLE))}). "
              f"Placements can only change on an editable version.")
        return 2 if args.apply else 0
    if not args.apply:
        print("\ndry run: re-run with --apply to write")
        return 0
    if args.legacy_sets:
        apply_legacy_sets(c, sets, rules, vlocs, guard)
    else:
        apply_asset_library(c, args, sets, rules, vlocs, guard)
    if replace_65:
        remove_legacy_65(c, guard, sets, vlocs)
    return read_back(c, sets, vlocs, replace_65)


# ------------------------------------------- screenshots: asset library writes

def reserve_and_upload_image(c: ASC, library_id, shot: Shot, version) -> str:
    body = {"data": {
        "type": "appAssetLibraryImages",
        "attributes": {"fileName": shot.path.name, "fileSize": shot.size, "category": ASSET_CATEGORY,
                       "referenceName": f"RoastMate {version} {shot.locale} {shot.devdir} {shot.path.name}"},
        "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": library_id}}},
    }}
    img = c.write("POST", "/v1/appAssetLibraryImages", body)["data"]
    c.upload_parts(img["attributes"]["uploadOperations"], shot.path.read_bytes())
    # Asset-library commits take `uploaded` alone; no sourceFileChecksum (unlike appScreenshots).
    c.write("PATCH", f"/v1/appAssetLibraryImages/{img['id']}",
            {"data": {"type": "appAssetLibraryImages", "id": img["id"], "attributes": {"uploaded": True}}})
    return img["id"]


def wait_image(c: ASC, image_id, shot: Shot, rule):
    deadline = time.time() + POLL_TIMEOUT
    while True:
        a = c.get(f"/v1/appAssetLibraryImages/{image_id}")["data"]["attributes"]
        if a.get("state") in IMAGE_PENDING and time.time() < deadline:
            time.sleep(POLL_SECONDS)
            continue
        if a.get("state") not in IMAGE_READY:
            die(f"{shot.locale} {shot.path.name}: image {image_id} is {a.get('state')} "
                f"{a.get('stateDetails')} (left in the library with no placements)")
        if a.get("specId") not in {s["specId"] for s in rule["specs"]}:
            die(f"{shot.locale} {shot.path.name}: processed as spec {a.get('specId')}, not one {shot.group} accepts")
        ia = a.get("imageAsset") or {}
        if (ia.get("width"), ia.get("height")) != (shot.width, shot.height):
            die(f"{shot.locale} {shot.path.name}: processed as {ia.get('width')}x{ia.get('height')}")
        return


def remove_placements(c: ASC, guard: DeleteGuard, loc_id, placed):
    """The script's ONLY delete, in both modes. Every placement passes the guard
    before the first DELETE goes out. Images are never deleted."""
    for p in placed:
        why = guard.problem(p, loc_id)
        if why:
            die(f"refusing DELETE: {why}")
    for p in placed:
        c.write("DELETE", f"/v1/appAssetLibraryPlacements/{p.id}")


def replace_group(c: ASC, guard: DeleteGuard, loc_id, group, limit, count, add):
    """Swap a group's placements on the target localization for what add() creates
    (returns the new ids for ordering). New ones go in first when old+new fits the
    group limit, so a failure leaves the old set showing; otherwise the old ones go
    first (a rerun of the same 6 onto 6 would hit the cap of 10)."""
    old = current_placements(c, loc_id, group).get(group, [])
    create_first = len(old) + count <= limit
    if not create_first:
        remove_placements(c, guard, loc_id, old)
    new = add()
    if create_first:
        remove_placements(c, guard, loc_id, old)
    return new, len(old)


def apply_asset_library(c: ASC, args, sets, rules, vlocs, guard: DeleteGuard):
    library_id = c.get(f"/v1/apps/{args.app_id}/assetLibrary")["data"]["id"]
    shots = [s for key in sorted(sets) for s in sets[key]]

    # 1. Upload every file once. Nothing on the product page changes yet.
    print(f"\n--- uploading {len(shots)} image(s) to library {library_id}")
    image_ids = {}
    for s in shots:
        image_ids[s.path] = reserve_and_upload_image(c, library_id, s, args.version)
        print(f"  committed {s.locale} {s.devdir}/{s.path.name} -> {image_ids[s.path]}")
    for s in shots:
        wait_image(c, image_ids[s.path], s, rules[s.group])
    print("  all images processed; specId and size confirmed")

    # 2. Per (locale, group): place the new images, drop the superseded placements,
    #    then order. Ordering runs last so orderedPlacements names exactly the group.
    print("\n--- placing")
    for (locale, group), group_shots in sorted(sets.items()):
        loc_id = vlocs[locale]["id"]

        def place(group_shots=group_shots, group=group, loc_id=loc_id):
            return [c.write("POST", "/v1/appAssetLibraryPlacements", {"data": {
                "type": "appAssetLibraryPlacements",
                "attributes": {"placementType": PLACEMENT_TYPE, "placementGroup": group},
                "relationships": {
                    "image": {"data": {"type": "appAssetLibraryImages", "id": image_ids[s.path]}},
                    "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}},
                }}})["data"]["id"] for s in group_shots]

        new, removed = replace_group(c, guard, loc_id, group, rules[group]["max"], len(group_shots), place)
        c.write("POST", "/v1/appAssetLibraryPlacementOrderingRequests", {"data": {
            "type": "appAssetLibraryPlacementOrderingRequests",
            "attributes": {"placementGroup": group},
            "relationships": {
                "orderedPlacements": {"data": [{"type": "appAssetLibraryPlacements", "id": p} for p in new]},
                "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": loc_id}},
            }}})
        print(f"  [{locale}] {group}: placed+ordered {len(new)}, removed {removed} superseded placement(s)")


def remove_legacy_65(c: ASC, guard: DeleteGuard, sets, vlocs):
    """The inherited 6.5" set, only where this run gave the locale a 6.9" set."""
    for locale in sorted({l for l, g in sets if g == LARGE}, key=LOCALES.index):
        loc_id = vlocs[locale]["id"]
        old65 = current_placements(c, loc_id, LEGACY_65_GROUP).get(LEGACY_65_GROUP, [])
        remove_placements(c, guard, loc_id, old65)
        print(f"  [{locale}] {LEGACY_65_GROUP}: removed {len(old65)} placement(s); images kept")


# ------------------------------------- screenshots: deprecated set-model uploads

def find_or_create_set(c: ASC, loc_id, display_type):
    rows, _ = c.get_all(f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets"
                        f"?filter[screenshotDisplayType]={display_type}&limit=10")
    if rows:
        return rows[0]["id"]
    return c.write("POST", "/v1/appScreenshotSets", {"data": {
        "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
        "relationships": {"appStoreVersionLocalization": {
            "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}})["data"]["id"]


def upload_legacy_screenshot(c: ASC, set_id, s: Shot) -> str:
    row = c.write("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots", "attributes": {"fileName": s.path.name, "fileSize": s.size},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
    c.upload_parts(row["attributes"]["uploadOperations"], s.path.read_bytes())
    c.write("PATCH", f"/v1/appScreenshots/{row['id']}", {"data": {
        "type": "appScreenshots", "id": row["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": s.md5}}})
    return row["id"]


def wait_screenshot(c: ASC, shot_id, shot: Shot):
    deadline = time.time() + POLL_TIMEOUT
    while True:
        st = (c.get(f"/v1/appScreenshots/{shot_id}")["data"]["attributes"].get("assetDeliveryState") or {})
        if st.get("state") == "COMPLETE":
            return
        if st.get("state") == "FAILED" or time.time() > deadline:
            die(f"{shot.locale} {shot.path.name}: appScreenshot {shot_id} {st}")
        time.sleep(POLL_SECONDS)


def require_exact_set(c: ASC, set_id, ids, label):
    """Docs title the set-model reorder PATCH "Replace all app screenshots for an app
    screenshot set" (deprecated -> placement ordering request) and do not say what it
    does to a screenshot left out of the list. Send it only when the set holds exactly
    the screenshots this run uploaded, so nothing is left out."""
    rows, _ = c.get_all(f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots?limit=200")
    have, want = {r["id"] for r in rows}, set(ids)
    if have != want:
        die(f"{label}: set {set_id} holds {len(have)} screenshot(s), {len(have - want)} not uploaded by this "
            f"run, {len(want - have)} of this run's missing; refusing the 'replace all' reorder PATCH. "
            f"The new screenshots are uploaded: order them in the ASC web UI.")


def apply_legacy_sets(c: ASC, sets, rules, vlocs, guard: DeleteGuard):
    """Uploads go through the deprecated set model; superseded screenshots are removed
    as placements by remove_placements(), never with DELETE /v1/appScreenshots."""
    print("\n--- uploading via deprecated appScreenshotSets (removal via placement DELETE)")
    for (locale, group), group_shots in sorted(sets.items()):
        loc_id = vlocs[locale]["id"]
        set_id = find_or_create_set(c, loc_id, LEGACY_DISPLAY_TYPES[group])

        def upload(group_shots=group_shots, set_id=set_id):
            ids = [upload_legacy_screenshot(c, set_id, s) for s in group_shots]
            for sid, s in zip(ids, group_shots):
                wait_screenshot(c, sid, s)
            return ids

        ids, removed = replace_group(c, guard, loc_id, group, rules[group]["max"], len(group_shots), upload)
        require_exact_set(c, set_id, ids, f"{locale} {LEGACY_DISPLAY_TYPES[group]}")
        c.write("PATCH", f"/v1/appScreenshotSets/{set_id}/relationships/appScreenshots",
                {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
        print(f"  [{locale}] {LEGACY_DISPLAY_TYPES[group]}: uploaded+ordered {len(ids)}, "
              f"removed {removed} superseded placement(s)")


# ---------------------------------------------------------------- read-back

def read_back(c: ASC, sets, vlocs, replace_65: bool) -> int:
    """Read from the placement model in both modes: it is what the removals act on,
    and the set-model screenshots show up there too (the live 6.5" set does)."""
    print("\n--- read-back")
    bad = 0
    for locale in sorted({l for l, _ in sets}, key=LOCALES.index):
        loc_id = vlocs[locale]["id"]
        for group in DEVICE_GROUPS.values():
            if (locale, group) not in sets:
                continue
            want = [s.path.name for s in sets[(locale, group)]]
            got = [p.name for p in current_placements(c, loc_id, group).get(group, [])]
            ok = got == want
            bad += not ok
            print(f"  {'OK  ' if ok else 'DIFF'} [{locale}] {group}: {len(got)}/{len(want)}  {', '.join(got)}")
        if replace_65 and (locale, LARGE) in sets:
            left = current_placements(c, loc_id, LEGACY_65_GROUP).get(LEGACY_65_GROUP, [])
            bad += bool(left)
            print(f"  {'DIFF' if left else 'OK  '} [{locale}] {LEGACY_65_GROUP}: {len(left)} left")
    return 3 if bad else 0


# --------------------------------------------------------------------- main

def build_parser():
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--version", required=True, help="appStoreVersion versionString, e.g. 1.7.0")
    common.add_argument("--platform", default="IOS", choices=("IOS", "MAC_OS"))
    common.add_argument("--app-id", default=os.environ.get("ASC_APP_ID", "6769317103"))
    common.add_argument("--issuer", default=os.environ.get("ASC_ISSUER_ID", "c5671c11-49ec-47d9-bd38-5e3c1a249416"))
    common.add_argument("--key-id", default=os.environ.get("ASC_KEY_ID", "DMMFP6XTXX"))
    common.add_argument("--key-path", default=os.environ.get("ASC_KEY_PATH"),
                        help="default ~/private_keys/AuthKey_<KEY_ID>.p8")

    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status", parents=[common], help="read-only report for one version")

    t = sub.add_parser("text", parents=[common],
                       help="keywords/description/promotionalText + name/subtitle (dry run unless --apply)")
    t.add_argument("--metadata-root", default=str(REPO / "metadata"),
                   help="holds <locale>/{keywords,description,promotional_text,name,subtitle}.txt")
    t.add_argument("--apply", action="store_true", help="actually write (default: dry run)")
    t.add_argument("--live-promo", action="store_true",
                   help="target a READY_FOR_SALE version and write ONLY promotionalText")

    s = sub.add_parser("screenshots", parents=[common],
                       help="iPhone screenshots via the App Asset Library (dry run unless --apply)")
    s.add_argument("--src-root", default=str(REPO / "metadata" / "screenshots"),
                   help="holds <en_US|zh_Hans|zh_Hant|ja_JP>/<iPhone_17_Pro_Max|iPhone_17_Pro>/NN-name.png")
    s.add_argument("--apply", action="store_true", help="actually write (default: dry run)")
    s.add_argument("--replace-legacy-65", action=argparse.BooleanOptionalAction, default=None,
                   help=f"remove the target version's {LEGACY_65_GROUP} (6.5\") screenshots in each locale "
                        f"that gets a 6.9\" set (default: on)")
    s.add_argument("--legacy-sets", action="store_true",
                   help="upload through the deprecated appScreenshotSets/appScreenshots flow instead "
                        "(only if the asset-library upload endpoints stop working). Superseded "
                        "screenshots are still removed with the guarded placement DELETE, never "
                        "DELETE /v1/appScreenshots, so the placement GET/DELETE endpoints must work")
    return ap


def main() -> int:
    args = build_parser().parse_args()
    # api() passes no timeout to urlopen, so urlopen falls back to this socket default
    # (connect and every read). upload_parts() sets its own, longer one.
    socket.setdefaulttimeout(API_TIMEOUT)
    c = ASC(args, apply=getattr(args, "apply", False))
    return {"status": cmd_status, "text": cmd_text, "screenshots": cmd_screenshots}[args.cmd](c, args)


if __name__ == "__main__":
    sys.exit(main())
