# RoastMate — Next-Phase Development Plan (v1.3 wave)

_Drafted 2026-08-30. Reviewed by Gemini 3.1 Pro + Gemini 3.7 Flash (both `SHIP-WITH-FIXES`); fixes folded in — see §7. Baseline: v1.2.0 (build 17) submitted 2026-06-14 (iOS-18/macOS-14 reach + `SFSpeechRecognizer` voice + cloud-sendable DARK). **First task of the next session: verify actual App Store + RemoteConfig + Worker state** before acting._

---

## 0. Where we are (verified against code 2026-08-30)

- **Shipping:** iOS + macOS v1.2.0 through review; reaches iOS 18 / macOS 14; iOS-18 voice via `SFSpeechRecognizer` (on-device only, fail-closed).
- **What runs where (verified):**
  - **On-device (FM devices):** Calm / Sharp / **Savage**, Vent/Feral private drafts, **classic Echoes** (`EchoesEngine.swift:105` hardcodes `useCloud = false`). These do **not** touch the cloud when Apple FM is available.
  - **Cloud (Worker → Groq/OpenRouter):** the **Vent/Feral** path *when the device has no FM* or via the consent-gated cloud path; the **虚拟舍友群 roommate group** (`EchoScene.roommateGroup`) which is cloud-only because on-device FM structurally refuses the harsh group-roast.
  - **Worker model reality (drifted — audit it):** `wrangler.toml` routes **zh-* → `qwen/qwen3-32b` (Groq)**, else → `llama-3.3-70b-versatile` (Groq); `DEFAULT_MODEL = nousresearch/hermes-3-llama-3.1-405b:free` (OpenRouter) — memory flags Hermes-3-405B as **dead (429s)**; `README.md` still says "DeepSeek V4 Flash primary." **zh IS on Qwen3-32B (correct), but the config/docs disagree — reconcile before any prompt tuning.**
- **Dangling from v1.2 (increments 5–8 not done):** cloud-sendable **DARK** (`cloud_sendable_enabled:false`); Worker `mode:roast` **implemented in `index.js` but not deployed** and clients not wired; cost/abuse gate + **Pro receipt verification** not built; privacy-label/compliance review pending; **iOS-18 real-device voice smoke** never run.
- **Today's PCC/guardrail finding** (`evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md`): default guardrails → Apple FM 100% hard-refuses Vent/Feral (all locales); `permissiveContentTransformations` removes the refusal **but** the on-device ~3B model is too gentle to match the cloud vent chain (esp. zh/ja). **Carried into this plan: the cloud Vent chain stays; do NOT chase PCC/on-device for Vent/Feral.**

## 1. Thesis for this wave

> Build the cost/monetization **dam** first, then finish what's half-shipped, then turn one moat into a measurable, safety-clean growth loop — without weakening the privacy / safety / "private draft, never sent" / non-companion position that is the actual moat.

Not a v2 rewrite. A ~6-week wave shipping as **v1.3** that leaves nothing DARK-and-forgotten and instruments growth so the next wave is data-driven. **Order is load-bearing: money + cost controls precede any cloud flip or viral surface (see §4 blind spot).**

---

## 2. Tracks

### Track M — Monetization + cost dam (FIRST; weeks 1–2)
The #1 risk (both reviewers) is a **viral cloud-cost blowout**: iOS-18 users are 100% cloud, and the free upstreams have hard daily caps — a viral surface before the dam is built can 502 the *whole* cloud path, including paying Vent users. Build the dam before opening any floodgate.
- **M.1 Pro receipt verification (StoreKit 2 JWS).** iOS 18+/macOS 14+ is StoreKit 2 — pass `Transaction.jwsRepresentation` on `CloudVentRequest`; verify on the Worker via ECDSA P-256 (Apple root CA chain) in Web Crypto **or** the App Store Server API. Gate cloud quota on verified active-Pro before any consumable-ledger complexity. _AC:_ Worker rejects forged/absent JWS; only verified Pro gets Pro cloud quota.
- **M.2 Free-tier cloud cost cap for no-FM devices.** iOS-18 free users are pure cloud cost — set an explicit, stricter free daily cap + edge-IP cap + a RemoteConfig breaker, and confirm Groq/OpenRouter headroom (audit the dead `DEFAULT_MODEL`). Datadog alert on breach. _AC:_ load test proves a surge degrades gracefully (free throttled, Pro unaffected), not a global 502.
- **M.3 Intent-triggered paywall + boost packs — NATIVE StoreKit 2 (no 3rd-party SDK).** Paywall fires at peak need (tap Feral/Vent or "Make it sendable" on a strong draft), not onboarding. Consumable "boost pack" covers cloud variable cost. A/B via a `RemoteConfig`-driven native paywall payload — **not** Superwall/RevenueCat (that breaks the zero-3rd-party-SDK + zero-tracking privacy moat; decision closed, §7). Consumables are **not** in `currentEntitlements` after finishing → need an **atomic server-side credit ledger** (not eventually-consistent KV alone) to prevent double-spend/replay. Wire conversion-source counters (Phase-4 Codex note). _AC:_ paywall fires at intent; one A/B variant live; boost-pack credit can't be double-spent.

### Track 0 — Close the v1.2 open loops (weeks 1–3, parallel with M)
- **0.1 Real-device iOS-18 voice smoke** (zh-Hans on-device `SFSpeechRecognizer`). _AC:_ transcribe 5 zh-Hans + 3 en vents on a real iOS-18 device; if quality is bad, hide voice on iOS 18 via RemoteConfig.
- **0.2 cloud-sendable go/no-go.** Run the zh-Hans sendable quality eval (extend `evals/runner` `WorkerBackend`, grade vs the vent bar, on the **actually-deployed** zh model = Qwen3-32B). **Only after Track M is live**, and after wiring `FeatureGenerator` + `ArgumentSimulator` sendable→cloud, EITHER deploy Worker `mode:roast` + flip `cloud_sendable_enabled:true`, OR keep it dark and delete the dead branch with a dated reason. _AC:_ eval report + single go/no-go; consent + receipt path proven first.
- **0.3 Privacy label + compliance copy review** (increment 6). Reconcile "on-device-first, else consented cloud" across App Privacy labels, in-app copy, marketing (avoid a "local AI" 5.1.1 exposure). _AC:_ label diff reviewed; copy unified 4 locales.
- **0.4 Worker config reconciliation.** Fix the model drift in §0 (README vs wrangler.toml vs dead `DEFAULT_MODEL`); make the deployed model self-documenting. _AC:_ one source of truth; a smoke request proves the live zh model.

### Track B — One growth moat, shipped safely and measured (weeks 3–4)
**#1 growth bet = P4 shareable artifact** (no unreleased API; "the output is the ad"). Confirmed over deeper P1 native-capture by both reviewers.
- **B.1 "Comeback Card" — the SENDABLE/comeback, not the raw named vent.** **Safety reframe (Flash's blind spot):** the moat is "the vent is private, never sent." A shareable card of a raw, named rant *contradicts* that and creates defamation/harassment + App-Review 1.1/1.2 liability. So the shareable artifact is the **witty sendable comeback** (and optionally a stylized, anonymized before/after), never a raw named attack. Hard requirements: automatic **PII entity masking** (names → "my manager", @handles, phone numbers), a **manual redaction preview** before render, and `SafetyFilter.validateOutput` on the rendered text. Static image via SwiftUI **`ImageRenderer`** — **drop the vertical-video variant** this wave (AVFoundation × 4 locales × dynamic length = a time sink). Watermark + App Store deep link; instrument share as a Tier-1 event. _AC:_ card renders 4 locales, light/dark, iOS+macOS; PII masking + redaction + safety gate enforced pre-render; share counted.
- **B.2 Native-capture top-ups (P1, cheap wins only).** Action-Button/Control-Center "Quick Vent," richer App Intents (Siri/Spotlight/Shortcuts). Defer the post-WWDC personal-context API. _AC:_ one-press quick-vent; App Intents invocable from Shortcuts.

### Track D — Distribution/research gate (parallel, Phase-5 locked priority)
Growth features without distribution build in a vacuum. Run the already-built recruit/interview pipeline + a small creator-seed of the B.1 card + one ASO pass **in parallel**, so B/M ship into a real funnel. _AC:_ N user conversations logged; one ASO iteration; a creator-seed test of B.1.

### ~~Track A.2 — permissive-guardrails on-device migration — KILLED~~
**Cut (both reviewers, unanimous, and verified against code).** Savage/Sharp/Calm and classic Echoes **already run on-device** under default guardrails; only roommate-group is cloud, and it needs strict `EchoesParser` tagging that permissive-mode meta-leaks/incoherence (proven today) would push past the 15% parse-fallback kill criterion. Add App-Review policy risk (permissive is for *analysis*, not profane *generation*) + negligible Cloudflare-edge cost savings ⇒ no ROI. **Do not pursue.** (Keeping only a one-line note that on-device permissive was measured and rejected.)

---

## 3. Sequencing (≈6 weeks, v1.3)

1. **Wk 1–2:** **Track M** (receipt gate → free cap → native paywall/boost-pack + ledger) + 0.1 voice smoke + 0.4 Worker reconciliation + kick off D.
2. **Wk 2–3:** 0.2 sendable eval → go/no-go (only after M live) + 0.3 privacy/copy.
3. **Wk 3–4:** **B.1 Comeback Card** (with the PII/safety gate) — the growth centerpiece.
4. **Wk 5:** B.2 quick-vent top-ups; A/B variants running; D creator-seed of B.1.
5. **Wk 6:** hardening, dual-sim + real-device matrix, DARK→eval→flip for anything gated, submit **v1.3**.

If time slips: ship **Track M + Track 0 + B.1**; defer B.2 and any cloud-sendable flip.

## 4. Biggest risk / blind spot (from review) — design around it
**Viral cloud-cost blowout.** iOS-18 = 100% cloud; the free upstreams have hard daily caps; `DEFAULT_MODEL` (Hermes-3-405B) is likely dead. If a viral B.1 card or a `cloud_sendable_enabled` flip lands *before* Track M's receipt gate + free cap + breaker + upstream-headroom audit, a surge can 502 the entire cloud path, killing the paid Vent experience for everyone. **Mitigation is the plan's ordering itself: M precedes any flip or viral surface.**

## 5. Open decisions (confirm early with Jason)
1. **Growth bet:** confirm **P4 Comeback Card** as #1. (Both reviewers: yes.)
2. **B.1 shareable content:** confirm it shares the **sendable/comeback** (+ optional anonymized before/after), **not** the raw named vent. (Recommendation + reviewer safety finding: yes.)
3. **cloud-sendable:** flip this wave only if 0.2 eval clearly passes *and* Track M is live; else keep DARK / delete. (Recommendation: gate on both.)
4. **Consumable ledger:** minimal server ledger now, or defer boost-packs and ship only the intent paywall + sub this wave? (Recommendation: if the atomic ledger is heavy, ship paywall+sub first, boost-packs next wave.)
5. **Scope of D** vs feature build this wave.

## 6. Non-goals / guardrails (do not regress)
- **Do NOT** move Vent/Feral to on-device/PCC (today's finding). **Do NOT** pursue killed Track A.2.
- **Do NOT** ship a shareable card of a raw, named vent; the shareable artifact is the sendable comeback, PII-masked, safety-filtered.
- **Do NOT** weaken `SafetyFilter`, the "private draft, for yourself only" framing, the 5.1.2(i) consent gate, or the non-companion position.
- **Do NOT** add a 3rd-party SDK (Superwall/RevenueCat included) — native StoreKit 2 only.
- **Do NOT** flip any cloud path or ship a viral surface before Track M's dam is live.
- **Do NOT** ship anything that invalidates the live build; branch + DARK-gate + eval-before-flip. Keep the byte-faithful eval harness the source of truth.

## 7. Review synthesis — Gemini 3.1 Pro + 3.7 Flash (2026-08-30)
Both independent reviews returned **SHIP-WITH-FIXES** and converged. Adopted:

| # | Source | Sev | Finding | Applied |
|---|---|---|---|---|
| 1 | Both | **P0** | Viral cloud-cost blowout: flip/viral before cost+receipt controls → global 502 | Re-sequenced: **Track M first**; §4 |
| 2 | Both | **P0** | Track A.2 is a trap: Savage/classic-Echoes already on-device; roommate needs strict parse (permissive meta-leaks blow the 15% kill criterion); policy risk; ~0 cost savings | **A.2 KILLED** |
| 3 | Flash | **P0** | Shareable "vent" card contradicts the "private, never sent" moat + defamation/1.1/1.2 risk; no PII mechanism | B.1 reframed to sendable-comeback + PII mask + redaction + safety gate |
| 4 | Flash | P1 | StoreKit 2 JWS verification + consumables not in `currentEntitlements` → need atomic server ledger | M.1/M.3 spec'd |
| 5 | Both | P1 | 3rd-party paywall SDK breaks the no-SDK/zero-tracking moat | Decision closed: **native StoreKit 2** |
| 6 | Flash | P1 | Scope bloat: drop B.1 vertical video; use `ImageRenderer` | Applied |
| 7 | Pro | P1 | Worker model config drift (README/DEFAULT_MODEL vs deployed) | New **Track 0.4**; §0 corrected (zh **is** Qwen3-32B) |
| 8 | Both | P2 | Factual: Savage/classic-Echoes on-device; only roommate cloud | §0 corrected |

Correction to Pro: it claimed Qwen3-32B "isn't deployed" — `wrangler.toml:22` shows zh **does** route to `qwen/qwen3-32b`; the drift is in the README + the dead `DEFAULT_MODEL`, not the zh path.

## 8. Definition of done for v1.3
Track M dam live (receipt gate + free cap + native paywall + non-double-spend); Track 0 loops each finished-or-killed with a written reason; B.1 Comeback Card live, PII/safety-gated, instrumented; A/B running; nothing left silently DARK without a dated review note; Worker config reconciled; 4-locale + dual-platform + real-device matrix green.
