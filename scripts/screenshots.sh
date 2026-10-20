#!/bin/bash
# Run the App Store screenshot UI test (ScreenshotTests/test_screenshots)
# once per locale on ONE simulator. Drops one .xcresult per locale in
# $SCREENSHOTS_RESULT_DIR (default build/Screenshots/). Then run
# scripts/extract-screenshots.sh to gate + extract the PNGs into
# metadata/screenshots/{locale}/{device}/.
#
# Why it looks like this (root cause found 2026-10-07):
# - The locale is passed as TEST_RUNNER_LOCALE. xcodebuild forwards ONLY
#   TEST_RUNNER_-prefixed variables to the test runner (prefix stripped).
#   The old `LOCALE=… xcodebuild` never reached the test, which then
#   defaulted to en_US: every "locale" set was English.
# - The app is uninstalled before each locale so the seeded History
#   samples, the trial wallet and every persisted flag start fresh in that
#   locale (SwiftData survives relaunch; -uitest does not reset it all).
# - Release by default. DEBUG builds are always Pro (StoreService.isPro),
#   so a Debug set shows no lock on Savage/Feral or the 16 Pro styles, no
#   credit chip, and a "Pro" badge in Settings — not what a free user
#   sees. Release shows the free tier: Vent unlocked, Pro items locked.
#
# Scene 01 (the Vent result) renders marketing/appstore/vent-fixtures/<lang>.txt
# — a real reply from the live Worker with only its profanity tokens deleted
# (see the README there) — passed as TEST_RUNNER_VENT_FIXTURE.
#
# Env overrides (all optional):
#   SCREENSHOTS_LOCALES         default "en_US zh_Hant ja_JP zh_Hans"
#   SCREENSHOTS_DEVICE          simulator name, default "iPhone 17 Pro Max"
#   SCREENSHOTS_UDID            use this simulator UDID instead of the name
#   SCREENSHOTS_CONFIGURATION   Release (default) or Debug
#   SCREENSHOTS_RESULT_DIR      where the .xcresult bundles go
#   SCREENSHOTS_DERIVED_DATA    -derivedDataPath for the build
#
# Requires: Xcode 26+ and the named simulator. Run ONE of these at a time
# per simulator: two UI-test runs on one device fight over the foreground.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/RoastMate.xcodeproj"
SCHEME="RoastMate"
BUNDLE_ID="yyh.roastmate.app"
OUTPUT_DIR="${SCREENSHOTS_RESULT_DIR:-$PROJECT_DIR/build/Screenshots}"
CONFIGURATION="${SCREENSHOTS_CONFIGURATION:-Release}"
DEVICE_NAME="${SCREENSHOTS_DEVICE:-iPhone 17 Pro Max}"
read -r -a LOCALES <<< "${SCREENSHOTS_LOCALES:-en_US zh_Hant ja_JP zh_Hans}"

# One simulator, by UDID: two devices can share a name, and simctl (status
# bar, uninstall) must hit the same device xcodebuild runs on.
UDID="${SCREENSHOTS_UDID:-}"
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
name = sys.argv[1]
devs = [d for rt in json.load(sys.stdin)["devices"].values() for d in rt
        if d.get("name") == name and d.get("isAvailable", True)]
if len(devs) != 1:
    sys.exit(f"expected exactly one available simulator named {name!r}, found {len(devs)}; set SCREENSHOTS_UDID")
print(devs[0]["udid"])
' "$DEVICE_NAME")
fi
echo "==> $DEVICE_NAME ($UDID), $CONFIGURATION, locales: ${LOCALES[*]}"

if pgrep -f "xcodebuild.*$UDID" >/dev/null; then
  echo "ERROR: another xcodebuild is already driving $UDID — wait for it to finish."
  exit 1
fi

DD_ARGS=()
if [ -n "${SCREENSHOTS_DERIVED_DATA:-}" ]; then
  DD_ARGS=(-derivedDataPath "$SCREENSHOTS_DERIVED_DATA")
fi
COMMON_ARGS=(
  -project "$PROJECT"
  -scheme "$SCHEME"
  -configuration "$CONFIGURATION"
  -destination "platform=iOS Simulator,id=$UDID"
  "${DD_ARGS[@]+"${DD_ARGS[@]}"}"
)

xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null

# Store-standard status bar for the run; restored on exit because this is
# a shared device.
xcrun simctl status_bar "$UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 2>/dev/null || true
trap 'xcrun simctl status_bar "$UDID" clear 2>/dev/null || true' EXIT

mkdir -p "$OUTPUT_DIR"
# xcodebuild refuses an existing -resultBundlePath. Previous bundles go to
# the Trash (recoverable), never rm -rf.
# Only THIS device's bundles: the 6.9" and 6.3" sets are separate runs that
# extract-screenshots.sh reads together.
safe_device="${DEVICE_NAME// /_}"
shopt -s nullglob
old_results=("$OUTPUT_DIR"/"${safe_device}"__*.xcresult)
shopt -u nullglob
if [ ${#old_results[@]} -gt 0 ]; then
  /usr/bin/trash "${old_results[@]}"
fi

echo "==> Building for testing ($CONFIGURATION)"
# ENABLE_TESTABILITY: the scheme's unit-test target `@testable import`s the
# app, which a Release build only allows with testability on.
xcodebuild "${COMMON_ARGS[@]}" \
  CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES \
  build-for-testing

FIXTURE_DIR="$PROJECT_DIR/marketing/appstore/vent-fixtures"
for locale in "${LOCALES[@]}"; do
  result="$OUTPUT_DIR/${safe_device}__${locale}.xcresult"
  echo ""
  echo "==> $DEVICE_NAME · $locale"
  case "$locale" in
    en_US) fixture_lang=en ;; zh_Hans) fixture_lang=zh-Hans ;;
    zh_Hant) fixture_lang=zh-Hant ;; ja_JP) fixture_lang=ja ;;
    *) echo "ERROR: no vent fixture mapping for $locale"; exit 1 ;;
  esac
  fixture_file="$FIXTURE_DIR/$fixture_lang.txt"
  if [ ! -s "$fixture_file" ]; then
    echo "ERROR: missing $fixture_file (scene 01's Vent reply)."
    exit 1
  fi
  xcrun simctl uninstall "$UDID" "$BUNDLE_ID" 2>/dev/null || true
  TEST_RUNNER_LOCALE="$locale" \
  TEST_RUNNER_VENT_FIXTURE="$(base64 < "$fixture_file" | tr -d '\n')" \
  xcodebuild "${COMMON_ARGS[@]}" \
    -only-testing:RoastMateUITests/ScreenshotTests/test_screenshots \
    -resultBundlePath "$result" \
    CODE_SIGNING_ALLOWED=NO ENABLE_TESTABILITY=YES \
    test-without-building
done

echo ""
echo "Done. Run scripts/extract-screenshots.sh to gate and extract the PNGs."
