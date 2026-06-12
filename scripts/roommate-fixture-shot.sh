#!/bin/bash
# Render ONE deterministic 虚拟舍友群 marketing screenshot from a fixed,
# hand-picked transcript (the judge-panel winner) — no live cloud roll.
# The transcript is read from $1 (a file of raw [ROLE/IDX] tagged lines)
# and injected via the app's -uitestRoommateFixture launch arg.
#
# Usage: ./scripts/roommate-fixture-shot.sh /tmp/roommate_winner.txt
set -euo pipefail

FIXTURE_FILE="${1:?usage: roommate-fixture-shot.sh <transcript-file>}"
[ -f "$FIXTURE_FILE" ] || { echo "no such file: $FIXTURE_FILE"; exit 1; }
# Base64 (single line) so the multi-line transcript survives env -> launch-arg
# without the newlines being flattened. Decoded app-side.
FIXTURE="$(base64 < "$FIXTURE_FILE" | tr -d '\n')"

PROJECT_DIR="/Users/jason/Documents/RoastMate"
UDID=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max (" | head -1 | grep -oE "[0-9A-F-]{36}")
RESULT="/tmp/xhs_fixture/run.xcresult"
OUT="/tmp/xhs_fixture/out"
rm -rf /tmp/xhs_fixture && mkdir -p "$OUT"

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl uninstall "$UDID" yyh.roastmate.app 2>/dev/null || true
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true
xcrun simctl ui "$UDID" appearance dark 2>/dev/null || true

TEST_RUNNER_ROOMMATE_FIXTURE="$FIXTURE" xcodebuild \
  -project "$PROJECT_DIR/RoastMate.xcodeproj" -scheme RoastMate \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:RoastMateUITests/ScreenshotTests/test_screenshot_roommate_fixture \
  -resultBundlePath "$RESULT" CODE_SIGNING_ALLOWED=NO test

tmp="$(mktemp -d)"
xcrun xcresulttool export attachments --path "$RESULT" --output-path "$tmp" >/dev/null
python3 - "$tmp" "$OUT" <<'PY'
import json, os, sys, shutil, re
tmp, out = sys.argv[1], sys.argv[2]
entries = json.load(open(os.path.join(tmp, "manifest.json")))
def it(n):
    if isinstance(n, dict):
        if "exportedFileName" in n: yield n
        for v in n.values(): yield from it(v)
    elif isinstance(n, list):
        for v in n: yield from it(v)
for a in it(entries):
    src = os.path.join(tmp, a["exportedFileName"])
    if not os.path.exists(src): continue
    name = a.get("suggestedHumanReadableName") or a["exportedFileName"]
    name = re.sub(r"_\d+_[0-9A-Fa-f-]+(\.png)$", r"\1", name)
    if not name.endswith(".png"): name += ".png"
    shutil.copyfile(src, os.path.join(out, name)); print("  ", name)
PY
xcrun simctl status_bar "$UDID" clear 2>/dev/null || true

# Promote the fixture capture into the marketing raw set
if [ -f "$OUT/xhs-04-roommate-chat.png" ]; then
  cp "$OUT/xhs-04-roommate-chat.png" "$PROJECT_DIR/marketing/xiaohongshu/raw/xhs-04-roommate-chat.png"
  echo "Updated marketing/xiaohongshu/raw/xhs-04-roommate-chat.png"
else
  echo "WARNING: fixture capture not produced"; exit 1
fi
