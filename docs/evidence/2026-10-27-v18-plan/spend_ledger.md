# Evaluation-spend ledger (plan §7.4) — stop at $2.00 total

OpenRouter balance at start: $9.87 remaining (`scripts/openrouter-balance.sh 5`, 2026-10-27 22:39 JST).
On-device runs cost $0 and are listed for completeness.

| date | run | calls | cost | running total |
|---|---|---|---|---|
| 10-27 | baseline: lens-1 probe all + free (on-device, macOS 27.2) | 104 | $0 | $0.000 |
| 10-27 | baseline: lens-2 fmb default vs permissive (on-device) | 16 | $0 | $0.000 |
| 10-27 | baseline: safety-set screens, judge (on-device) | 60 | $0 | $0.000 |
| 10-27 | A1 preview, `wrangler dev --remote` (pilot 6 + gate 14; 20/20 cap) | 20 | $0.0038 (used $0.1329 → $0.1367) | $0.004 |
| 10-29 | judge / intent / identity tuning + e2e (on-device, macOS 27.2) | ~1,600 judge + 120 generations | $0 | $0.004 |
| 10-29 | A1 round 2 preview (6 of the approved 12 calls; stopped once the blind read failed) | 6 | $0.0011 (used $0.1368 → $0.1379) | $0.005 |
