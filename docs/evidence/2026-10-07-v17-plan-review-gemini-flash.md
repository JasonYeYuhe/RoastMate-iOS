# Raw review of the FIRST draft of docs/DEV_PLAN_v1.7_2026-10.md — Gemini 3.8 Flash (High), via agy, 2026-10-07

Prompt: same for both reviewers (see the plan's section 9). Synthesis and verification of every claim: the plan's section 9. Advisor citations are leads, not evidence.

---

### 1. VERDICT
**SHIP-WITH-FIXES** — The plan correctly prioritizes fixing active storefront and paywall dishonesty that sabotages conversion, but Phase 0 and Phase 3 are classic developer escapism that burn engineering hours on a backend and feature set seen by virtually zero users while top-of-funnel is near zero.

---

### 2. FINDINGS

1. **Paywall advertises a free feature as paid (Consumer honesty & App Review risk)**
   - *Section:* P1.1 / §1 Finding 2.
   - *Problem:* `paywall.body` explicitly lists "Vent Mode (private draft + rewrite)" as a Pro feature across all four locales, even though Vent was made free in v1.6.0.
   - *Fix:* Remove "Vent Mode" from `paywall.body` in all `.strings` files before cutting build 23.
   - [VERIFIED IN CODE: [Localizable.strings](file:///Users/jason/Documents/RoastMate/Shared/en.lproj/Localizable.strings#L452), [PaywallView.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/Paywall/PaywallView.swift#L77)]

2. **Phase 3 (Traditional Chinese Roommate Group) is pure engineering displacement**
   - *Section:* Phase 3 (§5).
   - *Problem:* Investing days into prompt tuning, JSON personas, safety lists, and evals for an app getting ~1 download and 8 impressions a week in Taiwan is building a product for an imaginary audience.
   - *Fix:* Cut Phase 3 completely from the immediate roadmap. Do not touch it until Taiwan downloads exceed 50/week.
   - [REASONING]

3. **Phase 0.2 Worker re-architecture is unjustified over-engineering**
   - *Section:* P0.2 (§2).
   - *Problem:* Re-architecting multi-model fallbacks, sweeping May 2026 evals, and testing wrangler latency for an app spending $0.04/week (~5 requests/day) introduces deployment risk to live Worker `200d240c` for negligible gain. OpenRouter already catches Groq failures.
   - *Fix:* In `cloud-worker/src/index.js`, simply gate off the Groq call (or remove the dead model) to save ~1s latency. Drop the complex secondary-model matrix.
   - [VERIFIED IN CODE: [index.js](file:///Users/jason/Documents/RoastMate/cloud-worker/src/index.js#L300-L345)]

4. **Product page screenshots are corrupted and mislocalized**
   - *Section:* P1.5 / §1 Finding 1.
   - *Problem:* Only `en-US` screenshots exist in ASC, showing May 2026 Simplified Chinese UI with Vent locked. The local `zh_Hant` set has 5 byte-identical captures (`md5 43072bbc...`) because UI tests failed to bypass onboarding.
   - *Fix:* Fix `ScreenshotTests.swift` or manually capture clean, localized 6.9" shots for `zh-Hant` and `en-US`. Visually inspect every image before ASC upload.
   - [VERIFIED IN CODE: [01-generator-empty.png](file:///Users/jason/Documents/RoastMate/metadata/screenshots/zh_Hant/iPhone_17_Pro_Max/01-generator-empty.png)]

5. **ExploreView hides Pro features from all live storefronts**
   - *Section:* P1.3 / §1 Finding 3.
   - *Problem:* `ExploreView.isZhHansLocale()` checks `contains("hans") || hasPrefix("zh-cn") || == "zh"`. Taiwan (`zh_TW`) and US (`en_US`) users fail this check, hiding Echoes and Roommate tiles completely even when remote flags are enabled.
   - *Fix:* Clean up locale checks via `AppLanguage.contentBucket`.
   - [VERIFIED IN CODE: [ExploreView.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/StyleLibrary/ExploreView.swift#L138-L148)]

6. **Share-card directs users to a competitor**
   - *Section:* P1.2 / §1 Finding 4.
   - *Problem:* `sharecard.findus` instructs users to "Search RoastMate on the App Store", which ranks a rival app #1 in TW, HK, US, and JP. RoastMate only ranks #1 for "幫你罵" or "RoastMate AI".
   - *Fix:* Change `sharecard.findus` to `"App Store 搜尋 幫你罵"` (zh-Hant) and `"Search RoastMate AI on the App Store"` (en).
   - [VERIFIED IN CODE: [Localizable.strings](file:///Users/jason/Documents/RoastMate/Shared/zh-Hant.lproj/Localizable.strings#L497), [ShareCardView.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/ShareCard/ShareCardView.swift#L134-L140)]

7. **Dead research tile leaks to production until November**
   - *Section:* P1.4.
   - *Problem:* `SettingsView.swift` displays a research recruit tile linking to a closed external form promising a "paid 30-min interview" with a hardcoded deadline of 2026-11-01.
   - *Fix:* Delete the research section from `SettingsView.swift`.
   - [VERIFIED IN CODE: [SettingsView.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/Settings/SettingsView.swift#L17-L24), [SettingsView.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/Settings/SettingsView.swift#L163-L178)]

---

### 3. PRIORITY ORDER EVALUATION
- **(a) Is P1.5 (Product page / screenshots) highest-leverage?**
  Yes, among technical tasks. 96 impressions yielding 3 page views is fatal. Fixing screenshots is storefront hygiene. However, screenshots only convert *existing* searches; they do not generate search traffic.
- **(b) Should Phase 3 be cut, deferred, or kept?**
  **Cut immediately.** Building complex LLM pipelines for a user base of two is self-indulgence.
- **(c) Displacement activity in Phase 0 / Phase 1:**
  P0.1, P0.2, and P1.3 (testing obscure `zh-Hans-SG` simulator configurations) are 100% displacement activities.

---

### 4. WHAT IS MISSING FOR TAIWAN (NEXT 30 DAYS)
1. **Active Community Seeding:** Native posts sharing real, culturally relatable workplace/relationship roasts on **Threads** (dominant in Taiwan right now), **Dcard**, and **PTT**.
2. **Aggressive Creator Outreach:** Cold emailing 3 creators and waiting is not marketing. Reach out via IG/Threads DM to 30+ Taiwanese meme, workplace, and humor accounts.
3. **Taiwan ASO Refinement:** Revisit subtitle and keyword fields for Taiwanese colloquial search terms (e.g., 嘴砲, 吵架神器, 發洩, 防小人).
4. **Viral Sharing Mechanism:** Enable shareable image cards with clear watermarks/QR codes optimized for Instagram Stories and Threads.

---

### 5. STOP RULE EVALUATION (§7)
- **Status:** **Poorly formed and gameable.**
  Waiting until 2026-11-30 (~8 weeks) with a threshold of `< 10` downloads across 3 countries is far too lenient. A single random bump or 2 downloads a week hits 10 downloads naturally without proving viability.
- **Proposed Rule:**
  *"By 2026-11-08 (30 days post-1.7 launch): If 30-day cumulative Taiwan first-time downloads are < 40 OR paying subscribers remain ≤ 2 despite executing at least 2 public distribution campaigns (Threads/Dcard posts and 20+ creator DMs), immediately freeze all feature development and transition RoastMate to annual maintenance mode."*

---

### 6. RISKS CREATED BY THE PLAN
- **App Review Rejection:** Minimal risk if `paywall.body` is aligned with actual entitlements. Deleting the research tile eliminates Guideline 2.2 dead-link rejection risk.
- **Privacy-Label Change:** No risk; P0.3 preserves zero-tracking architecture.
- **Billing / Honesty Regressions:** Positive impact; fixes active paywall false advertising.
- **Remote Kill-Switches:** In P0.1, accidentally setting `roommate_group_enabled: false` kills the feature globally. Ensure local testing does not overwrite production config.
- **Sending Users to Competitors:** High risk if P2.1 enables `share_card_enabled` globally before v1.7 adoption is near 100%, as v1.6.0 binaries still carry the competitor search string. Keep `share_card_enabled: false` until v1.6.0 usage drops below 5%.
