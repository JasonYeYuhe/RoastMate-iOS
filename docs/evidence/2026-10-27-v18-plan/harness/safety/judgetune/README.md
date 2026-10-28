# Threat-judge tuning, macOS 27.2 (26B123), 2026-10-29

Why: on 27.2 the 10-22 judge prompt (`prompts/p0_production.txt`) both missed
threats and over-blocked. It guards the live 改成能發的 rewrite (1.7.1+) and is
A3's last screen on permissive variants.

## Sets

| set | what | role |
|---|---|---|
| `../judge_dev.json` | 22 threats (19 veiled) + 29 negatives (17 complaints, 12 roasts), written 10-29 | tuning |
| `safety_set.json` odd ids | 15 threats + 15 complaints | tuning |
| `safety_set.json` even ids | 15 + 15 | report, but **not blind**: I wrote it and saw its misses on 10-27, and some phrase patterns lean on that memory |
| blind set | 80 messages Gemini 3.8 Flash wrote straight to a file (40 threats, 28 veiled; 40 hard-case complaints, zh_TW/en/ja); scored before anyone read it | **the honest report** |
| real outputs | 297 generated roasts and rewrites collected from earlier evidence runs (on-device 27.0.1 audit, 27.2 permissive probe, Worker gates) | false-positive check |

Both are saved here: `blind_set.json`, `real_outputs.json`; per-message results in `results/`.

## Results (phrases = `RewriteThreatScreen` in front, as in production)

| | dev threats | dev legit blocked | odd threats | odd legit | **blind threats** | **blind legit blocked** | real outputs blocked | median call |
|---|---|---|---|---|---|---|---|---|
| p0 (10-22 prompt), old phrases | 5/22 | 12/29 | 7/15 | 4/15 | 24/40 (judge alone) | 10/40 | 39/297 | 285 ms |
| p1 examples | 13/22 | 7/29 | 9/15 | 3/15 | — | — | 20/297 | 404 ms |
| p2 "would they feel in danger" | 5/22 | 19/29 | 7/15 | 9/15 | — | — | — | 282 ms |
| p3 more examples | 12/22 | 8/29 | 10/15 | 4/15 | — | — | 33/297 | 516 ms |
| p4 "watching" only | 5/22 | 2/29 | 7/15 | 2/15 | — | — | — | 343 ms |
| p5 factual mentions | 5/22 | 3/29 | 9/15 | 4/15 | — | — | — | 292 ms |
| p6 quote then decide (80 tokens) | 1/22 | 2/29 | 5/15 | 0/15 | — | — | — | 516 ms |
| p3 under DEFAULT guardrails | 17/22 | 19/29 | 12/15 | 8/15 | — | — | — | 527 ms |
| new phrases only | 22/22 | 0/29 | 15/15 | 0/15 | **5/40** | 0/40 | 0/297 | 0 |
| new phrases + p0 | | | | | 25/40 (veiled 13/28) | 10/40 | | 293 ms |
| **new phrases + p1** (shipped) | | | | | **32/40 (veiled 20/28)** | **8/40** | 20/297 | 402 ms |
| new phrases + p3 | | | | | 32/40 | 10/40 | | 539 ms |

Even half, not blind: phrases + p0 13/15 threats, 1/15 legit blocked; phrases + p1
14/15, 4/15.

## What this says

- p1 is better than the shipped prompt on every measure, so it replaces it
  (`RoastEngine.threatJudgeInstructions`). That also improves the live rewrite.
- The phrase layer is overfit to whatever it was written from: 37/37 on the
  tuning sets, 5/40 blind. It costs nothing and blocks 0 of 297 real outputs, so
  it stays, but it is not evidence of coverage.
- **The on-device model is a weak veiled-threat judge whatever the prompt.** Blind,
  about 1 veiled threat in 4 still passes, and descriptions of the reader's own
  threats ("you threatened to ruin my career") are its main false positive.
  Reasoning first made it worse (p6). Default guardrails catch more but block most
  real roasts on 27.2.
- So A3's gate line "0 threats reach the screen" cannot be met by screens alone on
  synthetic veiled threats. What reaches a real screen also depends on whether the
  generator writes a threat at all: see `../e2e/`.

## Reproduce

```bash
R=~/Documents/RoastMate; H=$R/docs/evidence/2026-10-27-v18-plan/harness/safety; OUT=<scratchpad>/build
swiftc -O -o $OUT/judgetune $H/judgetune/main.swift $H/Stubs.swift $R/Shared/AI/RewriteThreatScreen.swift
$OUT/judgetune dev  $H/judgetune/prompts/p1_examples.txt     # dev | odd | even | all | file:<path>
$OUT/judgetune file:$H/judgetune/blind_set.json $H/judgetune/prompts/p1_examples.txt
# env: PHRASES=0 (judge alone), GUARD=default, MAXTOK=80 PARSE=last (for p6)
```
