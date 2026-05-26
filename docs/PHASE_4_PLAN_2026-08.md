# RoastMate — Phase 4 Plan (2026-08, v2 post-advisor-review)

**Date:** 2026-05-26 · **Author:** Claude (for YE) · **Status:** v2 — revised
after Gemini 3.1 Pro + Codex gpt-5.5 parallel review (both 2026-05-26).
**Builds on:** `docs/PHASE_3_PLAN_2026-07.md` + `project_phase3_w1_status` memory.
**Frame:** Phase 3 finishes in W8 (~Aug 23); Phase 4 ≈ Aug 24 → mid-Oct, six 1-week sprints.

> **One-line frame:** *"v1.0–v1.0.3 shipped. Surface complete. Telemetry alive.
> Cross-device tight. Now the next 8 weeks turn 'works' into 'compounds' —
> latency, onboarding, the A′ → product feedback ladder."*

---

## 0. State at the start of Phase 4 (audit)

### Shipped through Phase 3
- **iOS v1.0.0 → v1.0.3** all LIVE or in review (v1.0.3 submitted 2026-05-26 09:36 UTC).
- **macOS v1.0.1** still `WAITING_FOR_REVIEW` since 2026-05-23 — Apple slow on macOS.
- **20+ styles × 5 modes × 5 intensities × 4 locales** (en, zh-Hans, zh-Hant, ja).
- **A′ telemetry schema v2** (18 counters; opt-in, on-device, no SDK).
- **CloudKit auto-sync** for 6 `@Model`s including the β3 append-only CreditLedgerEntry.
- **Eval harness Tier A (preflight) + Tier B (baseline)** — but cloud-only.
- **Cloud worker** version 4663fae8; Groq Qwen3 (zh) + Llama-3.3-70B (en/ja); GLM Air fallback.
- **209/209 tests green** (178 W1 baseline + 31 added across W1 + W2).

### Carry-overs from Phase 3 W3-W8
- **α2** — `/v1/sharp` worker endpoint (Sharp/Calm cloud fallback).
- **α5** — B3 day 2: AppleFM XCTest harness so eval can run on-device traffic.
- **ε3** — weekly triage off real A′ data (needs ~4 weeks of v1.0.2+ data).
- **γ** — WWDC26 capability matrix (Jun 8-12) — fills in during Phase 3 W3.
- **δ** — growth loop, gated on ≥50 organic share taps in first 4 weeks of v1.0.2.

### Things v1.0.x doesn't do yet but probably should (gap audit)
- **Streaming responses** — both Apple FM and cloud worker can stream tokens.
  Today the user stares at a spinner for 1-5s. First-token streaming flips
  perceived latency from "waiting" to "happening." Single largest perception
  upgrade available.
- **Onboarding / first vent in < 60s** — today's flow asks the user to pick
  style + intensity + mode + type situation before any output appears. New
  users do not yet know what those mean.
- **Discoverability** — 5×5×20 = 500 surface-area combinations with no
  curation. Power users explore; new users freeze.
- **Pro value proposition clarity** — consumables ($0.049/gen) are cheaper
  per-generation than the monthly Pro tier (~$0.06/gen at 50 gens/mo). The
  real Pro draw is style/intensity unlock, not "unlimited" — current copy
  buries the lede.
- **Multi-modal input** — screenshot → on-device OCR → vent. Apple Vision is
  on-device, fits the privacy moat exactly. Vent about "this shit my
  coworker just sent" is a strong vent surface.
- **Performance budget** — there is no measured p50/p95 latency target per
  cell. Streaming alone would fix perceived; cold-start optimization fixes
  real.
- **Accessibility audit** — VoiceOver/Dynamic Type/Reduce Motion have not
  been swept since v1.0.0; the eval harness has nothing for it.
- **Locale parity** — Japanese pacing/word-count assumptions follow Chinese
  patterns where they shouldn't. Memory `project_aprime_status` notes
  ja-vent failed strong-word checks more than zh did — ja deserves its own
  calibration pass, not just C-a-of-Chinese-translated.
- **App Store discovery investment** — Custom Product Pages, App Preview
  videos, screenshot iteration have not been touched since the initial
  v1.0 submit.
- **Cloud worker observability** — backend selection is hard-coded; no
  latency/cost monitoring; no automatic fallback ladder. Memory says
  Hermes-3-405B is dead, patched to GLM Air. Next dead model is unobserved
  until traffic breaks.

---

## 0.5 Advisor synthesis (2026-05-26)

Both Gemini 3.1 Pro and Codex gpt-5.5 reviewed Phase 4 v1 in parallel. Findings
that change the plan:

### Convergences (both advisors, act unconditionally)

| Issue | Both |
|---|---|
| **Latency p50/p95 cannot be raw counters.** A′ EventLedger is integer-only. Use histogram-bucket counters (`generate_latency_under_1500ms`, etc.). Bump `TelemetryExport.schemaVersion` 2 → 3 — the schema-additive contract requires it. | ✅ |
| **ε4 multi-modal screenshot moves to Phase 5.** OCR introduces too many new failure modes for a W6 fallback slot. Scope properly in Phase 5. | ✅ |
| **β1′ ships now**, no need to wait for A′ data — starter prefill addresses both possible frictions at once. | ✅ |

### Gemini's catches

- **🔴 P0 — α2′ Sharp/Calm cloud fallback breaches 5.1.2(i).** Today
  `cloudAIConsentRaw` was granted FOR Vent/Feral privacy-masking. UserSettings'
  own comment says "Calm / Sharp / Savage stay 100% on-device regardless of this
  flag." α2′ as scoped would silently expand the consent past what users agreed
  to. **Fix:** either drop α2′, OR add a separate `cloudFallbackConsentRaw` with
  an explicit Sharp/Calm-fallback prompt. **Decision (this v2):** drop α2′ from
  Phase 4 scope. Sharp/Calm stay on-device. Re-evaluate in Phase 5 only with a
  proper distinct consent path.
- **🟡 P1 — Streaming + variantCount=3 is an architectural decision.**
  `RoastEngine.generate` returns `[String]` of 3 variants for non-vent modes.
  α6 streaming must decide: stream the first variant only with the others loading
  silently, OR refactor to `variantCount=1` across the board. v2 plan: stream
  variant-1 first, load variants-2-and-3 in parallel after, render as they land.
- **🟡 P2 — Q1 streaming priority** — move α6 to W1 so subsequent α work uses
  the new async surface. (Codex argues opposite — see below.)

### Codex's catches

- **🔴 P0/P1 — Streaming has a safety/accounting commit boundary.** Today
  `RoastEngine.swift` does input-validate → wait for full → output-validate →
  record success at L115/L219. `RoastGeneratorViewModel.swift` spends a credit
  at L100-114 BEFORE generation, saves history only after final validated
  text at L121-144. Naïve streaming could:
  - Display/share unsafe partial tokens
  - Fire telemetry success before final validation
  - Spend a credit on a cancelled generation that never produced output
  **Fix:** model streaming as events (`.partial`, `.finalValidated`, `.failed`,
  `.cancelled`) with a transient stream buffer for UI. No share / history /
  ledger-success / rating-prompt notification fires until `.finalValidated`.
  Define cancellation refund policy explicitly.
- **🟡 P1 — Paywall decision data is incomplete.** The α3 `paywall_trigger_*`
  counters tell us IMPRESSION source, not CONVERSION source. `PaywallView`
  records nothing per-purchase; `StoreService` records generic
  `purchase_attempts` / `purchases_completed`. β4 paywall refresh would learn
  impression volume but not which source actually buys. **Fix:** add
  `purchase_attempt_source_*` and `purchase_completed_source_*` counters
  (4 sources × 2 = 8 new) in P4-W4, BEFORE β4 paywall refresh in W5.
- **🟡 P1 — `firstLaunchDate` is brittle as the new-user gate.** It's seeded by
  wallet initialization, not necessarily true app first launch. Use
  `hasSeenOnboarding` transition or a new `starterCarouselSeenRaw` flag.
- **🟡 P2 — β1′ duplicates existing scenario surface.** `RoastGeneratorView`
  already shows scenarios on the idle empty-state. Don't build a parallel
  carousel system; improve the cold-start prominence + style/intensity prefill
  of what's already there.
- **🔴 Risk-register addition: δ gate integrity.** `share_taps` counter only
  fires on Share Sheet *open*, not completed share. Many simple `ShareLink`s
  in the app may not increment it at all. A ≥50 gate could be a false negative
  OR biased toward share-card composer users. **Fix:** audit every share
  affordance (`RoastCard`, `GeneratedRoastCard`, `ShareCardComposer` etc.)
  for telemetry-instrumentation parity BEFORE the gate fires in 4-week
  window.
- **Q1 streaming priority — Codex disagrees with Gemini.** Codex says α5 XCTest
  harness MUST land in W1 before streaming, so streaming regressions are
  measurable. v2 plan: keep α6 in W2, but require α5 XCTest harness as W1
  exit-gate.

### Both advisors' divergence on Q1 — synthesis
Gemini: "α6 to W1 so other α work doesn't get rewritten."
Codex: "α5 XCTest harness to W1 so streaming regressions are measurable."

Resolution: BOTH α5 AND α2/α5 rescoping in W1. α2′ is dropped (Gemini P0); α5
is high-value-low-risk and unblocks measured streaming. α6 in W2 with the
event-protocol from Codex + variantCount strategy from Gemini.

---

## 1. Phase 4 scope — three themes + carry-overs (v2 revised)

### α′ — Quality compounds (continuation of Phase 3 α)
The Phase 3 telemetry + eval harness work shipped the *measurement* layer.
Phase 4 closes the *act on what you measure* loop.

#### α2′ — `/v1/sharp` cloud fallback (carried from P3 W3)
- New worker endpoint mirroring `/v1/vent` but with Sharp/Calm prompts (no
  ventPreamble, no feralPreamble). Uses same `MODEL_OVERRIDE_ALLOWLIST` side
  door for eval.
- iOS `RoastEngine` retries cloud iff `cloudAIConsentRaw` is granted AND the
  on-device call fails with a recoverable error (network or
  guardrail-violation; not "user typed slurs").
- Default OFF (no UI change); user opts in via existing toggle.
- Unblocks Tier A 16-cell matrix in the harness.

#### α5′ — AppleFM XCTest harness (carried from P3 W3)
- Move EvalRunner from SPM CLI into an XCTest target so it can call the
  local Foundation Models framework with proper entitlements.
- Required to test ~60% of production traffic (on-device intensities).
- Recommended approach per Phase 3 §3.1: move existing EvalRunner sources
  into a new `RoastMateEvalTests` target.

#### α6 — Streaming responses ⭐ (new, v2-revised)
- Apple FM `LanguageModelSession.streamResponse(to:options:)` (iOS 26).
- Cloud worker streams via SSE.
- **NOT** a uniform `AsyncStream<String>` — Codex P0/P1 catch. Event protocol:
  ```
  enum GenerationEvent {
      case partial(String)        // transient stream buffer; UI-only
      case finalValidated([String]) // safety-filtered final variants
      case failed(RoastError)
      case cancelled              // refund credit if spent
  }
  ```
- Safety/accounting commit boundary:
  - `partial` updates a transient UI buffer; NO share/history/ledger touch.
  - `finalValidated` is the only event that records `recordGeneration(cloud:)`,
    notifies `RatingPromptService`, saves to history, marks `wasShared = false`.
  - `cancelled` reverses any pre-charged credit (so the user isn't billed for
    output they never got).
- **variantCount=3 strategy** (Gemini P1): stream variant-1 first for instant
  feedback, then load variants 2-3 in parallel after, render as they land.
  Don't open 3 concurrent FM sessions — memory + thermal hazard.
- **Histogram-bucket telemetry** for first-token latency (NOT raw p50/p95 —
  EventLedger is integer-only):
  - `first_token_under_400ms`, `first_token_400_to_1000ms`,
    `first_token_1000_to_2500ms`, `first_token_over_2500ms`.
- Feature flag in W2 sprint; flip on in W3 once stable. Telemetry bucket
  counters live in EventLedger end-of-enum (additive within schema v3).
  Bump `TelemetryExport.schemaVersion` 2 → 3 (the schema-additive contract
  requires bumping when new keys are introduced).

#### ε3 — weekly triage cadence (continuation)
- First triage Monday after v1.0.2 reaches 4 weeks of A′ data.
- `evals/triage/2026-MM-DD.md` — top failure tags by locale + mode +
  intensity, paywall-source dropoff, optional `feedback_tag_*` clusters.
- Drives prompt tune ladder (C-d, C-e, …).

### β′ — Friction down (new theme: onboarding + UX)

Phase 3 measured. Phase 4 acts on the most likely friction points BEFORE
A′ data hits the threshold required to confirm them — these are obvious
enough that running A/B on the void is not productive.

#### β1′ — First vent in <60s — "starter prefill" (new, v2-revised)
- **Not a parallel carousel system** (Codex P2). `RoastGeneratorView` already
  surfaces scenarios on idle. β1′ promotes a 3-pick subset to a more prominent
  cold-start position AND auto-fills style/intensity from
  `Scenarios.defaultStyleId` when the user taps one.
- **Gate via `hasSeenOnboarding` transition** (Codex Q2) OR a new
  `starterCarouselSeenRaw: Bool?` field on UserSettings, NOT `firstLaunchDate`
  (which is wallet-seeded, not first-app-launch). Once a user dismisses or
  generates from the starter prefill, the flag flips and the cold-start path
  becomes the normal idle path.
- Tap a card → pre-fills the situation field + auto-suggests a style /
  intensity combo from `Scenarios.defaultStyleId`. User can edit before
  generate.
- Targets: median first-vent generate ≤60s from app open. Measured via a
  new A′ histogram counter `time_to_first_generation_bucket_under_30s`,
  `..._30_to_60s`, `..._60_to_120s`, `..._over_120s`.

#### β2′ — Discoverability without ML (new)
- "Recommended for you" without per-user model: a static map from
  `(style.tags, locale, intensity_history_mode)` → ranked combos.
  Privacy-safe (no model, no upload).
- Surface as a "Try" row on the generator screen for users post-onboarding.
- Validated via A′ tag-feedback delta: if "wrong style" tag drops by >25%
  for users seeing the row, it's a win.

#### β3′ — Performance audit (new, v2-revised)
- **Histogram-bucket counters, not raw p50/p95** (both advisors). EventLedger
  is integer-only; storing raw timestamps for percentile compute bloats local
  state + CloudKit sync.
- Buckets per `(intensity, locale, backend)` would be 5 × 4 × 2 × 5 = 200
  counters — too many. Scope to:
  - 4 latency buckets × 2 paths (apple_fm, cloud) = 8 new counters.
  - Names: `generate_latency_under_1500ms_apple_fm`,
    `generate_latency_1500_to_3000ms_apple_fm`, etc.
- Targets (informational; don't gate ship):
  - Apple FM Sharp/Calm: p50-bucket = "under 1500ms"
  - Cloud vent/feral: p50-bucket = "1500-3000ms"
  - App cold-start: p50 < 1.0s on iPhone 12 baseline (measured via
    `app_cold_start_under_1000ms` etc.)
- Bump `TelemetryExport.schemaVersion` 2 → 3 (same bump as α6).

#### β4′ — Pro value-prop refresh (new, v2-revised)
- **First add purchase conversion-source counters** (Codex P1) — α3
  `paywall_trigger_*` tracks IMPRESSION source; we don't yet track which
  source actually CONVERTS. Add 8 new counters in P4-W4 BEFORE β4:
  - `purchase_attempt_source_low_credits` / `..._pro_tap` /
    `..._style_locked` / `..._intensity_locked`
  - `purchase_completed_source_low_credits` / `..._pro_tap` /
    `..._style_locked` / `..._intensity_locked`
  Threaded by stashing the trigger source in `PaywallView` state and reading
  it from `StoreService.purchase()` callbacks.
- Today's `PaywallView` lists Pro features and consumables side-by-side.
  Decision after 4 weeks of v1.0.2+/v1.0.3+ data (conversion AND impression):
  - If `purchase_completed_source_pro_tap >> low_credits`: lead with Pro,
    credit packs below.
  - If `purchase_completed_source_{low_credits, style_locked, intensity_locked}`
    dominate: lead with credits, Pro as upgrade.
- **Don't pre-build both variants.** Build a small reorderable/content-slot
  structure in PaywallView (Codex Q3); make one evidence-based edit when the
  data lands. No remote-config — single-binary ship.

### γ′ — System integration (carried + WWDC-conditional)

#### γ-from-P3 — WWDC26 (Jun 8-12) capability matrix
- Filled during P3 W3 (Jun 9-15).
- Phase 4 actions any matrix-positive workstreams from there. Until then:
  no Phase 4 commit to γ.

### δ′ — Growth loop (data-gated, carried from P3)

#### δ-from-P3 — ≥50 organic share taps gate
- Measured at v1.0.2 + 4 weeks (≈ end of June 2026).
- If pass: ship the prepared direct-share + animated-GIF + Custom Product
  Page workstreams (built behind feature flag in P3 W5-8).
- If fail: redirect to α + β depth.

### ε′ — Multi-modal screenshot vent — **DEFERRED TO PHASE 5 (v2)**

~~Screenshot → on-device OCR → vent.~~

Both advisors: too many new failure modes (OCR quality across locales,
emoji-heavy text, stylized messages, garbage sanitization, share-extension
re-architecture) for a 1-week W6 fallback slot. Scope properly in Phase 5 as
its own dedicated track. Optionally use a W6 spike to validate OCR baseline
on a representative locale corpus before committing to a Phase 5 build.

---

## 2. Phase 4 sequencing (six 1-week sprints, Aug 24 → Oct 5) — v2 revised

| W | Dates | Focus |
|---|---|---|
| P4-W1 | Aug 24 – Aug 30 | **α5′ AppleFM XCTest harness** (P3 carry; W1 exit-gate so streaming regressions are measurable). α2′ DROPPED — see §0.5. |
| P4-W2 | Aug 31 – Sep 6  | **α6 streaming responses** (event protocol; transient buffer; commit boundary at `finalValidated`; histogram-bucket telemetry; bump TelemetryExport.schemaVersion to 3). Behind feature flag. |
| P4-W3 | Sep 7  – Sep 13 | **β1′ starter prefill** (gate via `hasSeenOnboarding` or new `starterCarouselSeenRaw`; extends existing RoastGeneratorView idle scenarios, not a parallel carousel) + **β3′ histogram-bucket latency counters** (8 new counters). |
| P4-W4 | Sep 14 – Sep 20 | **purchase_*_source_\* counters** (8 new) for β4 prerequisite + **β2′ discoverability** (extend existing scenario row) + **first ε3 weekly triage** off v1.0.2+ data. Audit share_taps coverage before δ gate fires. |
| P4-W5 | Sep 21 – Sep 27 | **β4′ Pro paywall refresh** (one-shot edit; reorderable PaywallView content-slot structure) + γ if WWDC matrix found a fit. |
| P4-W6 | Sep 28 – Oct 5  | **δ ship** if gate passed AND share_taps audit clean (animated GIF + direct-share + CPP). Optional ε4 OCR spike (no ship). Ship **v1.0.4** (α5+α6) and **v1.0.5** (β1′+β2′+β3′+β4′ + δ if go). |

**Ship cadence:** assume v1.0.4 in W3 (carrying α2+α5+α6), v1.0.5 in W6
(carrying β + γ if any + δ or ε4).

### Decisions LOCKED at the start of Phase 4
- **No remote-config for prompts.** Same decision as P3 §9.1.
- **A′ schema v3** is the next-bump trigger if any failure or feedback counter
  reveals a sub-category gap. Stay additive-only; never rename.
- **Companion drift forbidden.** ε4 multi-modal vent is fine (one-shot
  input, no persistent persona) but anything that proposes a "memory" of
  the user's past vents is rejected.
- **Privacy moat absolute.** No third-party SDK ever. ε4's OCR is on-device
  Apple Vision only.

---

## 3. Open decisions for advisor synthesis (Gemini + Codex)

**Q1 — Streaming priority.** α6 (streaming responses) is the single largest
perceived-latency upgrade available. It's also a non-trivial UI refactor.
W2 placement is aggressive. Is it the right call to put streaming SECOND
(after α2/α5 carry-overs in W1), or should it be W1 + push α5 to later?

**Q2 — Onboarding bet.** β1′ assumes the new-user friction is "don't know
what style/intensity to pick." If A′ telemetry (when data lands) shows
the actual drop-off is at "type situation" — different fix entirely. Should
β1′ wait for data, or is "type situation friction" so unlikely that we
should ship the starter cards now?

**Q3 — Pro paywall refresh timing.** β4′ explicitly waits for `pro_tap` /
`low_credits` / `style_locked` source-counter data (P3 W2 α3 just shipped
that). 4-week-after-v1.0.2-LIVE puts the decision in late June. Should we
also build BOTH variants ahead of time so the flip is one feature-flag
change after data lands, or design as one-shot when the call comes?

**Q4 — Multi-modal screenshot (ε4).** It's a swing — could be a major
product unlock or a maintenance burden if OCR quality is patchy. Worth
trying in P4-W6 as a fallback to δ, or should it be its own Phase 5 swing
with proper scoping?

**Q5 — What's missing from this plan?** Be sharp. The Phase 3 review caught
two P0 bugs we'd shipped. Look for the equivalent of those — things that
"look right" but are subtly wrong, or things this plan didn't even
mention that should be Top-3 priority.

---

## 4. Success criteria for Phase 4

- **α′:** v1.0.4 ships with α2+α5+α6 streaming. p50 perceived first-token
  latency < 400ms for Apple FM Sharp/Calm. 209+ tests still green.
- **β′:** v1.0.5 ships with first-vent ≤60s + discoverability row + Pro
  paywall refresh. A′ counters show actionable signal within first month.
- **γ′:** at least one WWDC26 workstream shipped OR documented why
  everything dropped.
- **δ′:** clean go/no-go decision based on absolute share-tap count.
- **ε4 (optional):** screenshot OCR vent ships as a P4-W6 swing OR is
  scoped + scheduled for Phase 5.

---

## 5. Out of this plan (re-emphasized)

- Mainland China SKU.
- Journal / persistent persona / companion drift.
- Korean / Hindi / Spanish locales (each = 1 month). Defer until A′ data
  justifies. Add to Phase 5 if download geography demand emerges.
- Watch voice-authoring expansion (cut in `project_nextwave_voice`).
- Custom user-defined styles.
- LLM-as-judge as gating (still rejected). Could revisit as ε3 advisory
  signal in Phase 5 if ε3 manual triage shows it'd help.
- Wholesale model migration (Phase 3 W4 decision still stands).
- Any feature requiring third-party SDK.

---

## 6. Risk register (v2 expanded)

- **Streaming commit boundary** (Codex P0/P1) — Phase 3 left
  `RoastGeneratorViewModel.swift:100-114` spending a credit BEFORE generation
  + saving history only after final variants at 121-144. Streaming must not
  leak unsafe partial tokens to UI/share/history/telemetry, and cancellation
  must refund. Event protocol + transient buffer enforces this; design the
  refund flow before α6 lands.
- **δ gate integrity** (Codex risk-register-missing) — `share_taps` counter
  fires only on Share Sheet *open*, not completed share. Many simple
  `ShareLink` instances may not increment it. The ≥50 gate could be biased
  toward share-card composer users. **Audit every share affordance** in P4-W4
  before the gate fires.
- **Streaming + Apple FM API shape** — `LanguageModelSession.streamResponse`
  may have cancellation/error-recovery surprises. Allocate full P4-W2 sprint
  + P4-W3 carry if needed.
- **β1′ scenarios curation** — the carousel needs to feel "this is for me"
  not "this is generic." Locale-specific scenarios are gated on
  `Shared/Resources/Scenarios.json` having depth. If shallow, scope scenarios
  first in early P4-W3 before β1′ implementation.
- **A′ data N is still small** — v1.0.2 went LIVE 2026-05-26. By P4-W4
  (~Sep 14), v1.0.3 has been LIVE ~3 months; the ε3 triage should have
  signal. But early-Phase-4 β1′ / β2′ / β4′ decisions still operate at
  small-N.
- **macOS v1.0.x review backlog** — macOS v1.0.1 has waited 3+ days. If
  Apple's slow on macOS continues, the macOS branch falls behind iOS by
  >1 version forever. Consider whether to escalate via Apple's expedite
  form (Phase 3 plan §9 mentioned this is an option).
- **PaywallView source attribution** (Codex P1) — α3 paywall_trigger_*
  counters fire at the trigger SITE; `PaywallView` itself is now a no-op
  for impression bumping (W2 P0 fix). β4 needs purchase-time conversion-
  source counters to close the loop — but the source must be threaded from
  trigger → PaywallView state → `StoreService.purchase()` callback. State
  threading risk: simple state-on-View won't survive sheet dismiss-reopen
  flows; use a singleton or environment.
