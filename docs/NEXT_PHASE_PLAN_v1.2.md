# RoastMate — Next-Phase Development Plan (post-v1.1 → v1.2 → v2.0)

**Date:** 2026-05-18 · **Author:** Claude (for YE) · **Status:** v2 DRAFT —
revised after Gemini 3.1 Pro + Codex (gpt-5.5) adversarial review.
**Builds on:** `docs/ROADMAP_v2.md`. This doc sequences and *falsifies* that
thesis against the 2026 landscape and the actual v1.1 shipped code.

> **Reviewers' one-line verdict:** the plan's best instinct is "tool, not
> companion"; its worst habit was "treating a good narrative as an executable
> dependency graph." This revision is **less ambitious in the calendar, more
> ambitious in falsifying its own assumptions.**

---

## 1. Context

v1.1 is code-complete and in App Store review (pillars D crisis-handoff, A
shareable card, B credits monetization, C native capture/Controls, + voice
venting + zh scenario pack). iOS build 5 queued; 6 IAPs await a browser-side
bundle step. Dev is done — the question is *what next, in what order*. The
2025–26 regulatory wave (Character.AI suits/settlement, Woebot shutdown, CA
SB 243/AB 489, Apple 5.1.2(i)) is structurally favorable to RoastMate's
posture — **but as a trust posture we must keep earning, not a statutory moat.**

---

## 2. Market & Regulatory Landscape (researched 2026-05-18)

- AI mental-health market ≈ **$8.25B (2025) → $36.44B (2034)**; companion apps
  +~700% (2022→mid-2025). Adjacent reply/dating-AI saw its **first revenue
  decline** in 2025 (monetization-fatigue). ([Flourish](https://www.myflourish.ai/post/top-ai-mental-health-apps-2026), [Business of Apps](https://www.businessofapps.com/news/dating-app-market-first-annual-revenue-decline/))
- Hybrid (sub+consumable) ≈35% of apps; credit-based AI pricing +126% YoY;
  **AI subscriptions skew monthly — weekly is only ~15% of the AI mix with
  materially weaker retention** (RevenueCat 2026). ([ASO Mobile](https://asomobile.net/en/blog/mobile-app-market-report-2025-monetization-ai-and-user-behavior/), [Schematic](https://schematichq.com/blog/ai-credits))
- Competitors: *companion* (Replika/Nomi/Character.AI — regulatorily wounded,
  5 youth-harm suits settled Jan 2026), *therapy* (Wysa/Youper/Ash/Yuna/Ven;
  Woebot dead), *reply/rizz* (YourMove ~$79/yr, SmoothRizz — cloud-only, no
  privacy story). RoastMate's wedge — *native + on-device-first + private +
  tool-not-companion + vent→rewrite→send ritual* — has **no direct combined
  competitor**. ([ABA](https://www.americanbar.org/groups/health_law/news/2025/ai-chatbot-lawsuits-teen-mental-health/), [YourMove](https://www.yourmove.ai/))
- Regulation = **hygiene floor, not differentiation**: SB 243 only bites a
  *companion chatbot*; AB 489 bites *implying a licensed clinician*; Apple
  5.1.2(i) (live 2025-11-13) binds *anyone* sending personal data to 3rd-party
  AI. The durable moat is **architecture + trust + restraint**, not the
  statutes. ([TechCrunch](https://techcrunch.com/2025/11/13/apples-new-app-review-guidelines-clamp-down-on-apps-sharing-personal-data-with-third-party-ai/), [Davis Polk](https://www.davispolk.com/insights/client-update/california-and-new-york-launch-ai-companion-safety-laws), [Nat. Law Review](https://natlawreview.com/article/novel-ai-laws-target-companion-ai-and-mental-health))

---

## 3. Strategic Thesis

> Win by being the **safe, native, private tool** while incumbents get
> regulated and sued — by owning the **text-input layer** (no unannounced APIs
> required) and proving the share loop, **not** by betting the roadmap on
> WWDC26 or drifting toward journaling/companionship.

---

## 4. Roadmap (calendar-light, evidence-heavy, WWDC-branched)

### Milestone A — v1.1.x SHIP GATES ONLY (now → review clears)
Strictly ship-blocking. Everything speculative removed from this tranche.
1. **Close the IAP loop** (carry-over, browser-side) — gates revenue.
2. **5.1.2(i) explicit pre-use cloud-AI consent — HARD SHIP GATE.** First time
   Vent/Feral would hit the Cloudflare→Groq/OpenRouter path, show a distinct,
   explicit consent (not onboarding copy, not just the Settings toggle, not App
   Privacy). **This is the single most likely review-rejection landmine and the
   most real item in this doc.** Also: re-evaluate the cloud-default. "Privacy-
   led" while production defaults cloud-on is a product contradiction —
   resolve it (default off, or first-run explicit choice), not patch it in copy.

### Milestone A′ — Post-launch learning system (parallel, the evidence base)
3. **Real measurement plan** (replaces "local-only counters", which both
   reviewers called analytically useless): a privacy-compatible aggregation/
   export path — opt-in aggregate funnel (paywall impression→pack→spend),
   cohort D7/D30 *return-to-tool*, cloud-use rate, churn reasons, App Store
   review mining, + a handful of user interviews. No third-party analytics SDK,
   but it must actually produce decision-grade data. Feature-rich + evidence-
   poor is the plan's core failure mode; fix it first.

### Milestone B — WWDC Week (Jun 8–12): a GATE, not a prophecy
4. **Eval harness + capability matrix BEFORE any migration/capture work**:
   per-mode quality, latency, refusal rate, safety, multilingual pass/fail
   thresholds, by platform/device/language. "Re-benchmark after WWDC" is
   meaningless without pre-defined pass/fail.
5. Branch the roadmap explicitly: **"APIs exist"** vs **"APIs don't exist."**
   Only the second branch is committed; the first is an options appendix until
   Apple actually ships. (As of 2026-05-18 only WWDC26 *dates* are official;
   bigger model / Core AI / Visual Intelligence / Messages-read are speculation.)

### Milestone C — v1.2 "Own the input layer" (the real native moat)
6. **Custom iOS Keyboard Extension** (the highest-leverage idea from review,
   replaces the speculative Apple-personal-context bet): generate / rewrite /
   send comebacks *in-place* inside iMessage/WhatsApp/IG using the text already
   in the field. **Zero unannounced APIs**, fully in our control, bypasses the
   screenshot-paste friction entirely. This is the anti-screenshot moat no
   cloud competitor can cheaply match. Must respect: keyboard "Full Access"
   privacy posture (do on-device by default; the 5.1.2(i) consent applies if it
   ever calls cloud), and the Pro/credit gating must hold inside the keyboard.
7. *Discovery track only (uncommitted):* permissioned Messages/Mail context —
   pursue **only if** WWDC26 ships a concrete API; treat as
   entitlement/UX/privacy feasibility spike, not a scheduled feature. It also
   risks fracturing the shared iOS/macOS/watch architecture — scope before
   committing.

### Milestone D — Growth loop (only after static cards prove out)
8. **Make the artifact a loop, not just an artifact** (both reviewers: "an
   artifact is not a loop"): export templates, watermark/attribution, a reason
   a viewer installs, creator-seeding plan. Gate on measured static-card share
   rate from A′ before building the **short-video** variant (deferred until
   static is proven).

### Speculative appendix (NOT committed — needs validation first)
- Conflict-pattern / longitudinal view: **first real strategic drift toward
  journaling/therapy** and toward SB 243 territory. Do not build until data
  proves users want *reflection*, not just *release*.
- "Hall of Roasts": **cut** — fights the privacy brand, moderation burden,
  strategically nonessential.
- zh-Hant/ja localized growth: keep as organic/ASO experiment, not a milestone.

---

## 5. Monetization — resolve the contradiction (do not ship the theater)

Both reviewers: **"consumables-primary" is not believable** while credits buy
*quantity only* and the marquee modes (Vent/Feral/Savage) stay Pro-gated — the
paywall foregrounds the thing users want least. Pick one, explicitly:
- **(Recommended) Pro-primary, credits as honest overflow/burst.** Matches the
  AI-sub-monthly reality and the "tool" brand; stop calling it
  consumables-primary. OR
- **Credits unlock genuine burst access to the premium modes** (so a credit
  actually buys the thing users want). Either is coherent; the current framing
  is not.
- **Kill the weekly tier** (premature, ~15% AI-mix, weak retention,
  "taxes you when you're upset" — wrong emotional aftertaste).
- **Remove Tinder/Bumble ARPPU** — irrelevant (life-outcome purchase vs.
  momentary negative-emotion catharsis; rage-moment users are price-sensitive).
- Keep the intent-triggered paywall (no onboarding wall) — the dating-market
  decline is the cautionary tale.

---

## 6. Compliance workstream (trust posture, not cargo cult)

- **5.1.2(i) consent = ship gate** (see A2). Highest priority, period.
- Argument Simulator: **low current legal risk** — as built it's a 12-turn-
  capped, user-directed rehearsal tool with no persistent persona; poor fit for
  SB 243's companion definition. **Drop the proposed session-length nudge —
  it's cargo-cult compliance** that adds friction without legal value.
- Instead maintain a **companion-drift trigger list**: persistent memory,
  longitudinal patterns, emotionally-responsive persona, relationship framing,
  uncapped turns → any of these flips classification risk; re-review before
  shipping any of them.
- AB 489: keep "tool, not therapist; AI-generated" affordance; never imply a
  clinician.
- *Judgment call (user decides):* a zero-data age affirmation at onboarding —
  cheap defensible hedge given roast/comeback content skews young, but adds
  friction and isn't legally required absent companion classification. Flagged,
  not assumed.

---

## 7. Reviewer synthesis & confidence

| Milestone | Gemini 3.1 Pro | Codex gpt-5.5 | This revision's response |
|---|---|---|---|
| A (as orig.) | 8/10 | 6/10 | Split into A (ship gates) + A′ (learning); short-video & analytics-theater removed |
| B | 4/10 | 8/10 | Recast as a hard gate w/ eval harness + API branch (Codex's framing) |
| C | 3/10 | 3/10 | Rebuilt around Custom Keyboard (no API dep); personal-context demoted to discovery |
| D (v2 patterns) | 2/10 | 4/10 | Moved to uncommitted speculative appendix |

Both flagged the same core flaws; revision addresses each. Net: the calendar
is shorter, the dependencies are falsifiable, the moat no longer waits on Apple.

## 8. Decisions (owner-resolved 2026-05-18 — user delegated "全权负责")

1. **Monetization → Pro-primary, credits as honest overflow.** Lowest-regret,
   brand-aligned, both advisors converged. Prices & SKUs **unchanged** (no
   repricing) — this is a paywall-emphasis + copy change (Pro = the value tier;
   credits = pay-as-you-go overflow), not a re-architecture. Implementation is
   the next reversible code item after compliance.
2. **Custom Keyboard Extension = committed v1.2 spine.** Adopted (both
   advisors' top structural fix; zero unannounced-API dependency). Large build
   → scoped as the v1.2 milestone, not started blindly this phase.
3. **Cloud default → first-run explicit choice. DONE & SHIPPED IN CODE**
   (`f6938e5`, the 5.1.2(i) consent gate). Decision closed.
4. **Age affirmation → use the EXISTING `hasAcknowledgedAgeGate` flow; add no
   new friction.** A zero-data age acknowledgment already exists in
   `UserSettings`; a forced extra gate is cargo-cult absent companion
   classification (Codex). Decision closed, no code change.
5. **This doc → committed** (`docs/NEXT_PHASE_PLAN_v1.2.md`). `ROADMAP_v2.md`
   is intentionally NOT rewritten — this doc supersedes/sequences it and says
   so; a destructive rewrite of the prior thesis adds risk without value.

**Sequenced next executable work (all reversible; Apple submit remains the
only stop-and-report gate):** (i) ✅ 5.1.2(i) consent gate — done/pushed;
(ii) monetization Pro-primary reposition (copy + paywall emphasis);
(iii) post-launch learning instrumentation (A′); (iv) v1.2 keyboard-extension
spike. The IAP-with-version bundle + final Submit still require the user's
browser + Apple 2FA — capability/auth wall, not a permission gap.
