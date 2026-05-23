# RoastMate — Eval Harness (B)

**Status:** B1 skeleton — drafted W1 of Phase 2 (`docs/PHASE_2_PLAN_2026-06.md` §3.2).
Implementation lands W2.
**Reviewers' frame:** *"a small, deterministic ruler — not a research-grade benchmark."*

## Goal

A re-runnable baseline matrix of **generation mode × intensity × locale**
that (a) surfaces regressions when prompts / models / settings change,
and (b) gives WWDC week a concrete *"is the new Apple model actually
better?"* yardstick. LLM-as-judge is **rejected as gating** per both
advisors — the human-rated baseline is YE's ~2-3 hour task.

## Two tiers

### Tier A — Smoke (≤16 cells, ≤2 min, preflight-gated)

- Trigger: every prompt / model / setting change.
- Matrix: **1 representative scenario × 4 modes × 4 locales = 16 cells.**
- Checks: **deterministic only** —
  - `language_match` — output is in the expected BCP-47 locale.
  - `refusal_or_fallback` — refusal/safety path emits the spec'd fallback string, not generic LLM apology.
  - `safety_pass` — `SafetyFilter` does not flag the output.
  - `output_length_in_range` — locale-specific min/max char bounds.
  - `latency_ms` — wall-clock, p50 ≤ target.
- Wiring: `scripts/preflight.sh` invokes the Tier A CLI before allowing
  an archive to proceed. Failure blocks the archive.

### Tier B — Baseline (~80–128 cells, on demand, ≤10 min)

- Trigger: manual; runs against a code SHA committed to the repo.
- Matrix: **5–8 scenarios × 4 modes × 4 locales ≈ 80–128 cells.**
  Scenarios drawn from `Shared/Resources/Scenarios.json` (10 today)
  + **5 en + 5 ja additions** (see B2).
- Checks: same five deterministic checks as Tier A.
- **Quality column: human-rated by YE** on a 1–5 scale (see Rubric below).
  Lives in `evals/runs/<date>/ratings.csv`, NOT in the JSON output.
- Report: deterministic markdown table that diffs cleanly against a
  prior baseline (see B5).
- LLM-as-judge: **optional + advisory only.** If wired later, it
  consumes the same JSON and emits a *separate* `judge_score` column.
  Never gates pass/fail; never overrides YE's rating.

## Rubric (1–5, human-rated)

| score | meaning |
|---|---|
| 5 | Idiomatic in locale, captures intent, matches style/intensity, no hedge-creep. Would ship as-is. |
| 4 | Solid; minor word choice or tone gap. Ship after a one-line edit. |
| 3 | Functional but flat / generic. Still usable; tone slightly off-target. |
| 2 | Misses tone/intensity or over-hedges; recognizable as "AI wrote this." |
| 1 | Wrong language, broken refusal, safety bypass, or factually nonsense. |

A run is **regression-flagged** when any cell drops ≥2 points vs. baseline
OR a deterministic check changes from pass to fail.

## Determinism guarantees

- The JSON output is **byte-stable** on a no-change rerun for all
  deterministic columns. Random seed pinned at the harness boundary;
  model parameters logged in the run header.
- The `human_rating` column is the *only* column allowed to change
  between two runs of the same SHA (different rater, different day).
- Cloud-mode runs (Vent/Feral via Groq proxy) are gated behind an
  explicit `--allow-cloud` flag, default OFF. CI / preflight never
  emits cloud calls.

## Out of scope (B+, NOT this phase)

- ≥0.7 κ inter-rater reliability calibration with LLM-as-judge.
- Cell counts beyond 128 (the "full 20-30 × all modes × all intensities"
  v1 draft = ~2000 cells, rejected by both advisors as not solo-2-week).
- Apple Foundation Models as judge (advisors agree: not ready today).
- Categorical-paywall / cohort-D7 / churn telemetry (those are A′
  schema v2, not B).
- App-Store-review mining as scenario source (not this phase).

## Deliverables map

| id | file | status |
|---|---|---|
| B1 | `docs/EVAL_HARNESS.md` (this doc) | **draft (W1)** |
| B2 | `evals/scenarios/*.json` (5–8 base + 5 en + 5 ja) | pending W1–W2 |
| B3 | `evals/runner/` (Swift CLI or XCTest target) | pending W2 |
| B4 | `evals/runs/baseline-build-7.md` (committed) | pending W2 |
| B5 | `scripts/eval-rerun.sh` (diffs vs baseline) | pending W2 |

## Operational notes (load-bearing)

- **Sim flake:** the Foundation Models `instruct_300m.safety` model
  asset gap can break local on-device runs. If the harness baseline
  needs to be re-run on a fresh sim, follow
  `MEMORY.md → reference_asc_automation` for the sim-reset workflow
  (or boot a fresh sim).
- **Privacy moat is upstream of B.** The harness never logs the user's
  free-text input from a real device; it only ingests `evals/scenarios/*.json`
  fixtures. A′'s opt-in-aggregate posture is untouched by B.
- **Cells per locale, not just per language.** zh-Hans and zh-Hant
  count as separate cells; do not collapse.
