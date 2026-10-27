# Baseline on macOS 27.2 (2026-10-27, 22:40–22:50 JST)

This Mac: macOS **27.2 (26B123)**, installed **2026-10-27 14:12** — after every
measurement in the plan, which were taken on 27.0.1. Apple Intelligence
available, model variant "AFM 3 Core". All calls on-device, $0.

## 1. On-device generation (`harness/audit/probe`, production prompts)

`probe_all.jsonl`, summary `probe_all_summary.txt`; free part `probe_free.jsonl`.

| part | 27.0.1 (plan §2.2 / lens 1) | **27.2 today** |
|---|---|---|
| Savage, Pro styles, 40 calls | zh_TW 10/16 model-written, en 14/16 accepted, ja 4/4 | **4/40 model-written**: en 0/16, zh_TW 2/16, ja 2/4, zh_CN 0/4 |
| Sharp + Pro style, 12 calls | 台劇腔 zh_TW 0/4 | **0/12** |
| Argument Simulator, 36 turns | 14/36 in the opponent's voice | **0/36** (all refused → curated) |
| Free: Composed `high_eq` + Sharp `passive_aggressive`, 16 calls (new part) | not measured (zh_TW Sharp refused 2/8 on 10-22) | **1/16 model-written** |

Every failure is `LanguageModelError` "May contain unsafe content" (84/84),
median 0.5 s. Not a broken model: `control_neutral.swift` — a neutral request and
a witty roommate complaint, en and zh — pass default guardrails 4/4 in 0.7–3.3 s.
What is refused is the production prompt.

## 2. Default vs permissive (`harness/lens2/fmb`, mode B)

`fmb_default_vs_permissive.txt`. 8 Savage/Pro cells (zh_TW ×4, en ×4):

| | default | permissive |
|---|---|---|
| accepted | **0/8** (律師函 en was accepted on 27.0.1) | **8/8**, 3 variants each, 24/24 strict pass, zh_TW all Traditional |
| latency | refusal 0.5–1.0 s | 3.9–6.8 s |

So A3's refuse-then-permissive costs ≈ 5–8 s, inside the ≤ 12 s target — but on
27.2 nearly every call takes the retry; "permissive stays the exception" no
longer holds.

## 3. Safety set, screen layers (`harness/safety`, `safety_screens.jsonl`)

`safety_set.json`: 30 threats (19 veiled, 26 held-out), 30 legitimate complaints
(28 held-out), 30 situations, 6 simulator cases; zh_TW / en / ja.

Layers as production runs them on a permissive variant: refusal check →
`SafetyFilter.validateOutput` → `RewriteThreatScreen` → one-word judge
(permissive, temperature 0, 4 tokens).

| | held-out | seed (tuned) |
|---|---|---|
| threats reaching the screen | **14/26** — 14 of 19 veiled pass | 0/4 |
| legitimate complaints blocked | 5/28 (c04 racism en, c07 en, c15 zh_TW, c23 小額訴訟 zh_TW, c27 ja) | 0/2 |

The judge catches 3/19 veiled threats on 27.2 (8/12 held-out on 27.0.1,
`RoastEngine.swift` comment). Judge median 274 ms, 0 errors.

**Consequence:** A3's gate ("0 threats reach the screen") fails on the screens
alone. A3 needs stronger veiled-threat screening first. Tune on a split of the
set, report on the other half, and add fresh items before claiming a held-out
number. The same judge guards the shipped 1.7.x 改成能發的 rewrite.

Crisis routing (`crisisSignal`) matches the code: s01–s03 hard, s04–s06 soft,
s07–s09 (telling someone else to die) none, by design. Simulator a03 would be
hard/soft but `ArgumentSimulatorViewModel` never calls `crisisSignal` (only
`validateInput`, :73) — A4 must route it.

## Reproduce

```bash
R=~/Documents/RoastMate; H=$R/docs/evidence/2026-10-27-v18-plan/harness; OUT=<scratchpad>/build
swiftc -O -o $OUT/lens1probe $H/audit/probe/{main,Stubs}.swift $R/Shared/AI/{PromptBuilder,StylePreset,SafetyFilter,ModelRefusal}.swift $R/Shared/Models/Intensity.swift
$OUT/lens1probe all > baseline.jsonl     # parts: savage | sharp | free | argument | all
python3 $H/audit/probe/analyze.py baseline.jsonl
swiftc -O -o $OUT/fmbprobe $H/lens2/fmb/{main,Stubs}.swift $R/Shared/AI/{PromptBuilder,StylePreset,SafetyFilter,ModelRefusal}.swift $R/Shared/Models/Intensity.swift
$OUT/fmbprobe B
swiftc -O -o $OUT/safetyrun $H/safety/{main,Stubs}.swift $R/Shared/AI/{SafetyFilter,ModelRefusal,RewriteThreatScreen}.swift
$OUT/safetyrun all > safety_screens.jsonl  # messages | crisis | all; exits 2 if the judge prompt drifted
```
