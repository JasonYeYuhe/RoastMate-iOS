#!/bin/bash
# Pre-submission sanity check. Run this before archiving for App Store.
# Validates project structure, builds all targets, runs unit tests,
# and verifies catch-all metadata is in place.
#
# Exits with non-zero status if any check fails.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/RoastMate.xcodeproj"

PASS=0
FAIL=0

ok() {
  echo "  ✓ $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  ✗ $1"
  FAIL=$((FAIL + 1))
}

require_file() {
  local f="$1"
  if [ -f "$f" ]; then ok "exists: $(realpath --relative-to="$PROJECT_DIR" "$f" 2>/dev/null || echo "$f")"
  else fail "missing: $f"; fi
}

require_nonempty() {
  local f="$1"
  if [ -s "$f" ]; then ok "non-empty: $(basename "$f")"
  else fail "empty: $f"; fi
}

section() {
  echo ""
  echo "=== $1 ==="
}

# ─────────────────────────────────────────────────────────────────────
section "Project structure"
require_file "$PROJECT_DIR/project.yml"
require_file "$PROJECT_DIR/ExportOptions.plist"
require_file "$PROJECT_DIR/upload.sh"
require_file "$PROJECT_DIR/RoastMate/PrivacyInfo.xcprivacy"
require_file "$PROJECT_DIR/RoastMate/RoastMate.entitlements"
require_file "$PROJECT_DIR/RoastMateMac/RoastMateMac.entitlements"
require_file "$PROJECT_DIR/RoastMateWatch/RoastMateWatch.entitlements"
require_file "$PROJECT_DIR/RoastMateShare/RoastMateShare.entitlements"
require_file "$PROJECT_DIR/RoastMateShare/Info.plist"
require_file "$PROJECT_DIR/RoastMateControls/RoastMateControls.entitlements"
require_file "$PROJECT_DIR/RoastMateControls/Info.plist"
require_file "$PROJECT_DIR/RoastMate/Configuration.storekit"

# ─────────────────────────────────────────────────────────────────────
section "Icons (must be real PNGs, not placeholders)"
for icon in \
  "$PROJECT_DIR/RoastMate/Assets.xcassets/AppIcon.appiconset/icon_1024.png" \
  "$PROJECT_DIR/RoastMateMac/Assets.xcassets/AppIcon.appiconset/icon_1024.png" \
  "$PROJECT_DIR/RoastMateWatch/Assets.xcassets/AppIcon.appiconset/icon_1024.png"
do
  if [ -f "$icon" ] && file "$icon" | grep -q "PNG image"; then
    size=$(stat -f%z "$icon" 2>/dev/null || stat -c%s "$icon")
    if [ "$size" -gt 10000 ]; then
      ok "icon present and >10KB: $(basename "$(dirname "$icon")")"
    else
      fail "icon suspiciously small (<10KB): $icon"
    fi
  else
    fail "icon missing or not a PNG: $icon"
  fi
done

# ─────────────────────────────────────────────────────────────────────
section "JSON resources"
for f in \
  "$PROJECT_DIR/Shared/Resources/StylePresets.json" \
  "$PROJECT_DIR/Shared/Resources/SampleRoasts.json" \
  "$PROJECT_DIR/Shared/Resources/ForbiddenTerms.json"
do
  require_file "$f"
  if [ -f "$f" ]; then
    if python3 -c "import json,sys; json.load(open('$f'))" 2>/dev/null; then
      ok "valid JSON: $(basename "$f")"
    else
      fail "invalid JSON: $f"
    fi
  fi
done

# ─────────────────────────────────────────────────────────────────────
section "Localization parity (4 locales must have same keys)"
LOCALES=(en zh-Hans zh-Hant ja)
declare -a COUNTS
for locale in "${LOCALES[@]}"; do
  file="$PROJECT_DIR/Shared/$locale.lproj/Localizable.strings"
  if [ -f "$file" ]; then
    count=$(grep -c '^"' "$file" 2>/dev/null || echo 0)
    COUNTS+=("$count")
    ok "$locale: $count keys"
  else
    fail "$locale: missing Localizable.strings"
  fi
done
# All counts should match within ±2 (allow minor drift for plural forms)
if [ "${#COUNTS[@]}" -eq 4 ]; then
  min=${COUNTS[0]}
  max=${COUNTS[0]}
  for c in "${COUNTS[@]}"; do
    (( c < min )) && min=$c
    (( c > max )) && max=$c
  done
  diff=$((max - min))
  if [ "$diff" -le 3 ]; then
    ok "localization key counts roughly aligned (delta=$diff)"
  else
    fail "localization key counts diverge by $diff — one locale is missing keys"
  fi
fi

# ─────────────────────────────────────────────────────────────────────
section "ASC metadata (4 locales × required fields)"
for locale in en-US zh-Hans zh-Hant ja; do
  for field in name.txt subtitle.txt description.txt keywords.txt \
               promotional_text.txt release_notes.txt \
               support_url.txt privacy_url.txt; do
    f="$PROJECT_DIR/metadata/$locale/$field"
    if [ -s "$f" ]; then
      ok "$locale/$field"
    else
      fail "$locale/$field missing or empty"
    fi
  done
done
require_nonempty "$PROJECT_DIR/metadata/review_notes.txt"

# ─────────────────────────────────────────────────────────────────────
section "Static site for GitHub Pages"
for f in index.html privacy.html terms.html support.html style.css; do
  require_file "$PROJECT_DIR/docs/site/$f"
done

# ─────────────────────────────────────────────────────────────────────
section "Bundle IDs match the plan"
expected=("yyh.roastmate.app" "yyh.roastmate.app.watchkitapp" "yyh.roastmate.app.share")
yml="$PROJECT_DIR/project.yml"
for bid in "${expected[@]}"; do
  if grep -q "$bid" "$yml"; then
    ok "found in project.yml: $bid"
  else
    fail "missing from project.yml: $bid"
  fi
done

# ─────────────────────────────────────────────────────────────────────
section "Builds"
build_target() {
  local scheme="$1" destination="$2" extra="$3"
  echo "  building ${scheme}..."
  if xcodebuild -project "$PROJECT" -scheme "$scheme" \
      -configuration Debug -destination "$destination" \
      $extra CODE_SIGNING_ALLOWED=NO build 2>&1 \
      | tail -50 | grep -q "BUILD SUCCEEDED"; then
    ok "$scheme builds"
  else
    fail "$scheme build failed"
  fi
}
build_target "RoastMate"      "generic/platform=iOS Simulator"      "-sdk iphonesimulator"
build_target "RoastMateMac"   "generic/platform=macOS"              ""
build_target "RoastMateWatch" "generic/platform=watchOS Simulator"  "-sdk watchsimulator"
build_target "RoastMateShare" "generic/platform=iOS Simulator"      "-sdk iphonesimulator"
build_target "RoastMateControls" "generic/platform=iOS Simulator"   "-sdk iphonesimulator"

# ─────────────────────────────────────────────────────────────────────
section "Unit tests"
# xcodegen only emits schemes for app/extension targets — there is no
# "RoastMateTests" scheme (this step silently failed since the v1.0
# initial commit). Tests run via the RoastMate scheme's test action
# (testTargets: RoastMateTests + RoastMateUITests).
if xcodebuild -project "$PROJECT" -scheme RoastMate \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    CODE_SIGNING_ALLOWED=NO test 2>&1 \
    | grep -q "\*\* TEST SUCCEEDED \*\*"; then
  ok "unit tests pass"
else
  fail "unit tests failed"
fi

# ─────────────────────────────────────────────────────────────────────
# α4 (Phase 3 W1): Tier A smoke harness. 1 scenario × vent+feral × 4
# locales = 8 cells, ≤2 min. Hits the live cloud worker, so this step
# is opt-in via ROASTMATE_TIER_A=1 — every prompt/model/setting change
# should run it before archive; routine dev can skip.
#
# When α2 ships /v1/sharp (W3), Tier A expands to 4 intensities × 4
# locales = 16 cells. Strong-word regression vs baseline is checked
# by scripts/eval-rerun.sh, not by this gate.
if [ "${ROASTMATE_TIER_A:-0}" = "1" ]; then
  section "Tier A smoke (--tier-a)"
  RUNNER_DIR="$PROJECT_DIR/evals/runner"
  RUNNER_BIN="$RUNNER_DIR/.build/debug/eval-runner"
  if (cd "$RUNNER_DIR" && swift build 2>&1) | tail -3 | grep -q "Build complete"; then
    ok "eval-runner built"
  else
    fail "eval-runner build failed"
  fi
  TIER_A_DIR="$PROJECT_DIR/evals/runs/run-preflight-tier-a"
  if [ -x "$RUNNER_BIN" ]; then
    if (cd "$PROJECT_DIR" && "$RUNNER_BIN" --tier-a --label preflight-tier-a); then
      ok "Tier A cells passed"
    else
      fail "Tier A failed — archive blocked (see stderr above)"
    fi

    # Strong-word regression check vs the committed baseline. A drop of
    # ≥2 strong words in any cell vs run-baseline-build-8 means a prompt
    # tune lost its bite — block the archive. Per advisor synthesis the
    # baseline diff is the load-bearing regression gate.
    BASELINE="$PROJECT_DIR/evals/runs/run-baseline-build-8"
    if [ -f "$BASELINE/results.json" ] && [ -f "$TIER_A_DIR/results.json" ]; then
      if "$PROJECT_DIR/scripts/eval-rerun.sh" --strict "$BASELINE" "$TIER_A_DIR" > /dev/null; then
        ok "no strong-word regression vs baseline"
      else
        fail "strong-word regression vs baseline (run eval-rerun.sh for details)"
      fi
    else
      echo "  (skipping baseline diff — results.json missing)"
    fi
  else
    fail "eval-runner binary missing at $RUNNER_BIN"
  fi
else
  echo ""
  echo "(skipping Tier A smoke — set ROASTMATE_TIER_A=1 before archive)"
fi

# ─────────────────────────────────────────────────────────────────────
echo ""
echo "=============================="
echo " Results: $PASS pass, $FAIL fail"
echo "=============================="

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
