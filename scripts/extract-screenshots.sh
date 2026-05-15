#!/bin/bash
# Walk the .xcresult bundles produced by screenshots.sh and copy out
# each XCTAttachment PNG into metadata/screenshots/{locale}/{device}/,
# renamed to its scene name (01-generator-empty.png, …) using the
# manifest.json that `xcresulttool export attachments` emits.
#
# Xcode 26's `xcresulttool get attachments` was removed; the supported
# path is `export attachments`, which writes UUID-named files plus a
# manifest mapping each to its suggested (XCTAttachment `name`) value.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$PROJECT_DIR/build/Screenshots"
DEST="$PROJECT_DIR/metadata/screenshots"

if [ ! -d "$SOURCE" ]; then
  echo "ERROR: $SOURCE does not exist. Run scripts/screenshots.sh first."
  exit 1
fi

mkdir -p "$DEST"

for bundle in "$SOURCE"/*.xcresult; do
  [ -d "$bundle" ] || continue
  base=$(basename "$bundle" .xcresult)
  device="${base%%__*}"
  locale="${base##*__}"
  out="$DEST/$locale/$device"
  rm -rf "$out"
  mkdir -p "$out"

  echo "==> $device / $locale"

  tmp="$(mktemp -d)"
  xcrun xcresulttool export attachments \
    --path "$bundle" \
    --output-path "$tmp" >/dev/null 2>&1 || {
      echo "  (export failed — check Xcode version)"
      rm -rf "$tmp"
      continue
    }

  python3 - "$tmp" "$out" <<'PY'
import json, os, sys, shutil, re
tmp, out = sys.argv[1], sys.argv[2]
manifest = os.path.join(tmp, "manifest.json")
if not os.path.exists(manifest):
    sys.exit(0)
with open(manifest) as f:
    entries = json.load(f)
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
for att in iter_atts(entries):
    src = os.path.join(tmp, att["exportedFileName"])
    if not os.path.exists(src):
        continue
    name = att.get("suggestedHumanReadableName") or att["exportedFileName"]
    name = re.sub(r"_\d+_[0-9A-Fa-f-]+(\.png)$", r"\1", name)
    if not name.endswith(".png"):
        name += ".png"
    shutil.copyfile(src, os.path.join(out, name))
    count += 1
print(f"  {count} screenshots")
PY
  rm -rf "$tmp"
done

echo ""
echo "Screenshots in: $DEST"
