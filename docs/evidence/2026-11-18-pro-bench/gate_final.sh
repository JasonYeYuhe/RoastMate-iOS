#!/bin/zsh
# Final same-day gate run for the on-device sendable items (plan §2), with the
# candidate and the 1.8.0 control INTERLEAVED in small shards: other sessions
# on this Mac drove the load average from ~5 to 92 on 11-19, which made the
# on-device model 2–3× slower for tens of minutes. Alternating shards makes such
# swings hit both builds alike, so the latency comparison stays fair.
#   gate_final.sh <cand.app> <control.app> <tag> [shards=24]
set -uo pipefail
CAND=${1:?cand app}; CTRL=${2:?control app}; TAG=${3:?tag}; N=${4:-24}
HERE=${0:A:h}; R=$HERE/../../..; H=$R/docs/evidence/2026-10-27-v18-plan/harness
mkdir -p $HERE/runs
# The shards append (>>), so leftover rows from a stopped run would be scored as part of
# this one. Refuse to start over them: move them to runs/void/ first.
if ls $HERE/runs/${TAG}_* >/dev/null 2>&1; then
  echo "runs/${TAG}_* already exists; move it to runs/void/ (or pick a new tag) first" >&2; exit 1
fi
for set in fixed unseen; do
  in=$HERE/inputs.json; [[ $set == unseen ]] && in=$HERE/sealed/inputs_unseen.json
  for i in $(seq 0 $((N - 1))); do
    for side in cand control; do
      app=$CAND; [[ $side == control ]] && app=$CTRL
      echo "[$(date +%H:%M:%S)] $set shard $i/$N $side" >&2
      $app/Contents/MacOS/bench sendable $in --set sendable --shard $i/$N >> $HERE/runs/${TAG}_${side}_${set}.jsonl 2>/dev/null
    done
  done
done
# Safety for the candidate (judge sets and e2e), and the fresh blind set for both.
$HERE/run_all.sh $CAND ${TAG}_cand judge_blind judge_real judge_fresh safety
$HERE/run_all.sh $CTRL ${TAG}_control judge_fresh
echo "[$(date +%H:%M:%S)] gate done" >&2
