#!/bin/bash
# Gate and extract the App Store screenshots from the .xcresult bundles
# that scripts/screenshots.sh produced, into
# metadata/screenshots/{locale}/{device}/, named by scene
# (01-generator-empty.png, …) from the XCTAttachment names.
#
# Nothing in metadata/ is touched unless EVERY bundle passes the gate:
#   - the bundle's test run passed (xcresulttool test-results summary);
#   - it has at least one NN-scene.png attachment;
#   - within a locale, every PNG's md5 is distinct (the 2026-05 sets had
#     5 of 6 byte-identical frames);
#   - across locales, no PNG is byte-identical to another locale's (that
#     is what a locale that never reached the app looks like).
# The previous version deleted the old set before extracting and skipped
# a failed export with `continue`, so a bad run silently replaced a good
# set with nothing.
#
# Env overrides: SCREENSHOTS_RESULT_DIR (bundles; default build/Screenshots),
# SCREENSHOTS_DEST (default metadata/screenshots).
#
# Xcode 26+: `xcresulttool export attachments` writes UUID-named files plus
# a manifest mapping each to its XCTAttachment name.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${SCREENSHOTS_RESULT_DIR:-$PROJECT_DIR/build/Screenshots}"
DEST="${SCREENSHOTS_DEST:-$PROJECT_DIR/metadata/screenshots}"

if [ ! -d "$SOURCE" ]; then
  echo "ERROR: $SOURCE does not exist. Run scripts/screenshots.sh first."
  exit 1
fi

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

shopt -s nullglob
bundles=("$SOURCE"/*.xcresult)
shopt -u nullglob
if [ ${#bundles[@]} -eq 0 ]; then
  echo "ERROR: no .xcresult bundles in $SOURCE."
  exit 1
fi

for bundle in "${bundles[@]}"; do
  base=$(basename "$bundle" .xcresult)
  device="${base%%__*}"
  locale="${base##*__}"
  echo "==> $device / $locale"

  result=$(xcrun xcresulttool get test-results summary --path "$bundle" 2>/dev/null \
    | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin).get("result", ""))
except Exception:
    print("unreadable")
') || result="unreadable"
  if [ "$result" != "Passed" ]; then
    echo "  REFUSED: test result is '$result' — open the bundle and fix the run."
    exit 1
  fi

  export_dir="$STAGING/export/$base"
  mkdir -p "$export_dir" "$STAGING/out/$locale/$device"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$export_dir" >/dev/null

  python3 - "$export_dir" "$STAGING/out/$locale/$device" <<'PY'
import json, os, re, shutil, sys
tmp, out = sys.argv[1], sys.argv[2]
manifest = os.path.join(tmp, "manifest.json")
if not os.path.exists(manifest):
    sys.exit("  REFUSED: no manifest.json — the run produced no attachments")
def iter_atts(node):
    if isinstance(node, dict):
        if "exportedFileName" in node:
            yield node
        for v in node.values():
            yield from iter_atts(v)
    elif isinstance(node, list):
        for v in node:
            yield from iter_atts(v)
count = 0
for att in iter_atts(json.load(open(manifest))):
    src = os.path.join(tmp, att["exportedFileName"])
    name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
    name = re.sub(r"_\d+_[0-9A-Fa-f-]+(\.png)$", r"\1", name)
    if not name.endswith(".png"):
        name += ".png"
    # Scene captures only (NN-name.png); skip XCTest's own failure shots.
    if not os.path.exists(src) or not re.match(r"^\d\d-[A-Za-z0-9-]+\.png$", name):
        continue
    shutil.copyfile(src, os.path.join(out, name))
    count += 1
if count == 0:
    sys.exit("  REFUSED: no NN-scene.png attachments in this bundle")
print(f"  {count} screenshots")
PY
done

python3 - "$STAGING/out" <<'PY'
import hashlib, os, struct, sys
root = sys.argv[1]
seen = {}          # md5 -> first path
problems = []
for locale in sorted(os.listdir(root)):
    for device in sorted(os.listdir(os.path.join(root, locale))):
        d = os.path.join(root, locale, device)
        for name in sorted(os.listdir(d)):
            path = os.path.join(d, name)
            data = open(path, "rb").read()
            w, h = struct.unpack(">II", data[16:24])
            md5 = hashlib.md5(data).hexdigest()
            rel = f"{locale}/{device}/{name}"
            print(f"  {rel}  {w}x{h}  {md5}")
            if md5 in seen:
                problems.append(f"{rel} is byte-identical to {seen[md5]}")
            else:
                seen[md5] = rel
if problems:
    print("REFUSED — duplicate frames (a scene did not change the screen, or a locale did not apply):")
    for p in problems:
        print("  " + p)
    sys.exit(1)
print("Gate passed: every PNG is distinct.")
PY

for locale_dir in "$STAGING/out"/*; do
  locale=$(basename "$locale_dir")
  for device_dir in "$locale_dir"/*; do
    device=$(basename "$device_dir")
    out="$DEST/$locale/$device"
    mkdir -p "$out"
    shopt -s nullglob
    old=("$out"/*.png)
    shopt -u nullglob
    if [ ${#old[@]} -gt 0 ]; then
      /usr/bin/trash "${old[@]}"
    fi
    cp "$device_dir"/*.png "$out"/
  done
done

echo ""
echo "Screenshots in: $DEST — now LOOK at every image before uploading."
