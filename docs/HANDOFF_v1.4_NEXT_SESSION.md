# RoastMate — v1.4 wave handoff (paste into a fresh session)

You are picking up **RoastMate** (帮你骂 / `~/Documents/RoastMate`, Swift 6,
iOS/macOS/watchOS, + a Cloudflare Worker `cloud-worker/`) to start the **v1.4
wave**. The prior session shipped v1.3 (the Track M cost/monetization "dam") to the
App Store and wrote + advisor-reviewed the v1.4 plan. Your job is to execute it.

## Read first, in order
1. `docs/DEV_PLAN_v1.4_2026-09.md` — the plan you are executing (reviewed by Gemini
   3.1 Pro + 3.7 Flash, both SHIP-WITH-FIXES; §9 = the review synthesis). Source of truth.
2. `docs/DEV_PLAN_v1.3_2026-08.md` + memory `project_v13_wave` — the dam you're
   building on (what shipped, the deferred items, the guardrails).

## Verify current reality BEFORE acting (the plan was written 2026-09-01)
1. **Is iOS v1.3.0 (build 18) approved yet?** Query ASC (the API key `DMMFP6XTXX` at
   `~/private_keys/AuthKey_DMMFP6XTXX.p8`, issuer `c5671c11-49ec-47d9-bd38-5e3c1a249416`,
   app id `6769317103`; reuse `scripts/asc_*` patterns). If still WAITING_FOR_REVIEW /
   IN_REVIEW, the Track-B ship gate is not open yet (but you can BUILD Track B dark).
2. **Is the dam healthy in prod?** If v1.3 is live, smoke `/v1/vent` (should be 200,
   Groq `qwen3.6-27b`) and check the deployed Worker version. The edge kill-switch is
   `CLOUD_DISABLED=true` on the Worker (emergency only — it kills ALL cloud).
3. **git state:** branch `feature/v1.3-track-m` (tag `v1.3.0` is LOCAL + UNPUSHED —
   the push was blocked by the permission classifier; ask Jason to allow/push, or
   have him do it). Not merged to main.

## ⚠️ CRITICAL Track-B warning (do this understanding FIRST)
**Track B is NOT greenfield.** A May-2026 pass already built the ShareCard feature
(`RoastMate/Sources/Features/ShareCard/{ShareCardComposer,ShareCardView,ShareCardRenderer}.swift`
+ `Shared/Services/Redactor.swift` + `RoastMateTests/ShareCardTests.swift`), and it
**predates the sendable-only safety decision**. It still contains a **raw-vent
reveal** (`includeVent` / `showVentWarning` / `ventVsSent` / an editable `TextEditor`
of the vent) — a **P0 both reviewers flagged**: it would render the user's private
vent onto a branded image (moat breach) and lets a user type PII/defamation back in
(1.1/1.2 ban). **The FIRST Track-B task is to PURGE that surface** (sendable-only,
immutable card) — see plan §3 B.1. Do not build new card UI before removing it.

## Confirm the open decisions with Jason (plan §6) — especially:
- **(2) Consumable DO ledger:** the two reviewers SPLIT — Flash "defer", Pro "build
  now (a viral loop on the non-atomic KV race = cost blowout)". Plan recommends:
  ship card DARK + gradual flip + kill-switch; build the DO before FULL rollout IF
  the M-d load test shows the race is exploitable. Get Jason's cost-risk appetite.
- **(1) Refund-check key scope:** a dedicated In-App-Purchase key (least privilege)
  vs the broad Admin key on the edge Worker (both reviews say dedicated). Provisioning
  a credential onto edge infra is Jason's call.

## Execute in this order (order is load-bearing — plan §4)
1. **Track M-finish (prove the dam):** M-a prod watch (Datadog) → M-b roommate token
   wiring (**a BUG — Pro users hit free caps → churn**, not cleanup) → M-c enable the
   refund check (`ASS_API_ENABLED`, key decision, sandbox e2e) → M-d load test (+ the
   DO decision).
2. **Track 0-finish:** 0.4 stale README + RemoteConfig mirror reconcile; 0.2 zh-Hans
   sendable eval; 0.1 iOS-18 voice smoke; 0.3 optional privacy-copy note.
3. **Track B fix+harden (build in parallel, ship DARK):** B.1 purge raw-vent +
   immutable → B.2 PII defense-in-depth (Worker prompt scrub + expand `Redactor` with
   `NLTagger(.nameType)` NER + Chinese contact/name patterns, run it on `sentText`) +
   strict `SafetyFilter` last → B.3 bar Feral from the card + reviewer note → B.4 QR/
   "search RoastMate" badge (a URL is inert on a static image) → B.5 App Store campaign
   referral for attribution → B.6 iOS-first + macOS compile-safe (`ShareLink`) → B.7
   `ViewThatFits` for long zh text → B.8 log generated-but-not-shared → B.9 on-device
   micro-copy.
4. **Ship v1.4 with the card DARK** (`share_card_enabled=false`, a NEW RemoteConfig
   flag — do NOT reuse `CLOUD_DISABLED`). After the §2 quantitative gate (≥72h in
   prod, ≥50 verified `/v1/auth` sessions, 0 crypto 500s, 0 false IP-blocks, load
   test passed), server-flip `share_card_enabled:true`. Track D creator-seed follows.

## Hard guardrails (plan §5)
- **Never** render the raw vent (or before/after) onto a shareable image; the card is
  the sendable comeback ONLY, and its text is IMMUTABLE (no `TextEditor`→`ImageRenderer`).
- Bar Feral/toxic from the card (App-Review 1.1/1.2). No "To:<Name>" on the canvas.
- Ship the card DARK behind `share_card_enabled`; flip only after the quantitative gate.
- Don't move Vent/Feral off cloud (Apple FM refuses/neuters vent — measured). Don't
  weaken `SafetyFilter` / "private draft, never sent" / the 5.1.2(i) consent gate /
  non-companion positioning.
- No 3rd-party SDK (`NLTagger`/`ImageRenderer`/`CIQRCodeGenerator` are Apple).
- Branch + DARK-gate + eval-before-flip; never invalidate the live build; the
  byte-faithful `evals/runner` harness is the source of truth for model/prompt changes.

## House workflow
- For any major product/arch decision, consult BOTH advisors — Codex (via the
  `codex:codex-rescue` agent or `codex exec`) + Gemini 3.1 Pro (`mcp__gemini__ask_gemini`
  model `pro`) — and synthesize before building. Verify claims against real code, not
  memory. Update `docs/` + auto-memory as you land increments.
- Full delegation on reversible steps; verify-then-report-blockers before any
  irreversible/outward step (ASC submit, git push, enabling a credential, flipping a
  live flag).

Start by reading the three docs, verifying v1.3's App-Store + prod state, reading the
existing ShareCard code, and reporting back the confirmed state + your proposed Week-1
plan (M-finish + the Track-B P0 purge) before you start coding.
