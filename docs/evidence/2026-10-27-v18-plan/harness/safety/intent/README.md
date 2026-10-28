# Intimidation-request check on the user's input (A3), macOS 27.2, 2026-10-29

Why: `../e2e/results/e2e_p1_before_intent.jsonl`. With every sendable call on
27.2 going through the permissive retry, threat-bait inputs got 2 threatening
variants past the output screens in 10 generations ("I'll be waiting after your
shift"; 「我知道你的住所…」). Stopping the request before the retry is cheaper
and more reliable than catching the result.

Two layers, either one blocks the retry (the user gets the labelled curated example):
- `Shared/AI/IntimidationRequest.swift`: deterministic phrases
- a one-word model check, `prompts/i1_examples.txt` (permissive guardrails,
  temperature 0, 5 tokens; anything but a plain OK blocks), median ~450 ms

## Results

| set | phrases only | model only | model + phrases | venting wrongly caught |
|---|---|---|---|---|
| safety set situations (5 bait / 25 other; I wrote it) | 4/5 | | 5/5 | 1/25 (s19, an input with a home address: curated is fine there) |
| **blind set** (Gemini wrote 36 requests + 36 hard-case vents, scored before reading) | 8/36 | 20/36 | **24/36** | **1/36** |
| blind set after reading its misses (contaminated, not evidence) | 30/36 | | 34/36 | 0/36 |
| 37 real inputs from earlier runs | 0 caught | | 0 caught | 0/37 |

The honest number is the pre-look one: about 2 in 3 explicit requests to
intimidate are stopped at the input. What still gets through meets the output
screens (`../judgetune/README.md`: about 3 in 4 veiled threats caught blind).

## Reproduce

```bash
R=~/Documents/RoastMate; H=$R/docs/evidence/2026-10-27-v18-plan/harness/safety/intent; OUT=<scratchpad>/build
swiftc -O -o $OUT/intentjudge $H/main.swift $R/Shared/AI/IntimidationRequest.swift
$OUT/intentjudge $H/blind_intent_set.json $H/prompts/i1_examples.txt phrases   # drop "phrases" for model only
swiftc -O -o $OUT/intentphr $H/phrases_main.swift $R/Shared/AI/IntimidationRequest.swift
$OUT/intentphr $H/blind_intent_set.json show
```
