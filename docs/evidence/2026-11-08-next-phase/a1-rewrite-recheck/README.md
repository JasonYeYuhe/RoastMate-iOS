# A1 — rewrite re-check of the P2.1 post examples (2026-11-08)

**Why:** the posts quote two 「改成能發的」 rewrites made on 10-23 with 1.7.1 code on
macOS 27.0.1. 1.8.0 changed the threat screen and the threat-judge prompt. Do the
quotes still pass, and does the rewrite still work on 27.2?

**What runs.** These production files are compiled as-is: `PromptBuilder`,
`StylePreset`, `SafetyFilter`, `ModelRefusal`, `RewriteThreatScreen` and
`Intensity`. The judge prompt and its parser are cut verbatim from `RoastEngine.swift`
at build time. `main.swift` repeats `RoastEngine.rewriteAsSendableDetailed` step by
step:
1. the permissive-guardrail generation, temperature max(0.4, 0.8 − 0.2), 250 tokens
2. the refusal check
3. stripping a leading number
4. the strict filter
5. the threat phrases
6. the judge

Setup: style 高 EQ, zh_TW. The situations and drafts are the 10-23 Worker outputs
(call 5 and call 3 in the post kit). This Mac: macOS 27.2 (26B123), Apple
Intelligence available. Cost $0. The working tree's `Shared/AI` is identical to
`v1.8.0-ios29`.

**Result** (`run_1108.jsonl`):

| | result |
|---|---|
| the two quoted rewrites through the 1.8.0 screens | strict OK, no threat phrase, judge SAFE, both |
| 慣老闆 (5 runs) | 4 rewrites; 1 blocked by the judge (「…我今天已經很忙了。」) |
| 室友 (5 runs) | 4 rewrites; 1 blocked by the judge (「…好像大家都聽不見。」); 2 say 「我的碗盤」 (wrong owner) |
| latency | 2.5–2.9 s per rewrite including the judge |

So the quotes are still representative of 1.8.0. About 1 in 5 tries ends in the
labelled example because of a judge false positive. The PTT post says so. The
false positives are parked in `docs/NEXT_PHASE_PLAN_2026-11.md` §9.

**Rerun:** `build_and_run.sh <out dir outside ~/Documents> [runs]`.
