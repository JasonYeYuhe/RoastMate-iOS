# Lens 3 — what Pro should be, and why anyone would keep paying (2026-10-27)

_Copied from the workflow's lens report (JSON) into Markdown for
`docs/DEV_PLAN_v1.8_2026-11.md`. Content unchanged except formatting. Because this
repo is public, a single subscriber's sub-national location and the ASC vendor
number were removed (the vendor number is in `~/Documents/credits.md`). Raw files
stayed in the session scratchpad; they are not in the repo._

## Method

Read-only. ASC reads used `scripts/asc_analytics.py`, the Sales SUBSCRIPTION
reports, the analytics reports r320 (Retention Messaging) and r226 (Subscription
State), and API reads of prices and offers. 2 Gemini calls, 0 Worker calls. Raw
outputs:
`/private/tmp/claude-501/-Users-jason-Documents-RoastMate/1d05a9de-aa8a-416a-9d69-7c7fdc5c212f/scratchpad/v18/lens3/`

## Measured baseline

- Funnel since 09-01: 16 first-time downloads → 2 Pro Monthly + 1 CN credit
  pack. 2/16 = 12.5% download-to-subscriber vs a freemium median of ~2.1% at day
  35 (RevenueCat). n is tiny; the interval is very wide.
- Since 10-04: 0 purchases from 7 downloads; 1 of those 7 is TW, 2 US, 4
  EG/RU/DE.
- The US payer was still an active full-price subscriber in the 10-24 Sales
  snapshot and the 10-25 state report (iPhone).
- No Retention Messaging instance exists after 09-23, so no US cancel-sheet
  visit is recorded (inferred: Apple seems to generate the report only on days
  with events).
- The TW payer saw the cancel sheet on day 0 with "No message".

## What this means for Pro work

- Pro work reaches ~1–3 buyers a month at today's traffic. Changes that work in
  every language reach everyone; Taiwan-only changes reach ~1 install every 3
  weeks.
- Free Gemini (3.8 Flash low, via agy, 2 of 2 calls) did not refuse: it wrote a
  profane zh-Hant vent, then 3 styled LINE-ready rewrites. "Swearing allowed + 3
  versions + styles" is not a moat.
- What Pro can still win on: one tap with no prompt to write; a native Taiwan
  voice; privacy (no account); formats a chatbot doesn't give in one tap (the
  multi-voice group chat, the share card).

## Ranked recommendations (evidence strength in brackets)

1. Show the paid thing on the buyer's own input: one free, labelled 痛罵 +
   Pro-voice preview after the first Vent (the existing consent names 痛罵).
   After purchase, run what they paid for instead of a text alert. [code
   measured; effect inferred]
2. Surface the yearly plan's 7-day free trial (configured in ASC for all 175
   territories; NT$690 ≈ NT$58/month, 36% off). The paywall never mentions it;
   plan order is unsorted. No trial on Monthly. [config measured; effect
   inferred from benchmarks]
3. Fix device-honest copy that now undersells Pro: since 10-22, 15 of 16 Pro
   styles shape 痛罵 on every device in zh-Hant, but the non-AI paywall and success
   text say styles need Apple Intelligence. [measured]
4. Re-position Pro around result quality and format, not "swearing unlocked".
   [measured: Gemini doesn't refuse]
5. Make Echoes / the roommate group visible in zh-Hant (Taiwan voice) — the only
   Pro formats that are cloud-based, work on every device and aren't a
   one-prompt chatbot job. Needs the owner to reverse v1.7 §5. [visibility
   measured; value a guess]
6. Swap 1:1 the Pro styles that don't fit Taiwan via a per-locale shelf
   (京片兒 has no zh-Hant voice; `localesSupported` is never read). [shelf
   measured; benefit a guess]
7. Cancel-sheet message (Retention Messaging API, pre-release, access request)
   and a win-back offer. No binary; Jason's step. [existence measured; effect a
   guess]
8. Rethink credits for incident-driven use: the 70-credit pack costs NT$90, the
   same as Pro Monthly; 160 and 380 packs cost more than 2 and 4 months of Pro.
   Credits never unlock 痛罵. [prices measured; behaviour inferred]
9. Lifetime: decide after 11-15, as the owner chose. [inferred]
10. Before deciding anything about cloud sendable modes, re-run the zh-Hant
    `mode:"roast"` gate against today's Worker. [prior failure measured; current
    quality unknown — lens 2 ran it the same day]
11. Don't invest in unlimited history; threads are already free. [inferred]

## Relation to the stop rule

- The 11-15 rule measures distribution. 7 downloads in 3 weeks (1 TW) means it
  will very likely fire (UNVERIFIED: depends on whether the P2.1 posts happen).
- Pro-quality work cannot change that reading and must not be used to argue
  with it.
- Frame the plan as an owner-approved exception to maintenance mode with its own
  limit (at most 2 binaries, ~4 weeks, at most $2 of OpenRouter evaluation
  spend), with no-code distribution work continuing in parallel.

## Proposed metrics (ASC only; no new collection)

- Leading: cancel-sheet events within 3 days of each new start (r320, and Days
  Before Canceling in the subscription event report); trial starts and
  trial-to-paid; the US renewal around 11-04.
- Success by 2027-01-31: ≥3 new paid starts and ≥1 first renewal among starts
  after the Pro binary.
- Kill by 2027-01-31: ≤1 new paid start, or every new start cancels within 3
  days → return to §7 maintenance.
- Thresholds are a calibration guess; expected volume ~0.3–1.6 payers/month
  (median benchmark vs observed rate).

## Findings

### Framing: Pro work reaches ~1–3 buyers a month; changes that work in every language beat Taiwan-only ones (verified)

- `asc_analytics.py --since 2026-09-01`: 16 first-time downloads (TW 4, CN 3, US
  5, EG 2, RU 1, DE 1). Purchases: Pro Monthly TW 09-19 ($2.23), Credits 10 CN
  09-25 ($0.39), Pro Monthly US 10-04 ($2.54). Subscription events: TW voluntary
  churn 10-19. Impressions 681, page views 61 (TW 32), taps 27. Since 10-04: 7
  downloads, 0 purchases.
- Sales SUBSCRIPTION 2026-10-24 and r226 state through 10-25: US Pro Monthly full
  price, "Active Standard Price Subscriptions 1", iPhone.
- r320 has daily instances only for 09-21..23 (the TW 09-19 "Cancel Sheet / No
  message / Cancels 1" rows); "no event" vs "not generated" is inferred.
- Benchmark: freemium median download-to-paid 2.1–2.2% at day 35
  (https://www.revenuecat.com/blog/growth/hard-paywall-vs-freemium.md,
  https://www.airbridge.io/en/blog/hard-paywall-vs-freemium-2026).
- Files: `asc_since_0901.txt`, `r320.tsv`, `r226.tsv`,
  `sales/subscription_2026-10-24.tsv`.
- **Options:** rank all-language changes first (paywall, preview,
  post-purchase, copy); Taiwan-only content second as an explicit owner bet;
  measure with events ASC already shows at n≈1 (r320 cancel-sheet events per
  start, Days Before Canceling, trial starts/conversions, the US renewal).
- **Risk:** over-reading n=2 either way.

### #1 — Free users never see 痛罵 or a Pro voice on their own text, and after buying nothing runs what they bought (verified)

- **Impact:** highest per buyer, in every language. The TW payer cancelled on day
  0. A free user sees lock icons and a list; after buying, a text alert and back
  where they were — a tapped Pro style is not selected and nothing runs.
- **Evidence:** `RoastGeneratorView.swift:257-277` (locked chip only opens the
  paywall); `PaywallView.swift:88-97` (after purchase `onChange(isPro)` shows an
  alert then closes; no hand-off); existing cloud consent already names 痛罵
  (zh-Hant.lproj:125-129); cost ~$0.00013/generation (DEV_PLAN_v1.7 §0); free
  lane cap 30/day (`wrangler.toml:99`); RevenueCat trial data (correlational:
  https://saastr.com/what-17000-subscription-apps-tell-us-about-free-trial-length-annual-plans-convert-86-better-with-30-day-trials-monthly-tops-out-at-two-weeks-and-ai-apps-hit-a-wall-at-16-days).
- **Options:** (a) after the first successful Vent, once per Apple ID:
  「同一件事，用 痛罵 + 台劇腔／冷處理 會是這樣」 — a real cloud generation on their
  text, labelled as a Pro preview, not saved as a Pro session; flag on the
  CloudKit-synced UserSettings. (b) Post-purchase: remember the intensity/style
  that opened the paywall; on `isPro`, select it and run it on the current
  situation, then show the device-honest list. (c) A pre-rendered sample instead
  of a live preview.
- **Effort:** S–M, one binary, Release verification (Debug is always Pro).
- **Risk:** the preview must stay one-per-account and labelled; must go through
  `CloudPermission` and `SafetyFilter`; slightly weakens "credits never unlock
  capability" (it is a preview, not credits — record it); every string paired in
  4 locales.

### #2 — The yearly 7-day free trial exists in all 175 territories, but the paywall never mentions it; plan order is random (verified)

- **Evidence:** ASC API: `yyh.roastmate.app.pro.yearly` APPROVED, NT$690 /
  US$19.99, introductory FREE_TRIAL ONE_WEEK in 175 territories incl. TWN.
  Monthly NT$90 / $2.99, no introductory, win-back or promotional offers; two
  active offer codes (creator 3-month, research 1-year). `paywall.yearly.trial`
  (all 4 lproj, line 173) has existed since commit 2fdb9e6 and is referenced by
  no Swift file; no Swift code reads `introductoryOffer` or
  `isEligibleForIntroOffer`. Yearly row copy 「Pro 全部功能，一年付一次。」
  (zh-Hant.lproj:172), no saving, no trial. `StoreService.loadProducts` filters
  without sorting. NT$690/12 = NT$57.5/month. RevenueCat: annual AI-app 5–9 day
  trials 23.3% conversion / 19.6% first renewal; annual no-trial 26.6% first
  renewal; monthly no-trial 49.5% first renewal (same saastr URL) → expected
  value of an annual trial start ≈ 0.23 × NT$542 ≈ NT$125 vs NT$71 for a Monthly
  purchase (INFERRED; holds only if trial starts ≈ Monthly buys). Files:
  `asc_subs.txt`, `asc_yearly_intro.txt`.
- **Options:** (a) deterministic order, yearly first; yearly row
  「7 天免費試用 · 之後 NT$690／年（約 NT$58／月）」 from
  `subscription.introductoryOffer`, shown only when `isEligibleForIntroOffer`;
  Monthly stays the no-trial option. (b) Savings without the trial. (c) Leave.
  Do NOT add a trial to Monthly.
- **Effort:** S. **Risk:** some NT$90-now buyers become NT$0-now; unreadable for a
  quarter at n≈1/month; 3.1.2 requires clear trial terms and no trial shown to
  ineligible IDs (use the eligibility API); legal footer already mentions trials
  (zh-Hant.lproj:215).

### #3 — Device-honest copy now undersells Pro (verified)

- **Evidence:** `cloud-worker/src/style_voice.js:1-20` (Pro styles shape
  Vent/Feral; free unchanged). STYLE_VOICES has a zh-Hant line for every Pro
  style except `bjing_taunt` (hans-only, `style_voice.js:140-142`, reason at
  30-33) — 京片兒 does nothing in a Taiwan user's 痛罵, nor in en/ja. The app sends
  styleName and styleId on vent requests (`RoastEngine.swift:653-660, 681-686`).
  zh-Hant.lproj:158 `paywall.body.curated` 「…狠、24 種風格、每則 3 個版本和吵架模擬器
  需要 Apple Intelligence。」; :179 `paywall.success.body.curated`; :162
  `paywall.feature.feral.detail` doesn't mention voices; the style row
  (`RoastGeneratorView.swift:257`) gives no hint that styles apply to 痛罵.
- **Options:** (a) rewrite the curated header, success text and 痛罵 row in 4
  locales: 痛罵 speaks in your chosen Pro style; per-locale count (15 in
  zh-Hant/en/ja, 16 in zh-Hans) unless 京片兒 is swapped; keep 狠 / 3 versions /
  simulator as needing Apple Intelligence; a one-line hint under the style row;
  extend StoreCopyTests. (b) Fold into the #6 shelf swap so the count stays
  uniform.
- **Risk:** must be true per locale — the 京片兒 gap is the unpaired-term class.

### #4 — Free Gemini does the core Pro job without refusing (verified, n=2)

- **Evidence:** `gemini_vent_probe.md`. Call 1 (gemini-3.8-flash-low via agy, no
  workspace): zh-Hant profane vent in Taiwan register, no refusal (used 幹你娘,
  下去啦, with mainland 老子/他媽/裝逼 mixed in). Call 2: 3 LINE-ready versions
  (冷處理 / 陰陽怪氣 / 台劇腔), no refusal. MEMORY flagged "ChatGPT would refuse
  this" as UNTESTED; for Gemini it is false. Current copy leads with swearing:
  「尺度全開的發洩 —— 粗口解鎖」 (zh-Hant.lproj:162), 「解鎖痛罵 · 狠的唯一方式」
  (:203).
- **Options:** re-position paywall/store copy around 「像台灣朋友在幫你罵」 (native
  voice), one tap, private (no account, nothing kept), formats (group chat,
  share card); keep "swearing unlocked" as a supporting line; test ChatGPT free
  and the consumer Gemini app once before quoting any comparison.
- **Risk:** agy CLI ≠ consumer app; ChatGPT untested; never name competitors in
  store copy.

### #5 — Echoes and the roommate group are invisible to every Taiwan and US user (verified visibility; value a guess)

- **Evidence:** `ExploreView.swift:138-147` `isZhHansLocale()`;
  `FeatureGenerator.swift:557-578` (proGated:true); `EchoesViewModel.swift:9-10`
  (roommate scene cloud-only). The consent sheet names only 發洩/痛罵
  (zh-Hant.lproj:125-129); the roommate group reuses it as Feral
  (`EchoesViewModel.swift:95-110`) — coverage in zh-Hant UNVERIFIED. zh-Hans
  roommate parse-fallback was 10% in June. v1.7 §5 revival gate: 20-scenario
  zh-Hant eval, parse-fallback ≤10%, 0 fully-Simplified transcripts.
- **Options:** (a) zh-Hant only: Taiwan personas in the Worker, gate →
  `AppLanguage.contentBucket`, the §5 eval plus mainland/Simplified checks, one
  share-card format. (b) Echoes visible with Taiwan voice first, roommate later.
  (c) Keep cut; the paywall keeps not advertising either.
- **Effort:** M. **Risk:** reaches ~1 TW install every 3 weeks; multi-voice
  Simplified/mainland bleed; revives a cut feature as the stop rule approaches.

### #6 — The Pro style shelf doesn't fit Taiwan; the app can't filter styles by locale

- **Evidence:** `StylePresets.json`: 8 free incl. 小紅書吐槽 (mainland platform)
  and 文學體 (魯迅); 16 Pro incl. 莎士比亞體, 東京上班族, 豆瓣短文, Reddit 解釋,
  京片兒; 台劇腔 the only Taiwan-specific one (zh-Hant names at
  zh-Hant.lproj:351-420). `localesSupported` decoded (`StylePreset.swift:25`),
  read by nothing. "24 styles" hard-coded in 5 strings per locale and
  `metadata/zh-Hant/description.txt:5,15,34`. Benefit a guess (style usage is not
  measurable).
- **Options:** (a) 1:1 zh-Hant swap via a filtered shelf (鄉民／PTT 推文體 for
  京片兒, 脆文體 for 豆瓣, 台式長輩 LINE 體 for Reddit, 公文／客服體 for 莎士比亞 or
  東京上班族; optionally Dcard 體 for 小紅書), each with a Worker hant voice, an
  on-device preamble/examples and a style_gate2-style check. (b) Just add a hant
  voice for 京片兒's slot. (c) Leave.
- **Effort:** M. **Risk:** unpaired-term class; on-device refusals on 27; few TW
  users today.

### #7 — Cancel sheet showed no message; Retention Messaging API and a win-back offer need no binary

- **Evidence:** r320 row 2026-09-19: Cancel Sheet, "No message", iPhone iOS 27.0,
  TW. The API is server-to-server and pre-release; access by request
  (https://developer.apple.com/contact/request/retention-messaging-api/). Default
  messages per product and locale; none shown for a locale without one; iOS
  15.1+/macOS 14+; must not mislead
  (https://developer.apple.com/documentation/retentionmessaging). 0 win-back
  offers on Monthly.
- **Options:** (a) Jason requests access; one accurate default message per locale
  for Monthly and Yearly. (b) Win-back for lapsed Monthly (a courtesy). (c) Skip.
- **Risk:** pre-release API and approval; message must be true on every device;
  real-time offers need a server endpoint.

### #8 — The credit ladder competes with Pro and doesn't serve one-incident 痛罵 use

- **Evidence:** prices (`asc_iap_prices.txt`): 10 credits NT$20/$0.49; 70
  NT$90/$2.99 (= Pro Monthly); 160 NT$190/$5.99; 380 NT$390/$11.99. One pack ever
  sold (CN, 10, 09-25). Free tier: 10 seeded + 2/day for 7 days
  (`CreditCatalog.swift:29-38`). Packs never unlock 痛罵 or 狠
  (`CreditCatalog.swift:11-15`; zh-Hant.lproj:196, 199). Incident-driven
  behaviour inferred.
- **Options:** (a) reprice or remove 160/380 in ASC; (b) credits buy one 痛罵
  (reverses the v1.1 doctrine); (c) a non-renewing 30-day pass (M); (d) leave and
  let lifetime cover occasional use.
- **Risk:** (b)/(c) could cannibalise the one subscriber, unreadable at this
  volume; copy at zh-Hant.lproj:196/199 would have to change.

### #9 — Lifetime Pro: wait until after 11-15, as the owner chose (not verified)

- FOR (inferred): day-0 cancel suggests a one-off buyer; ~$0.00013/generation;
  Gemini 3.8 Flash suggested ~NT$300 on 10-22; one-time/lifetime rose 6.4% →
  10.3% of monetisation models 2023→2025 (Adapty via
  https://www.airbridge.io/en/blog/should-you-offer-a-lifetime-subscription).
- AGAINST adding before 11-15: 0 purchases since 10-04 and ~3 downloads/week; the
  stop rule counts "new paying subscriber" and a non-consumable muddies it; the
  first non-consumable must ship with a binary (UNVERIFIED for this account); it
  caps the active payer's value if they switch.
- **Options:** decide after 11-15 (price ~1–1.5 annual payments, NT$690–990;
  define up front whether it counts as a payer); never; now (breaks the reading).

### #10 — The biggest gap is still canned output without Apple's model; re-gate cloud quality before deciding (verified)

- `cloud_sendable_enabled` retired; `ROAST_MODE_ENABLED = "false"`
  (`wrangler.toml:69`); zh-Hant `mode:"roast"` failed the v1.5 gate 20/24
  (DEV_PLAN_v1.5:15, 95); the Worker has since gained Taiwan register and
  post-processing (4ed652f); whether roast now passes was unmeasured by this lens
  (lens 2 measured it the same day).
- **Options:** (a) replay the v1.5 roast inputs through `wrangler dev --remote`
  (~$0.003) before any code; (b) keep curated labels and invest in #1–#6.

### #11 — Unlimited history isn't a reason to keep paying

- Free tier prunes at 30 non-favourite, non-sample sessions
  (`HistoryService.swift:95-98`); SituationThread is not Pro-gated
  (`RoastGeneratorViewModel.swift:104-109`). Keep as a footnote; a Pro
  "situation memory" is a later guess.

## Open questions

- US renewal ~11-04: read Sales SUBSCRIPTION_EVENT 11-04..06 filtered to App
  Apple ID 6769317103, plus any r320 instance.
- Has the US payer used 痛罵 since 10-04? Datadog `lane=pro` (connector failed);
  isolates one person — a privacy question for Jason.
- Payers' devices; share of Taiwan installs with Apple Intelligence.
- Does free ChatGPT refuse the same vent? Does the consumer Gemini app match agy?
- Does the owner accept reversing v1.7 §5 and the "credits never unlock 痛罵/狠"
  doctrine?
- Is the yearly trial actually offered on the purchase sheet to Taiwan Apple IDs?
  Release build only.
- Will Jason request Retention Messaging API access?
- Does the roommate consent copy cover it in zh-Hant?
- No native Taiwanese reader yet.
- Were the P2.1 posts published (decides whether T exists)?
- Do lifetime purchases, credit packs and trial starts count as payers in the
  success metric? Decide before any ships.
