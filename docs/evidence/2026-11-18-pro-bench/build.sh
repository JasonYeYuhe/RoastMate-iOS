#!/bin/zsh
# Build the bench against one Shared/ tree into a minimal .app (so StylePresets,
# ForbiddenTerms and Localizable.strings load from the bundle as in the app).
#
#   build.sh <shared-dir> <out.app> [extra.swift ...]
#
# control:   git archive v1.8.0-ios29 Shared | tar -x -C $S/control  → build.sh $S/control/Shared $S/control.app
# candidate: build.sh ~/Documents/RoastMate/Shared $S/cand.app
# Output must live outside ~/Documents (global CLAUDE.md, build roots rule 8).
set -euo pipefail
SHARED=${1:?shared dir}; APP=${2:?out .app}; shift 2
HERE=${0:A:h}
case "$APP" in "$HOME/Documents"*) echo "refusing to build inside ~/Documents" >&2; exit 2;; esac
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
# iCloud duplicates (`* 2.swift`) are excluded, as in the probe recipe.
find "$SHARED" -name '*.swift' ! -name '* 2.swift' -print0 | xargs -0 swiftc -O -swift-version 6 \
  -parse-as-library -module-name RoastMateBench \
  -enable-upcoming-feature NonisolatedNonsendingByDefault -enable-upcoming-feature InferIsolatedConformances \
  -enable-upcoming-feature InferSendableFromCaptures -enable-upcoming-feature GlobalActorIsolatedTypesUsability \
  -enable-upcoming-feature DisableOutwardActorInference \
  -o "$APP/Contents/MacOS/bench" "$HERE/bench_main.swift" "$@"
cp "$SHARED"/Resources/*.json "$APP/Contents/Resources/"
for l in "$SHARED"/*.lproj; do rm -rf "$APP/Contents/Resources/${l:t}"; cp -R "$l" "$APP/Contents/Resources/"; done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>yyh.roastmate.bench</string>
<key>CFBundleExecutable</key><string>bench</string>
<key>CFBundleName</key><string>bench</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>zh-Hant</string><string>ja</string></array>
</dict></plist>
PLIST
echo "built $APP"
