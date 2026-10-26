Model: gemini-3.8-flash-high (via agy-backed mcp__gemini__ask_gemini, workspace /Users/jason/Documents/RoastMate) — answer received 2026-10-26T16:05:59Z (UTC). Verbatim, unedited.

---

### (1) Will this plan actually make the paid features better for a paying user in Taiwan? Which items matter most, which are wasted effort?

**Yes, conditionally.** For a paying user on an Apple Intelligence device (iOS 27), the plan transforms a broken experience (where 50–75% of paid Savage/style generations return 5 static canned lines or copy Simplified Chinese examples) into a functioning, localized product. For a user on a non-AI device (iPhone 13/14/15 base), the app remains primarily a 痛罵 (Feral) generator unless B1 ships.

* **Matters Most:**
  1. **A3 + A5 (On-device Permissive Guardrails & zh-Hant Prompt Parity):** Savage with 硬核回擊 or 台劇腔 currently gets refused 3/4 to 5/8 times on iOS 27, dumping users into the 5 canned fallback lines. Fixing prompt script leakage and adding the permissive fallback directly fixes the hero Pro feature on AI phones.
  2. **A6 (Purchase Intent Handoff & Yearly Trial Visibility):** The Day-0 TW churn occurred partly because purchasing dropped the user right back to the paywall/generator with no selection, no run, and no clear state. Surfacing the already-configured 7-day trial and auto-selecting/running the tapped style immediately upon purchase addresses the exact cancellation window.
  3. **A4 (Argument Simulator Prompt Fix):** Today the system prompt tells the model to generate what *the user* should say while the user prompt says *play the opponent*, resulting in numbered lists and role confusion. Fixing this makes the Pro simulator actually work.
  4. **B4 (Taiwan Style Relocalization):** Selling 京片兒 (Beijing slang) and 豆瓣 (Douban) as paid Pro styles in Taiwan alienates local users. Replacing them with authentic Taiwanese tropes (台式長輩文, 文青日記體) gives local credibility.
  5. **B5 (One-time 痛罵 Preview):** Lets a prospect experience the real cloud voice on their own situation before paying.

* **Wasted Effort:**
  1. **B1 (Cloud Sendable Modes in 1.8.1):** A massive architectural undertaking (new cloud route, versioned consent in 4 languages, server-side Pro token checks, App Privacy questionnaires, and a whole second binary) for an app averaging 1 TW download every 3 weeks. Calm and Sharp are *free* on-device features; pushing them to the cloud for non-AI devices is premature optimization.
  2. **A1 (Tuning 硬核回擊 for Feral before 11-04):** Targeted at saving the single US subscriber renewal on en_US. Does nothing for Taiwan payers and distracts from the core release.
  3. **A7 (Echoes zh-Hans/en copy fixes: Groq → OpenRouter):** Echoes is completely hidden in zh-Hant (`ExploreView.swift:138-148`), and the app is delisted in China. Rewriting zh-Hans consent strings has zero impact on Taiwan payers.
  4. **B6 (Worker `od` log boolean):** With ~1 download every 3 weeks in Taiwan, sample size will be statistically meaningless for months.

---

### (2) Anything FALSE in the plan (cite file:line; mark VERIFIED if you opened it)

1. **`AppleFMBackend.respondCached` guardrails parameter is technically defective:**
   * **Plan claim (lines 363–365):** *"Add a guardrails parameter to `AppleFMBackend.respondCached (AppleFMBackend.swift:32-45)`... call with default guardrails first. Only after a default refusal, retry once with `permissiveContentTransformations`."*
   * **VERIFIED ([AppleFMBackend.swift](file:///Users/jason/Documents/RoastMate/Shared/AI/AppleFMBackend.swift#L32-L69)):** `respondCached` reuses `self.session` whenever `keepSession && sessionKey == key && session != nil`. In FoundationModels, a `LanguageModelSession` is initialized with an immutable model/guardrail configuration (`LanguageModelSession(model:instructions:)`). Passing a new `guardrails` parameter to `respondCached` with the same `sessionKey` will **silently ignore** the parameter because the existing session is reused. To retry with permissive guardrails, the session cache key must include the guardrail enum, or the retry must use `respondFresh`.
2. **Citation minor discrepancy on `en.lproj:563`:**
   * **Plan claim (line 470):** *"The consent body names OpenRouter, not Groq... (zh-Hans.lproj:563, en.lproj:563)."*
   * **VERIFIED ([en.lproj](file:///Users/jason/Documents/RoastMate/Shared/en.lproj/Localizable.strings#L562-L565)):** In `en.lproj`, line 563 is `"echoes.consent.title"`; the body naming Groq is actually at line 564. (In `zh-Hans.lproj`, it is line 563).
3. **Verified Claims that are TRUE in Code:**
   * **VERIFIED ([StoreService.swift](file:///Users/jason/Documents/RoastMate/Shared/Services/StoreService.swift#L72-L86)):** Line 78 filters without sorting, leaving `products` in arbitrary StoreKit order.
   * **VERIFIED ([Localizable.strings](file:///Users/jason/Documents/RoastMate/Shared/zh-Hant.lproj/Localizable.strings#L173)):** `paywall.yearly.trial` exists in all 4 locales but is referenced by zero Swift files.
   * **VERIFIED ([PaywallView.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/Paywall/PaywallView.swift#L88-L97)):** Purchase completion triggers an alert that dismisses the paywall, but never passes back the tapped style or auto-runs generation.
   * **VERIFIED ([PromptBuilder.swift](file:///Users/jason/Documents/RoastMate/Shared/AI/PromptBuilder.swift#L143-L145), [#L252-L253](file:///Users/jason/Documents/RoastMate/Shared/AI/PromptBuilder.swift#L252-L253), [ArgumentSimulatorViewModel.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/ArgumentSimulator/ArgumentSimulatorViewModel.swift#L111-L128)):** The simulator prompt asks to "Play the OTHER side" while `PromptBuilder` mode guidance explicitly tells the model to produce "the response *the user* should give back" and forces a numbered list.
   * **VERIFIED ([PromptBuilder.swift](file:///Users/jason/Documents/RoastMate/Shared/AI/PromptBuilder.swift#L531-L546)):** `examplesForPrompt` checks only `containsHan`, passing Simplified Chinese examples to `zh-Hant` devices.
   * **VERIFIED ([StylePresets.json](file:///Users/jason/Documents/RoastMate/Shared/Resources/StylePresets.json#L305)):** `taiwanese_drama` system preamble hardcodes Chinese particles `啦/喔/欸` into English generation.
   * **VERIFIED ([style_voice.js](file:///Users/jason/Documents/RoastMate/cloud-worker/src/style_voice.js#L140-L142)):** `bjing_taunt` defines only `hans`; `hant`, `en`, and `ja` are absent.
   * **VERIFIED ([ExploreView.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/StyleLibrary/ExploreView.swift#L138-L148)):** `isZhHansLocale()` hard-hides Echoes and the Roommate Group for all non-Simplified locales (`zh_TW`, `en`, `ja`).
   * **VERIFIED ([RemoteConfig.swift](file:///Users/jason/Documents/RoastMate/Shared/Services/RemoteConfig.swift#L218-L220)):** `roommateGroupAllowed` requires `roommateGroupEnabled && echoesEnabled`.
   * **VERIFIED ([Localizable.strings](file:///Users/jason/Documents/RoastMate/Shared/zh-Hant.lproj/Localizable.strings#L158), [#L179](file:///Users/jason/Documents/RoastMate/Shared/zh-Hant.lproj/Localizable.strings#L179)):** Paywall and success sheets on non-AI devices explicitly state styles require Apple Intelligence, directly contradicting the Worker where Pro styles *do* shape Feral drafts.

---

### (3) App Review / privacy (5.1.2(i), 2.3.x, 3.1.x) or cost risks it misses

1. **Guideline 3.1.2 (Subscription Pricing & Trial Disclosures):**
   * Surfacing `paywall.yearly.trial` and emphasizing the "NT$58/month" equivalent without prominently displaying the total upfront billed amount ("NT$690/year") and renewal terms violates App Store Review Guideline 3.1.2. The yearly total must be clear and unmissable.
2. **Guideline 2.3.1 / 3.1.2 (ASC Subscription Descriptions Mismatch):**
   * The plan acknowledges that ASC subscription descriptions still state `"Unlimited generations + all styles, billed monthly"`, but relies on an in-app `PlanCopy` abstraction. The native StoreKit purchase confirmation sheet rendered by iOS displays the ASC description string. App Review often cross-checks this sheet against what the app actually provides; if a reviewer sees "unlimited" on the OS sheet while the app restricts modes, it faces a 2.3.1/3.1.2 rejection.
3. **Guideline 5.1.2(i) & App Privacy Declarations for B1:**
   * If B1 routes Composed/Sharp/Savage to OpenRouter, the app must update the App Store Connect Privacy Nutrition Labels for "User Content" (App Functionality / Personalization).
   * Shipped strings (`onboarding.privacy.body`, `cloud.consent.footnote`, `settings.about_ai.body`) currently pledge: *"Composed, Sharp, and Savage always run on-device and never use cloud"* ([en.lproj:20, 133, 136](file:///Users/jason/Documents/RoastMate/Shared/en.lproj/Localizable.strings#L20)). If B1 ships without airtight versioned consent gating, it breaches existing user promises.
4. **Guideline 1.2 / 2.3 (Permissive Guardrails for Generation):**
   * In A3, Apple's `permissiveContentTransformations` API is officially documented for *transforming* existing text, not generating greenfield sharp roasts. The plan mitigates this with `ModelRefusal`, `RewriteThreatScreen`, and `threatJudge`, but if any slur, threat, or self-harm content slips through during an App Review test, it risks immediate rejection under Guideline 1.2 (Safety/Objectionable Content).
5. **Cost / Operational Risks:**
   * OpenRouter auto-top-up is OFF with $9.88 remaining. In B1, the proposed "zh-Hant Simplified character check + retry" doubles inference cost on failures. A sudden spike or stuck retry loop could drain the balance, triggering a silent global outage for all cloud features.

---

### (4) What is missing that would most help keep or win payers?

1. **The Roommate Group (虛擬室友群) in Taiwan Traditional Chinese (Cut as B2):**
   * **This is the biggest strategic mistake in the plan.** The plan cuts B2 to pursue B1. Yet as Finding 10 admits, basic text venting is not a defensible moat against ChatGPT or Gemini. The Roommate Group is a unique, highly engaging format (a 3-roommate multi-voice simulated group chat) that **already runs entirely on the Cloud Worker** and works on *every single device* (AI and non-AI alike). Lens 4 showed the Worker already passes the 8/8 parsing contract for `zh_TW`. Instead of abandoning it, polishing the prompt to Traditional Chinese and exposing it in `ExploreView` gives Taiwan users an immediate, distinctive Pro feature they cannot replicate in standard chatbots.
2. **First-Run Default Mode for Non-AI Devices:**
   * When an install lacks Apple Intelligence, the app still defaults to 銳利 (Sharp), which serves static canned quotes ([RoastGeneratorViewModel.swift](file:///Users/jason/Documents/RoastMate/RoastMate/Sources/Features/RoastGenerator/RoastGeneratorViewModel.swift#L20)). A new user typing their frustration gets a generic canned response on their very first tap and uninstalls. The app must default to 發洩 (Vent) when `!isOnDeviceModelAvailable`.
3. **LINE / Social Context Sharing:**
   * Taiwanese interpersonal conflict happens in LINE and Threads. A prominent "Copy for LINE" or export button formatted for chat bubbles directly maps the app to real-world utility.
4. **Mandatory 痛罵 Preview (B5):**
   * B5 is currently conditional/deferred. Showing one free, high-impact 痛罵 draft with a Pro voice on the user's actual situation is the single highest-leverage conversion lever.

---

### (5) Is the sequencing and the relation to the 11-15 stop rule sound?

**No, the sequencing and stop-rule relationship are contradictory.**

1. **Violates the Spirit and Intent of the Stop Rule:**
   * `DEV_PLAN_v1.7_2026-10.md` §7 and `HANDOFF_v1.7_NEXT_SESSION.md:130-134` explicitly state: *"The wave ends at the stop rule in §7 (read on 11-15)... Do not argue with it by finding new code to write; that is the exact pattern it exists to stop."*
   * Calling v1.8 a "bounded exception" while scheduling work through December 5 (Binary 1.8.1) and measurement through January 31, 2027 completely hollows out the stop rule. With 0 marketing posts published and Taiwan at ~1 download every 3 weeks, the 11-15 stop rule will almost certainly fire. Committing to a secondary feature binary (1.8.1) before 11-15 is classic runaway scope.
2. **Over-Engineered Two-Binary Staging:**
   * Target date for 1.8.0 submission is 11-12, just 3 days before the 11-15 stop rule check. If 1.8.0 slips by even a couple of days, 1.8.1 collides directly with the stop-rule evaluation.
   * Trying to rush A1 before 11-04 for a single US subscriber whose status cannot even be verified from client telemetry wastes critical setup days.

---

### (6) Verdict: SHIP-WITH-CHANGES

Do not ship as proposed (specifically, kill Binary 1.8.1 / B1, and consolidate into a single, high-impact Binary 1.8.0).

#### Required Changes:
1. **Collapse to a Single Binary (1.8.0) and Freeze:**
   * **Drop B1 entirely.** Do not build the cloud sendable pipeline for Composed/Sharp/Savage. It is a high-risk, low-reward compliance rabbit hole for a user base that does not yet exist.
   * **Drop Binary 1.8.1.** Ship all necessary fixes in 1.8.0 by 11-12, and let the 11-15 stop rule govern future development.
2. **Revive the Roommate Group (B2) in Place of B1:**
   * Unhide `roommateGroup` in `ExploreView.swift` for `zh-Hant`.
   * Apply the Taiwan Traditional Chinese prompt fix to the Worker (`vent_prompt.js` / `EchoesParser`). This provides real Pro multi-voice value on every device without altering client cloud consent architectures.
3. **Fix the Technical Flaw in A3 (`respondCached`):**
   * Do not pass `guardrails` to the existing cached session in `AppleFMBackend.swift`. Either incorporate `guardrails` into the session cache key or use `respondFresh` with `.permissiveContentTransformations` upon detecting a standard refusal.
4. **Make B5 (痛罵 Preview) and First-Run Default Mandatory in 1.8.0:**
   * Guarantee that non-AI devices default to 發洩 (Vent) so first-time users get a real dynamic LLM response rather than a canned card.
   * Give every user one free Pro-styled 痛罵 preview on their own input.
5. **App Store Compliance Hardening (A6 / Review):**
   * Ensure the yearly subscription UI explicitly displays the total billed amount (`NT$690/年`) alongside the trial and monthly breakdown.
   * Edit the ASC subscription description in the App Store Connect web console to remove "Unlimited generations" before submitting 1.8.0.
6. **Drop Distractions (A1, A7, B6):**
   * Do not spend time tuning en_US Worker styles for the US renewal (A1), rewriting delisted zh-Hans Echoes strings (A7), or instrumenting low-volume Worker telemetry (B6). Focus 100% of effort on Taiwan localization, on-device AI quality, and purchase handoff.
