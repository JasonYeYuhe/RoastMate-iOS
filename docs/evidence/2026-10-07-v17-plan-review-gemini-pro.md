# Raw review of the FIRST draft of docs/DEV_PLAN_v1.7_2026-10.md — Gemini 3.1 Pro (High), via agy, 2026-10-07

Prompt: same for both reviewers (see the plan's section 9). Synthesis and verification of every claim: the plan's section 9. Advisor citations are leads, not evidence.

---

**1. VERDICT**
SHIP-WITH-FIXES — the core focus on repairing the App Store funnel and honest copy is exactly right, but the plan still smuggles in displacement activity (evaluating and building features for an audience of zero) that must be cut.

**2. FINDINGS**
1. **P1.5 (Product page / screenshots):** [VERIFIED IN CODE: `metadata/screenshots/zh_Hant/iPhone_17_Pro_Max/01-generator-empty.png`] Problem: 5 of the 6 zh-Hant screenshots are literally byte-identical. The UI test stalled and captured the exact same frame repeatedly. Fix: Your pipeline is broken or the files are stale; find out why and regenerate them cleanly.
2. **P1.1 (Paywall header):** [VERIFIED IN CODE: `Shared/zh-Hant.lproj/Localizable.strings:157`] Problem: The paywall explicitly sells Vent Mode ("發洩模式") as a Pro feature, taking money under false pretenses. Fix: Rewrite the strings in all locales and add the preflight grep as planned.
3. **P1.2 / P2.1 (Share card competitor):** [VERIFIED IN CODE: `Shared/zh-Hant.lproj/Localizable.strings:500`] Problem: The share card explicitly tells users to search "RoastMate", which ranks a competitor #1 in your target markets. Fix: Change the string to "RoastMate AI" and 「幫你罵」 before enabling the share card.
4. **P1.3 (Locale gates):** [VERIFIED IN CODE: `RoastMate/Sources/Features/StyleLibrary/ExploreView.swift:138`] Problem: `isZhHansLocale` uses `id.hasPrefix("zh-cn")`, but `.lowercased()` preserves the underscore (`zh_cn`), so the check fails silently. Fix: Route through `AppLanguage.contentBucket` as planned.
5. **P0.2 (Dead primary model):** [VERIFIED IN CODE: `cloud-worker/wrangler.toml:23`] Problem: The Groq primary model is confirmed dead (404), leaving OpenRouter as a single point of failure. Fix: Remove the Groq hop and rely natively on OpenRouter's fallback mechanism.
6. **P0.1 (Worker eval):** [REASONING] Problem: You are planning to spend time evaluating the OpenRouter model on the roommate group prompt. With mainland China delisted and the feature gated to Simplified Chinese, the roommate group currently has *zero reachable audience*. Fix: Cut this entirely. It is displacement activity.

**3. Priority Order**
(a) **Yes, P1.5 is the highest leverage item.** A 3% page-view conversion rate from 96 impressions means your storefront is bleeding users. Showing a US or Taiwanese searcher Chinese UI with a lock icon on a free feature guarantees they bounce. Fixing this is direct distribution work.
(b) **Phase 3 MUST BE CUT.** Building a Traditional-Chinese Roommate Group for an audience of exactly *one* Taiwanese subscriber is textbook displacement activity. Do not retreat into Xcode to build features for a single user. You need top-of-funnel growth, not deeper features.
(c) **Yes, P0.1 is displacement activity.** Evaluating cloud model performance for a feature that is invisible to your entire reachable market is an excuse to avoid distribution work.

**4. MISSING**
Active distribution experimentation in the target market. Relying entirely on ASC impressions and cold creator emails is too passive for a ~2-download-a-week app. You have two paying subscribers who bought on Day 0 at full price. You should be finding out *why* they paid, and experimenting with grassroots distribution in Taiwanese communities (e.g., Threads, Dcard, PTT) where the "幫你罵" concept resonates, rather than just polishing the binary. 

**5. Stop Rule**
**Not well-formed.** Waiting nearly two full months (until 11-30) for a bar as low as "< 10 downloads" gives you six weeks to invent more coding tasks and rationalize ignoring the rule.
**Proposed Rule:** If by 2026-10-31 (three weeks after 1.7.0 goes live), the new screenshots and Phase 2 creator outreach have not lifted organic downloads > 5/week, and neither of the 2 current subscribers renews, stop all feature work immediately.

**6. Risks Created**
- **Sending users to a competitor:** P2.1 flips `share_card_enabled` after ~7 days. Users who haven't updated from 1.6.0 will still have the old competitor-directing string in their binary. The risk is small given the tiny install base, but it is real.
- **Honesty regressions:** None. P1.1 mitigates App Review and honesty risks by bringing the paywall copy in line with actual free-tier behavior.
- **Kill-switches:** Safe. Removing Groq (P0.2) solidifies the cloud path without breaking existing `cloud_sendable_enabled` or `vent_cloud_enabled` remote flags.
