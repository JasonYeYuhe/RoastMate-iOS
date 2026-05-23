# RoastMate — Phase 2 Plan (2026-06)

**Date:** 2026-05-23 · **Author:** Claude (for YE) · **Status:** v2 — finalized
after a Gemini 3.1 Pro + Codex (gpt-5.5) adversarial review of the v1 draft
(both converged tightly; this doc folds their critique in).
**Builds on:** `docs/NEXT_PHASE_PLAN_v1.2.md` (the v1.2→v2.0 macro strategy)
and `docs/A_PRIME_TELEMETRY.md` (the schema A′ ships).
**Frames:** 2026-05-24 → ~2026-06-21 (around WWDC26 Jun 8–12).

> **Reviewers' one-line verdict:** *"The direction is right, but B was
> trying to be scientifically credible before it was operationally useful;
> A′ doesn't matter until real users can export it."* This doc cuts B in
> half, pulls A′ delivery to W1, and refuses the LLM-as-judge yak-shave.

---

## 1. State at the start of this phase (verified 2026-05-23)

- **iOS v1.0** = `READY_FOR_SALE` (LIVE on App Store).
- **macOS v1.0** = `WAITING_FOR_REVIEW` (submitted 03:53Z today; sub `1ebdb9a2`).
- All 6 IAPs `APPROVED` (4 consumable credit packs + monthly/yearly Pro).
- **HEAD `5532ade`** on branch `v1.1`, pushed to `origin/v1.1`.
- **A′ telemetry MVP** is on branch but NOT in any uploaded build — needs a
  bump-and-upload to deliver to real users.
- WWDC26 confirmed **Jun 8–12** (Apple Newsroom). ~2.5 weeks out.
- Known-environmental: 3 sim unit tests fail on missing
  `com.apple.fm.language.instruct_300m.safety` model asset; reproduces at
  pre-A′ HEAD (verified via stash). Not blocking; fix is to re-download
  the sim's Foundation Models assets or boot a fresh sim.

---

## 2. Phase 2 scope

**Ship A′ + minimal share attribution (W1) → build a small, deterministic
B eval harness (W2) → meet WWDC with a ruler in hand (W3 gate) → make
the post-WWDC API branch decision on the evidence (W4).**

**Explicitly NOT in scope:**
- LLM-as-judge calibration (both advisors: yak-shave; manual-rate 80-120
  cells in 2-3 hours instead of prompt-engineering κ ≥0.7 for two weeks).
- D growth loop / short-video export (gated on A′ share-tap data).
- Custom keyboard extension (Option B dormant, 2026-05-19 decision).
- Conflict / patterns journal (companion brand third-rail; ethics pass first).
- Wholesale model migration without baseline harness data.
- Categorical telemetry breakdown / cohort flag (schema v2).

---

## 3. Workstreams

### 3.1 W1 deliverable — **build 8: A′ + minimal attribution → TestFlight**

The single most-leverage W1 ship. Both advisors: A′ doesn't matter until
real users can export it; the plan must not let build 8 drift to W4.

**Scope:**
- Bump `CURRENT_PROJECT_VERSION` 7→8 (per-platform; ASC accepts macOS 8
  even though iOS 7 is LIVE).
- **Minimal C-c:** ~~a subtle "via RoastMate" badge on the share card so
  the artifact is at least attributable~~ → **already shipped in v1.0**
  (`ShareCardView.swift:114-127` renders flame + "RoastMate" heavy +
  localized tagline). v2-of-v2 correction 2026-05-23 after re-reading
  the live code; both advisors re-converged on **skip the badge edit
  this phase**, treat brand-forward watermark as the attribution, and
  defer explicit "via" provenance language until A′ data shows share-
  card-driven acquisition or confusion. NO QR / template / size
  variants either — those wait for A′ share-tap data to justify them.
- Archive + export + altool upload for iOS (build 8). Submit to TestFlight
  external testing for the dev's 2-3 zh / en / ja beta testers.
- macOS build 8 can wait until macOS 1.0 review clears (don't compete
  with the in-review submission).

**Success criteria:** build 8 in TestFlight by end of W1; first telemetry
export by end of W2.

### 3.2 B — Eval harness (priority 2, week 2) — **two-tier, deterministic-first**

**Goal:** a re-runnable baseline matrix of generation mode × intensity ×
locale that surfaces regressions and gives the WWDC week a concrete
"is the new Apple model better?" ruler. NOT a research-grade benchmark.

**Tier A — Smoke (≤16 cells, ≤2 min):**
- Runs on every prompt / model / setting change.
- 1 representative scenario × 4 modes × 4 locales = 16 cells.
- Deterministic checks only: language match, refusal-or-fallback, safety
  pass/fail, output length range, latency.
- Wired into `scripts/preflight.sh` so it gates archives.

**Tier B — Baseline (~80-120 cells, on demand):**
- 5-8 scenarios × 4 modes × 4 locales ≈ 80-128 cells.
- Same deterministic checks as Tier A.
- **Quality is human-rated by YE** for the baseline run (~2-3 hours
  total per advisors' math). Score 1-5; ratings live alongside the JSON
  in `evals/runs/<date>/ratings.csv`.
- LLM-as-judge is optional / advisory ONLY (cloud judge via existing
  Groq proxy; never gating). Apple FM as judge is rejected (both
  advisors: it's not a good judge today).
- Reports as a deterministic markdown table that diffs cleanly vs. a
  prior baseline run.

**Deliverables (B1–B5):**

| id | deliverable |
|---|---|
| B1 | `docs/EVAL_HARNESS.md` — methodology + scoring + rubric (concise) |
| B2 | `evals/scenarios/` — 5-8 base scenarios × 4 locales drawn from existing `Shared/Resources/Scenarios.json` + 5 en + 5 ja additions |
| B3 | `evals/` Swift CLI or XCTest target — runs the cells, emits deterministic JSON + markdown report |
| B4 | **Baseline run** on build-7 code → committed `evals/runs/baseline-build-7.md` |
| B5 | `scripts/eval-rerun.sh` — diffs new run vs baseline, prints regression report |

**Success criteria for B itself:**
- Tier A ≤2 min, runnable in preflight on demand.
- Tier B ≤10 min wall-clock to complete (excluding human rating).
- A no-change rerun is byte-deterministic on the deterministic columns;
  the rated-quality column is human-only (no κ gate this phase).
- **Considered done when YE has rated the baseline once.** Hardening
  (LLM judge, κ calibration, larger matrix) belongs to a "B+" phase iff
  WWDC produces a real migration to evaluate.

### 3.3 C narrow slice — load-bearing quality fixes (week 2)

Two items only this phase (C-c moved to W4 / D pending A′ data per Codex):

- **C-a:** Tune the Vent prompt + sampling in
  `Shared/AI/PromptBuilder.swift` for the zh scenario pack. Today's
  outputs occasionally over-hedge or reach for English idioms. Targeted
  fix; ship with a fixture-output diff against the W2 baseline.
- **C-b:** zh-Hant tone audit on Vent / Feral / Sharp. Codex's framing:
  a focused review checklist + 6-10 representative fixture outputs, NOT
  a broad localization project.

**Explicitly NOT in C this phase:**
- New share-card formats / templates / sizes.
- Short-video export (D, gated on A′ share-tap data).
- QR codes / aggressive attribution (defer pending A′ signal).
- Gallery / community (cut entirely per macro plan §8).

### 3.4 Operational track

- **A′ baseline gathering — on the critical path, not parallel.** Install
  build 8 on dev machine + 2-3 zh / en / ja TestFlight testers W1. One
  week of usage → manual aggregation by end of W2. Treat as direction-
  only / smoke test of the pipeline; not statistically significant.
- **macOS review:** if Apple rejects on a fixable issue (screenshots,
  metadata), expedite immediately per Codex — *"review-state churn
  beats calendar purity."* If it sails, no action needed.
- **Schema v2 backlog (note, don't build):** cohort-D7/D30 "did_generate"
  flag, categorical paywall-trigger, App-Store review-mining script.
- **Repo hygiene (small W1 task):** `.gitignore` the screenshot working-
  tree noise + the cloud-dup `RoastMate 2.xcodeproj/` so future commits
  don't have to manually exclude them.

### 3.5 WWDC week (Jun 8–12) — fill a capability matrix, don't just watch

Per Codex: passive "watch sessions" mode turns WWDC reactivity back into
vibes. Pre-write the matrix; fill it during the week:

| API surface | local model avail? | API shape | latency expectation | privacy posture | multilingual? | deployable before iOS 27 GA? | migration cost (S/M/L) |
|---|---|---|---|---|---|---|---|
| (e.g. new Foundation Models tier) | | | | | | | |
| (e.g. Visual Intelligence dev API) | | | | | | | |
| (e.g. SwiftUI generation primitives) | | | | | | | |
| (e.g. richer App Intents) | | | | | | | |

NO migration code commits this week. The matrix is the ONLY WWDC-week
deliverable. The API branch decision is committed in **W4**.

---

## 4. Sequencing

| week | dates | focus |
|---|---|---|
| W1 | May 24 – May 31 | **Build 8 TestFlight ship (A′ + minimal "via RoastMate" badge).** Repo-hygiene gitignore. Start B1 docs + B2 scenarios. Watch macOS review email. |
| W2 | Jun 1 – Jun 7   | B3 harness CLI + B4 baseline run + YE manually rates the 80-120 cells. C-a prompt tune. C-b zh-Hant audit + fixtures. A′ exports landing from TestFlight. |
| W3 | Jun 8 – Jun 14  | **WWDC week.** Fill the §3.5 capability matrix. No migration commits. |
| W4 | Jun 15 – Jun 21 | **API branch decision** committed. Either: scoped migration spike (APIs land) OR C-c attribution + D groundwork (no APIs / A′ supports it). Possible macOS build 8 if iOS 1.0.1 ships. |

---

## 5. Decisions locked in this revision (no longer open)

Both advisors agreed on most; I marked the one genuine fork.

1. **A′ build delivery → ship build 8 in W1 (TestFlight first).** Both
   advisors converged: A′ only matters with real users.
2. **C-c attribution → minimal "via RoastMate" badge bundled with the W1
   A′ ship; defer QR / templates / sizes until A′ shows share-tap signal
   in W4.** This is the *compromise* between Gemini ("don't measure a
   broken loop — ship C-c with A′") and Codex ("defer C-c until A′ data
   justifies it"). Tiny badge is a 1-2h add that keeps the loop honest
   without spending pre-WWDC time on QR mechanics.
3. **macOS rejection → expedite immediately if fixable** (Codex). The
   3.1.2(c) description sync should preempt the iOS-era rejection, but
   if Apple flags ja/zh-Hant screenshots or anything else fixable, push
   the patch on the same day.
4. **LLM-as-judge → REJECTED as gating** (both advisors). Use
   deterministic checks for B's pass/fail; YE human-rates the baseline
   manually (~2-3 hours). Cloud LLM judge is optional and advisory only
   if added later in B+ hardening.
5. **Eval scenarios → start from `Shared/Resources/Scenarios.json` +
   5 en + 5 ja additions.** No App-Store-review crowdsourcing this phase.

---

## 6. Risks & mitigations

- **B scope creep** — the matrix is the temptation. Hold to Tier A + Tier
  B sizes (≤16 / ≤128 cells) and the human-rated baseline. Anything more
  is B+ and not this phase.
- **WWDC distraction** — the "no migration commits until W4" rule is
  the firewall. The pre-written capability matrix gives WWDC week a
  concrete deliverable that *isn't* code.
- **Sim infrastructure flake** (current 3-test issue) — note the reset
  workflow inline in the B docs; run the harness baseline on a device
  iff the sim's Foundation Models assets stay broken.
- **A′ N too small** — explicit caveat in the baseline report; treat the
  TestFlight data as a smoke test of the pipeline, not signal.
- **macOS review babysit** — Codex's "expedite if fixable, otherwise let
  it cook" is the rule; do not let macOS review-state pull focus from
  iOS evidence work.

---

## 7. Hard guardrails carried forward (do not regress)

- **Privacy moat:** on-device by default; cloud only behind 5.1.2(i)
  explicit consent; ephemeral audio; **no third-party SDK** (analytics,
  paywall, anything).
- **"Tool, not a companion" framing:** no relationship simulation, no
  persistent persona, no longitudinal patterns.
- **SafetyFilter and crisis handoff:** additive only; never weaken.
- **Build pipeline:** bump `CURRENT_PROJECT_VERSION` per platform per
  upload; keep keyboard target in `project.yml` but `embed:` commented
  out. macOS .pkg pipeline + installer cert path documented in memory
  `reference_asc_automation`.
- **A′ schema v1 keys are a public contract** — new counters go at the
  end of `EventLedger.Counter`; nothing renames.

---

## 8. Out of this plan (re-emphasised)

- Custom keyboard (Option B dormant).
- Companion drift (no journal, no longitudinal patterns, no persistent persona).
- Cloud-default-on flip (5.1.2(i) gate is final).
- Mainland-China SKU.
- LLM-as-judge as gating requirement.
- Wholesale model migration without baseline.

---

## 9. Advisor synthesis (what changed in v2 of this draft)

| draft v1 (my first cut) | v2 (after both advisors) | source |
|---|---|---|
| B = "20-30 prompts × all modes × all intensities × 4 locales" | **B = two-tier (≤16 smoke / ≤128 baseline)**; "full matrix" is B+ | Codex (~2000 cells is not a 2-week solo deliverable) |
| LLM-as-judge with ≥0.7 κ as B success gate | **Deterministic checks gating; YE manual-rates baseline; LLM judge optional & advisory only** | Both (κ calibration ≈ 2-week research project; manual rate ≈ 2-3 hours) |
| A′ build bump deferred to W4 | **A′ build 8 to TestFlight in W1** | Both (A′ only matters when real users can export) |
| C-c attribution polish = "polish" in week 2-3 | **Minimal badge with A′ in W1**; defer QR/templates pending A′ data | Synthesis (Gemini wants it shipped, Codex wants it gated; minimal badge bridges) |
| C-b = "zh-Hant tone audit" (open-ended) | **C-b = focused checklist + 6-10 fixture outputs** | Codex |
| WWDC week = "watch sessions" | **Pre-written capability matrix filled during the week** | Codex |
| macOS review = babysit watch | **Expedite if fixable; otherwise let it cook** | Codex (Gemini said cut babysitting; this is the pragmatic version) |
| 5 open decisions left to user | **All 5 resolved here** (4 unanimous, 1 synthesised) | Synthesis |

Reviewer-rated likelihood that v2 ships on time, solo, in 4 weeks:
- **High** for W1 (A′ ship + minimal C-c + repo hygiene).
- **High** for W2 (B harness Tier A + B + baseline + C-a + C-b focused).
- **Medium** for W3 (depends on WWDC content; matrix is the safety valve).
- **Medium** for W4 (API branch decision — depends on what WWDC actually
  ships; the plan has both branches scoped).
