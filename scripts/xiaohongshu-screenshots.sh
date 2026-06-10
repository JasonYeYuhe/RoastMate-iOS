#!/bin/bash
# 小红书 (Xiaohongshu) marketing screenshots — one-shot runner.
#
# Runs ScreenshotTests/test_screenshots_xiaohongshu (zh-Hans, iPhone 17
# Pro Max) and extracts the PNGs into marketing/xiaohongshu/raw/.
# Unlike screenshots.sh (the App Store set), this captures FEATURE
# OUTPUT — the 虚拟舍友群 group chat (REAL cloud generation; network
# required), a 替你出气 transcript, and the bridge → rewrite loop.
#
# The app is uninstalled first so UserDefaults/SwiftData reset → the
# roommate cloud-consent sheet appears deterministically (the test
# accepts it). Status bar is pinned to the marketing-standard 9:41.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/RoastMate.xcodeproj"
DEVICE_NAME="iPhone 17 Pro Max"
BUNDLE_ID="yyh.roastmate.app"
RESULT="$PROJECT_DIR/build/Screenshots-XHS/iPhone_17_Pro_Max__zh_Hans.xcresult"
OUT="$PROJECT_DIR/marketing/xiaohongshu/raw"

# Two simulators can share the name — resolve ONE UDID and use it for
# simctl AND xcodebuild so the status-bar override hits the right device.
UDID=$(xcrun simctl list devices available | grep "$DEVICE_NAME (" | head -1 | grep -oE "[0-9A-F-]{36}")
if [ -z "$UDID" ]; then
  echo "ERROR: no available simulator named '$DEVICE_NAME'"; exit 1
fi
echo "==> Using $DEVICE_NAME ($UDID)"

rm -rf "$RESULT" "$OUT"
mkdir -p "$(dirname "$RESULT")" "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
# Fresh app state → deterministic consent sheet + seeded samples.
xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
# Marketing-standard status bar (best-effort; not fatal if unsupported).
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 2>/dev/null || true
# Dark mode — matches the brand (dark UI + orange) and the website.
xcrun simctl ui "$UDID" appearance dark 2>/dev/null || true

echo "==> Running the screenshot flow (build + test; roommate scene hits the real Worker)"
LOCALE="zh_Hans" xcodebuild \
  -project "$PROJECT" \
  -scheme "RoastMate" \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:RoastMateUITests/ScreenshotTests/test_screenshots_xiaohongshu \
  -resultBundlePath "$RESULT" \
  CODE_SIGNING_ALLOWED=NO \
  test

echo "==> Extracting PNGs"
tmp="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$tmp" >/dev/null

python3 - "$tmp" "$OUT" <<'PY'
import json, os, sys, shutil, re
tmp, out = sys.argv[1], sys.argv[2]
manifest = os.path.join(tmp, "manifest.json")
if not os.path.exists(manifest):
    sys.exit("no manifest.json — did the test produce attachments?")
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
print(f"  {count} screenshots → {out}")
PY
rm -rf "$tmp"

# Clear the status-bar override so the sim isn't stuck at 9:41 for dev work.
xcrun simctl status_bar "$UDID" clear 2>/dev/null || true

echo ""
echo "Done: $OUT"
ls -la "$OUT"
