#!/bin/bash
# Run RoastMateUITests across every locale we ship and every device we
# need screenshots for. Drops the raw .xcresult bundles in `build/Screenshots/`.
# Run `extract-screenshots.sh` afterward to pull PNGs out of the bundles
# and into `metadata/screenshots/{locale}/{device}/`.
#
# Requires: Xcode 26+ with the listed simulators installed.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/RoastMate.xcodeproj"
OUTPUT_DIR="$PROJECT_DIR/build/Screenshots"
SCHEME="RoastMate"

LOCALES=("en_US" "zh_Hans" "zh_Hant" "ja_JP")

# Pick the simulators App Store wants. As of 2026-05, ASC accepts a
# single canonical iPhone size if you provide the largest one supported.
# Add more entries for iPad if/when you wire that up.
DEVICES=(
  "iPhone 17 Pro Max"
  "iPhone 17 Pro"
)

mkdir -p "$OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"/*

for device in "${DEVICES[@]}"; do
  for locale in "${LOCALES[@]}"; do
    safe_device="${device// /_}"
    result="$OUTPUT_DIR/${safe_device}__${locale}.xcresult"
    echo ""
    echo "==> $device · $locale"
    LOCALE="$locale" xcodebuild \
      -project "$PROJECT" \
      -scheme "$SCHEME" \
      -destination "platform=iOS Simulator,name=$device" \
      -only-testing:RoastMateUITests/ScreenshotTests/test_screenshots \
      -resultBundlePath "$result" \
      CODE_SIGNING_ALLOWED=NO \
      test
  done
done

echo ""
echo "Done. Run scripts/extract-screenshots.sh to extract PNGs."
