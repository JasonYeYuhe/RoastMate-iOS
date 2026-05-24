# RoastMate — Phase 3 Plan (2026-07)

**Date:** 2026-05-24 · **Author:** Claude (for YE) · **Status:** v1 draft
for Gemini 3.1 Pro + Codex (gpt-5.5) adversarial review.
**Builds on:** Phase 2 wrap-up — `docs/PHASE_2_PLAN_2026-06.md` + the
six `evals/runs/2026-05-23*.md` baselines.
**Frames:** Jun 22 → ~Aug 23 (post-Phase-2-W4 through end of summer).

> **One-line frame:** *"v1.0.1 is LIVE. Phase 2 W1–W2 closed early.
> v1.1 features (voice/share/crisis/widget/consumables) all shipped as
> part of v1.0.0. We have real users. A′ data is incoming. WWDC is in
> two weeks. The next 8 weeks are about turning the existing surface
> into something that compounds — not about adding more surface."*

---

## 1. State at the start of this phase (verified 2026-05-24)

- **iOS v1.0.1 = `READY_FOR_SALE` (LIVE)** with A′ telemetry MVP +
  voice + share card + crisis handoff + Controls widget + consumables.
- **macOS v1.0.1 = `WAITING_FOR_REVIEW`** (sub created 2026-05-23,
  Apple has the iOS clearance, macOS expected within ~24-48h of this
  doc).
- **Branch `v1.1` HEAD `4275dcd`**, pushed; all Phase 2 W2 deliverables
  committed: B1-B5 eval harness, C-a + C-b prompt tunes, worker
  patches (CoT plain-prose strip, GLM Air fallback, 24-model
  allowlist).
- **Cloud worker version `4663fae8`** (allowlist-gated model override
  side door for eval; default route = Groq Qwen3-32B for zh, Groq
  Llama-3.3-70B for en/ja).
- **B harness baseline `evals/runs/run-baseline-build-8/`** — 63/64
  PASS (98.4%); the one failure is a Groq TPM blip (now mitigated by
  Runner's 5s+3s sleep schedule).
- **A′ first-week export expected ~2026-05-31.** Sample size will be
  tiny (the dev's own device + maybe a handful of organic v1.0
  installs that upgrade to v1.0.1 and opt in).
- **WWDC26 Jun 8–12.** Capability matrix `docs/PHASE_2_PLAN_2026-06.md`
  §3.5 is the framework for that week.

---

## 2. Phase 3 scope

**Premise:** v1.0 → v1.0.1 was about *getting the existing build to
real users and instrumenting it*. v1.1+ should be about *deepening
what's there into something that compounds*, not about adding new
surface area before A′ data tells us what's working.

Three themes, all independently shippable:

- **α — Quality & reliability.** Tune the still-untuned modes (Sharp/
  Calm), add the cloud fallback Sharp/Calm don't have, instrument what
  A′ schema v1 can't see yet (cohort + paywall-trigger), wire the B
  harness into preflight so future PRs can't ship a regression.
- **β — Cross-device convergence.** Replace the local-only Apple
  Sign-In with a CloudKit user record so a user who pays on iPhone
  sees the same Pro state and history on Mac. This is the single
  biggest "feels premium" gap today.
- **γ — WWDC bets (gated on Jun 8–12).** Apple Intelligence integrations
  — Writing Tools, Image Playground, Visual Intelligence — if any
  shipped APIs make sense for RoastMate's vent surface.

**Explicitly NOT in scope this phase:**
- Mainland China SKU (separate future SKU; ICP + 备案 + GFW).
- Conflict / patterns journal (companion drift).
- Korean / Hindi / Spanish locales (each = 1 month of calibration
  work; defer until we have evidence of demand).
- Watch voice authoring (cut per `project_nextwave_voice`).
- Wholesale model migration (already covered by Phase 2 W4 decision).
- D growth loop / short-video / direct social intent —
  **explicitly gated** on A′ share-tap data showing organic interest.
- Third-party SDK of any kind.
- Custom user-defined styles (depth-of-engagement feature; defer until
  A′ shows users actually exhaust the 20+ presets).

---

## 3. Workstreams

### 3.1 α — Quality & reliability

#### α1 — Sharp/Calm prompt tune (C-a equivalent)

C-a (Phase 2) tuned the **vent/feral** prompts for zh + ja. Sharp and
Calm still use only the universal `intensityGuidance` line. Sharp is
the **single most-used intensity** (it's the default for most styles),
yet it has never been B-harness-rated.

- Pick: 5 base.json scenarios × Sharp/Calm × zh-Hans/zh-Hant/ja/en
  = 40 cells.
- Identify the failure modes (likely: over-polite, hedge-creep,
  missing the bite that Sharp's `intensityGuidance` claims).
- Patch worker / on-device PromptBuilder.swift in parallel — Sharp/
  Calm currently go on-device only, so the change has to land in
  `Shared/AI/PromptBuilder.swift` AND require a new app version
  (a v1.0.2 patch). Worker change alone is insufficient.

**Open question for advisors:** the prompt-tune for Sharp has to ship
in the app binary (Apple FM call site). v1.0.2 just for a prompt
tweak feels heavy. Is there a way to make the on-device prompt
remote-configurable without violating the no-third-party-SDK rule?
(Possible: a tiny JSON the cloud worker serves; iOS fetches at
launch and falls back to bundled-default on offline.)

#### α2 — Sharp/Calm cloud fallback (when Apple FM fails)

Today: if Apple FM returns `guardrailViolation` or the model asset is
unavailable, Sharp/Calm have no fallback — the user sees a generic
error. **A′ telemetry will catch this rate** once `generations_failed`
counter ships in schema v2.

- Add a new worker endpoint `/v1/sharp` that mirrors `/v1/vent` but
  uses the Sharp/Calm prompt path (no `ventPreamble`, no
  `feralPreamble`).
- iOS RoastEngine retries cloud iff `cloudAIConsentRaw` is granted AND
  the on-device call fails with a recoverable error (network or
  guardrail-violation specifically; not "user typed slurs").
- Default OFF (no UI change); user opts in via existing
  `cloudAIConsentRaw` toggle.

#### α3 — A′ schema v2 (catch what v1 can't see)

`docs/A_PRIME_TELEMETRY.md` "Out of scope this session" already
documents:
- Cohort D7/D30 return-to-tool flag
- Categorical paywall trigger
- Churn-reason exit survey

Schema v2 adds these as **additive counters at the end of
`EventLedger.Counter`** (the schema-v1 keys are a public contract;
nothing renames):
- `generations_failed_*` (one per failure category: `guardrail`,
  `network`, `quota`, `safety_filter`, `model_asset_missing`)
- `paywall_trigger_*` (one per source: `low_credits`, `pro_tap`,
  `style_locked`, `intensity_locked`)
- `sessions_with_generation` (used for D7/D30 retention ratio)
- `share_tap_destination_*` (which app the user shared to — needs
  iOS 16+ `ActivityType` introspection; may not be possible without
  PII risk; defer if so)

#### α4 — B harness wired to preflight

`docs/EVAL_HARNESS.md` §"Tier A" specifies a 16-cell smoke test
gating archives. Today the CLI exists but isn't wired into
`scripts/preflight.sh`. Wire it:
- Add `eval-runner --tier-a` mode that runs 1 representative scenario
  × 4 intensities × 4 locales (16 cells, ≤2 min).
- `scripts/preflight.sh` invokes Tier A; archive blocked if any cell
  fails OR if strong-word count drops ≥2 vs the committed baseline
  (`evals/runs/run-baseline-build-8/results.json`).
- Run `scripts/eval-rerun.sh` against baseline; abort archive on
  critical flips.

#### α5 — B3 day 2: AppleFM backend in CLI

The CLI currently can only call the cloud worker. To run the same
matrix against on-device Apple FM (which is what 60%+ of intensity
combos actually use in production), the harness needs to call the
local Foundation Models framework.

Options:
- (a) **Move EvalRunner into Xcode as an XCTest target** — gets FM
  entitlements via the host app. Cost: project.yml change + non-trivial
  refactor of EvalRunner from SPM to XCTest.
- (b) **CLI stays standalone; AppleFM backend uses a different code
  path** — e.g., spawn a sibling iOS-app process that exposes a local
  HTTP endpoint, then the CLI calls it like any other backend. More
  exotic but keeps the CLI portable.

Recommend (a) — XCTest is the path of least resistance for FM
entitlements, and the XCTest can still call the WorkerBackend over
HTTP. Move the existing EvalRunner sources into a new
`RoastMateEvalTests` target.

---

### 3.2 β — Cross-device convergence

Today's Apple Sign-In stores `userID` + `fullName` + `email` in the
**app-group Keychain only**. The user record isn't on a server; the
Pro subscription state isn't synced across devices (works only via
StoreKit transaction restore, which requires the user to remember
"Restore Purchases" on a new device).

Phase 3 β goal: a user who signs in with Apple ID on iPhone, then
installs RoastMate on Mac and signs in with the same Apple ID, sees
their Pro state and history without any "restore" friction.

**β1 — CloudKit user record**
- Private CloudKit DB (per-user; no `_defaultZone` schema bleeds).
- `User` record type with: `appleUserID`, `firstLaunchDate`,
  `proRestoredAt`, `consumableLedger` (CKReference to a list of
  consumable-purchase records for cross-device wallet sync).
- Schema deployed via CloudKit dashboard or first-launch admin push.

**β2 — Pro state sync**
- StoreKit 2 `Transaction.currentEntitlements` stream → write to
  CloudKit User record on change.
- On launch: pull User record from CloudKit (if signed in) → seed
  local `StoreService.isPro`.
- Conflict resolution: latest `purchaseDate` wins (StoreKit gives
  this for free).

**β3 — Consumable ledger sync**
- Today: consumable credits are durable-first + tx-id ledger
  (per advisor fix in commit `d0f5b6a`). Stays local primary; CloudKit
  is a *mirror* for cross-device restore.
- Mirror writes only on `Transaction.finished()` (don't double-charge
  on restore).

**β4 — History sync (optional polish)**
- Vent + sent history as private CloudKit records.
- Default OFF (user opts in via Settings → "Sync history across
  devices"). Adds CloudKit-DB load that may matter for free tier.
- If the user opts out, history stays local (current behavior).

**Open question for advisors:** is β1+β2 alone enough for the
"feels premium" gap, or does β4 history-sync need to ship in the
same release? Risk of shipping β1+β2 alone: power users on multiple
devices see Pro restored but lose history context.

---

### 3.3 γ — WWDC bets (gated on Jun 8–12)

Phase 2 W3 was "fill the capability matrix". Phase 3 γ is "act on it
if anything ships that fits RoastMate's surface."

Pre-WWDC, the speculative wishlist is:

- **γ1 — Writing Tools integration (iOS 26)**: "Rewrite for vent"
  surface in any text field system-wide. Could be RoastMate's biggest
  single distribution lift if Apple opens the Writing Tools API to
  third parties (current 26.0 docs are read-only for app providers).
- **γ2 — Image Playground for share cards**: Image generation as a
  share-card background option. Would replace the current gradient.
  Low complexity if API allows it.
- **γ3 — Visual Intelligence**: Camera → vent about what's in the
  frame. Tap a sign that says "No parking 9pm-7am Mon-Fri" → vent
  about it. Novel use case Apple hasn't telegraphed yet but feels
  natural for the vent flow.
- **γ4 — Smart Reply alternative**: iOS 26 Mail shows "Smart Reply"
  suggestions. If the App Intent surface exposes a "Reply with…" type,
  RoastMate's existing Reply mode becomes a system-level option.
- **γ5 — Genmoji for the share card watermark**: Replace the static
  flame.fill with a Genmoji the user picks. Marginal but cute.

All γ items: **commit nothing until WWDC capability matrix is filled**
in Phase 2 W3 (Jun 8–14). γ work executes Phase 3 weeks 2-4 (Jul).

---

### 3.4 δ — Growth loop (data-gated)

**δ is parked until A′ data ships.** First-week A′ export (~2026-05-31)
will tell us:
- `share_taps / generations_total` ratio
- `purchase_attempts / paywall_impressions` ratio
- Whether A′ telemetry export tap actually happens (meta-check that
  the opt-in itself is usable)

If `share_taps / generations_total` > 5% in the first week (with N≥10
generations), δ becomes worth doing:
- δ1: Rich share-card formats (animated GIF showing vent→sent transition)
- δ2: Direct-share intents (Twitter, Threads, Xiaohongshu URL schemes)
- δ3: Custom Product Page for the share-card flow (App Store CPP A/B)

If < 5%, δ stays parked and we redirect to α + β depth.

---

## 4. Sequencing

| week | dates | focus |
|---|---|---|
| W1 | Jun 22 – Jun 28 | **Sharp/Calm prompt tune (α1)** + B harness wire to preflight (α4) + B3 day 2 AppleFM backend (α5) |
| W2 | Jun 29 – Jul 5  | **CloudKit user record + Pro sync (β1+β2)** + A′ schema v2 (α3); first-week A′ analysis |
| W3 | Jul 6 – Jul 12  | **CloudKit consumable ledger sync (β3)** + Sharp/Calm cloud fallback (α2) + ship a v1.0.2 carrying α1+α2+α3 |
| W4 | Jul 13 – Jul 19 | **γ work IFF WWDC matrix points to a fit** — otherwise History sync (β4) + δ go/no-go based on 4-week A′ |
| W5–8 | Jul 20 – Aug 23 | γ implementation (if go) OR δ implementation (if A′ supports) OR α depth (Sharp/Calm tune for en/ko prep) |

**Decisions LOCKED before drafting this plan:**
- v1.0.1 is the current LIVE version; do NOT plan a "v1.1" ship —
  the v1.1 features already shipped under v1.0.0.
- All A′ schema additions are end-of-enum and never rename.
- Cloud-default-on flip stays final-NO.

---

## 5. Risks & mitigations

- **α1 (Sharp/Calm tune) requires a new app binary** because Apple FM
  is on-device. The remote-config workaround (worker serves tuned
  prompts) needs to be safe against MITM (cache + signature) — not
  trivial, may push α1 into a 2-week instead of 1-week task.
- **β CloudKit work touches schema** — schema changes are forward-only
  in CloudKit (you can add fields, can't drop). One bad schema design
  becomes a forever-cost. Mitigation: prototype on a dev CloudKit
  container first; promote schema to production only after the iOS
  client is shipping reads cleanly.
- **γ is entirely WWDC-contingent.** If WWDC ships nothing relevant
  to vent surfaces, γ drops to zero and the freed cycles go to α+β.
- **A′ first-week sample size is tiny.** N=5-20 users is not
  statistically significant. Treat first-week A′ as a smoke test of
  the pipeline, not signal. Real signal needs ≥4 weeks of data.
- **The macOS v1.0.1 review may flag something** — if Apple rejects on
  e.g. macOS-specific entitlement or sandbox issue, fix-and-resubmit
  same day. Don't let it pull focus from α1/β1 dev work.

---

## 6. Out of this plan (re-emphasized)

- Mainland China SKU.
- Journal / longitudinal patterns / companion drift.
- Watch voice authoring.
- Custom user-defined styles.
- Korean / Hindi / Spanish (each = ~1 month of calibration).
- Cloud-default-on flip.
- Third-party SDK (RevenueCat, analytics, etc.).
- D growth loop **unless A′ data justifies** (gate: share_taps >5%).
- LLM-as-judge as gating (rejected Phase 2; still rejected).

---

## 7. Open decisions for advisor synthesis

Specific questions for **Gemini 3.1 Pro + Codex (gpt-5.5)**:

**Q1 — Sharp/Calm tune deployment vector:**
Sharp uses on-device Apple FM. Prompt tune must ship in the app binary
unless we add a remote-config mechanism. Is the remote-config worth
the complexity (a couple-hundred-line + MITM defense), or just ship
a v1.0.2 with the tuned prompts and accept that future prompt iter-
ation requires a release? Argue for one direction.

**Q2 — β order: β1+β2 first, or β1+β2+β3 together?**
β1 (User record) + β2 (Pro sync) is the minimum that delivers "I
bought on iPhone, see Pro on Mac". β3 (consumable ledger sync) is
strictly more, but its bug-surface is higher (double-counting credits
across devices). Should we ship β1+β2 in v1.0.2 and β3 in v1.0.3, or
hold β1+β2 until β3 is ready to land together?

**Q3 — γ pre-WWDC speculation budget:**
How much time should we *budget* for γ work before WWDC actually
happens? My instinct: zero. Don't plan γ until Apple ships the
capability. Gemini and Codex have historically pushed for "scenario
plan all 3 likely outcomes" — does that apply here, or is "zero
planning until capability lands" the right discipline?

**Q4 — δ A′ threshold:**
Plan says "δ unlocks if share_taps / generations_total > 5% in week 1".
Is 5% the right gate? Higher (10%) might be too conservative if we
want to ship growth-loop work in a 2-month phase. Lower (2-3%) risks
building D for users who don't actually share.

**Q5 — Sharp/Calm cloud fallback risk:**
α2 adds a `/v1/sharp` endpoint and makes the on-device path retry to
cloud on failure. This expands the cloud surface from vent-only to
all-intensities (still gated by consent). Is the consent UX strong
enough? Currently the cloud-consent toggle is one prompt at first
launch + a Settings toggle; the user doesn't see a per-call indicator.

---

## 8. Success criteria for this phase

- **α**: a v1.0.2 ships with Sharp/Calm tuned + cloud fallback + A′
  schema v2 + B harness in preflight. 156/156 tests green. A′ first
  4-week export aggregated and reviewed.
- **β**: CloudKit User record + Pro sync deployed; new device on same
  Apple ID sees Pro state within 30s of sign-in. Zero double-charge
  reports.
- **γ**: WWDC matrix yields ≥1 actionable API; one γ workstream
  shipped OR documented why everything dropped.
- **δ**: clean go/no-go decision based on A′ data, documented.

---

## 9. Advisor synthesis (2026-05-24, post Gemini 3.1 Pro + Codex gpt-5.5)

Both advisors reviewed the v1 draft independently. Convergences and the
single non-trivial disagreement below.

### 9.1 Convergences (act on these unconditionally)

| Issue | Both advisors |
|---|---|
| Q1 remote-config | **NO. Ship v1.0.2 binary with bundled tuned prompts.** Codex: "remote prompt config creates signing, cache, rollback, versioning, review, and safety-policy surface before you have proven prompt iteration speed is the bottleneck." Gemini: "App Store review <24h; rolling your own MITM-safe remote config to avoid clicking Submit is textbook yak-shaving." |
| A′ N=5-20 risk | **Acknowledged. Use only for plumbing-validation + anecdote routing.** Both: not enough for quantitative gates. |
| Q4 δ threshold | **5% is wrong.** Gemini: gate on **absolute ≥50 organic share taps**. Codex: gate on signal being both numerically AND qualitatively obvious. Plan updated below. |
| Q3 γ pre-WWDC | **Zero pre-WWDC planning.** Codex: "gamma is speculative product theater" until APIs land. |
| Q2 β order | **β1+β2 first, β3 separate release.** Codex: "consumable ledger sync is money-adjacent and double-credit-prone; deserves its own release, tests, and rollback story." |

### 9.2 Genuine divergence — β priority

**Gemini:** "**Demote β.** Cross-device sync is premature optimization
before you prove single-device retention. Pure engineering vanity at
N=20."

**Codex:** "**Keep β as #2.** Cross-device Pro state is a paid-product
trust issue. Order should be alpha → beta → delta → gamma."

**Synthesis (my call):** Codex wins on β1+β2 specifically. Cross-device
Pro state is a *trust* issue once macOS goes live, not a *retention*
optimization. Gemini's point lands for **β3 (consumable ledger sync)
and β4 (history sync)** — those are vanity at our current scale.

**Phase 3 β scope NARROWED:**
- β1 (CloudKit User record): KEEP
- β2 (Pro state sync): KEEP
- β3 (consumable ledger sync): **defer to Phase 4** (only land when
  multi-device complaints actually surface)
- β4 (history sync): **defer to Phase 4** (true polish, no current
  evidence of demand)

### 9.3 Missing item both advisors flagged

**Gemini caught `SKStoreReviewController`** — no in-app rating prompt
today. "If a user completes a vent session and triggers a share or
copy, you must ask for an App Store rating. By Week 2 or ASO stagnates."

**Codex caught qualitative feedback loop** — A′ counters tell you
*what* but not *why*. "Privacy-preserving 'bad / useful' action per
generation: locale, mode, style, intensity, backend, failure category,
optional user note. No raw text unless attached. Weekly triage."

These are two halves of the same hole: **the post-launch user-learning
loop**. Promote to its own workstream:

### 9.4 NEW workstream — ε: post-launch user-learning loop

**Charter:** make the first 8 weeks of v1.0.1 users a compounding
learning asset, not a tiny telemetry pool we wave hands at.

**ε1 — SKStoreReviewController prompt** (cost: ≈1 hour)
- Trigger: first successful share-tap OR third successful generation
  in the same session, **whichever comes first**.
- Throttling: Apple already enforces 3-per-365-days; no additional
  client throttling needed.
- Critical: do NOT trigger after a refusal/safety-fallback/error — only
  on a known-good outcome.
- Done when: shipped in v1.0.2 alongside α1.

**ε2 — In-app generation feedback** (cost: ≈4 hours)
- Add a tiny `👍 / 👎` row beneath each generation card, plus optional
  tag picker: "wrong tone", "too soft", "too harsh", "wrong language",
  "wrong style", "didn't address the situation", "factually wrong",
  "other".
- Stored locally as an extension of A′ schema v2:
  `feedback_thumbsup`, `feedback_thumbsdown`, `feedback_tag_*` counters.
- **No raw text logged. Ever.** The tag is the unit; the user's
  situation/response stays on-device per the privacy moat.
- Exported via the same Share Sheet → JSON pipeline as A′ (no
  background upload).

**ε3 — Weekly triage** (cost: ≈15min/week)
- A weekly markdown file: `evals/triage/2026-MM-DD.md`
- Aggregates: top failure tags by locale, top failure tags by mode,
  any new patterns in the share_destination counters.
- Drives the next prompt tune (becomes the C-d, C-e, ... ladder).

**ε ships in v1.0.2 alongside α1 (Sharp/Calm tune).** Same release,
same review cycle.

### 9.5 Revised sequencing

| Week | Original (v1 draft) | Revised |
|---|---|---|
| W1 (Jun 22-28) | α1 + α4 + α5 | α1 (Sharp/Calm) + **ε1 (rating prompt) + ε2 (feedback action)** + α4 (harness to preflight) |
| W2 (Jun 29-Jul 5) | β1+β2 + α3 | β1+β2 + α3 (A′ schema v2, **now includes ε2 counters**) |
| W3 (Jul 6-Jul 12) | β3 + α2 + ship v1.0.2 | α2 (Sharp/Calm cloud fallback) + ship **v1.0.2 carrying α1+ε1+ε2+α3** + start β1+β2 |
| W4 (Jul 13-Jul 19) | γ IFF WWDC | First **ε3 weekly triage** off real v1.0.2 data + WWDC matrix review + ship β1+β2 as **v1.0.3** |
| W5-8 | γ/δ/α depth | γ implementation if matrix found a fit, else δ go/no-go on **absolute ≥50 share taps**, else α depth (en/ko prep) |

**β3 (consumable ledger sync) and β4 (history sync) drop out of Phase 3
entirely.** They become Phase 4 candidates only if observed pain
emerges.

### 9.6 Updated success criteria

- **α**: v1.0.2 ships with Sharp/Calm tuned + cloud fallback + A′
  schema v2 + B harness in preflight. ε1 + ε2 land in same v1.0.2.
- **β**: v1.0.3 ships β1+β2; cross-device Pro state observed working
  via Apple Sign-In on macOS v1.0.1 once macOS LIVE.
- **γ**: WWDC matrix yields ≥1 actionable API; one γ workstream
  shipped OR documented why everything dropped.
- **δ**: Gate updated — only build IFF **≥50 organic share taps in
  the first 4 weeks** (absolute, not ratio).
- **ε**: weekly triage file committed every Monday starting v1.0.2
  ship + 1 week.

### 9.7 What the advisors said matters most

> Gemini: "This is a sensible engineering roadmap but a flawed
> post-launch product strategy. Demote the β cross-device sync until
> you actually have multi-device users, and spend those weeks fixing
> your baseline distribution and App Store rating loops so your
> telemetry isn't just statistical noise."

> Codex: "Ship the plan after restructuring sequencing to alpha, beta,
> feedback loop, then delta/gamma gates. The plan is directionally
> right, but it still treats instrumentation as counters; for a
> just-launched app, the compounding asset is a tight user-learning
> loop."

**Net: plan v2 = plan v1 with β trimmed to β1+β2, ε added, sequencing
re-ordered. Workstreams stay; priorities sharpen.**
