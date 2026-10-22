

######## synthesis

RoastMate: why payers leave and what to fix first (synthesis, 2026-10-22)

**中文摘要**
- 「這兩天很多人退訂」大部分不是 RoastMate。10-16 到 10-21 整個開發者帳號有 3 筆流失：RoastMate 只有 1 筆（台灣那位），另外 2 筆是 ColorArchive。RoastMate 沒有任何退款；美國那位仍在訂閱，約 11-04 續訂。
- 台灣那位在 09-19 購買的當天就關掉了自動續訂，比 Vent 改成免費（09-27）早 8 天。所以「Vent 變免費」不是他退訂的原因。原因要嘛是第一次使用就失望，要嘛是「買完就關續訂」的習慣，數據分不出是哪一個。
- 先修這三件：
  1. Worker 的繁中罵法是大陸口吻：29 則繁中回覆有 27 則帶「老子／傻逼／服了」這類大陸用語，台灣用語 0 則。改 Worker 不用送審。
  2. iOS 27 上，Apple 模型一拒絕，App 就顯示錯誤，而不是預設範例（已在 macOS 27 實測）。
  3. 「改成能發的」對真實發洩稿 6/6 被拒；改用 permissiveContentTransformations 之後 6/6 成功（今天實測）。
- 需要你決定兩件事：要不要讓 16 種 Pro 風格影響「痛罵／發洩」；要不要為沒有 Apple Intelligence 的手機開雲端 sendable（只能用新開關加新同意書，`cloud_sendable_enabled` 永遠不能開）。價格先不動。
- 這次只做了分析。沒有推送、沒有部署 Worker、沒有改 repo、沒有寫 App Store Connect。

---

## 0. Two corrections to the premise (measured; I re-checked the raw files)

**"Many unsubscribed these two days."** The vendor-wide SUBSCRIPTION_EVENT reports for 10-16..10-21 show three losses:

| date | app | event | country | days before canceling |
|---|---|---|---|---|
| 10-16 | ColorArchive | Cancel | AU | 12 |
| 10-20 | RoastMate | Cancel | TW | 0 |
| 10-21 | ColorArchive | Refund | LV | – |

- Source files: `scratchpad/churn/data/sales/subevent_2026-10-16/19/20.tsv`.
- RoastMate has 0 refunds.
- The US subscriber is active in the 10-20 snapshot ($2.99, no billing retry).

**The TW payer decided on day 0.**
- The Sales row has Days Before Canceling = 0. Apple's definition: https://developer.apple.com/help/app-store-connect/reference/subscription-event-report/
- The Retention Messaging report shows, on 2026-09-19: Cancel Sheet page view 1, Cancels 1, iPhone, iOS 27.0, TW (`data/r320.tsv`). The purchase was the same day on the same device (r12, NT$90).
- So the decision was made on v1.5.0, 8 days before v1.6.0 made Vent free.

**Date fix.** iOS 1.7.0 went live 2026-10-14T23:38Z (https://itunes.apple.com/lookup?id=6769317103&country=tw), not around 10-20.

**What this implies:**
- Only 2 people have ever paid. One has lapsed, one is active. Keeping payers really means fixing the first session for future buyers.
- Taiwan had 0 first-time downloads in October (r3). The v1.7 stop rule (DEV_PLAN_v1.7 §7, read 11-15) still applies.

## 1. Why payers leave (ranked)

**1. The first session on the buyer's own device does not deliver what the paywall sold.**
Evidence: the mechanism is measured. That it caused the TW cancel is a guess; a reflexive cancel-after-buying fits the data equally well.
- **Static paywall header.** It reads 「痛罵 · 狠 · 全部 24 種風格 · 每則回擊 3 個版本 · 吵架模擬器…」 on every device (PaywallView.swift:77, zh-Hant.lproj:157). Only the Savage row adapts to the device (PaywallView.swift:221-228).
- **Canned output on phones without Apple's model.** Every sendable generation returns the same 5 lines per language and ignores style and input (FallbackRoasts.swift:7-13, 53-62).
- **Styles are ignored in Vent/Feral on every device** (cloud-worker/src/index.js:655, PromptBuilder.swift:72).
- **New users start on the wrong mode.** The default is 銳利 (RoastGeneratorViewModel.swift:20, 309), and 發洩 is the 5th chip (Intensity.swift:15-22). The first taps on a phone without the model are canned.
- **On iOS/macOS 27 with Apple Intelligence, refusals show as errors.**
  - AppleFMBackend.swift:69-72 catches only `GenerationError`.
  - The new `LanguageModelError` type exists in SDK 27 (FoundationModels swiftinterface:1527), and nothing in the repo references it.
  - Measured on macOS 27.0.1. iPhone behaviour is UNVERIFIED.
- **The TW payer's actual day 0 was on v1.5.0.** Lens 4 checked tag v1.5.0: on-device prompts told zh_TW to reply in 简体中文, and calendar=roc phones got a Worker 400 and then canned text. Both are fixed now. Their device class is unknown.

**2. An occasional-use product sold as a monthly subscription.** Evidence: inferred.
- The free tier gives about 24 real generations in week 1 (CreditCatalog.swift:29, 34, 38). The free history cap is 30 (HistoryService.swift:95-96). A user who opens the app a few times a month never reaches a Pro limit in month 1.
- All cloud use combined (app, web demo and dev calls) is about 5–12 generations a day. That comes from OpenRouter spend of $0.0347 → $0.0650 between 09-24 and 10-22, divided by the plan's ~$0.00013 per generation.
- Neither payer's device shows an app update after download (r3). What that means is UNVERIFIED.

**3. Taiwan-voice and output defects in Vent (the free hero feature) and Feral (the one Pro benefit that works on every device).**
Evidence: the defects are measured; their effect on churn is a guess.
- **Mainland slang.** My recount of the three lenses' samples: 27/29 zh-Hant replies contain mainland markers (老子、傻逼、服了、裝什麼裝、特麼). 0/29 contain a Taiwan-specific term; 幹 is not counted because the prompt already lists it.
- **The prompt asks for these words.** The Hant word lists are at index.js:676-677. The shared rules sent to every locale carry Simplified mainland examples at index.js:619, 633 and 645.
- **Simplified characters** appear in roughly 6/29 replies (lens 2 hand-checked 5/14; lens 4 found 1/10; lens 1 0/5). The 09-03 baselines were 6/16, so this is long-standing, not a regression.
- **Other defects:**
  - English words inside Chinese replies: 3/14.
  - Literal markdown asterisks in en replies: 3/6.
  - en vent replies of 99–113 words, although the prompt asks for 1–3 sentences.
  - The prompt's word list printed into the reply (en and ja): 2/12.
  - ja replies using a male 俺 voice for female users: 5/6.
- **The scores need a native reader.** The 2.79/5 zh-Hant score came from one non-native judge.
- **Reliability is fine:** 34/34 HTTP 200, mean latency 4.8 s.

**4. Vent became free.** Measured: this did not cause the TW churn. For future buyers it may still weaken Pro's appeal (inferred). Pro now leads with Feral and Savage, and Savage is hollow on most phones.

**5. Buying gives no confirmation.** Verified in code:
- PaywallView never reads `store.isPro`.
- Purchase errors are swallowed by `try? await store.purchase` (PaywallView.swift:262).
- The buy buttons and 「繼續免費使用」 stay on screen after purchase.

## 2. What to fix first (ranked; A = just do, B = needs your decision, C = pricing)

Order of work: #1 this week (Worker only, no review). Then one binary, 1.7.1, carrying #2–#5. Decide #6 now, and #7 after measurement.

**#1 (A) Worker: Taiwan voice and output cleanup.** No binary.
- **What to change** in cloud-worker/src/index.js:
  - Rewrite the Hant word lists (676-677) in Taiwanese register: 幹、靠北、三小、白目、北七、機車、很盤. Ban 老子、傻逼、特麼、服了、裝什麼裝、卧槽 for Hant.
  - Split the shared rule examples (619, 633, 645) by script. The en prompt gets English words only (this fixes the "Uru-see" leak).
  - Replace ja's "must use N words / zero = task failed" quota (686). It causes the word-list dump.
  - Add a ja rule to match the user's own first-person pronoun.
  - After the reasoning strip (around 485-497): strip markdown; detect runs of 3+ Latin letters in zh/ja replies and retry once on the fallback model.
  - Add a timeout (AbortSignal, ~10 s) to the upstream fetch. There is none today, so a hung provider uses the app's whole 25 s (CloudConfig.swift:43).
  - Optional: a Simplified→Traditional character pass for zh-Hant. This reverses the recorded "opencc" cut in DEV_PLAN_v1.7 §6, so test it on the 14 saved samples first.
- **Who:** every Vent/Feral user on every device.
- **Effort:** S for the prompts; M with the post-processing and retry.
- **Risk and cost:** no App Review. A production deploy follows the plan's gate; rollback is the current version, 90d8f1c5. Each retry costs about $0.0001.
- **Gate:** rerun the same 26 inputs (14 zh-Hant, 6 en, 6 ja; about $0.003). Pass if mainland markers ≤ 2/14, Taiwan terms appear in at least half, and there are 0 Simplified characters, 0 markdown and 0 list dumps.
- **Decision:** none, except that the Simplified→Traditional pass reverses a recorded cut.

**#2 (A) iOS/macOS 27 shows errors instead of the labelled fallback.** Binary.
- **What to change:**
  - In AppleFMBackend.swift:66-73, add an `if #available(iOS 27, macOS 27, *)` catch for `LanguageModelError` and map it to `FMBackendError.generation`. Safest: map every non-cancellation error that way, so RoastEngine returns labelled curated text (RoastEngine.swift:282-297, 429-444).
  - Add a unit test that throws a non-`GenerationError` through the backend.
- **Who:** every user (free and Pro) on an AI-capable device running iOS/macOS 27, whenever Apple's model refuses. Refusal rates measured on macOS 27.0.1:
  - Savage with the 硬核回擊 style: zh_TW 5/8, en 7/8
  - zh_TW Sharp: 2/8
  - The rewrite on real drafts: 6/6
- **The US payer** was on iOS 26.6 at purchase, so probably unaffected unless they have upgraded (UNVERIFIED).
- **Effort:** S. **Risk:** low; ordinary review. **Cost:** 0. **Decision:** none. It is an OS-compatibility fix, which the stop rule allows even in maintenance mode.
- **Small fixes to ship in the same binary** (S, no decision):
  - The Japanese vent hard-rail terms already in the working tree.
  - Put the Taiwan crisis lines first for Taiwan users. Today two Hong Kong numbers come first (CrisisResources.swift:42-51). Lens 4 says those tel: links won't dial from Taiwan without +852; UNVERIFIED.
  - Hide the Echoes cloud toggle wherever the Echoes tile is hidden (SettingsView.swift:64-73).
  - Change 「正在重試」 to 「請再試一次」; nothing actually retries (zh-Hant.lproj:210).
  - Set the home-screen name to 幫你罵/帮你骂 through InfoPlist.strings (project.yml:48 sets RoastMate for every language).

**#3 (A) On-device quality pass for iOS 27.** Binary.
- **(a) Make it sendable.** Use `SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)` for the rewrite only.
  - Measured today (macOS 27.0.1, production `rewriteAsSendablePrompt`, the same 6 real production drafts): default guardrails refused 6/6; permissive guardrails succeeded 6/6 in 1.8–5.9 s, with no profanity in the output.
  - 3 of the 6 got the point of view wrong (e.g. 「完全忽略你的貢獻」), so tighten the prompt's POV rule as well.
  - Evidence: `scratchpad/churn/fmperm/perm_rewrite.txt`.
  - This flow is exactly what the first planned Threads post demonstrates (DEV_PLAN_v1.7 §4, P2.1).
- **(b) Sharp/Composed in zh-Hant.** Replace the single 凌晨兩點/物管 example (PromptBuilder.swift:322, 328, 388, 404) with 2–3 different situations. On macOS 27, 6/6 zh_TW Sharp outputs copied it into unrelated situations.
- **(c) Savage and 硬核回擊.** Retune against the iOS 27 model. Gate: refusals ≤ 1/8 per locale.
- **Who:** users on Apple Intelligence devices, the only ones for whom Savage, styles, 3 versions and the simulator are real.
- **Effort:** M. **Risk:** no change to where data goes, and output still passes SafetyFilter. **Decision:** none.

**#4 (A) Honest paywall, and a real after-purchase state.** Binary.
- **What to change:**
  - Make `paywall.body` depend on the device. Without the model, lead with 痛罵 · 發洩不扣點數 · 無限歷史, and say that styles, 3 versions and the simulator need Apple Intelligence.
  - Remove the invented claim 「僅在配得上的風格中開放」 (zh-Hant.lproj:159) in all 4 locales.
  - After purchase: react to `isPro`, dismiss the paywall, select the chip the user tapped, show one device-honest "here is what you now have" screen, and show purchase errors.
  - Also fix the App Store Connect product text 「無限生成 + 全部風格」 and the zh-Hant names 月度/年度 (from lens 4's read-only query). That is an App Store Connect write.
- **Who:** every buyer, most of all on phones without Apple Intelligence (their share in Taiwan is UNVERIFIED).
- **Effort:** S. **Risk:** lowers exposure under 2.3.1 and 3.1.2 (https://developer.apple.com/app-store/review/guidelines/#subscriptions). It may lower conversion on those phones. That is the intent: a day-0 cancel is a lost subscriber anyway.
- **Decision:** none. Plan §8 already requires copy that is true on every device.

**#5 (A) First session on phones without the on-device model.** Binary.
- **What to change:**
  - When `!isOnDeviceModelAvailable`, default to 發洩 and put it first in the chip row.
  - In 發洩/痛罵, grey out the style row with 「風格只套用在可發送的版本」, and stop a style chip from opening the paywall (RoastGeneratorView.swift:253-277). Skip this if #6 is approved.
  - Give the curated banner a reason (zh-Hant.lproj:212): either 「需要 Apple Intelligence（iPhone 15 Pro 以上，語言設為繁體中文）」 or 「雲端已關閉 → 設定」. Hide 不扣額度 for Pro users. Traditional Chinese Apple Intelligence has existed since iOS 26.1: https://9to5mac.com/2025/11/11/ios-26-1-brings-apple-intelligence-to-these-eight-new-languages/ and https://support.apple.com/en-us/121115
  - Free users who tap the Pro-style sample get an error box instead of the paywall (lens 4: RoastGeneratorView.swift:487, RoastGeneratorViewModel.swift:306-308). Filter it out or show the paywall.
- **Who:** every new install on such a phone; this is the moment both payers converted.
- **Effort:** S–M. **Risk:** low. **Decision:** none. The value is inferred.

**#6 (B) Let Pro styles shape Feral/Vent.** Worker first, binary later.
- **What it changes:** reverse "Intensity overrides Style for private drafts" (index.js:655, PromptBuilder.swift:72). Keep the anger, but let the style set the voice: 台劇腔 = melodramatic, 冷處理 = two cold sentences.
  - The Worker already receives the style's display name on vent requests (RoastEngine.swift:505-510).
  - The next binary should also send `styleId`; `CloudVentRequest` already has the field (CloudVentClient.swift:97).
  - Swap the market-mismatched Pro styles (京片兒, 豆瓣, Shakespeare, Reddit) for 2–3 Taiwan styles (鄉民/PTT 推文體, 台式長輩).
- **Why:** on phones without the model, Feral is the only real Pro generator, and 16 of the 24 styles do nothing there today. This gives Pro a difference users feel on every use, with no new data flow and no consent change.
- **Effort:** M (about $0.01 of evaluation). **Risk:** low.
- **Decision:** yes. It reverses a deliberate design and changes what Pro is.

**#7 (B) Real sendable modes on phones without the on-device model.** My recommendation: decide after 2 weeks of the device-mix count in §3, not now.
- **What would change:** on those phones, Composed/Sharp/Savage, the styles, 3 versions and the argument simulator would use the Worker's existing `mode:"roast"` path (index.js:237; the client side, runCloudRoast, is in RoastEngine.swift) instead of 5 canned lines. Text from those modes would leave the device (Worker → OpenRouter → model provider) for users who consent.
- **Why the old rule exists:** every shipped consent sheet says "Composed, Sharp, and Savage always run on-device and never use cloud" (en.lproj:133), and old installs read the same global flag (see the note in the live roastmate-config.json). So `cloud_sendable_enabled` must stay false.
- **The only compliant route** is a new remote-config key that only new binaries read, plus:
  - a new consent version that names the sendable modes and the provider
  - rewritten onboarding.privacy.body, settings.about_ai.body and cloud.consent.footnote in all 4 locales (en.lproj:20, 133, 136)
  - matching product-page copy
  - a review of the App Privacy answers
  - an extended CI guard
  - its own kill switch
- **Cost:** about $0.0004 per tap (3 variants). Under $1/month at today's volume. The real constraint is the $10 hard cap with auto top-up off: at $0, every cloud generation becomes canned.
- **Risk:** guideline 5.1.2(i) requires explicit permission before sending personal data to a third-party AI (https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage). The quality of `mode:"roast"` output in zh-Hant is UNMEASURED.
- **Effort:** M–L. If you build it, make it Pro-only first.

**#8 (C) Pricing and packaging: keep prices, make small changes only.**
- **No price change.** Two payers cannot test one. The day-0 cancel weakens the plan's earlier "monthly works" argument, but it does not point in any specific direction.
- **Do not add a trial to Monthly.** The TW buyer paid NT$90 and turned off renewal; a trial would have turned that into $0 (inference).
- **Rewrite what Pro means once #4 and #6 land:** 痛罵 on every device · 發洩不限次數 · 風格套用在痛罵 · 無限歷史 · on Apple Intelligence phones, 狠 + 3 versions + the simulator.
- **Optional:**
  - A lifetime Pro purchase, which fits occasional use. The cloud cost per user is tiny.
  - A win-back offer for the lapsed TW user: https://developer.apple.com/help/app-store-connect/manage-subscriptions/set-up-win-back-offers/. It is a courtesy, not an experiment, with one person.
  - Both are App Store Connect writes and your call.
  - Credit packs are already on the paywall (PaywallView.swift:38).

## 3. What to measure next

1. **Your 5-minute check, with the App Store build.** On an iOS 27 iPhone with Apple Intelligence in 繁體中文:
   - Pick 狠 with 硬核回擊 on any situation.
   - Then tap 改成能發的 on a 痛罵 draft.
   - Two error messages confirm #2 on iPhone. A simulator cannot test this.
2. **A fixed regression set, run on every Worker change and every OS release.**
   - Cloud: the 34 saved inputs (`cloud_samples.json`, `sample_cloud.py`, `analyze.py`; about $0.004 per run). Score mainland vs Taiwan markers, Simplified characters, Latin runs, markdown, list dumps and length.
   - On-device: the probes in `fmprobe/` and `fmperm/`. Score the refusal rate and how often the calibration example leaks into output.
3. **One native Taiwanese reader**, blind, rating the 14 zh-Hant samples before and after #1.
4. **Device mix and outcomes at the Worker, aggregate only.** Your decision: it reverses plan §6's cut of server counters.
   - Per day, count requests by mode, intensity, locale group and outcome (ok, 5xx, timeout, hard rail, fallback model).
   - From the next binary, add a true/false "on-device model available" field to each request.
   - No device ID, no text, 90-day retention.
   - Leave out the free/Pro split: with one Pro user, it would show that one person's usage.
   - Check whether this changes the App Privacy answers (UNVERIFIED).
   - The share of Vent requests from phones without the model is the number that decides #7.
5. **The app's opt-in, local-only log.** Record cloud failures as `.network` (that category has no call site today) and log the iOS 27 error types separately. This mainly helps your own device testing.
6. **App Store Connect reads.**
   - Around 11-04/05: the SUBSCRIPTION_EVENT report for the US renewal (check Days Before Canceling). Filter to App Apple ID 6769317103 so ColorArchive doesn't mix in.
   - Weekly first-time downloads for the 11-15 stop rule. Start the 1.7.0 window at 10-15.
7. **OpenRouter balance weekly.** $9.94 was left today, per lens 3.

Not worth waiting for: Apple's session, crash and deletion reports are not generated below 5 contributing users, and all show 0 instances today (https://developer.apple.com/documentation/analytics-reports/privacy).

## UNVERIFIED / open
- Whether an iPhone on iOS 27 behaves like macOS 27.0.1 (error type and refusal rates).
- Whether apps built with SDK 26 also get the new error type on iOS 27. That decides whether the TW payer (iOS 27.0, v1.5.0) could have seen errors on day 0.
- The device class of both payers, and the share of Taiwan installs with Apple Intelligence.
- Whether the US payer has already turned off renewal. Sales reports show a voluntary cancel only at the end of the period.
- Whether Taiwanese users actually mind mainland slang. The prior is strong, but it is untested with a native reader.
- Whether the P2.1 community posts were published. `share_card_enabled` is still false in the live config.
- Datadog log ingestion: the Datadog connection failed this session.
- Lens 4's minor claims that I did not re-check: the effect of Simplified style examples on output, Siri phrases, the language of the sample situations.

**What I re-checked myself:** the App Store Connect cancel and retention rows, the catch clause in AppleFMBackend, the SDK error type, the paywall and zh-Hant strings, the Worker prompt lines, the consent footnote, the live flags, the crisis-line order, the slang recount, and the permissive-guardrail rewrite probe. Everything else is cited from the lens reports as they verified it.

Files are in /private/tmp/claude-501/-Users-jason-Documents-RoastMate/1d05a9de-aa8a-416a-9d69-7c7fdc5c212f/scratchpad/churn/:
- cloud_samples.json
- calls.jsonl
- worker_probe.jsonl
- data/r320.tsv
- data/sales/subevent_2026-10-19.tsv
- data/sales/subscription_2026-10-20.tsv
- fmprobe/probe_zh_TW_run2.txt
- fmprobe/p2/probe2_default_sharp.txt
- fmperm/perm_rewrite.txt
- fmperm/main.swift

######## challenge

**Verdict: AGREE-WITH-CHANGES.** The diagnosis is mostly right, and its five most important claims hold up when re-checked. The plan gets one causal question wrong: the Taiwan payer did not see the iOS 27 error bug, because that bug only exists in builds from 1.6.0 onward. Its measurement and #7 sections rest on two false premises, and the 1.7.1 binary should be much smaller. Nothing was pushed, deployed, committed or written to App Store Connect. I made 0 Worker calls and two read-only App Store Connect API reads.

## 1. The five key claims, re-checked

1. **Taiwan payer cancelled on day 0: confirmed.**
   - Apple's definition: Days Before Canceling is "the number of days from the start date to when a subscriber canceled" (https://developer.apple.com/help/app-store-connect/reference/subscription-event-report/).
   - The `subevent_2026-10-19.tsv` row shows Cancel, Original Start 2026-09-20, days 0.
   - `r320.tsv` shows a Cancel Sheet view and a cancel on 09-19, from an iPhone on iOS 27.0 in TW.
2. **iOS/macOS 27 refusals show an error instead of the labelled fallback: confirmed, and I found when it started.**
   - The code path:
     - AppleFMBackend.swift:69-72 catches only `GenerationError`.
     - RoastEngine.swift:296-297 and 443-444 turn anything else into `generationFailed`.
     - RoastGeneratorViewModel.swift:199-204 puts that on screen as an error.
   - `LanguageModelError` is in the iPhoneOS27.1 SDK interface at line 1527 (available from iOS 27).
   - I re-ran the probe on macOS 27.0.1 and the error type was `LanguageModelError`.
   - **New finding:** I patched the same binary's load command to say SDK 26.0 (`vtool`, file `scratchpad/churn/review/errtype_sdk26`). It then got `GenerationError` and matched `.guardrailViolation`. So which error comes back depends on the SDK the app was built with.
   - The App Store Connect build records show v1.5.0 (build 21) was built with SDK `23F81a` (26.5) and 1.6.0 (build 22) with `24A430` (27.0). The local archives agree: 1.6.0 and 1.7.0 were built with `iphoneos27.0`.
   - So the error bug arrived with 1.6.0 on 09-27. On iOS 27.0 with v1.5.0, the Taiwan payer would have got the labelled examples, not errors. That answers one of the plan's open UNVERIFIED items, assuming iPhones behave like macOS.
3. **The zh-Hant prompt asks for mainland slang: confirmed.**
   - The word lists are at index.js:676-677. The shared Simplified examples are at 619, 633 and 645.
   - My recount over `cloud_samples.json`, `worker_probe.jsonl` and `calls.jsonl`: 27 of 29 replies contain a mainland term and 0 contain a Taiwanese one.
   - Small fix to the plan: the Japanese "zero swear words = task failed" quota is at line **685** (Feral), not 686.
4. **"Make it sendable" works with permissive guardrails: true, but only half usable.**
   - All 6 rewrites in `fmperm/perm_rewrite.txt` came back without a refusal. But 3 have the point of view wrong, and the English one is third-person narration, not a message anyone could send. That leaves 2–3 of 6 usable.
   - Apple's docs say this mode does not throw for text output; instead "it generates a String refusal message" (https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations). Without a check for refusal text, users could get a refusal shown as their rewrite.
5. **The paywall header is static and buying gives no confirmation: confirmed.**
   - The header is fixed at PaywallView.swift:77 (zh-Hant.lproj:157). Purchase errors are swallowed by `try?` at line 262.
   - No view that presents the paywall closes it when `isPro` changes. The same code was in v1.5.0 at line 253.
   - The 1.7.0 release date of 2026-10-14T23:38:50Z is confirmed by the iTunes lookup.

## 2. Causes and fixes the plan missed

- **What the Taiwan payer most likely saw on day 0 is already fixed.**
  - In v1.5.0, the old Worker's language rule only recognised IDs containing "hant", so a phone sending `zh_TW` was told 「必须用简体中文」 (`git show v1.5.0:cloud-worker/src/index.js`, the language-directive function). The app's own prompts for `zh_TW` also said Simplified (commit d7efd49 message).
  - The v1.5.0 paywall sold 「發洩模式(私密草稿 + 改寫)」, and the rewrite part is exactly what default guardrails refuse.
  - So the remaining fixes should be justified by future buyers, not by this cancellation.
- **Lack of purchase confirmation deserves a higher rank.** A visit to the cancel sheet on the day of purchase fits a buyer checking "did that go through?" as well as it fits a reflexive cancel. Bundle the after-purchase state with #2.
- **The plan's server counters already exist.**
  - Every Worker request already sends intensity, locale, mode, outcome, model, latency and `lane` (pro or free) to Datadog (index.js:403-405 and 415-439; lane values in lane.js:35 and 47).
  - So no new collection or "zero-tracking" reversal is needed. Fix the Datadog connection and read the logs. They can show today whether the one active Pro user has used Feral at all since 10-04.
  - Privacy side effect: `lane=pro` already isolates that one person's usage in the logs.
  - At about 2 installs a week, two more weeks of counts could not settle #7 anyway.
- **#7's premise is wrong.** zh-Hant output from the cloud `mode:"roast"` path was measured and **failed** the earlier quality gate, 20 of 24 (DEV_PLAN_v1.5:15 and 95). The Worker switch for that path is off (`ROAST_MODE_ENABLED`, wrangler.toml:69). Drop #7 rather than deferring the decision.
- **Most recent installs are on OS 27.** 3 of the 4 first-time downloads since 10-15 were on macOS 27.0, iOS 27.0 or macOS 27.2 (`r3.tsv`), including 2 Macs. That makes #2 the biggest first-session problem.
- **Errors also replace the fallback when the cloud fails.** On an Apple Intelligence device running 27, a failed cloud Vent falls through to the on-device model, which refuses (RoastEngine.swift:186-194, then 236-298). The user sees an error, not the labelled example. That includes the moment the OpenRouter balance runs out.
- **Vent replies all start the same way.** 19 of 29 zh-Hant replies open with 他媽的, and 26 contain it. The fixed swear-word quota at 676-677 causes this, and a repeat user will feel it as a template.
- **The English Worker cleanup is the only fix that can reach the active US payer.** `r3.tsv` shows no 1.7.0 update for any US iPhone. Whether they still have the app is UNVERIFIED, but no binary fix can reach them before the ~11-04 renewal.
- **Crisis lines are a safety issue, not a "small fix".** Taiwan phones list two Hong Kong `tel:` numbers first (CrisisResources.swift:42-51). Whether those links fail when dialled from Taiwan is UNVERIFIED.

## 3. Recommendations to change or drop

- **Worker #1:**
  - Drop the Simplified→Traditional converter: it reverses a recorded cut and does nothing about 傻逼 or 老子.
  - A 10 s upstream timeout plus a retry can reach about 20 s against the app's 25 s limit (CloudConfig.swift:43), and roommate replies average 6.4 s. A 10 s cut-off would also stop OpenRouter's own fallback model mid-attempt. Budget the timeout and the retry together.
- **#3(c) Savage retune and #6 styles-shape-Feral:** defer. Each is medium effort and would need re-doing for every Apple model release or redesigning Pro, with one paying user as evidence. Once #2 ships, Savage refusals become labelled examples, which is acceptable for now.
- **1.7.1 scope:** limit it to #2, the after-purchase state, crisis-line order and the Japanese safety terms already in the working tree. Bundling #2 through #5 conflicts with the 11-15 stop rule (DEV_PLAN_v1.7 §7).
- **Reject Gemini's "turn on auto top-up".** The $10 hard cap is deliberate, and the weekly balance check already exists.

## 4. Gemini 3.8 Flash (High), summarised close to verbatim

1. **"Scope creep driven by a phantom churn crisis."** The other unsubscribes were a different app, so the real problem is no new users, not churn. Enforce the stop rule. Kill #3, #6, #7 and the win-back offer, because #7 breaks the privacy promise and would drain the $9.94.
2. **Invert the order: ship the binary before the Worker.** That means closing the paywall on purchase, showing purchase errors, and catching `LanguageModelError`. It guessed the Taiwan buyer left because the paywall hung and the error appeared. The error half is ruled out by the build-SDK finding above, and it also called the error a "crash", which it isn't.
3. **Add a prominent lifetime unlock** (about $9.99 / NT$300) instead of relying on monthly. Turn on auto top-up or add a low-balance alert. I reject the auto top-up part.

Its first ship was a 1.7.1 hotfix with the after-purchase paywall fix and the `LanguageModelError` catch.

## 5. First thing to ship

**#2, the `LanguageModelError` catch in AppleFMBackend.swift:63-73, mapping every non-cancellation error to `FMBackendError.generation`, plus a unit test.** Submit it as a minimal 1.7.1 together with the after-purchase dismiss-and-error fix.

- It is a regression the app introduced with the switch to SDK 27 in 1.6.0.
- It breaks the first session on the OS used by 3 of the 4 recent installs, and on every failed cloud Vent there.
- It is a small change that doesn't change where data goes, and the stop rule allows it as an OS-compatibility fix.

The same week, deploy the Worker prompt cleanup: Taiwanese word lists, varied openers, English length and asterisks, examples split by script. It needs no App Review, and it is the only change that reaches existing installs.

Before submitting, test once with a Release build on a real iOS 27 iPhone. Still UNVERIFIED: iPhone behaviour (only macOS was measured), the payers' device types, and whether Taiwanese users actually mind mainland slang.

Files are in /private/tmp/claude-501/-Users-jason-Documents-RoastMate/1d05a9de-aa8a-416a-9d69-7c7fdc5c212f/scratchpad/churn/review:
- errtype_sdk26
- recount.py