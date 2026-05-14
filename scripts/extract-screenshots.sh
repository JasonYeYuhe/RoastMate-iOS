#!/bin/bash
# Walk the .xcresult bundles produced by screenshots.sh and copy out
# each XCTAttachment PNG into metadata/screenshots/{locale}/{device}/.
# Filenames come from the attachment's `name` property
# (e.g. "01-generator-empty.png").

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
  base=$(basename "$bundle" .xcresult)
  device="${base%%__*}"
  locale="${base##*__}"
  out="$DEST/$locale/$device"
  mkdir -p "$out"

  echo "==> $device / $locale"

  # Pull every attachment payload reference and copy to disk.
  xcrun xcresulttool get test-results tests --path "$bundle" --format json \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
def walk(node):
    if isinstance(node, dict):
        for v in node.values(): walk(v)
    elif isinstance(node, list):
        for v in node: walk(v)
walk(data)
" > /dev/null 2>&1 || true

  # Fallback: shell out to xcresulttool's legacy 'get attachments' path
  # which works across Xcode 26 versions.
  xcrun xcresulttool get attachments \
    --path "$bundle" \
    --output-path "$out" 2>/dev/null || \
  xcrun xcresulttool export attachments \
    --path "$bundle" \
    --output-path "$out" 2>/dev/null || \
    echo "  (no attachments extracted — check Xcode version)"

done

echo ""
echo "Screenshots in: $DEST"
