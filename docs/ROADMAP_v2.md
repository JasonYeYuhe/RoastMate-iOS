# RoastMate — Next-Phase Development Plan (v1.x → v2)

_Written 2026-05-15. v1.0 (iOS build 4, iPhone-only; macOS build 3) submitted to App Store review for both platforms — "Waiting for Review". This plan covers what to build once 1.0 is live._

---

## 1. Where the market is in mid-2026 (research-backed)

**Apple on-device AI is our tailwind and it's accelerating.**
- The Foundation Models framework (~3B on-device model, free, a few lines of Swift: guided generation, tool calling) is production-validated. Apple's own blessed pattern is **"on-device first, cloud fallback"** — literally RoastMate's architecture. Day One (Automattic) is the flagship privacy-journaling adopter, an app adjacent to ours.
- **WWDC 2026 is June 8–12 (≈3–4 weeks out).** Expected: more capable / larger-context on-device models, fine-tuning, a **personal-context API** (Calendar/Mail/Messages/Notes), **Siri 2.0 + deeper App Intents**, Visual Intelligence dev API, Swift ergonomics for AI. This directly enables our biggest moats (see P1/P2).

**The emotional-AI market is enormous — but "AI companions" are now under legal fire.**
- AI-companion market is huge and growing fast (tens of millions of users; text-based = ~46% share). Demand for emotionally-intelligent tools is mainstream.
- **2026 regulatory wave:** California SB 243 (eff. Jan 1 2026), New York (eff. Nov 5 2025), OR/ID/WA — mandatory "you're talking to AI / not human" disclosures, minor safeguards, FTC pressure, lawsuits over psychological dependence. Companion/relationship bots are the target.
- **This is a gift for our positioning:** RoastMate is **not a companion** — it's a *tool* that helps you say it yourself, then gets out of the way. No simulated relationship, no dependence loop, on-device, safety-filtered. In a market where companion apps get sued, "the AI that doesn't pretend to be your friend" is a *defensible, compliant, trust-positive* wedge.

**The "AI reply / comeback" utility space is commoditized.**
- TextBack, Rizz/SmoothRizz, AIFreeBox, Typli, Reply Assist — all "screenshot/paste → pick tone → 3 ready replies," many free/no-login. Racing to zero on pure utility.
- Our non-copyable moat is the **two-stage emotional ritual** ("vent first, privately + cathartically → then rewrite into the version that actually wins"), **privacy/on-device**, **style depth**, and **native multi-surface** (Watch/Mac/Share/Siri). Compete on emotion + outcome + trust, never as a generic reply box.

**Monetization in 2026: hybrid is the default.**
- Subscription fatigue is brutal at the £5–10/mo tier; ChatGPT normalized $20; AI's real variable cost broke all-you-can-eat. **60%+ of top-grossing apps now run hybrid** (subscription + consumables). Intent-triggered paywalls (fire at peak need, not gated onboarding) and weekly pricing for **bursty** usage convert best. Heavy paywall A/B testing → ~19× revenue.
- RoastMate usage is intrinsically bursty (you vent when something *just happened*) and has a real cloud variable cost (Vent/Feral) — this maps almost perfectly onto the 2026 hybrid playbook.

**Virality in 2026: the output is the ad.**
- Shares/saves > likes; UGC-style content outperforms branded 93%; "watch me destroy this argument / AI receipts" is native TikTok/IG format. RoastMate's outputs (the savage line, the "vent vs. the version I sent" before/after) are inherently shareable social capital — most competitors' bland replies aren't.

---

## 2. Strategic thesis for v2

> **Go from "an app you open" to "a reflex you reach for" — by being the most *native*, *private*, *non-creepy*, and *shareable* way to win the conversation you can't stop replaying.**

Four moats, in priority order. P1–P3 are differentiation competitors structurally can't copy; P4–P5 are growth/revenue; P6 are bigger bets.

---

## 3. Prioritized pillars

### P1 — Native, contextual capture (the anti-screenshot moat) — **highest leverage**
Competitors make you screenshot/paste. We shouldn't.
- **App Intents / Siri 2.0:** "Hey Siri, help me clap back at this," "Vent about this." Register rich App Intents so RoastMate is invokable from Siri/Spotlight/Shortcuts/Action Button.
- **Action Button + Control Center + Lock Screen "Quick Vent"** (one press → vent box, no unlock friction in the moment of rage).
- **Share Extension upgrade:** already exists — make it the fastest path (select text in Messages/Mail/anywhere → full intensity+style picker → vent→sendable inline).
- **Post-WWDC26: personal-context API** — read the actual Messages/Mail thread (with permission) so the AI sees the real conversation instead of a pasted blob. This is the single biggest UX leap vs. the entire competitor set.
- _Selling point:_ "RoastMate is *in* iOS, not a website you paste into. It already knows what they said."

### P2 — Adopt WWDC26 Foundation Models upgrades early
- Re-benchmark Vent/Feral on the new larger-context / higher-quality on-device model. Goal: push **more** of Vent/Feral on-device so cloud becomes optional turbo, not the default for catharsis.
- _Selling points:_ "Your rage never leaves your phone." Lower cloud cost → better margins. Be in the **first wave** of apps showcasing the WWDC26 model (App Store featuring + press angle).

### P3 — Own the "not a companion, a tool" trust position
- Explicit, marketed stance: no relationship simulation, no dependence loop, no "always-on friend." Ship visible trust UI: on-device badge, "this is a tool, not a therapist/friend" honesty, crisis-resource handoff if self-harm signals (also de-risks us vs. the 2026 regulatory wave).
- _Selling point:_ "Every other emotional AI wants you addicted to it. This one wants you to not need it." Timely, press-worthy, App-Review-friendly, and a real wedge while companion apps get sued.

### P4 — Shareable-artifact growth loop
- One-tap **"Comeback Card" / "Vent vs. Sent" before-after** export (beautiful, watermarked image + short vertical video variant) designed for TikTok/IG/小红书. The artifact is the install ad.
- Optional anonymized "Hall of Roasts" gallery (opt-in, safety-filtered) for social proof + SEO.
- _Selling point + growth:_ content competitors can't match because ours is funny + emotionally charged + screenshot-native.

### P5 — 2026-proof hybrid monetization
- Keep an affordable sub, but go **hybrid**: consumable "boost packs" (extra cloud Vents / extra rewrites) that cover the real cloud variable cost; test a **weekly** tier for bursty users.
- **Intent-triggered paywall:** fire at the peak emotional moment (when they hit Feral/Vent or tap "Make it sendable" on a great draft) — not at onboarding.
- Wire **RevenueCat/Superwall paywall A/B** from day one; commit to continuous experiments.
- _Outcome:_ revenue that survives subscription fatigue + covers AI cost; aligns with the dominant 2026 model.

### P6 — Bigger bets (sequence after P1–P5 land)
- **Voice venting:** talk-vent (rising modality, more cathartic than typing) → on-device transcription → rewrite. Strong differentiator; pairs with Watch.
- **Conflict journal / patterns over time:** longitudinal, private, on-device insight ("you keep having this fight"). Sticky, journaling-adjacent (the Day One lane), retention engine — *without* becoming a "companion."
- **Localized growth push:** 4-language UI already shipped; zh/ja markets are underserved for this exact emotional niche — localized ASO + creator seeding.

---

## 4. Timeline (anchored to WWDC 2026, June 8–12)

- **Now → WWDC (≈3 wk): "no-new-API" wave** — ship things that need no unreleased API and don't risk the in-review 1.0: P4 shareable card, P5 hybrid monetization + intent paywall + A/B, P1a (Action Button / Control Center / richer App Intents / Share Extension upgrade), P3 trust UI. Land as **v1.1**.
- **WWDC week:** rebenchmark on the new Foundation Models; scope the personal-context + Siri 2.0 APIs.
- **Post-WWDC (v1.2 → v2):** P2 (new on-device model), P1b (Messages/Mail context, Siri 2.0), then P6 bets. Aim to be a launch-window showcase app for the new model.

---

## 5. Selling points to lead marketing/ASO with
1. **"It already knows what they said."** Native iOS context capture vs. paste-a-screenshot competitors. (P1)
2. **"Your rage never leaves your phone."** On-device-first; cloud is an optional, switch-off-able turbo. (P2)
3. **"The emotional AI that doesn't want you addicted to it."** Tool, not companion — trust + timely vs. the 2026 companion-app backlash. (P3)
4. **"Vent first. Then send the version that actually wins."** The two-stage ritual — already our line; it's the moat, keep it central.
5. **"Watch me win this argument."** Shareable comeback cards — the product markets itself. (P4)

---

## 6. Guardrails (do not regress these)
- v1.0 is in App Review — **do not ship changes that could invalidate the in-review build**; new work targets v1.1+ on a branch.
- On-device-first, privacy-first is the brand. Any new cloud use must be optional + disclosed + reflected in App Privacy.
- Safety filter + "private draft, for yourself only" framing is load-bearing for App Review and the non-companion position — never weaken it.
- Keep iOS iPhone-only unless iPad gets real design + screenshots (see `docs/` + memory). macOS/Watch stay in lockstep on the shared engine.
- The repo's `metadata/review_notes.txt` is stale/wrong — never reuse it; the live ASC notes are canonical.

---

## 7. Sources
- [Apple Foundation Models — ML Research](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) · [Foundation Models docs](https://developer.apple.com/documentation/FoundationModels) · [Should my app use Apple Foundation Models (OpenForge)](https://openforge.io/should-my-app-be-using-apple-foundation-model/)
- [WWDC 2026 preview (Yahoo/Tom's Guide)](https://tech.yahoo.com/ai/apple-intelligence/articles/wwdc-2026-preview-ios-27-043000444.html) · [WWDC26 developer expectations](https://www.abhs.in/blog/apple-wwdc-2026-what-developers-should-expect) · [Computerworld: WWDC 2026 AI leap](https://www.computerworld.com/article/4168225/wwdc-2026-how-apple-can-take-a-great-leap-in-ai.html)
- [AI companion market (Fortune Business Insights)](https://www.fortunebusinessinsights.com/ai-companion-market-113258) · [APA: AI & emotional connection](https://www.apa.org/monitor/2026/01-02/trends-digital-ai-relationships-emotional-connection)
- [AI reply tools 2026 (softservice)](https://softservice.org/ai/ai-respond-to-text/) · [TextBack — App Store](https://apps.apple.com/us/app/textback-ai-reply-assistant/id6760047261) · [SmoothRizz](https://www.smoothrizz.com/)
- [State of App Monetization 2026](https://www.igniscor.com/post/state-of-app-monetization-2026) · [RevenueCat: hybrid monetization 2026](https://www.revenuecat.com/blog/growth/ai-hybrid-monetization/) · [Adapty: monetization 2026](https://adapty.io/blog/mobile-app-monetization-2026/)
- [NY & CA AI companion laws (Morrison Foerster)](https://www.mofo.com/resources/insights/251120-new-york-and-california-enact-landmark-ai) · [NY safeguards in effect (Manatt)](https://www.manatt.com/insights/newsletters/client-alert/new-york-s-safeguards-for-ai-companions-are-now-in-effect)
- [TikTok algorithm 2026](https://posteverywhere.ai/blog/how-the-tiktok-algorithm-works)
