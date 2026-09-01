# `apple-fm-guardrail` — on-device Apple FM guardrail measurement

Self-contained sibling of the `EvalRunner` (worker) target. Wires the on-device
Apple Foundation Models path the worker harness left stubbed ("B3 day 2"), to
measure the **guardrail refusal rate** on RoastMate's real prompts.

**Production code is NOT modified.** The prompt-construction sources here are
byte-verbatim copies (SHA-verified) of the shipping app, so the model sees
exactly what production sends:

- `PromptBuilder.swift`, `Intensity.swift`, `StylePreset.swift` — `cp` of
  `Shared/AI/…` and `Shared/Models/…` at repo HEAD `2fcce6d`.
- `AppLocalization.swift` — CLI stand-in. Only value that reaches the prompt is a
  style's `displayName` (one line of the user prompt); real per-locale display
  names are hard-coded from the four `Localizable.strings`. Guardrail-irrelevant.
- `Scenarios.swift`, `Checks.swift` — `cp` of the worker harness helpers.

## What it measures (and the methodology fix)

A refusal is counted **only** on a compile-time `if case .guardrailViolation`
match (`AppleFM.swift`). Every other `GenerationError` (rate limit, context
window, `unsupportedLanguageOrLocale`, decode, …) is bucketed separately and
**excluded** from the refusal numerator. This deliberately does NOT reuse
production's `AppleFMBackend.failureCategory(for:)`, which funnels unknown cases
into `.guardrail` and would over-count. Reports give the true-guardrail rate and
the production-style over-count rate side by side.

Hard availability gate: emits nothing unless `SystemLanguageModel.default
.availability == .available` (never fabricates from a simulator).

## Run

```bash
swift build --package-path evals/runner --product apple-fm-guardrail
evals/runner/.build/debug/apple-fm-guardrail --help
evals/runner/.build/debug/apple-fm-guardrail \
  --locale zh-Hans,zh-Hant,ja,en --intensity vent,feral --label myrun
# --dump-prompt prints the exact (system,user) per cell and skips the model call.
```

Outputs `results.json`, `report.md`, `cells.jsonl` under `evals/runs/run-<label>/`.
First run: `evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md`.
