#!/bin/zsh
# Re-run the P2.1 post examples through the shipped rewrite path (read-only, $0).
# Usage: build_and_run.sh <out_dir> [runs=5]   (out_dir must be outside ~/Documents)
set -euo pipefail
R=${ROASTMATE_ROOT:-$HOME/Documents/RoastMate}
OUT=${1:?out dir}; RUNS=${2:-5}; mkdir -p $OUT
H=$R/docs/evidence/2026-11-08-next-phase/a1-rewrite-recheck
# The judge prompt and verdict parser are cut verbatim out of the shipped engine.
{ echo 'import Foundation'; echo 'enum Judge {'
  awk 'index($0,"static let threatJudgeInstructions"){p=1} p{print} p&&/"""$/&&++n==2{exit}' $R/Shared/AI/RoastEngine.swift
  awk 'index($0,"static func threatJudgeSaysSafe"){p=1} p{print} p&&/^    }$/{exit}' $R/Shared/AI/RoastEngine.swift
  echo '}'; } > $OUT/Judge.swift
swiftc -O -o $OUT/rewrite $H/main.swift $OUT/Judge.swift \
  $R/docs/evidence/2026-10-27-v18-plan/harness/safety/e2e/Stubs.swift \
  $R/Shared/AI/{PromptBuilder,StylePreset,SafetyFilter,ModelRefusal,RewriteThreatScreen}.swift \
  $R/Shared/Models/Intensity.swift
ROASTMATE_ROOT=$R $OUT/rewrite $RUNS
