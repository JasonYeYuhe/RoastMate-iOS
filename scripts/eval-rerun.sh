#!/bin/bash
# eval-rerun.sh — B5 diff helper.
# Compares two `evals/runs/run-*` JSON snapshots, prints regression report.
#
# Usage:
#   scripts/eval-rerun.sh BASELINE_DIR NEW_DIR
#   scripts/eval-rerun.sh evals/runs/run-baseline-build-8-base evals/runs/run-20260601T...
#
# Output: stdout markdown table with the rows where:
#   - ok flipped (pass→fail OR fail→pass)
#   - latency changed by >50% in either direction
#   - vent strong-word count changed by ≥2
#   - safetyFlags set differs
#   - text changed (always — but only flagged if a deterministic check
#     also flipped, since LLM noise gives different text every run)

set -euo pipefail

if [ $# -ne 2 ]; then
  echo "Usage: $0 BASELINE_DIR NEW_DIR" >&2
  echo "Both dirs must contain results.json." >&2
  exit 2
fi
BASE="$1"
NEW="$2"

if [ ! -f "$BASE/results.json" ]; then
  echo "ERROR: $BASE/results.json not found" >&2
  exit 1
fi
if [ ! -f "$NEW/results.json" ]; then
  echo "ERROR: $NEW/results.json not found" >&2
  exit 1
fi

python3 - "$BASE/results.json" "$NEW/results.json" <<'PYEOF'
import json, sys

with open(sys.argv[1]) as f: baseline = json.load(f)
with open(sys.argv[2]) as f: newrun = json.load(f)

# Index by (scenarioId, intensity, locale, backendName)
def key(c):
    return (c["scenarioId"], c["intensity"], c["locale"], c["backendName"])

bmap = {key(c): c for c in baseline}
nmap = {key(c): c for c in newrun}

regressions = []
improvements = []
flips = []
latency_changes = []
strong_changes = []
flag_changes = []
new_cells = []
removed = []

for k in set(bmap) | set(nmap):
    b = bmap.get(k); n = nmap.get(k)
    if b is None:
        new_cells.append(k); continue
    if n is None:
        removed.append(k); continue
    # OK flip
    if b["ok"] != n["ok"]:
        flips.append((k, b["ok"], n["ok"]))
    # Latency change > 50%
    if b["ok"] and n["ok"] and b["latencyMs"] > 100:
        pct = (n["latencyMs"] - b["latencyMs"]) / b["latencyMs"]
        if abs(pct) > 0.5:
            latency_changes.append((k, b["latencyMs"], n["latencyMs"], pct))
    # Strong-word count change ≥ 2
    if b["ok"] and n["ok"]:
        bs = (b.get("checks") or {}).get("ventStrongWordCount") or 0
        ns = (n.get("checks") or {}).get("ventStrongWordCount") or 0
        if abs(bs - ns) >= 2:
            strong_changes.append((k, bs, ns))
    # Safety flag set changes
    if b["ok"] and n["ok"]:
        bf = set((b.get("checks") or {}).get("safetyFlags") or [])
        nf = set((n.get("checks") or {}).get("safetyFlags") or [])
        if bf != nf:
            flag_changes.append((k, sorted(bf), sorted(nf)))

print(f"# Eval diff — {sys.argv[1]} → {sys.argv[2]}")
print()
print(f"- baseline cells: {len(baseline)}")
print(f"- new cells:      {len(newrun)}")
print(f"- new in newrun:  {len(new_cells)}")
print(f"- removed:        {len(removed)}")
print(f"- ok flips:       {len(flips)}")
print(f"- latency >50%:   {len(latency_changes)}")
print(f"- strong ±2:      {len(strong_changes)}")
print(f"- flag changes:   {len(flag_changes)}")
print()

def fmt_key(k): return f"`{k[0]}`/`{k[1]}`/`{k[2]}` → `{k[3]}`"

if flips:
    print("## OK flips (CRITICAL)")
    print()
    print("| cell | baseline | new |")
    print("|---|---|---|")
    for k, bok, nok in flips:
        emoji = "❌→✓" if not bok and nok else "✓→❌"
        print(f"| {fmt_key(k)} | {bok} | {nok} {emoji} |")
    print()

if latency_changes:
    print("## Latency changes (>50%)")
    print()
    print("| cell | baseline ms | new ms | %Δ |")
    print("|---|---|---|---|")
    for k, b, n, pct in latency_changes:
        arrow = "↑" if pct > 0 else "↓"
        print(f"| {fmt_key(k)} | {b} | {n} | {arrow}{pct*100:+.0f}% |")
    print()

if strong_changes:
    print("## Vent strong-word count changes (±2 or more)")
    print()
    print("| cell | baseline | new |")
    print("|---|---|---|")
    for k, bs, ns in strong_changes:
        delta = ns - bs
        sign = "+" if delta > 0 else ""
        print(f"| {fmt_key(k)} | {bs} | {ns} ({sign}{delta}) |")
    print()

if flag_changes:
    print("## Safety flag set changes")
    print()
    print("| cell | baseline flags | new flags |")
    print("|---|---|---|")
    for k, bf, nf in flag_changes:
        bs = ",".join(bf) or "—"
        ns = ",".join(nf) or "—"
        print(f"| {fmt_key(k)} | {bs} | {ns} |")
    print()

if new_cells:
    print("## New cells in newrun")
    print()
    for k in new_cells:
        print(f"- {fmt_key(k)}")
    print()

if removed:
    print("## Cells removed from newrun")
    print()
    for k in removed:
        print(f"- {fmt_key(k)}")
    print()

verdict = "**PASS** — no regressions" if not flips and not strong_changes else "**REGRESSION DETECTED** — review above"
print(verdict)
PYEOF
