#!/bin/bash
set -euo pipefail

# Archive + export + upload the iOS build to App Store Connect.
# Mirrors the Stride upload script. Adjust scheme / archive name as needed.

PROJECT_DIR="/Users/jason/Documents/RoastMate"
ARCHIVE_PATH="$PROJECT_DIR/build/RoastMate.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/Export"
SCHEME="${SCHEME:-RoastMate}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"

if [ -z "${APPLE_ID:-}" ]; then
  echo "ERROR: set APPLE_ID env var (your developer account email)"
  exit 1
fi

# Keychain item 'AC_PASSWORD' must hold an app-specific password.
# See: https://support.apple.com/HT204397

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "=== Step 1/3: Archiving $SCHEME ==="
xcodebuild archive \
  -project "$PROJECT_DIR/RoastMate.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  -quiet

if [ ! -d "$ARCHIVE_PATH" ]; then
  echo "ERROR: Archive failed"
  exit 1
fi
echo "Archive OK"

echo ""
echo "=== Step 2/3: Exporting IPA ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$PROJECT_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_PATH" \
  -quiet

IPA_PATH=$(find "$EXPORT_PATH" -name "*.ipa" -print -quit)
if [ -z "$IPA_PATH" ]; then
  echo "ERROR: IPA export failed"
  exit 1
fi
echo "IPA OK: $IPA_PATH"

echo ""
echo "=== Step 3/3: Uploading to App Store Connect ==="
xcrun altool --upload-app \
  -f "$IPA_PATH" \
  -t ios \
  -u "$APPLE_ID" \
  -p "@keychain:AC_PASSWORD" \
  --verbose

echo ""
echo "Done! Check App Store Connect."
