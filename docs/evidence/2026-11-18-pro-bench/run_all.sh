#!/bin/zsh
# Run every on-device part of the bench with one build.
#   run_all.sh <bench .app> <tag> [modes...]     (default: all modes)
# Writes runs/<tag>_<mode>.jsonl next to this script. Sequential on purpose:
# the on-device model serves one request at a time, and latency is a metric.
set -uo pipefail
APP=${1:?app}; TAG=${2:?tag}; shift 2
HERE=${0:A:h}; R=$HERE/../../..; H=$R/docs/evidence/2026-10-27-v18-plan/harness
BIN=$APP/Contents/MacOS/bench
mkdir -p $HERE/runs
modes=(${@:-sendable sim rewrite judge_blind judge_real safety})
for m in $modes; do
  out=$HERE/runs/${TAG}_$m.jsonl
  echo "[$(date +%H:%M:%S)] $TAG $m → ${out:t}" >&2
  case $m in
    sendable)    $BIN sendable $HERE/inputs.json > $out ;;
    unseen)      $BIN sendable $HERE/sealed/inputs_unseen.json --set sendable > $out ;;
    sim)         $BIN sim > $out ;;
    sim_unseen)  $BIN sim --setups $HERE/sealed/sim_unseen.json > $out ;;
    rewrite)     $BIN rewrite $HERE/inputs.json --runs 2 > $out ;;
    judge_blind) $BIN judge $H/safety/judgetune/blind_set.json > $out ;;
    judge_real)  $BIN judge $H/safety/judgetune/real_outputs.json > $out ;;
    judge_fresh) $BIN judge $HERE/sealed/blind_set_fresh.json > $out ;;
    safety)      $BIN safety $H/safety_set.json --runs 2 > $out ;;
    *) echo "unknown mode $m" >&2 ;;
  esac
done
echo "[$(date +%H:%M:%S)] $TAG done" >&2
