# `evals/runner/` — eval harness implementation

**Status:** W1 skeleton + ad-hoc backend comparison script. Full Swift
CLI (B3 per `docs/PHASE_2_PLAN_2026-06.md` §3.2) lands W2.

## Layout

```
evals/runner/
├── README.md                           (this file)
├── scripts/
│   └── compare_backends.py             (ad-hoc 3-way backend comparison)
└── Sources/EvalRunner/                 (W2 — Swift Package CLI; not started)
```

## `scripts/compare_backends.py`

One-off comparison harness for "given the same RoastMate-generated
prompt, what do DeepSeek / xAI Grok / Groq Qwen3 return?". Useful
input for the W4 API-branch decision (§4 of the phase plan).

### Why a Python ad-hoc script, not the Swift CLI?

- The Swift CLI (B3) needs to run Apple Foundation Models in-process,
  which means an iOS/macOS test bundle. That's the W2 deliverable.
- For a one-off cross-backend taste test that hits HTTP-only APIs,
  Python is faster to write and runs cross-platform.
- The Python script is a **reference implementation** for the prompt
  construction logic — when the Swift CLI lands, it can cross-validate
  by sending the same bytes to the same backends.

### Run

1. Drop your keys in `/tmp/api_keys.env` (one per line, `KEY=VALUE`):
   ```
   DEEPSEEK_API_KEY=sk-...
   XAI_API_KEY=xai-...
   GROQ_API_KEY=gsk_...
   ```
2. `python3 evals/runner/scripts/compare_backends.py`
3. Script auto-wipes `/tmp/api_keys.env` after reading.
4. Structured output also saved to `/tmp/roastmate_backend_compare.json`.

### What's mirrored from `Shared/AI/PromptBuilder.swift`

The script's `build_system_prompt()` + `build_user_prompt()` reproduce
the Swift logic for the **default** code path:
- `locale = zh-Hans`, `style = passive_aggressive`, `mode = roast`,
  `intensity = sharp`, `safeMode = ON`, `variants = 3`.
- Universal safety preamble, language hint, language enforcement,
  per-mode guidance, per-intensity guidance — all byte-equivalent.
- The `passive_aggressive` style ships only one English few-shot
  example, which the Swift `examplesForPrompt` filter drops for zh.
  The script preserves that drop (no EXAMPLES block in the zh prompt).

### What's NOT mirrored (intentionally)

- Vent / Feral private-draft prompts (those have their own preambles
  + calibration examples; defer to the Swift CLI in W2).
- Rewrite-as-sendable two-step (separate flow, W2+).
- Reply / Translate / Argument / Social modes (different scoping;
  W2 deliverable).

## W2 Swift CLI (B3) — planned layout

```
Sources/EvalRunner/
├── main.swift                 — argparse, dispatch
├── PromptBuilder.swift        — link or mirror Shared/AI/PromptBuilder.swift
├── Backend.swift              — protocol Backend { call(system, user) async -> Result }
├── Backends/
│   ├── AppleFM.swift          — Foundation Models (gated #if canImport)
│   ├── Groq.swift
│   ├── DeepSeek.swift
│   ├── Grok.swift
│   └── OpenRouter.swift       — fallback path the production worker uses
├── Runner.swift               — iterates scenarios × modes × locales
├── DeterministicChecks.swift  — language_match / refusal_or_fallback /
│                                safety_pass / output_length / latency
└── ReportWriter.swift         — markdown diff vs baseline; JSON snapshot
```

The CLI consumes `evals/scenarios/*.json` (already populated W1) and
emits `evals/runs/<date>/{snapshot.json, report.md, ratings.csv}`.

## Out of scope this phase

- LLM-as-judge κ calibration (rejected by both advisors per plan §5).
- Backends beyond the 4 listed above.
- A model-routing decision in `evals/`; that lives in the production
  cloud-worker (`cloud-worker/src/index.js`) and is updated based on
  baseline / regression evidence the harness produces.
