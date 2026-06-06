#!/bin/bash
set -euo pipefail

# Archive → export → upload to App Store Connect using the ASC API KEY
# (.p8) — NO keychain, NO deprecated altool, NO app-specific password.
# Models FlowPilot's build-appstore.sh (the cleanest of Jason's apps).
#
# Why this exists: the old upload.sh used `xcrun altool` (deprecated) +
# `@keychain:AC_PASSWORD`, and the macOS .pkg path needed a hand-built
# temp signing keychain (roastmate-signing.keychain-db). Passing the ASC
# API key to xcodebuild + automatic signing (-allowProvisioningUpdates)
# lets Xcode fetch/manage the distribution + Mac-Installer certs itself,
# and ExportOptions destination=upload uploads directly. So neither the
# temp keychain nor altool is needed.
#
# Usage:
#   ./scripts/build-upload-asc.sh                 # iOS (scheme RoastMate)
#   SCHEME=RoastMateMac DESTINATION='generic/platform=macOS' ./scripts/build-upload-asc.sh
#
# The ASC API key (DMMFP6XTXX) is shared across Jason's apps. Override
# via API_KEY_ID / API_ISSUER / API_KEY_PATH if needed.

PROJECT_DIR="/Users/jason/Documents/RoastMate"
SCHEME="${SCHEME:-RoastMate}"
DESTINATION="${DESTINATION:-generic/platform=iOS}"
EXPORT_PLIST="${EXPORT_PLIST:-$PROJECT_DIR/ExportOptions-upload.plist}"
ARCHIVE_PATH="$PROJECT_DIR/build/${SCHEME}.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/Export-${SCHEME}"

API_KEY_ID="${API_KEY_ID:-DMMFP6XTXX}"
API_ISSUER="${API_ISSUER:-c5671c11-49ec-47d9-bd38-5e3c1a249416}"
API_KEY_PATH="${API_KEY_PATH:-$HOME/private_keys/AuthKey_${API_KEY_ID}.p8}"

if [ ! -f "$API_KEY_PATH" ]; then
  echo "ERROR: ASC API key not found at $API_KEY_PATH"
  echo "       (set API_KEY_PATH, or drop AuthKey_<id>.p8 in ~/private_keys/)"
  exit 1
fi

# Passed to BOTH archive and export so automatic signing can talk to ASC.
AUTH=(
  -authenticationKeyPath "$API_KEY_PATH"
  -authenticationKeyID "$API_KEY_ID"
  -authenticationKeyIssuerID "$API_ISSUER"
  -allowProvisioningUpdates
)

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "=== Step 1/2: Archiving $SCHEME ($DESTINATION) ==="
xcodebuild archive \
  -project "$PROJECT_DIR/RoastMate.xcodeproj" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "$DESTINATION" \
  -archivePath "$ARCHIVE_PATH" \
  "${AUTH[@]}" \
  -quiet
[ -d "$ARCHIVE_PATH" ] || { echo "ERROR: archive failed"; exit 1; }
echo "Archive OK"

echo ""
echo "=== Step 2/2: Export + upload via ASC API key (no keychain, no altool) ==="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -exportPath "$EXPORT_PATH" \
  "${AUTH[@]}" \
  -quiet

echo ""
echo "Done — uploaded to App Store Connect via the API key. Check ASC processing."
