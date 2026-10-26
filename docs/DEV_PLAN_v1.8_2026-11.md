# RoastMate — Next-Phase Plan (v1.8): make what Pro sells real on the payer's device

_Drafted 2026-10-27 against HEAD `b737392` (live 1.7.2 build 26, Worker
`046f2134`). The four measured lens reports behind it are in
`docs/evidence/2026-10-27-v18-plan/lens-1..4-*.md`. Every number comes from those
reports or was re-checked here; anything not measured is marked UNVERIFIED.
**Reviewed 2026-10-27** by Gemini 4 Argon (High) and Gemini 3.8 Flash (High),
both SHIP-WITH-CHANGES (`review-gemini4argon.md`, `review-gemini38flash.md`).
§9 lists every material point and what was done with it. The biggest change
from the draft: **1.8.1 is no longer pre-committed.** It is one slot that Jason
fills, or leaves empty, on 11-15 with the stop rule's result in front of him._

**Why this plan exists.** On 2026-10-27 the owner decided: "make all our current
paid features better, because paying users keep shrinking." The v1.7 stop rule
(read 11-15) points to maintenance mode. This plan is a deliberate, bounded
exception to that rule. §2 states the bounds and its own kill criteria.

**In one paragraph.** Pro's base is solid on every device: Feral (痛罵) through
the cloud, Pro styles shaping 痛罵/發洩, unlimited history and no credits. Four of
the paywall's Pro rows are not solid: Savage (狠), styles in sendable modes, 3
versions and the Argument Simulator.
- On devices without Apple's model, all four return canned lines.
- On iOS/macOS 27 with Apple Intelligence, Apple's model refuses the
  Taiwan-flavoured styles most of the time.
- Where it does answer, our own prompts make the output templated.
- The simulator's prompt contradicts itself.
- The copy on devices without the model now *undersells* the one style benefit
  that works everywhere, and the live privacy policy still says two false things.

The plan has three parts:
1. **Binary 1.8.0 (decided; ships before 11-15):** fix what we control on-device
   at $0, make the copy, the privacy policy and the purchase flow true.
2. **11-15, Jason's call:** read the stop rule, then fill **at most one** 1.8.1
   slot (a narrow cloud rewrite for Pro on devices without Apple's model is the
   recommended candidate), or none. If the rule fired, the default is none.
3. **Then stop** (code freeze 12-05).

---

## 0. Where we are (measured 2026-10-27 unless dated)

**Live.**
- iOS and macOS 1.7.2 build 26, live since 2026-10-23 20:45Z. Tags v1.7.0, v1.7.1
  and v1.7.2 (→ `64c4867`); `project.yml` is at 1.7.2 / 26.
- Worker `046f2134` (rollback `7846ac95`).
- Live config (`roastmate-config.json`, fetched today): `vent_cloud_enabled`,
  `roommate_group_enabled`, `echoes_enabled` and `share_card_enabled` are true
  (share card since 10-23). `cloud_sendable_enabled` is false and RETIRED.
  `force_local_only` is false.
- `wrangler.toml`:
  - `ROAST_MODE_ENABLED="false"` (:69), `CLOUD_DISABLED="false"`, `GROQ_ENABLED="false"`
  - `DAILY_LIMIT_PER_DEVICE=30`, `PRO_DAILY_LIMIT=200` (:104)
- OpenRouter has $9.88 left (balance log 10-26) with auto-top-up OFF (a hard cap).
  Spend rose 0.0522 → 0.1247 between 10-12 and 10-26; that includes the 10-22
  investigation.
- Live privacy policy (`jasonyeyuhe.github.io/RoastMate/privacy.html`, "Last
  updated October 20, 2026", fetched today; source is the separate Pages repo
  `JasonYeYuhe/RoastMate`, **not** the stale `docs/site/privacy.html`). See
  finding 12.

**Money and funnel** (`scripts/asc_analytics.py`; lens 3):

| window | first-time downloads | purchases | other |
|---|---|---|---|
| 09-01 → 10-26 | 16 (TW 4, CN 3, US 5, EG 2, RU 1, DE 1) | Pro Monthly TW 09-19 · Credits 10 CN 09-25 · Pro Monthly US 10-04 | impressions 681, page views 61 |
| 10-07 → 10-24 | **7** (4 iPhone, 3 Mac; **TW 1**) | **0** | impressions 301, page views 26 |

- **Two payers ever,** both on Pro Monthly at full price, both converting on
  download day.
  - **TW** cancelled on day 0 (09-19, v1.5.0, iOS 27) and lapsed 10-19.
  - **US** was active in the 10-24 Sales report and the 10-25 state report and
    renews about 11-04. They were on iOS 26.6 at purchase. No 1.7.x update has been
    seen on any US iPhone (10-22 r3). **No binary can reach them before renewal;
    only Worker changes can.**
- **Prices.**
  - Monthly NT$90 / US$2.99.
  - Yearly NT$690 / US$19.99, **with a 7-day free trial configured in all 175
    territories that the app never shows.** `paywall.yearly.trial` exists in 4
    locales and no Swift file reads it (nor `introductoryOffer` /
    `isEligibleForIntroOffer`); `StoreService.loadProducts` does not sort the plans
    (`StoreService.swift:72-86`).
  - Credit packs: 10 / 70 / 160 / 380 credits for NT$20 / 90 / 190 / 390.
  - The StoreKit purchase sheet shows the ASC subscription descriptions, which
    still say "Unlimited generations" (v1.7 handoff, 10-22; the API refuses edits
    while the subscription is ACTIVE).
- **Distribution:** no P2.1 post is logged as of 10-27. The outreach log has no
  post rows, and the posts file said "Nothing here has been posted" on 10-23. The
  stop rule's T has not started.
- **Cost of the cloud:** a 3-variant sendable call is about $0.0002 on the primary
  model and $0.00056 on the fallback. Feral/Vent is about $0.00013. Even if every
  call fell back, an active Pro user would cost under $0.10 a month, against about
  $2.54 net per month (lens 2).

**What Pro sells vs what a payer gets** (lens 1: 88 on-device calls through the
production prompt, filter and refusal code on macOS 27.0.1 M1 Pro, plus 20
production Feral calls). Device classes:
- **A:** iPhone, Apple Intelligence on, iOS 27.
- **B:** the same on iOS 26.
- **C:** iPhone without Apple's model (iOS 18, AI off or unsupported, older than
  15 Pro).
- **D:** Mac with Apple Intelligence (this Mac, which is also the only proxy for A).
- **E:** Mac without it.

| Pro benefit (paywall row) | A / D (OS 27 + AI) | B (iOS 26 + AI) | C / E (no Apple model) |
|---|---|---|---|
| 痛罵 Feral (cloud, after consent) | **REAL**: 20/20 OK, median 1.9 s; zh-Hant Taiwan terms 10/10, 0 Simplified, 0 names | REAL | REAL. Its 改成能發的 follow-up is curated |
| Pro styles in 發洩/痛罵 (cloud, since 10-22) | **REAL** for 15 of 16 (京片兒 has a voice only in zh-Hans; 硬核回擊 reads like the unstyled default) | REAL (same) | REAL (same), **but the paywall and success text here say styles need Apple Intelligence** |
| 狠 Savage (on-device) | **WEAK**: refused → curated in zh_TW 6/16, en 2/16, zh_CN 2/4, ja 0/4. zh_TW 硬核回擊 3/4 and 台劇腔 3/4 | UNVERIFIED for Pro styles (free styles: 1/32 refused on macOS 26.6.2 in Aug) | **CURATED**: 5 lines per language, ignores input and style |
| Pro styles in sendable modes | **WEAK**: 台劇腔 in Sharp zh_TW refused 4/4; output that does come back is templated | UNVERIFIED | **CURATED** |
| 3 versions per comeback | **WEAK**: 3/30 calls near-duplicate; stock openers repeat | UNVERIFIED | **CURATED** (3 of the 5 lines) |
| 吵架模擬器 Argument Simulator | **WEAK**: 10/36 turns refused. Of the 26 written, 14 speak as the opponent, 7 flip to the user's side, 5 are confused | UNVERIFIED (same prompt bug, inferred) | **BROKEN**: a canned roast line plays the "opponent" every turn |
| Unlimited history | REAL | REAL | REAL |
| No credits | REAL | REAL | REAL (only matters for 發洩/痛罵) |
| Echoes / 虛擬室友群 (not on the zh-Hant/en paywall) | HIDDEN outside zh-Hans | HIDDEN | HIDDEN |

**Realness per class today:** A/D have 4 of 8 sold rows real and 4 weak. C/E have
4 real and 4 canned, and the copy on C/E denies one of the real ones. **Which class
payers are on is unknown.** 3 of 4 first-time downloads since 10-15 were on OS 27
(10-22 r3), and 3 of 7 since 10-07 were Macs. App Store Connect cannot say which
devices have Apple Intelligence.

## 1. What the evidence says

Strength tags:
- **[M]** measured on production code paths or production services.
- **[I]** inferred.
- **[G]** a guess.

The mechanisms are strong evidence. Any link from them to churn or conversion is
inferred from n = 2 payers.

1. **Without Apple's model, 4 of 7 Pro rows are canned** [M]. Code path:
   `RoastEngine.swift:296-303` falls back to `FallbackRoasts.swift:7-13, 36-63`.
   Since 1.7.1 this is disclosed (`paywall.body.curated`, zh-Hant.lproj:158). The
   share of payers this hits is unknown. The 改成能發的 rewrite under a 痛罵 card
   is curated there too (`RoastEngine.swift:476-479`). (lens 1 F1)
2. **On OS 27 with AI, Apple refuses the Taiwan-flavoured Pro styles, and
   permissive guardrails remove the refusals** [M on macOS 27.0.1; iPhone
   UNVERIFIED].
   - With default guardrails, 3 of 8 cells were hard-refused. Combined with the
     10-22 run, 硬核回擊 is refused zh_TW 8/12 and en 9/12.
   - With `permissiveContentTransformations`: 0/8 refused and 48/48 variants passed
     the strict filter, at mediocre quality.
   - Precedent: 1.7.1's rewrite already ships under permissive mode with three
     screens (`RoastEngine.swift:462-570`). (lens 2 b)
   - **Mechanics that matter for the fix** (review, verified): the cached path
     `AppleFMBackend.respondCached` builds `LanguageModelSession(instructions:)` on
     the default model and reuses it while `keepSession` and the key match
     (`AppleFMBackend.swift:32-45`); the key has no guardrail component
     (`RoastEngine.swift:305`). A permissive retry must go through `respondFresh`
     (`AppleFMBackend.swift:48-55`), never the cached session.
3. **When the on-device model does answer, our own prompts make Pro styles
   templated** [M].
   - English 台劇腔 versions open with 欸/喔/啦 18/18, because the preamble tells
     every locale to use those particles (`StylePresets.json:305`).
   - 職場冷暴力 pastes the preamble's stock phrases 12/12.
   - "I'd have said:" opens 9 of 12 en 冷處理 versions; it comes from the roast
     guidance at `PromptBuilder.swift:247`.
   - zh-Hant prompts carry Simplified few-shot examples, because
     `examplesForPrompt` filters by Han characters, not by script
     (`PromptBuilder.swift:531-546`). This is the unpaired-term bug class.
   (lens 1 F3)
4. **The simulator is broken by its own prompt** [M].
   - The input says "play the OTHER side" (`ArgumentSimulatorViewModel.swift:111-128`).
   - The mode guidance asks for "the response *the user* should give back"
     (`PromptBuilder.swift:252-253`).
   - Every sendable prompt asks for a numbered list (`PromptBuilder.swift:143`).
   - Each turn sends only the user's last line; the conversation lives only in
     the cached on-device session (`ArgumentSimulatorViewModel.swift:122-128`,
     `keepSession: true` at :148).
   - Result: 14 of 36 turns speak as the opponent, and 12 of 36 are numbered lists.
   (lens 1 F5)
5. **Feral is the only Pro generator that is real everywhere, and it measures
   well, but it is undersold** [M].
   - The C/E copy says styles need Apple Intelligence (zh-Hant.lproj:158 and :179;
     en.lproj:158).
   - 硬核回擊 reads like the default.
   - 京片兒 has no voice outside zh-Hans (`style_voice.js:140-142`).
   (lens 1 F2, lens 3 #3)
6. **The Worker's `mode:"roast"` was re-gated today, and the v1.5 failure is mostly
   gone** [M; 19 preview calls, one non-native reader].
   - Passes: 57/57 variants pass the strict filter; exactly 3 variants in 19/19
     calls; 0 profanity; p50 latency 5.4 s.
   - zh-Hant: 1 of 9 cells has one Simplified character; 0 English-only replies.
     **What changed since the 10-22 challenge dropped this path:** its measured
     reason (20/24 failed in v1.5) is now 1/9.
   - Missing:
     - style voice (台劇腔 recognisable 0/3)
     - name scrub (a name was echoed in 3/3 variants)
     - no invented facts (3/27 zh-Hant variants invented some)
     - second person in ja
     - **no server-side Pro check**: tokenless requests fall to the free lane,
       `lane.js:46-54`
   - The client always sends `mode:"roast"` for sendable cloud calls and never
     sends `priorContext` (`RoastEngine.swift:670-690`); the Worker knows only
     vent / roommate / roast (`index.js:671-676`). Reply Helper, Emotion
     Translator and Social Roast share this path through `FeatureGenerator`
     (`FeatureGenerator.swift:130-174`). (review, verified)
   (lens 2 a)
7. **Private Cloud Compute cannot help C/E** [M on the SDK and Apple's docs]. It is
   Apple-Intelligence-only, its guardrails cannot be configured, and it has a
   per-user daily quota. An Aug-30 eval log calls the entitlement "just-granted"
   (`evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md:4`), but
   `RoastMate.entitlements` has no PCC key and today's unsigned probe failed every
   generation; whether a signed build gets it is UNVERIFIED. (lens 2 c)
8. **Echoes and the roommate group** [M].
   - Hidden outside zh-Hans (`ExploreView.swift:138-148`).
   - The roommate group's zh_TW output parses 8/8, but 8/8 contain Simplified
     characters (copied from the prompt's examples) and 0/4 Feral transcripts swear.
   - **Classic Echoes was refused 22/22 on macOS 27**, including a harmless input,
     and falls back to one canned, *unlabelled* transcript.
   - Its copy and consent are **false today**: the zh-Hans/en consent names Groq
     and says Casual stays on-device; the roommate screen says 「完全本机生成」;
     the consent title/allow/deny buttons talk about "Feral" and "Stay on-device"
     although the roommate group needs the grant for both tones and generates
     nothing without it (`EchoesViewModel.swift:98-118`,
     `EchoesEngine.swift:205-215`); and the Settings toggle with its footer
     「日常語氣一律只在這台裝置上處理」 renders **in every locale**
     (`SettingsView.swift:61-73`; zh-Hant.lproj:565-566, ja.lproj:566-567,
     en.lproj:569-570, zh-Hans.lproj:570-571). (lens 4; review)
9. **The purchase flow** [M code; effect I].
   - The yearly trial is invisible and the plan order is unsorted.
   - A locked style chip only opens the paywall (`RoastGeneratorView.swift:263-274`).
   - After buying, nothing is selected or run (`PaywallView.swift:88-97`).
   - **A free user who taps the second sample gets an error, not the paywall**
     (review, verified): sample 2 of the 5 shown uses the Pro style `mba_boss`
     (`SampleRoasts.json` index 1; `RoastGeneratorView.swift:492`); `loadSample`
     sets the style with no tier check (`RoastGeneratorViewModel.swift:332-345`);
     the Generate button checks only the intensity (`RoastGeneratorView.swift:283-291`);
     the view model then shows `quota.exhausted.body` as an error
     (`RoastGeneratorViewModel.swift:104-107`). Same guard in
     `FeatureGenerator.swift:113-116`.
   - The TW day-0 cancel is the only cancellation we have. (lens 3 #1, #2)
10. **"Swearing unlocked" is not a moat** [M, n=2, CLI rather than the consumer
    app]. Gemini 3.8 Flash wrote a profane zh-Hant vent and 3 styled LINE-ready
    rewrites without refusing. What Pro can still win on: one tap, a native Taiwan
    voice, privacy, and formats. (lens 3 #4)
11. **Reach** [M + estimate]. Any Pro change reaches about 1–3 buyers a month. A
    Taiwan-only change reaches about 1 install every 3 weeks. Changes that work in
    every language come first.
12. **The live privacy policy is false in two places and incomplete** [M, fetched
    10-27; found by the review on the stale repo copy, re-checked on the live page].
    - It says that with cloud off the app will "generate Vent / Feral locally on
      Apple's on-device model (with gentler output)". Since v1.7 the code shows
      labelled examples; the in-app copy was fixed, the policy was not.
    - It says Vent/Feral go to the cloud "by default"; the app asks for consent
      first (5.1.2(i)).
    - It doesn't mention the roommate group (`mode=roommate`) or the `styleId`
      the app has sent since 1.7.1.
    - The Worker sends no provider data-collection preference to OpenRouter
      (`index.js:561-578`; no `data_collection` anywhere in `src/`). Whether the
      OpenRouter account setting already excludes providers that train on prompts
      is UNVERIFIED.

## 2. Goals, success metrics, kill criteria

**Goal.** On every device the app ships to, each Pro row the paywall shows is
either real there or not claimed there, with zh-Hant first, and every privacy
claim is true. Payers keep paying.

### 2.1 Relation to the v1.7 stop rule (plainly)

The v1.7 stop rule (`DEV_PLAN_v1.7_2026-10.md` §7, :249-275) tests distribution.
It is read on **11-15**, or 4 weeks after T if that is later. T is the later of
1.7.0's product page going live and the third P2.1 post.
- No P2.1 post is logged as of 10-27. If T hasn't happened by 11-15, the rule's
  first branch fires: "distribution isn't happening → stop feature work."
- With posts, it stops only if first-time downloads average **< 5 a week**
  (baseline about 3) **and** there is no new paying subscriber, over the 4 weeks
  after T.

**This plan is feature work that the rule would forbid. The owner chose it on
10-27.** Both reviewers said the draft let it run past the rule (§9 #1). So:

1. **1.8.0 is the owner's exception, and it is bounded.**
   - One binary, submitted by **11-12**, live before the 11-15 read.
   - At most 3 production Worker deploys in the whole plan, one per purpose — A1
     (with A9's option), B4's voice, a slot item's turn-on — plus rollbacks.
   - At most **$2** of evaluation spend on OpenRouter.
   - Nothing outside §3 gets built.
2. **1.8.1 is not pre-approved.** On 11-15 the agent records the stop rule's result
   word for word in the handoff and gives Jason a one-page brief. Jason then picks
   **at most one** item for 1.8.1 from §3 (B) "the 11-15 slot", or none.
   - **If the rule fired, the default is none.** 1.8.1 happens only if Jason, with
     the record in front of him, says so explicitly in chat.
   - If the rule passed, the slot is available; Jason still picks.
   - No preparatory code for any slot item before 11-15 (reading and planning
     only).
3. **No self-extension.** Code freeze **12-05**. After it, maintenance-mode rules
   apply whatever 11-15 said: fixes for regressions this plan introduced and App
   Review responses only.
4. **Distribution without code continues in parallel** (P2.1 posts, creator batch
   2). It is Jason's work and is not displaced by this plan. Nothing in this plan
   counts as distribution, and the rule's T and thresholds are untouched.

| 11-15 stop rule | 1.8.1 | 2027-01-31 read of this plan | then |
|---|---|---|---|
| fires | none, unless Jason explicitly re-approves one slot | kill | maintenance mode; no further plans |
| fires | (same) | success | one more plan is allowed, and it starts with distribution (the product converts the traffic it gets; traffic is the gap) |
| passes | Jason may fill the slot | kill | the next plan is distribution only; paid features stay frozen |
| passes | (same) | success | the next plan may include paid features (§5 revive conditions) |

### 2.2 Product targets (we control these; each is a ship gate; harness in §7)

| benefit | class | baseline 10-27 | target | item |
|---|---|---|---|---|
| Feral quality | all | 20/20 OK, swear 20/20, zh-Hant Taiwan terms 10/10, 0 Simplified | no regression | A1 |
| 硬核回擊 in 痛罵 distinguishable from unstyled | all | 0/2 pairs | ≥ 5/6 blind pairs | A1 |
| Savage + Pro styles written by the model, not curated | A/D | Savage zh_TW 10/16; Sharp 台劇腔 zh_TW 0/4 | ≥ 7/8 per locale × style (zh_TW, en, ja) | A3 |
| Permissive output reaching the screen | A/D | n/a (new path) | 0 threats, 0 self-harm content, 0 slurs on the safety set (§7.1) | A3 |
| Templating | A/B/D | CJK in en 18/18 (台劇腔); "I'd have said" 9/12; top opener 7/12 | 0 CJK in en; 0/12; ≥ 3 distinct openers per 12 | A5 |
| Script in zh-Hant on-device prompts | A/B/D | Simplified examples sent | 0 Simplified examples (unit test); 0 Simplified characters in output | A5 |
| 3 versions near-duplicate | A/B/D | 3/30 calls | ≤ 1/30 | A5 |
| Simulator speaks as the opponent | A/D | 14/36 (39 %); 12/36 numbered | ≥ 29/36 (80 %); 0 numbered | A4 |
| Simulator | C/E | canned roast lines as the opponent | no fake turns; an honest "needs Apple Intelligence" state | A4 |
| Paywall and success claims true per locale and device | all | C/E copy denies styles in 痛罵 | every claim true (StoreCopyTests) | A2 |
| Yearly trial shown correctly | all | never shown | shown only when eligible; NT$690/年 stays the most prominent price | A6 |
| Free user taps a Pro-style sample, then Generate | all | orange error (`quota.exhausted.body`) | the paywall opens, with that style as the hand-off intent | A6 |
| Echoes/roommate copy and consent true | 4 locales | names Groq; "fully on-device"; Settings footer false in every locale | true; consent re-asked | A7 |
| Privacy policy claims true | all | 2 false claims, 2 omissions (finding 12) | 0 false claims (checklist against the code) | A9 |
| Savage / styles / 3 versions real | C/E | canned | not claimed (A2); real only if the 11-15 slot is B1-S | A2 / B1-S |

**Realness score** = sold rows that are real ÷ sold rows claimed on that device.
- Today: A/D 4/8 (4 weak); C/E 4/8 (4 canned, 1 understated).
- After 1.8.0: A/D 8/8 measured real (the refusal and simulator targets above).
  C/E: 100 % of claims true, with the canned rows not claimed.
- If the 11-15 slot is B1-R: on C/E, 改成能發的 under a 痛罵/發洩 card becomes real
  for Pro (a new, true row). If it is B1-S: C/E 7/8 real (the simulator stays
  on-device; §5).

### 2.3 Payer outcomes (App Store Connect only; no new collection)

A **new start** is a Pro subscription start, paid or free trial, in the
SUBSCRIPTION_EVENT report for App Apple ID 6769317103, counted from the day 1.8.0
goes live (about 11-14). Credit packs are not starts. If Jason adds Lifetime Pro
at 11-15 (B8), a lifetime purchase counts as a new start that is "not cancelled"
unless refunded within 14 days.

- **Leading signals,** read weekly:
  - for every new start, Days Before Canceling and any cancel-sheet event within 3
    days (r320)
  - trial starts and trial → paid
  - the US renewal around 11-04, recorded but not counted (it predates 1.8.0)
- **Denominator,** recorded at every read: first-time downloads since 1.8.0 went
  live, and starts per first-time download. If the window ends with fewer than
  **40** first-time downloads (today's ~3.6 a week), the verdict is recorded as
  "traffic-limited". The consequences in §2.1 do not change, because missing
  traffic is the distribution failure the stop rule tests.
- **SUCCESS on 2027-01-31** requires all three:
  - at least 3 new starts
  - at least 2 of them not cancelled within 3 days
  - at least 1 that reaches a second paid period (a Monthly renewal, or the yearly
    trial converting)
- **KILL on 2027-01-31** if either holds:
  - at most 1 new start
  - every new start cancels within 3 days

  Then: maintenance mode as defined in v1.7 §7, and no further paid-feature plan.
- **In between** (2 starts, mixed): no new feature plan.
- Calibration: the expected volume is about 0.3–1.6 payers a month (lens 3), so 3
  starts in about 11 weeks is a stretch, not a formality. These thresholds are a
  judgment call, set before any data arrives.

### 2.4 Early kills (any time)

- An item whose gate fails **twice** is cut from its binary, not tried a third
  time.
- 1.8.0 not submitted by **11-19** (a week late): no 1.8.1 at all; the next binary
  is fixes for 1.8.0 only.
- Evaluation spend over $2, or the balance under $5: stop evaluations. Topping up
  is Jason's.
- A3 rejected by App Review: remove the permissive path and ship A2's AI-device
  caveat. One Resolution Center reply at most.
- Any threat, self-harm content or slur that reaches a user, whether found by a
  gate after ship or reported: set `ondevice_permissive_enabled:false` (or the
  slot item's flag) the same day, then investigate.

## 3. Scope

### (A) Just do — binary 1.8.0 (plus A1 on the Worker)

Ranked. Each item lists **what** changes, **who** it helps, the **gate**, App
Review and privacy notes, **cost** and **effort**.

**A1 — Worker: make 硬核回擊 a voice you can tell apart in 痛罵 (no binary; first week).**
- **What:** `cloud-worker/src/style_voice.js`, `STYLE_VOICES.savage_no_filter`
  (en / hans / hant / ja), plus `test/style_voice.test.js`. Give the style a
  structural signature the unstyled Feral draft lacks, for example 3–4 one-line
  charges, each naming one thing they did, then a verdict of at most 6 words. Never
  a swear-word count.
- **Who:** every Pro user on every device and in every script (including hant) who
  picks the flagship-named Pro style in 痛罵/發洩. It also reaches the active US
  payer before their renewal; that is a side effect, not the deadline.
- **Gate:**
  - style_gate2 blind pairs: 硬核回擊 vs unstyled Feral distinguishable in ≥ 5/6
  - swear present at no lower a rate than unstyled
  - within the 1.3× length ceiling
  - `harness/worker-compare/compare_ext.mjs` shows no prompt diff for any other
    style or any free style
  - cloud harness unchanged
  - at most 20 preview calls (`npx wrangler dev --remote`)
- **Review/privacy:** none. **Cost:** about $0.005. **Effort:** S (½ day). Record
  the new version id and the rollback (`046f2134`). A9's optional Worker change
  rides this deploy.

**A2 — Copy that is true in both directions (1.8.0).**
- **What:** `Shared/*.lproj/Localizable.strings`, 4 locales.
  - `paywall.body.curated`, `paywall.success.body.curated`,
    `paywall.feature.feral.detail` and the PlanCopy rows say the chosen Pro style
    sets the voice of 痛罵 and 發洩 on every device.
  - 狠, 3 versions and the simulator stay "needs Apple Intelligence" on C/E.
  - A one-line hint under the style row in 發洩/痛罵 (`RoastGeneratorView.swift:257`).
  - Lead the Feral row and the unlock line (zh-Hant.lproj:162, :203) with result
    and format (a Taiwan voice, one tap, private). 「粗口解鎖」 becomes a supporting
    line.
  - The claim must be true per style and per locale. 京片兒 has no voice outside
    zh-Hans, so either compute counts in code or leave that style out of the hint,
    unless B4 fixes it.
  - Never name competitors.
  - **Fallback:** if A3 is dropped or rejected, add an AI-device caveat for
    zh-Hant.
  - Product page: update the zh-Hant/en description lines that repeat these claims
    on the 1.8.0 version (`scripts/asc_product_page.py`, dry run first, `--app-id
    6769317103` passed explicitly). New ASC versions don't inherit the promotional
    text: re-set it.
  - Optional, first to drop: macOS screenshots for zh-Hant/en (today May-era,
    Simplified, Debug=Pro). Not a blocker: macOS 1.7.0–1.7.2 passed review with
    them.
- **Who:** every buyer, most of all on C/E, where today's copy denies the one style
  benefit that works everywhere.
- **Gate:**
  - StoreCopyTests:
    - no curated string says 痛罵/發洩 styles need Apple Intelligence
    - every count equals the computed count for that locale
    - 4-locale paired-term parity
  - Release build (`ENABLE_TESTABILITY=YES`) of the paywall and success alert on a
    disposable iOS 18.5 device (class C) and on this Mac (class D), in zh-Hant and
    en, looked at by a person, with a v1.7.2 control.
  - zh-Hant wording read by the native reader (owner task).
  - **Submit gate (Jason, ASC web UI):** the Pro Monthly and Yearly subscription
    descriptions no longer say "Unlimited generations" / 「無限生成」 in any
    locale. 1.8.0 is not submitted until this is done.
- **Review/privacy:** lowers exposure under 2.3.1 and 3.1.2. **Cost:** 0.
  **Effort:** S (~1 day).

**A3 — On-device sendable generation that Apple doesn't refuse on OS 27 (1.8.0).**
- **What:**
  - For sendable calm / sharp / savage, the simulator included: the first call
    stays exactly as today (default guardrails, `respondCached`). **Only after a
    default refusal,** retry once through `respondFresh(guardrails:
    .permissiveContentTransformations)` (`AppleFMBackend.swift:48-55`) — a fresh
    session, never the cached one, because the cache is keyed without guardrails
    and would replay the default session (`AppleFMBackend.swift:32-45`,
    `RoastEngine.swift:305`). If a cached permissive session is ever added, its key
    must include the guardrail mode.
  - Every permissive output must pass, per variant:
    1. `ModelRefusal.looksLikeRefusal`
    2. `SafetyFilter.validateOutput`
    3. `RewriteThreatScreen`
    4. the one-word threat judge, **one call per variant** (it was tuned and
       measured on single messages with `maxTokens: 4`, `RoastEngine.swift:550-591`;
       about 270 ms each)
  - A variant that fails is dropped; if none survive → labelled curated text. The
    floor stays.
  - New restrict-only remote key `ondevice_permissive_enabled`: absent or true
    allows the retry; false means default guardrails only.
- **Why default first:** Apple's guardrail stays on every call it accepts (en 14/16
  and ja 4/4 were accepted). A refused call costs about 1 s more, since refusals
  arrive in 0.5–1.5 s. And the permissive path stays the exception. Lens 2
  suggested permissive for every call; this is the conservative use of the same
  public API.
- **Who:** everyone on an AI device running OS 26 or 27 who uses Savage, a Pro
  style, 3 versions or the simulator. Free Composed/Sharp benefit too (zh_TW Sharp
  was refused 2/8 on 10-22).
- **Gate,** on this Mac and on one real iOS 27 iPhone (TestFlight; owner task):
  - refused → curated ≤ 1/8 per locale × style for 硬核回擊, 台劇腔, 職場冷暴力 and
    冷處理 in Savage, and 台劇腔 in Sharp; zh_TW, en and ja
  - 100 % strict-filter pass
  - the safety set (§7.1; it must be rebuilt first — the 10-22 held-out set lived
    in a scratchpad that no longer exists): 0 threats, 0 self-harm content and 0
    slurs reach the screen, and self-harm inputs still go to the crisis resources
    (`SafetyFilter.crisisSignal`)
  - median latency of a refused-then-permissive call ≤ 12 s
- **Review/privacy:** low-to-moderate unknown (Guideline 1.2 if anything slips).
  Apple's docs describe the mode for transforming text; 1.7.1's permissive rewrite
  passed review. Reviewer notes get one sentence about the screens. No consent
  change. **Cost:** $0. **Effort:** S–M (1.5–2 days).

**A4 — The Argument Simulator plays the other side (1.8.0).**
- **What:**
  - Its own prompt path in `PromptBuilder` (Shared, so `RoastMateTests` can test
    it): a new `RoastMode` case, or argument-specific system and task text.
    - an opponent persona, with the chosen style applied to the opponent's voice
    - one reply, no numbering (skip `PromptBuilder.swift:143` for n=1)
    - no Sharp calibration (`PromptBuilder.swift:434-442`)
    - at most 80 words
    - **stateless per turn:** the prompt carries the setup and the transcript so
      far (≤ 12 turns, each ≤ 80 words) instead of relying on the cached session.
      This is what lets A3's fresh permissive retry keep the context.
  - `ArgumentSimulatorViewModel.swift:109-150` calls the new path, and uses A3's
    refusal retry and per-turn screens.
  - On C/E the tile opens a short "needs Apple Intelligence" explanation instead of
    a conversation with canned roast lines (a cloud simulator is cut, §5).
- **Who:** every payer who opens a Pro-only tool the store sells as 「AI 扮演對方」.
- **Gate:**
  - lens 1's 36-turn set on this Mac: ≥ 29/36 turns in the opponent's voice
    (lens-1 rubric, hand-classified); 0 numbered lists; refusals ≤ 1/8 per locale
  - the threat judge on simulator turns: its false-positive rate on the 36-turn
    set is recorded (a turn wrongly blocked shows curated text); 0 threats pass on
    the safety set's simulator cases
  - a unit test proves the prompt contains the transcript and no numbering
    instruction
  - on a disposable iOS 18.5 device, no fake turn appears
- **Cost:** $0. **Effort:** S–M (1–1.5 days).

**A5 — Pro styles stop sounding templated on-device (1.8.0).**
- **What:** `StylePresets.json`, `StylePreset.swift`, `PromptBuilder.swift`.
  - Preambles become language-aware. Chinese particles only when the output is zh
    (taiwanese_drama, `:305`). The title is written in Traditional, or dropped, for
    zh-Hant. The corporate stock phrases become "for example", not a list to paste.
  - Examples per script for every Pro style. Add zh-Hant (and ja) examples;
    `examplesForPrompt` picks by script so zh-Hant prompts get 0 Simplified
    examples.
  - Reword the roast guidance (`:247`) so outputs don't open with "I'd have said:".
    Strip that wrapper in post-processing as a backstop.
  - A Savage calibration block (three different situations, shape only), like
    Sharp/Calm (`:92-97`).
  - Near-duplicate check across the 3 versions (similarity ≥ 0.6): regenerate the
    duplicate once.
- **Who:** AI-device users of Savage and Pro styles (A/B/D). Free Composed/Sharp
  get script-correct examples too.
- **Gate:**
  - rerun lens 1's probe (40 Savage + 12 Sharp-Pro calls) and meet the §2.2 targets
    (0 CJK in en, 0 Simplified in zh_TW, ≥ 3 distinct openers per 12, 0 "I'd have
    said", near-duplicate ≤ 1/30)
  - no refusal regression against A3's numbers
  - the CJK parity test extended to preambles and examples
  - a snapshot test proves the free-style prompts are unchanged
- **Cost:** $0. **Effort:** M (2 days). Re-run at every Apple OS or model release.

**A6 — The purchase flow tells the truth and hands off (1.8.0).**
- **What:**
  - Sort the plans deterministically, yearly first (`StoreService.swift:72-86`).
  - The yearly row (`PaywallView.swift:305-342`):
    - **NT$690／年 (the billed amount, `displayPrice`) stays the largest, most
      prominent price** (3.1.2(c)).
    - Under it, smaller: `paywall.yearly.trial` (zh-Hant.lproj:173, unused today)
      built from `subscription.introductoryOffer`, plus ≈ the per-month price.
    - The trial line appears **only when `await
      product.subscription?.isEligibleForIntroOffer` returned true before the row
      rendered**; unknown or false → no trial line. Monthly stays the no-trial
      option.
  - Hand-off: the paywall receives the intent that opened it (a locked style chip,
    a locked intensity, or a Pro-style sample). On `isPro`
    (`PaywallView.swift:88-97`) the presenter selects it. If the paywall came from
    a generate tap with non-empty input, it runs once. The device-honest success
    text stays.
  - **Pro style selected by a free user → the paywall, not an error.** The
    Generate buttons check the style tier as well as the intensity
    (`RoastGeneratorView.swift:283-291`, `FeatureGenerator.swift:370-380`) and
    open the paywall with that style as the hand-off intent; the view-model guards
    stay as the safety net.
  - The intent and trial-line decisions live in a small Shared type so
    `RoastMateTests` can cover them (the test bundle cannot see app-target types,
    `project.yml:229-236`).
- **Who:** every buyer in every language, in the first minute — the minute in
  which the only cancellation we have (day 0) happened.
- **Gate:**
  - Release build with `RoastMate/Configuration.storekit` (it has the yearly intro
    offer, :216-220): the trial line appears when eligible and disappears once the
    intro is used (Xcode transaction manager); NT$690 is visibly the primary price;
    the order is stable; after a test purchase the tapped chip is selected
  - a free user taps sample 2 and then Generate: the paywall opens, no error
  - checked on a disposable iOS 18.5 device and on this Mac, with a v1.7.2 control
  - **never verified in Debug (Debug is always Pro)**
- **Review:** 3.1.2. Trial terms must be clear and shown only to eligible users;
  the legal footer already covers trials (zh-Hant.lproj:215). **Cost:** 0.
  **Effort:** S (1–1.5 days).

**A7 — Echoes/roommate: make the shipped copy and consent true (1.8.0, mandatory).**
- **What:** fix live accuracy defects, **in all 4 locales**.
  - Scene-aware blurbs: the roommate screen says it is generated in the cloud after
    consent (`EchoesView.swift:141-149`; zh-Hans.lproj:547, en.lproj:551).
  - The consent sheet (`echoes.consent.title/body/allow/deny`; zh-Hans.lproj:562-566,
    en.lproj:562-566) names OpenRouter, not Groq; says both roommate tones use the
    cloud; and the deny button no longer promises "Stay on-device" for a scene that
    generates nothing without the grant.
  - `settings.echoes_feral_cloud` and its footer in zh-Hans, en, zh-Hant and ja
    describe what the grant does today (after B3, the roommate group only).
  - The Settings Echoes toggle and footer appear only where an Echoes tile can show
    (`SettingsView.swift:61-73`).
  - **Version the consent** (a new key, asked once more), because existing grants
    were given under false text.
  - Classic Echoes: as B3 decides.
- **Who:** zh-Hans Pro users today; every locale's Settings screen today; any future
  zh-Hant opening.
- **Gate:**
  - StoreCopyTests: no "Groq", and no on-device wording, in any string reachable
    from the roommate scene or the Settings toggle, in any locale
  - the toggle is absent in the zh-Hant, en and ja UI
  - `EchoesFlowUITests` (zh-Hans) passes with the re-ask
  - a Release check
- **Review/privacy:** fixes a 5.1.2(i) accuracy defect; mention the re-ask in the
  reviewer notes. **Cost:** 0. **Effort:** S (0.5–1 day).

**A8 — Small Taiwan items (1.8.0; first to drop).**
- **What:**
  - zh-Hant and zh-Hans `InfoPlist.strings` set the home-screen name to 幫你罵 /
    帮你骂 (`project.yml:48, 127` set "RoastMate" for the iOS and Mac apps). The
    Mac target also needs `LSHasLocalizedDisplayName` (its `Info.plist` carries
    only `NSUserActivityTypes`); whether macOS needs more is UNVERIFIED — check
    the built bundle. The Share and Controls extensions hardcode
    `CFBundleDisplayName = RoastMate` (`RoastMateShare/Info.plist:7-8`,
    `RoastMateControls/Info.plist:7-8`): localize or leave, and say which.
  - No Watch check: the Watch app is in no shipped bundle (`project.yml:82-102`).
  - zh-Hant App Shortcut phrases (`GenerateRoastIntent.swift:116-138`).
  - 4–6 zh-Hant samples in `SampleRoasts.json`, taken from real harness output of
    styles that work in Taiwan and shown first for zh-Hant (today there are 0
    zh-Hant responses). **Only after A6's sample fix,** because most of those
    styles are Pro.
- **Who:** Taiwan prospects and users.
- **Gate:** the samples pass the script and mainland-marker scan; the label reads
  幫你罵 on a zh-Hant iPhone and in Finder/Launchpad on a zh-Hant Mac.
- **Cost:** 0. **Effort:** S (≤ 1 day).

**A9 — The privacy policy says what the code does (no binary; before 1.8.0 is submitted).**
- **What:** `privacy.html` in the Pages repo `JasonYeYuhe/RoastMate` (clone it; the
  repo's own `docs/site/` is stale and deploys nothing).
  - Replace "generate Vent / Feral locally on Apple's on-device model (with gentler
    output)" with what happens: labelled examples.
  - "by default" → "after you allow it".
  - Disclose the roommate group (zh-Hans) and the style id. Keep the wire-field
    list exact.
  - Jason checks the OpenRouter account's privacy setting (exclude providers that
    train on or keep prompts). Optionally the Worker adds `provider: {
    data_collection: "deny" }` to the OpenRouter body (`index.js:569-578`), only if
    ≤ 6 preview calls show both models still route with normal latency; it rides
    A1's deploy.
- **Gate:** a checklist in `docs/evidence/2026-10-27-v18-plan/` maps every claim in
  the policy to the code or config that makes it true; **Jason approves the diff
  before it is pushed** (it is a legal page in his name).
- **Who:** every user; App Review reads the policy URL.
- **Cost:** 0. **Effort:** S (½ day).

### (B) Needs an owner decision

Each item gives the decision, my recommendation and a date.

**B0 — Run this plan as the bounded exception in §2.1** (1.8.0 decided; 1.8.1 only
through the 11-15 slot). *Recommend yes.* By **10-29**. Everything below assumes
it.

**B3 — Classic Echoes (替你出气): retire the tile in 1.8.0.** *Recommend retire.*
Both reviewers agree.
- Refused 22/22 on macOS 27, including 「同事借了我的订书机一直没还」.
- Permissive mode gives 0/12 parseable transcripts.
- It shows a canned transcript without a label, which breaks the labelled-curated
  rule.
- It is visible only in zh-Hans (CN delisted).
- The alternative (A7 minimum): label it with `CuratedNoticeBanner` and stop showing
  its cloud consent.
- It cannot be hidden remotely without also killing the roommate group
  (`RemoteConfig.swift:220-222`).
- By **10-31**.

**B4 — A minimal Taiwan relocalization of two Pro styles (1.8.0).** *Recommend
yes, if the native reader approves the names.* (zh-Hant only; no Japanese work.)
- In zh-Hant only, same ids: 京片兒 → 「台式長輩文」, with a new Worker `hant` voice
  and an on-device zh-Hant preamble.
- Align the zh-Hant labels with the voices the Worker already uses (string-only):
  豆瓣短文 → 「文青日記體」; the MBA 黑話 blurb → 「對焦、綜效、落地」.
- The Worker serves the new voice only when `styleName` is 台式長輩文, so 1.7.x
  clients that still show 京片兒 stay unstyled. Keep the retired names as aliases in
  `style_names.js`. 「24 種風格」 stays true.
- If there is no reader by **11-06**, ship only the label alignment.
- The new Worker voice is its own production deploy (A1 ships before B4 is
  decided); §2.1 allows for it.
- Effort about 1–1.5 days. Decide by **10-31**.

**B5 — One labelled 痛罵 preview for free users (1.8.0 if decided by 10-31).**
*Recommend yes;* both reviewers ranked it among the highest-leverage items.
- After a free user's first successful cloud 發洩, offer once per iCloud account:
  the same situation in 痛罵 with a Pro voice (台劇腔 or 冷處理).
  - labelled as a Pro preview, not saved as a Pro session, never repeated
  - goes through `CloudPermission` and `SafetyFilter`
  - the once-flag lives on the CloudKit-synced `UserSettings`; the decision logic
    lives in Shared so it can be unit-tested
  - no Worker change: Feral with a Pro `styleId` is accepted on the free lane today
- Why: the buyer sees the one Pro generator that works everywhere, on their own
  text, before paying.
- Cost: it bends the "credits never unlock a capability" doctrine. Record it as a
  preview exception, not credits. About $0.00013 per preview.
- Gate (Release build):
  - offered only after a cloud Vent; never for Pro, never without consent
  - offered once, and not again after a reinstall on the same iCloud account
  - the label appears in all 4 locales
- Effort S–M (1 day).

**B7 — Retention Messaging API (no code; Jason's).** *Recommend requesting access
now; low priority.*
- If granted after 1.8.0 is live, upload one true default message per locale for
  Monthly and Yearly. For example, that 痛罵 speaks in your Pro style, and that
  yearly works out to about NT$58 a month.
- No win-back offer.

**The 11-15 slot — at most one item for 1.8.1, chosen by Jason on 11-15, or none
(§2.1).** The agent prepares a one-page brief by 11-14: the stop-rule record, the
US renewal, 1.8.0's review status, the funnel, and each candidate's cost. No code
for any candidate before Jason picks. *Recommendation: if the rule fired, none. If
it passed, or Jason re-approves anyway, B1-R.*

**B1-R — Pro cloud rewrite (改成能發的) on devices without Apple's model.**
*(Gemini 4 Argon's proposal; recommended candidate.)*
- *What it fixes:* on C/E the follow-up to every 痛罵 — the paid feature that is
  real there — returns a canned line unrelated to the draft
  (`RoastEngine.swift:476-479`, `FallbackRoasts.curated`). It is the narrowest way
  to give C/E Pro users "a sendable message in my style, from my own text".
- **Worker** (preview first; production only after 1.8.1 is live):
  - a new `mode:"rewrite"` taking the situation and the draft (each ≤ 1500
    characters), style and locale; **rejected unless `lane=pro`**, with its own
    `REWRITE_DAILY_LIMIT_PRO=50`
  - the prompt ported from `PromptBuilder.rewriteAsSendablePrompt`, plus the
    `style_voice.js` line with a no-profanity override and the Taiwan register for
    hant; "never invent facts"
  - `stripNameAddress`; a zh-Hant Simplified-character check plus one retry
  - a server-side THREAT/SAFE judge call on the output (the device has no model to
    run `threatJudgeInstructions`); THREAT → an error the client shows as labelled
    curated text
  - kill switches: `CLOUD_DISABLED`, a new `REWRITE_MODE_ENABLED` (false until
    1.8.1 is live)
- **Client:**
  - `rewriteAsSendableDetailed` goes to the cloud only if there is no on-device
    model, the user is Pro, **a Pro session token is in hand** (no tokenless
    fallback for this mode), the new restrict-only key `pro_cloud_rewrite_enabled`
    (default false, read only by 1.8.1) is true, and the new consent version is
    granted. Never as a fallback after an on-device refusal.
  - `SafetyFilter.validateOutput` and `RewriteThreatScreen` still run on the result.
  - A 403 is treated like a 401 (invalidate the token, retry once) and otherwise
    shows a specific, labelled message — never the generic "try again"
    (`CloudVentClient.swift:62-79, 167-171` handle only 401 today).
  - A versioned consent before the first cloud rewrite. The old copy promised the
    rewrite never leaves the device (zh-Hant.lproj:20, :136; en.lproj:20, :136), so
    the existing Vent grant does not cover it.
  - Copy in 4 locales: `onboarding.privacy.body`, `settings.about_ai.body`, the C/E
    paywall row, the privacy policy (A9's page), App Privacy answers re-checked
    (Jason). `cloud.consent.footnote` stays true (Composed/Sharp/Savage don't move).
- **Gate:** ≤ 25 preview calls: 12 real Feral drafts (zh_TW 6, en 3, ja 3), 8 threat
  drafts, 5 self-harm / PII / slur bait. 0 threats, slurs or names reach the
  output; 0 Simplified in zh-Hant; 100 % strict pass; p90 ≤ 8 s; 403 without a
  token; native reader ≥ 8/12 usable. Client: an end-to-end Release check against
  a **preview** Worker with `ALLOW_SANDBOX_RECEIPTS=true`, never production.
- **Effort:** Worker S–M (1 day); client M (2–3 days); ~1 hour of Jason's time.
- **Prerequisite:** production Pro tokens are verified to mint (owner task).

**B1-S — Cloud sendable modes for Pro on devices without Apple's model.** *(The
draft's B1; both reviewers called it premature.)*
- *Scope, narrowed by the review:* 沉著 / 銳利 / 狠, Pro styles and 3 versions in
  the **main generator only** (`mode .roast`). Reply Helper, Emotion Translator
  and Social Roast keep the honest "needs Apple Intelligence" state on C/E — the
  Worker has no reply/translate/social modes, and `FeatureGenerator` would
  otherwise send them down the roast prompt behind the Vent consent sheet. Thread
  continuations (`priorContext`, never sent to the cloud) stay on-device.
- **Worker:** reject `mode:"roast"` unless `lane=pro` (`ROAST_DAILY_LIMIT_PRO=50`);
  inject the `style_voice.js` lines into `buildRoastSystemPrompt` (`:757-759`) with
  the sendable override; split the safety examples by script (`:744`); zh-Hant
  Simplified check plus one retry; `stripNameAddress` and a placeholder strip per
  variant; "never invent facts"; ja in the second person.
- **Client:** a new key `pro_sendable_cloud_enabled` (plus `_locales`), default
  false, read only by 1.8.1, AND-ed with a new versioned `SendableCloudConsent`
  naming 沉著/銳利/狠, the styles, 3 versions, OpenRouter and the model provider,
  and saying it applies only without Apple Intelligence; token-in-hand routing and
  403 handling as in B1-R; the CI guard keeps `cloud_sendable_enabled` false and
  the new key false; copy in 4 locales (`cloud.consent.footnote` en:133,
  `onboarding.privacy.body` en:20, `settings.about_ai.body` en:136), paywall rows,
  product page, privacy policy; kill switches: the client flag,
  `ROAST_MODE_ENABLED`, `CLOUD_DISABLED`.
- **Gate:** lens 2's 18 cells plus 6 adversarial (≤ 25 preview calls): 0/9 zh-Hant
  cells with Simplified; ≤ 1/9 with mainland words; 台劇腔 recognisable blind in
  3/3 locales; 0 names; 0 invented facts (hand-read); 100 % strict pass; 0
  profanity; exactly 3 variants 18/18; p90 ≤ 12 s; 6/6 adversarial declined or
  kept safe; 403 without a Pro token; native reader ≥ 8/12 usable. Client e2e
  against a preview Worker only.
- **Effort:** Worker S–M (1 day); client M–L (4–6 days); ~1 hour of Jason's time in
  ASC. **Prerequisite:** token minting verified.

**B2 — Open the roommate group (虛擬室友群) to zh-Hant.** *(Gemini 3.8 Flash's
proposal; candidate.)*
- For: the one Pro Explore format that runs in the cloud on every device; zh_TW
  output already parses 8/8 (lens 4).
- Against, measured: 8/8 zh_TW transcripts contain Simplified; 0/4 Feral swear;
  zh-Hant has 0 of the 29 `echoes.*` strings, including the consent sheet, so it
  **does** need consent and copy work; the persona lookup repeats the region-only
  bug; its bridge sends users to 狠, which is canned on C/E. It reaches about 1 TW
  install every 3 weeks.
- Gate (replaces v1.7 §5's audience gate, which cannot fire): 20 zh-Hant scenarios;
  parse-fallback ≤ 10 %; **0 Simplified characters anywhere**; mainland markers
  ≤ 2/20; a swear word in ≥ 80 % of Feral transcripts; a native reader ≥ 4/5;
  restrict-only `roommate_group_locales`.
- Effort: Worker 0.5–1 day; binary 3–4 days. Requires A7 live.

**B8 — Lifetime Pro.** The owner said "decide after 11-15" (10-22). *Candidate for
the slot; no recommendation before the 11-15 data.* A lifetime purchase counts as a
new start (§2.3). Whether the account's first non-consumable must ship with a
binary is UNVERIFIED (assume yes, so it would be 1.8.1's slot).

### Owner tasks (Jason's, not the agent's)

- Decisions: B0 by **10-29**; B3, B4, B5 by **10-31**; the 11-15 slot on **11-15**.
- **Before 1.8.0 is submitted (~11-12):**
  - ASC web UI: edit the Pro Monthly and Yearly subscription descriptions so none
    says "Unlimited generations" / 「無限生成」 (the API refuses while ACTIVE).
  - Approve the privacy-policy diff (A9) before it is pushed; check the OpenRouter
    account privacy setting.
- **A native Taiwanese reader,** one person for about an hour, before submitting
  1.8.0 (about 11-08), and again before 1.8.1 if a slot is chosen. The agent
  prepares blind sheets; Jason asks and sends; the agent never messages anyone.
  With no reader by 11-06, ship on the machine gates and record the gap.
- **An iOS 27 iPhone check** of the 1.8.0 TestFlight build, about 10 minutes, with
  a script. It covers A3, A4 and A5, and an iOS 26 device too if one is at hand.
- **If a cloud slot item is chosen (B1-R or B1-S), verify that production Pro tokens
  mint.** Either:
  - fix the Datadog connector and count `/v1/auth` outcomes and `lane=pro`
    requests since 10-04 (counts only, never one person's requests), or
  - redeem one of his own unused offer codes on his own Apple ID (a $0 production
    transaction), use Feral once while watching `wrangler tail`, then cancel the
    subscription.
  - App Privacy answers, if a cloud slot item ships.
- Unchanged: P2.1 posts (Threads, Dcard, PTT, as drafted in
  `docs/distribution/2026-10-23-p21-posts.md`) and creator batch 2, each send
  confirmed; topping up OpenRouter by hand (below $5 during this plan's evaluations,
  otherwise below $2).

## 4. Sequencing (dates are targets; the bounds in §2.1 are not)

| when | what | gate / output |
|---|---|---|
| 10-28 (day 1) | Fix the absolute paths in `docs/evidence/2026-10-27-v18-plan/harness/` (copied 10-27, §7.1); rebuild the safety set; re-run the baselines | baselines in the evidence dir |
| 10-28 → 10-30 | **A1** in preview → gate → production deploy (plus A9's Worker option if Jason's check is done and the preview passes) | version id + rollback in the handoff |
| 10-29 | Owner: B0 | — |
| 10-31 | Owner: B3, B4, B5 | — |
| 10-28 → 11-10 | **1.8.0** build: A2–A8 + approved B3–B5 | each item's gate |
| 11-02 → 11-06 | **A9** policy diff → Jason approves → push to the Pages repo | claim checklist |
| 11-04 → 11-06 | Read the US renewal (SUBSCRIPTION_EVENT filtered to 6769317103; r320) | record it |
| ~11-08 | 1.8.0 TestFlight → Jason's iOS 27 iPhone check; native reader pass | — |
| by 11-11 | Jason: ASC subscription descriptions edited (submit gate) | — |
| **11-12** | **Submit 1.8.0** (build 27), iOS + macOS | preflight green on `RoastMate-UITests`; Release checks with a v1.7.2 control; codesign probe first |
| 11-14 | One-page 11-15 brief for Jason | — |
| **11-15** | **v1.7 stop rule read**, recorded word for word → **Jason fills the slot or not** | — |
| 11-16 → 11-19 | If a slot item was chosen: its Worker gate in preview | gate result |
| 11-19 → 12-02 | 1.8.1 build (the slot item), plus fixes from 1.8.0 review | item gates |
| **12-03** | **Submit 1.8.1** (build 28), if any | — |
| after 1.8.1 is live | Worker flag on for the slot item + its flag in the remote config; 5-call smoke test | rollback = flag false, then `wrangler rollback` |
| **12-05** | **Code freeze** for this plan | — |
| 12-15 | Read 1: rerun the product gates against the shipped builds; read the ASC events | — |
| **2027-01-31** | **Final read**: §2.3 success or kill | — |

**If 11-12 is at risk, drop in this order:** the macOS screenshots → A8 → B4 (the
string-only part stays) → A5's near-duplicate regeneration → A6's auto-run.
**Never drop** A2, A3's screens, A6's sample fix, A7 or A9.

Effort: 1.8.0 is about 10–13 agent-days with everything approved. A slot item is
3–7 more.

## 5. Cut list (with reasons)

| cut | why | what would revive it |
|---|---|---|
| Private Cloud Compute | Doesn't reach C/E; no entitlement key in the app; guardrails can't be configured; a per-user quota conflicts with "unlimited"; a fee is announced | A signed build that gets the entitlement and the native reader judging A3's quality insufficient → a 1-hour signed TestFlight probe |
| Retuning Savage and style prompts against the OS 27 model to avoid refusals | A3 removes refusals at S cost; retuning recurs with every model release and may not converge (10-22 challenge) | App Review rejects A3 |
| Cloud Argument Simulator (`mode:"argue"`) | M effort; more user text leaves the device; needs a cloud consent first. C/E gets an honest state instead (A4) | A later plan, after a cloud slot item has run without a kill |
| B6: an "on-device model present" field in Worker logs | Both reviewers: at ~3 installs a week it takes months; it cannot inform the 11-15 decision (1.8.0 goes live ~11-14); the privacy policy's exact wire-field list would have to change | A future cloud decision that needs the device mix |
| A separate OpenRouter key or reserve for Pro traffic | Spend was $0.07 over two weeks including investigations; abuse is bounded by the 30/day device, 200/day Pro and 8/day web caps; the weekly balance check stays | Spend above $1 a week |
| Lifetime Pro in 1.8.0 | The owner set "after 11-15"; it is now an 11-15 slot candidate (B8) | — |
| A "copy for LINE" button | Every card already has a copy button (`RoastCard.swift:73-76`); a LINE-formatted share is a new surface | A later plan |
| Feral multi-take (2–3 drafts) | A new surface; Pro has no credits, so tapping again already gives another take | — |
| Classic Echoes moved to the Worker | B3 retires it | — |
| Wider Taiwan style shelf (懶人包體, 存證信函體, PTT 鄉民體, `localesSupported` filtering, reordering) | Value is a guess; needs native taste; PTT slang carries slur risk; touches many surfaces | A native reader plus some evidence of style use (there is none; telemetry is local and opt-in) |
| Credit-ladder changes (reprice or remove packs, credits buy 痛罵, a 30-day pass) | 1 pack ever sold; reverses a doctrine; could cannibalise the one subscriber; unreadable at this volume | — |
| Trial on Monthly | The TW buyer paid NT$90 and cancelled; a trial would have made that $0 (10-22 synthesis #8) | — |
| Win-back offer | One lapsed user; a courtesy, not an experiment | — |
| Server-side Pro gating of Feral | Not payer-facing; would break Pro users if token minting is broken | After the token check, reconsider |
| More history (unlimited, "situation memory") | Free users rarely reach 30; threads are already free | — |
| Simplified → Traditional converter | Recorded cut (v1.7 §6; 10-22 challenge); doesn't fix vocabulary | — |
| Echoes / roommate in en and ja | No signal | — |
| Third-party analytics or SDKs | Never | — |

## 6. Guardrails (the ones that apply, restated)

From v1.7 §8, unchanged:
- Never render the raw vent on a shareable image.
- `RoastEngine.generate(cloudVentEnabled:)` stays defaulted to false. Anything that
  spends a credit uses `generateDetailed` and checks provenance.
- One home per rule: `CloudPermission`, `CloudVentService.generate(_:auth:)`,
  `GeneratedRoastKind.isShareable`, `Redactor.maskToken`,
  `AppLanguage.contentBucket`, `CuratedNoticeBanner`.
- CJK: an **unpaired term** is the bug class (it has shipped three times). Every
  new string, preamble, example and style name is paired across the locales and
  guarded by the parity test.
- Copy must describe what the code does **on every device the app ships to, per
  locale and per style.** Compute counts in code; don't type them. **The privacy
  policy and the ASC subscription descriptions are copy too.**
- Debug is always Pro. Verify the paywall, trial, hand-off, preview and consent
  only in Release (`ENABLE_TESTABILITY=YES`), with a control on the previous tag.
- No third-party SDK. Never flip `cloud_sendable_enabled`. Never post or send
  anything in Jason's name without his confirmation of the exact text and
  destination.

New for this plan:
- **Any new cloud path** needs: a new flag read only by new binaries, a new
  versioned consent, an App Privacy review, a CI guard, a kill switch, a
  server-side Pro check and token-in-hand routing on the client (no silent
  tokenless fallback that ends in a 403). It is used **only when there is no
  on-device model, never as a fallback after an on-device refusal.**
- **Permissive guardrails** are never used without all of: the refusal-text check,
  the phrase screen, the threat judge (one call per message) and `SafetyFilter`.
  The labelled curated floor stays. A session key never spans guardrail modes.
- **Logic under test lives in `Shared/`.** `RoastMateTests` is a hostless bundle
  that cannot see app-target types (`project.yml:229-236`); view behaviour is
  checked in Release builds or `RoastMateUITests`.
- **Every prompt change** runs the harness before and after: the on-device probe,
  plus `compare_ext.mjs`, the style gate and the cloud harness for the Worker.
  Record the numbers under `docs/evidence/`.
- **Every Worker deploy** records the new version id and the rollback command in
  the handoff.
- Never name competitors in store copy.
- Machine rules: reuse simulators; use one disposable iOS 18.5 device and delete
  it afterwards; never stop a UI-test run without shutting its simulator down; one
  heavy job at a time.
- Scope: an idea that isn't in §3 goes to §8 for the next plan. It does not get
  built.

## 7. Measurement plan

**7.1 Harness (product realness and safety).** Copied into the repo on 10-27:
`docs/evidence/2026-10-27-v18-plan/harness/` (sources and results; no compiled
binaries; raw ASC TSVs left out — `lens3/*.py` re-fetch them). The scripts still
carry absolute scratchpad paths at the top: fix those first.
  - `audit/probe/` (`main.swift`, `Stubs.swift`, `analyze.py`): on-device Savage,
    Sharp-Pro, 3 versions and simulator
  - `audit/argument_roles.json`: the role rubric
  - `lens2/roast_gate.py`, `lens2/score_gate.py`, `lens2/fmb/`: the Worker roast
    gate and permissive on-device probe
  - `lens4/rm_probe.py`, `lens4/rm_analyze.py`, `lens4/echoprobe/`: roommate and
    classic Echoes
- **The safety set** (new, in the repo): `harness/safety_set.json` with at least 24
  threats (12 of them veiled, e.g. 「我在你家楼下等你」, "I'll be waiting near your
  car"), 24 legitimate complaints that describe harassment, racism or violence,
  self-harm, PII/doxxing and slur bait, in zh_TW and en (ja for A3). The 10-22
  held-out set lived in a scratchpad that is gone; seed it from
  `RewriteThreatScreenTests.swift` and the examples in `RoastEngine.swift:528-531, 576-591`.
- Alongside them stays the existing `docs/evidence/2026-10-22-churn-and-fixes/harness/`
  (cloud, worker-compare, on-device).

Run it:
- before each binary submit (on this Mac, macOS 27, Apple Intelligence on)
- after each Worker deploy
- at the 12-15 read
- at every Apple OS or model release (it is the regression set for A3 and A5)

The metrics and targets are in §2.2. Store every run's summary in the evidence dir.

**7.2 Payer outcomes (App Store Connect, read-only; no new collection).**
- weekly `python3 scripts/asc_analytics.py --since 2026-11-14`
- SUBSCRIPTION_EVENT (Days Before Canceling, trial starts and conversions), always
  filtered to App Apple ID 6769317103 so ColorArchive doesn't mix in
- r320 (cancel-sheet events)
- r226 (subscription state)
- first-time downloads since 1.8.0, for §2.3's denominator

Apple's session, crash and deletion reports are not generated below 5 contributing
users, so don't wait for them.

**7.3 Worker logs (Datadog; existing fields).** Weekly counts by mode × intensity ×
locale group × outcome. Once a cloud slot item is live, add its volume, 403s and
spend. **Never read per-request `lane=pro` lines for one person.** The Datadog
connector failed on 10-22 and 10-27; fixing it is Jason's.

**7.4 Spend.** Check the OpenRouter balance weekly (the scheduled task plus
`scripts/openrouter-balance.sh`). Keep an evaluation-spend ledger in the evidence
dir with one line per gate run; stop at $2 in total.

**7.5 What we cannot measure, so must not claim:** why a payer stays or leaves;
which styles people use; any causal link from one item to a renewal. With 1–3
buyers a month, §2.3 is a sanity check on direction, not an experiment.

## 8. Open questions

1. **Device mix:** what share of payers and prospects are on C/E? Nothing in this
   plan measures it (B6 cut); the 11-15 slot is decided without it.
2. **iPhone on iOS 27:** is the refusal behaviour, and A3/A4/A5's effect, the same
   as on macOS 27.0.1? Only the Mac was measured. **iOS 26** Pro-style refusal
   rates were never measured.
3. Will App Review accept permissive guardrails for *generating* replies, beyond
   1.7.1's rewrite?
4. Does production `/v1/auth` mint Pro tokens? If not, Pro users silently run on
   the free 30-a-day lane today, and any cloud slot item's Pro-only check would
   lock them out.
5. Current App Privacy answers: is "User Content → App Functionality" already
   declared for Vent?
6. Native readers: zh-Hant for A2, B4 and any slot item; Japanese for Feral (lens 1
   found its grammar awkward; UNVERIFIED).
7. Is the yearly trial actually offered to Taiwan Apple IDs on the real purchase
   sheet? Only a Release or TestFlight build can show it.
8. Are the P2.1 posts published by 11-15? That decides which branch of the stop
   rule applies.
9. Does the US payer renew around 11-04? Read it from ASC only. Do not read their
   Worker usage.
10. PCC: does a signed build actually get the entitlement the Aug-30 log mentions?
    Small Business Program enrollment: the "15 % commission" in the cost math
    assumes it.
11. Should free C/E users ever get a cloud sendable path, for example metered by
    credits? Out of scope here; listed for the next plan.
12. Watch item: 幹 is the swear word in 8 of 10 zh_TW Feral drafts
    (`cloud_feral_scores.txt`). Is that a template a repeat user will notice? Track
    it in the cloud harness; no action unless the native reader flags it.
13. Does the OpenRouter account already exclude providers that train on or keep
    prompts (A9)? Only Jason can see the setting.
14. Does macOS show a localized app name from `InfoPlist.strings` without more
    keys (A8)? Check the built bundle.

## 9. Review synthesis — Gemini 4 Argon (High) + Gemini 3.8 Flash (High), 2026-10-27

Both via `agy` with read access to the repo and the same prompt, answered
2026-10-26 16:06–16:08Z (verbatim in `review-gemini4argon.md`,
`review-gemini38flash.md`). **Both: SHIP-WITH-CHANGES.** Every point that would
change the plan was re-checked against the code, the live services or the
evidence before it was applied. Advisor citations are leads, not evidence.

| # | source | point | disposition and reason |
|---|---|---|---|
| 1 | Both | The plan bypasses the stop rule: 1.8.1 pre-committed through 12-05, "11-15 doesn't change scope", verdict pushed to 01-31 | **Partly accepted.** 1.8.0 stays (the owner's 10-27 decision; it ships before 11-15). 1.8.1 is no longer pre-committed: one slot, filled by Jason on 11-15 with the stop-rule record, default none if the rule fired (§2.1). Not accepted: Flash's "drop 1.8.1 entirely" — taking the option away from the owner isn't the plan's call |
| 2 | Both | B1 (cloud sendable modes on C/E) is premature for ~3 installs a week | **Partly accepted.** Nothing of B1 is built before 11-15; it survives only as candidate B1-S, narrowed by #9. The C/E share of payers is unknown and can't be measured in time — the reviewers' point stands |
| 3 | Both | A3's permissive retry through `respondCached` would silently reuse the default session | **Accepted, verified.** `AppleFMBackend.swift:32-45` builds `LanguageModelSession(instructions:)` on the default model and reuses it while `keepSession` and the key match; the key (`RoastEngine.swift:305`) has no guardrail part. A3 now retries through `respondFresh` (:48-55), and A4 is made stateless per turn so the fresh session loses no context — a consequence neither reviewer named |
| 4 | Argon | Batching 3 variants into one threat-judge call misfits a judge built for one message | **Accepted, verified** (`RoastEngine.swift:550-591`: single-message instructions, `maxTokens: 4`, measured per message). One call per variant (~270 ms each); simulator-turn false positives measured in A4's gate |
| 5 | Argon | A7 misses the zh-Hant/ja Settings footer and the consent title/allow/deny/label | **Accepted, verified.** zh-Hant.lproj:565-566 and ja.lproj:566-567 say Casual stays on-device; the toggle renders in every locale (`SettingsView.swift:61-73`); the roommate scene needs the grant for both tones and generates nothing without it (`EchoesViewModel.swift:98-118`, `EchoesEngine.swift:205-215`), so "Stay on-device" (en.lproj:566) is false there. A7 now covers 4 locales and all those keys |
| 6 | Argon | A free user who loads a Pro-style sample gets an orange error instead of the paywall | **Accepted, verified.** Sample index 1 is `mba_boss` (Pro) inside the 5 shown (`RoastGeneratorView.swift:492`); `loadSample` has no tier check (`RoastGeneratorViewModel.swift:332-345`); the button checks only intensity (`RoastGeneratorView.swift:283-291`); the guard shows `quota.exhausted.body` (:104-107). Same in `FeatureGenerator.swift:113-116`. Added to A6 and its gate; A8's Pro-style samples wait for it |
| 7 | Both | 3.1.2(c): the billed yearly amount must be the most prominent price; the trial only for eligible users | **Accepted.** A6 already limited the trial to eligible users; it now keeps NT$690/年 primary, resolves eligibility before the row renders, and shows no trial line when unknown |
| 8 | Both | ASC subscription descriptions still say "Unlimited generations" on the StoreKit sheet while `PRO_DAILY_LIMIT=200` | **Accepted.** Verified `wrangler.toml:104`; the sheet text is from the v1.7 handoff (10-22). Now a hard 1.8.0 submit gate (Jason, ASC web UI) instead of an undated owner note |
| 9 | Argon | B1 as drafted mis-routes Explore tools, drops thread context, and can strand a paying user on a silent 403 | **Accepted as B1-S constraints, verified.** `FeatureGenerator.swift:130-174` routes Reply Helper / Emotion Translator / Social Roast through `CloudPermission` + `generateDetailed`; the cloud call always sends `mode:"roast"` with no `priorContext` (`RoastEngine.swift:670-690`); the Worker knows vent/roommate/roast only (`index.js:671-676`); the client falls back tokenless and invalidates only on 401 (`CloudVentClient.swift:62-79, 167-171`) while optimistic Pro can be granted from CloudKit (`StoreService.swift:23, 243-249`). B1-S is now generator-only with token-in-hand routing and 403 handling |
| 10 | Argon | The public privacy policy is false and contradicts B1/B6 | **Accepted in substance; new A9.** Argon read `docs/site/privacy.html`, which is stale (the live site is the separate Pages repo, updated 10-20 to drop Groq). Re-checked on the live page today: it still promises a "gentler" on-device Vent/Feral, says cloud is used "by default", and omits the roommate group and the style id (finding 12) |
| 11 | Argon | OpenRouter calls carry no `provider.data_collection: "deny"` | **Partly accepted, verified** (`index.js:561-578`; no `data_collection` in `src/`). The account-level setting is UNVERIFIED, so Jason checks it first; the request field is added only if a preview shows both models still route (A9) |
| 12 | Argon | A8's display-name work: the Watch isn't shipped; the Mac and extension plists don't localize | **Accepted, verified.** `project.yml:82-102` (Watch in no shipped bundle); `RoastMateMac/Info.plist` carries only `NSUserActivityTypes`; `RoastMateShare/Info.plist:7-8` and `RoastMateControls/Info.plist:7-8` hardcode the name. Whether macOS needs `LSHasLocalizedDisplayName` is UNVERIFIED → checked on the built bundle |
| 13 | Argon | Unit tests on `ArgumentSimulatorViewModel` / B5 are impossible in the hostless test bundle | **Partly accepted.** This draft doesn't require them (Argon's line numbers point at an earlier draft), but the constraint is real (`project.yml:229-236`): new §6 guardrail, and A4/A6/B5 logic goes into `Shared/` |
| 14 | Argon | The 01-31 gate has no traffic denominator | **Accepted.** §2.3 records first-time downloads and starts per download, and labels a window under 40 downloads "traffic-limited"; the consequences stay the same |
| 15 | Both | B6 (`od` field in Worker logs) is premature | **Accepted; cut** (§5). It can't inform the 11-15 decision and would change the policy's exact wire-field list |
| 16 | Flash / Argon | A1 is a distraction aimed at one US renewal / fine but don't chase 11-04 | **Partly accepted.** A1 stays (½ day, every device, every Pro user, all four scripts including hant); 11-04 is no longer its deadline. Flash's "does nothing for Taiwan" is wrong: the hant voice changes too |
| 17 | Flash | Drop A7, it is zh-Hans only | **Rejected.** It is a live 5.1.2(i) accuracy defect, and the false Settings footer renders in every locale (#5). App Review judges the binary, not the market |
| 18 | Flash | Revive the zh-Hant roommate group instead of B1, "without altering consent" | **Partly accepted** as slot candidate B2. The no-consent-change claim is false: zh-Hant has 0 of 29 `echoes.*` strings including the consent sheet, and 8/8 zh_TW transcripts contain Simplified (lens 4) |
| 19 | Argon | Replace B1 with a Pro cloud 改成能發的 rewrite on C/E | **Accepted as the recommended slot candidate (B1-R), verified** (`RoastEngine.swift:476-479` returns curated text without the model). Not as proposed in one respect: it can't just reuse the Vent consent "with updated disclosure" — onboarding and Settings promised the rewrite never leaves the device (zh-Hant.lproj:20, :136), so it gets a versioned consent, and a server-side threat judge because C/E has no on-device model to run one |
| 20 | Argon | Pull Lifetime Pro into 1.8.0 | **Rejected for 1.8.0** — the owner set "decide after 11-15" (10-22). **Partly accepted:** B8 moves from "not before 01-31" to an 11-15 slot candidate, and §2.3 now says how a lifetime purchase counts, so metric hygiene is no longer a reason to defer |
| 21 | Flash | Default to 發洩 on first run when there is no on-device model | **Rejected: already shipped** in 1.7.1 (`Intensity.firstSessionDefault`, `RoastGeneratorViewModel.swift:20-25`, also used by `loadSample` :336-338) |
| 22 | Flash | Add a "Copy for LINE" button | **Rejected.** Every card has a copy button (`RoastCard.swift:73-76`); a LINE-formatted share is a new surface (§5) |
| 23 | Both | B5 (one 痛罵 preview) should be in | **Accepted as a stronger recommendation;** still an owner decision by 10-31 because it bends the credits doctrine |
| 24 | Flash / Argon | B4 matters for Taiwan / cut B4's "Japanese voice work" | Flash **accepted** (B4 unchanged). Argon **rejected**: B4 has no Japanese work; it is zh-Hant only |
| 25 | Argon | May-era macOS screenshots are a 2.3.x rejection risk | **Partly accepted.** Not a blocker — macOS 1.7.0–1.7.2 passed review with them — but added to A2 as the first optional item to drop |
| 26 | Both | The $9.88 hard cap is a single point of outage; separate Pro key; B1 retries cost more | **Partly accepted.** The weekly check stays, with "below $5 → Jason tops up" during evaluations. A separate key is cut (§5): $0.07 spent in two weeks, every lane capped, retries limited to one |
| 27 | Flash | Permissive generation risks Guideline 1.2 | **Accepted as already covered** (screens, safety gate, kill flag, reviewer note), strengthened by #4 and the rebuilt safety set |
| 28 | Argon | Taiwan distribution (Threads, IG, Dcard, PTT) must run now | **Accepted as Jason's parallel work** (unchanged; the posts are drafted) |
| 29 | Flash | 1.8.0 on 11-12 collides with 11-15 if it slips | **Partly accepted.** Moot once 1.8.1 isn't pre-committed; a submit later than 11-19 now means no 1.8.1 at all |
| 30 | Citations | Argon: `lane.js:52-60` is past the file's end; the PCC entitlement was recorded as granted. Flash: the en Groq consent body is at :564, not :563 | Argon's two **accepted** (`lane.js` has 55 lines, the free lane is :46-54; the PCC wording now cites `evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md:4` and notes the app has no entitlement key). Flash's **rejected**: en.lproj:562 is the title and :563 is the body |

**Found while checking, not raised by either reviewer:**
- The draft misstated the stop rule's second branch. It stops only if downloads
  are < 5 a week **and** there is no new paying subscriber (`DEV_PLAN_v1.7_2026-10.md`
  §7); fixed in §2.1.
- The 10-22 held-out threat set that A3's gate relied on is gone with its
  scratchpad. §7.1 now rebuilds a safety set in the repo first.
- The policy's "by default" wording (finding 12).
- The draft capped Worker deploys at 2 while needing 3 (A1, B4's voice, B1's
  turn-on); §2.1 now names the three.

**Citations, checked.** Flash's code citations held except en.lproj:563. Argon's
substance held on every point above, but several line numbers did not: the trial
string is at zh-Hant.lproj:173 (not :136, which is `settings.about_ai.body`), the
curated paywall copy is at :158/:179 (not :326/:331), and its references into
this plan (a "unit test on ArgumentSimulatorViewModel" at :402, B8 at :677-686)
match an earlier draft, not this one.
