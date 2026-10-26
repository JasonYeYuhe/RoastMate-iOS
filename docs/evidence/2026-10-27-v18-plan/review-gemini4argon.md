Model: gemini-4-argon-high (via agy-backed mcp__gemini__ask_gemini, workspace /Users/jason/Documents/RoastMate, read-only prompt) — answer received 2026-10-26T16:07:54Z (UTC). Verbatim below.

---

(1) WILL THIS PLAN MAKE PAID FEATURES BETTER FOR A TAIWAN PAYER?

Yes for 1.8.0 (Workstream A + B3 + B5); mostly premature or wasted effort for 1.8.1 (B1), B4, and B6.
In Taiwan, Apple Intelligence requires iPhone 15 Pro+ on iOS 26.1+ with AI enabled, so Taiwan buyers split across C/E (older or non-Pro iPhones, AI off) and A/D (newer Pro/16+ on OS 26.1/27).

Highest-leverage items (keep):
- A6 (Paywall conversion + 7-day Yearly trial + post-purchase auto-run): Yearly has had a configured 7-day free trial in StoreKit (RoastMate/Configuration.storekit:216-220, VERIFIED) and localized trial copy (Shared/zh-Hant.lproj/Localizable.strings:136, VERIFIED) that PaywallView never renders (RoastMate/Sources/Features/Paywall/PaywallView.swift:305-342, VERIFIED), while sorting plans nondeterministically and dead-ending purchase on an alert instead of running the blocked Pro action. Highest conversion impact in the plan.
- A2 (Honest C/E Pro style copy): Shared/zh-Hant.lproj/Localizable.strings:326 and :331 (VERIFIED) tell a Taiwan C/E user before and after purchase that the 24 styles need Apple Intelligence, even though cloud-worker/src/style_voice.js:1-292 (VERIFIED) already shapes both 痛罵 and 發洩 with all 24 voices (台劇腔, 陰陽怪氣, 文言文, etc.). Fixing this immediately restores real paid value on C/E for near-zero cost.
- B5 (One-tap 痛罵 + Pro-style preview on the user's own text): Solves the free-Vent relief paradox (free 發洩 already vents 80% of anger) by letting a Taiwan user feel 痛罵 + 台劇腔 on their actual situation once before hitting the paywall.
- A3 + A5 + A4 + A1 (Output quality on A/D and cloud): Stopping OS 27 Pro-style refusals (A3, once its two design bugs below are fixed), removing Simplified character leakage and 不是X，是Y templates on-device (A5), fixing the reversed Argument Simulator prompt (A4, Shared/AI/PromptBuilder.swift:415-420, VERIFIED), and giving 硬核回擊 real punch in the Worker (A1, cloud-worker/src/style_voice.js:169-174, VERIFIED) directly improve paid output.
- A7 + B3 + A8: Retiring broken Classic Echoes (B3), fixing false privacy strings (A7, expanded per §2/§3), and shipping the 幫你罵 home-screen name + zh-Hant samples (A8, once the sample-tap bug below is fixed).

Wasted or premature effort (cut or defer):
- B1 (Cloud sendable for Pro on C/E, ~1 week M-L + 1.8.1 binary): Biggest engineering item, widest 5.1.2(i) surface, incomplete across Explore tools/Threads as written, and built for an unmeasured C/E payer base while total traffic is ~3 downloads/week (1 TW download in 3 weeks). Defer until distribution proves demand.
- B6 (Worker od: true|false telemetry): At ~3 installs/week, daily KV buckets take months to be statistically meaningful while creating Privacy Policy / Privacy Manifest compliance work.
- B4 (Japanese voice/preamble work): 0 payers in Japan and no native reviewer. Keep factual string parity only; cut voice engineering.
- Rushing A1 before 11-04 for the 1 US subscriber (docs/DEV_PLAN_v1.8_2026-11.md:308-310, VERIFIED): A1 is fine to ship because it takes half a day, but optimizing deadlines around 1 US user whose style usage is unknown is noise.


(2) ANYTHING FALSE IN THE PLAN

1. Out-of-bounds citation for lane.js: docs/DEV_PLAN_v1.8_2026-11.md:171 (VERIFIED) cites cloud-worker/src/lane.js:52-60. That file is only 55 lines long (cloud-worker/src/lane.js:1-55, VERIFIED); the tokenless free-lane fallback block is lines 46-54 (VERIFIED).

2. "Whether this account holds the [PCC] entitlement is UNVERIFIED": Claimed at docs/DEV_PLAN_v1.8_2026-11.md:173-174, 723, and 851 (VERIFIED). Repo eval log evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md:4 (VERIFIED) explicitly records "PCC (the just-granted Private Cloud Compute entitlement)". What is missing is the key in RoastMate/RoastMate.entitlements:1-24 (VERIFIED). (Cutting PCC in §5 remains right because PCC does not run on C/E devices.)

3. Echoes false privacy copy claimed to exist only in zh-Hans / en: docs/DEV_PLAN_v1.8_2026-11.md:184 and :466-472 (VERIFIED) state the false "Casual stays on-device" copy is live in zh-Hans (and en). In fact, settings.echoes_feral_cloud.footer makes the exact same false claim in Shared/zh-Hant.lproj/Localizable.strings:566 and Shared/ja.lproj/Localizable.strings:567 (VERIFIED), and RoastMateTests/StoreCopyTests.swift:285-291 (VERIFIED) requires those keys in all 4 locales. Worse, A7 misses echoes.consent.title (:562), echoes.consent.allow (:565), echoes.consent.deny (:566, "只用本机生成" / "Stay on-device" — false in Roommate Group, where denying dismisses without generating at RoastMate/Sources/Features/Echoes/EchoesView.swift:78-80 and EchoesViewModel.swift:98-118, VERIFIED), echoes.consent.body naming retired Groq (Shared/zh-Hans.lproj/Localizable.strings:563, cloud-worker/wrangler.toml:34-36, VERIFIED), and settings.echoes_feral_cloud (:570) still claiming it only governs "Feral" when Shared/AI/EchoesEngine.swift:215-217 (VERIFIED) requires feralCloudGranted for BOTH Casual and Feral in Roommate Group.

4. A8 Watch and extension display-name assumptions: docs/DEV_PLAN_v1.8_2026-11.md:488-496 (VERIFIED) gates A8 on checking "the Watch and extension names too" after adding InfoPlist.strings.
- RoastMateWatch is NOT embedded in any shipped app bundle (project.yml:82-102, VERIFIED: "never been embedded here, so it is in no shipped bundle").
- RoastMateMac/Info.plist:1-25 (VERIFIED) lacks both CFBundleLocalizations and LSHasLocalizedDisplayName, so macOS ignores InfoPlist.strings.
- RoastMateShare/Info.plist:7-8 and RoastMateControls/Info.plist:7-8 (VERIFIED, GENERATE_INFOPLIST_FILE: NO at project.yml:189, 215, VERIFIED) hardcode CFBundleDisplayName = RoastMate and carry no CFBundleLocalizations array.

5. Impossible unit-test targets in A4 (and B5): docs/DEV_PLAN_v1.8_2026-11.md:402-403 (VERIFIED) requires a "Unit test on ArgumentSimulatorViewModel" in RoastMateTests (and :642 requires one for B5). project.yml:225-241 (VERIFIED) documents that RoastMateTests is a hostless bundle compiling only Shared/ — "App-target types are NOT reachable... view models, views... cannot be tested here at all." ArgumentSimulatorViewModel lives in RoastMate/Sources/Features/ArgumentSimulator/ArgumentSimulatorViewModel.swift (VERIFIED).

6. A3 session-cache and batched threat-judge assumptions contradict live code:
- docs/DEV_PLAN_v1.8_2026-11.md:365-367 (VERIFIED) adds guardrails to AppleFMBackend.respondCached (Shared/AI/AppleFMBackend.swift:32-45, VERIFIED) to retry once with permissiveContentTransformations after a default refusal. Because Shared/AI/RoastEngine.swift:305 (VERIFIED) omits guardrails from sessionKey and respondCached (:40) reuses self.session when keepSession == true and sessionKey == key, multi-turn Simulator (ArgumentSimulatorViewModel.swift:148, VERIFIED) will reuse the cached .default session and refuse again unless guardrails invalidates/partitions the cached session.
- docs/DEV_PLAN_v1.8_2026-11.md:372 (VERIFIED) batches 3 variants into one call to RoastEngine.threatJudgeInstructions (Shared/AI/RoastEngine.swift:549-552, 584-600, VERIFIED). That judge uses maxTokens: 4, expects one singular message ("You check a message before it is sent"), and hardcodes POV ("The writer is 'I'; the reader is 'you'"), which misjudges multi-variant numbered lists and opponent-POV Argument Simulator turns.

7. B1 omits Explore sendable tools and Thread context while claiming Pro sendable styles work on C/E: docs/DEV_PLAN_v1.8_2026-11.md:573-590 (VERIFIED) omits RoastMate/Sources/Features/Shared/FeatureGenerator.swift:134-174, 285-294 (VERIFIED), which drives Reply Helper, Emotion Translator, and Social Roast (all promised 3 Pro variants in metadata/zh-Hant/description.txt:35, VERIFIED). Even on RoastGenerator, Shared/AI/RoastEngine.swift:262-270, 670-691 (VERIFIED) hardcodes mode: "roast", drops .reply/.translate/.social (unsupported in cloud-worker/src/index.js:671-675, VERIFIED), and drops priorContext from Thread continuations (RoastGeneratorViewModel.swift:174, VERIFIED).


(3) APP REVIEW / PRIVACY (5.1.2(i), 2.3.x, 3.1.x) AND COST/RELIABILITY RISKS MISSED

- 5.1.2(i) — Public Privacy Policy (docs/site/privacy.html) is already inaccurate and contradicts B1 and B6:
  - docs/site/privacy.html:28 (VERIFIED) states "Calm / Sharp / Savage / Make-it-sendable rewrite — 100% on-device via Apple's Foundation Models, always." B1 never updates docs/site/privacy.html or metadata/*/description.txt (metadata/zh-Hant/description.txt:7, 40, 50, VERIFIED).
  - docs/site/privacy.html:26, 36, 51, 58 (VERIFIED) still names retired Groq, omits live Roommate Group (mode=roommate), repeats the v1.7-banned lie that disabling Cloud AI produces "a (gentler) Vent draft using Apple's on-device model" (:51), and enumerates exact wire fields (:37-43) + "no device fingerprinting" (:58), which B6's od: true|false capability flag violates unless disclosed there and checked against RoastMate/PrivacyInfo.xcprivacy:9-10 (VERIFIED).
  - OpenRouter upstream sub-provider retention: cloud-worker/src/index.js:569-578 (VERIFIED) sends prompts to OpenRouter (qwen/qwen3-235b-a22b-2507, z-ai/glm-4.5-air in cloud-worker/wrangler.toml:38-39, VERIFIED) WITHOUT provider: { data_collection: "deny" }, allowing OpenRouter sub-providers that log/train by default, while neither consent sheet nor privacy.html names Qwen/Z.ai or downstream sub-processors.
  - FeatureGenerator consent trap: If B1 changes CloudPermission.resolve without updating FeatureGenerator.swift:139-142, 285-294 (VERIFIED), Explore tools will present the Vent CloudConsentSheet (which promises Calm/Sharp/Savage stay on-device) before sending sendable text to cloud.

- 2.3.1 / 2.3.3 — StoreKit purchase sheet and macOS screenshots:
  - Apple's native StoreKit payment sheet still reads ASC's subscription localization "Unlimited generations" / "無限生成 + 全部風格" (RoastMate/Configuration.storekit:151-248, docs/HANDOFF_v1.7_NEXT_SESSION.md:53-56, VERIFIED) while the Worker enforces PRO_DAILY_LIMIT = 200 (cloud-worker/wrangler.toml:26, VERIFIED). Make editing ASC subscription descriptions a hard pre-1.8.0 submit gate, not an undated §6 note.
  - macOS App Store screenshots are still May-era Simplified Chinese with Debug=Pro (docs/HANDOFF_v1.7_NEXT_SESSION.md:76, VERIFIED) — a live 2.3.1/2.3.3 rejection risk when submitting 1.8.0 for macOS.

- 3.1.2(a)/(c) — Trial price hierarchy and eligibility race in A6:
  - Guideline 3.1.2(c) requires the billed recurring amount (NT$690/year) to be the most clear and conspicuous price; "7 天免費試用" must be visually subordinate.
  - PaywallView.swift:305-342 (VERIFIED) triggers buy(product) immediately on row tap and currently does not gate trial copy on async product.subscription?.isEligibleForIntroOffer. Showing "7 天免費試用" to an ineligible lapsed subscriber (such as the lapsed TW buyer) before StoreKit charges Day 0 risks 3.1.2 rejection and instant refund.

- Reliability / silent Pro lockout / cost availability risks:
  - B1 403 + optimistic Pro lockout: Shared/Services/StoreService.swift:23-24, 243-249 (VERIFIED) grants 90-day optimistic Pro from CloudKit before local JWS resolves, Shared/Services/CloudVentClient.swift:62-79 (VERIFIED) falls through to tokenless requests when proSessionToken() is nil, and CloudVentClient.swift:167-180 (VERIFIED) invalidates tokens only on 401, not 403. Under B1, Worker returns 403 on tokenless mode:"roast", silently stranding a paying subscriber on curated lines with the misleading .cloudFailed ("try again in a moment") banner (Shared/AI/RoastEngine.swift:83-95, VERIFIED).
  - A8 Pro-sample error-box bug: RoastGeneratorView.swift:487-495 and RoastGeneratorViewModel.swift:332-345 (VERIFIED) let a free user load a Pro-style sample, but generateButton (RoastGeneratorView.swift:290, VERIFIED) checks only selectedIntensity.requiresPro, NOT style.tier == .pro — hitting RoastGeneratorViewModel.swift:105-108 (VERIFIED) and rendering an orange error banner instead of PaywallView (same bug in FeatureGenerator.swift:114-116, 372, VERIFIED). Putting Pro-style zh-Hant samples first in A8 breaks first-run UX in Taiwan.
  - $9.88 OpenRouter balance cap with auto-top-up OFF (docs/DEV_PLAN_v1.8_2026-11.md:725, docs/HANDOFF_v1.7_NEXT_SESSION.md:114-120, VERIFIED): Protects developer wallet, but is a single point of total cloud outage for paying Pro users if free-lane traffic or a balance dip exhausts $9.88. Separate Pro API key/budget or low-balance alert is needed.


(4) WHAT IS MISSING THAT WOULD MOST HELP KEEP OR WIN PAYERS

1. Taiwan-native distribution (0 posts published to date): 1 download in Taiwan in 3 weeks means code changes alone cannot win payers. P2.1 must run now, localized for Taiwan's actual channels (Threads, Instagram Reels/carousels, Dcard, PTT — not 小红书/Reddit).
2. Lifetime Pro / one-time unlock (wrongly deferred in B8 until 2027-01-31): RoastMate is an episodic anger utility (1-2 incidents/month), proved by the TW Day-0 cancel and 24 free generations in week 1. Deferring a NT$490-590 ($14.99-$19.99) Lifetime Pro non-consumable solely to keep SUBSCRIPTION_EVENT clean (docs/DEV_PLAN_v1.8_2026-11.md:677-686, VERIFIED) sacrifices the best-fit Taiwan monetization model for metric hygiene. Track paid_conversions = subscription_starts + lifetime_unlocks.
3. Cloud "改成能發的" (Make-it-sendable rewrite) for Pro on C/E (wrongly cut in §5, :701): On C/E, 痛罵 is the hero paid feature, and every 痛罵 card prompts the user to tap "改成能發的" (Shared/zh-Hant.lproj/Localizable.strings:440-441, VERIFIED). Today, when a paying C/E user taps it under their paid 痛罵 draft, Shared/AI/RoastEngine.swift:481-483, 603-608 (VERIFIED) returns a random canned line unrelated to their vent. Routing Pro C/E rewrites through the Worker (1 small endpoint/mode, reusing Vent cloud consent with updated disclosure) completes the core "先罵爽，再說人話" loop for ~20% of B1's cost and risk.
4. Fix the Pro-style sample -> orange error banner bug in RoastGeneratorView.swift:290 and FeatureGenerator.swift:372 so Generate opens PaywallView (or triggers B5 preview) instead of throwing quota.exhausted.body.


(5) IS THE SEQUENCING AND RELATION TO THE 11-15 STOP RULE SOUND?

No. docs/DEV_PLAN_v1.7_2026-10.md:273-275 (VERIFIED) created the 11-15 / T+4w stop rule explicitly because "v1.3 through v1.6 each found a reason to keep building, and this rule exists so v1.7 cannot." Yet on 10-27 — with 0 distribution posts shipped (T unstarted) and 19 days until 11-15 — v1.8 pre-approves 14-17 agent-days across two binaries (1.8.0 on 11-12, 1.8.1 on 12-03), declares that 11-15 "doesn't change this plan's scope" (docs/DEV_PLAN_v1.8_2026-11.md:705, VERIFIED), and pushes the verdict to 2027-01-31 (§2.3). That bypasses the stop rule.
Additionally, §2.3's 2027-01-31 gate (≥3 starts = SUCCESS, 0 = PIVOT) lacks a minimum traffic denominator: without shipping distribution, ~3 downloads/week yields noisy zeros regardless of product quality.

Sound sequencing:
- Ship A1 + corrected 1.8.0 BEFORE 11-15.
- Start Taiwan distribution (Threads/IG/Dcard, ≥20-30 posts) immediately alongside 1.8.0.
- Hard-gate ANY 1.8.1 work on the stop rule at T+4w (with T starting no later than 11-15): if 30 TW posts + 1.8.0 produce <2 trial/paid starts, stop building features.


(6) VERDICT: SHIP-WITH-CHANGES

1. Scope 1.8.0 to the high-leverage fixes and ship before 11-15: Keep A1, A2, A3, A4, A5, A6, A7, A8, B3, B5. Cut B4 (beyond string accuracy) and B6; freeze 1.8.1 (B1) behind the T+4w distribution gate.
2. Replace B1 in near-term scope with Pro C/E cloud "改成能發的" rewrite (completing the paid 痛罵 -> sendable reply loop on C/E without B1's multi-surface sendable sprawl), and pull B8 (Lifetime Pro non-consumable, ~NT$490-590) INTO 1.8.0 instead of deferring to 2027-01.
3. Fix the two A3 bugs before coding: include guardrails in AppleFMBackend session caching (AppleFMBackend.swift:40, RoastEngine.swift:305) so keepSession retries don't reuse .default sessions, and run threat screening per-variant with POV-neutral wording instead of batching 3 variants into maxTokens: 4 (RoastEngine.swift:549-552, 584-591).
4. Fix A8 + sample-tap bugs: check !isPro && style.tier == .pro in RoastGeneratorView.swift:290 and FeatureGenerator.swift:372 (open PaywallView instead of erroring); add CFBundleLocalizations + LSHasLocalizedDisplayName to RoastMateMac/Info.plist and CFBundleLocalizations to RoastMateShare/Info.plist & RoastMateControls/Info.plist; drop the nonexistent Watch check.
5. Move A4/B5 testable state machines into Shared/ (or cover in RoastMateUITests), since RoastMateTests cannot import RoastMate/Sources/ (project.yml:236-241).
6. Close all 5.1.2(i) / 2.3.x / 3.1.2 gaps BEFORE 1.8.0 submission:
   - Update docs/site/privacy.html (remove Groq and the false "gentler on-device Vent" claim, disclose Roommate Group + OpenRouter model providers, and add provider: { data_collection: "deny" } in cloud-worker/src/index.js:569-578).
   - Fix ALL Echoes/Roommate consent & Settings strings across all 4 locales (including echoes.consent.title/allow/deny, Groq removal, and settings.echoes_feral_cloud label once Classic Echoes is retired).
   - Gate A6's trial badge strictly on async isEligibleForIntroOffer == true and keep NT$690/year visually primary per 3.1.2(c).
   - Make editing ASC Subscription Display Name/Description (removing "Unlimited generations" / "無限生成") and replacing May-era Simplified macOS screenshots hard pre-submit blockers for 1.8.0.
7. Protect Pro cloud availability: add a low-balance alert or dedicated OpenRouter key/reserve for authenticated Pro traffic so free-lane usage cannot exhaust the $9.88 cap and drop subscribers onto curated fallbacks.
