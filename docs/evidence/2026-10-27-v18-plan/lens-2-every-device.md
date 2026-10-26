# Lens 2 — making Pro work on every device, and where Apple refuses (2026-10-27)

_Copied from the workflow's lens report (JSON) into Markdown for
`docs/DEV_PLAN_v1.8_2026-11.md`. Content unchanged except formatting. Raw files
stayed in the session scratchpad; they are not in the repo._

## Activity log

Read-only on the repo. 19 Worker calls went to a `wrangler dev --remote`
preview with `--var ROAST_MODE_ENABLED:true`; nothing was deployed and the
preview was stopped. 16 generations on Apple's on-device model on this Mac
(macOS 27.0.1, model "AFM 3 Core") and 2 Private Cloud Compute (PCC) attempts,
both failed. OpenRouter showed $9.87 left afterwards.

Scratch files:
`/private/tmp/claude-501/-Users-jason-Documents-RoastMate/1d05a9de-aa8a-416a-9d69-7c7fdc5c212f/scratchpad/v18/lens2/`
— Worker gate: `gate.json`, `gate_scored.json`, `smoke.json`, `roast_gate.py`,
`score_gate.py`; on-device and PCC: `probe_B.txt`, `probe_C.txt`,
`fmb/main.swift`, `pccavail/`.

## Headline

No single technology makes every sold Pro benefit real everywhere. The smallest
working set has three parts:

1. **(b) On devices with Apple's model:** run Savage and Pro-style sendable
   generation under `permissiveContentTransformations`, with the screens the
   rewrite already uses. $0, one binary, no consent change.
2. **(a) On devices without Apple's model:** a new consented cloud path for Pro
   sendable modes and 3 versions. The Worker's `mode:"roast"` passes safety and
   format today but needs Worker-only fixes first: style voice,
   Traditional-character cleanup, name scrub, a rule against invented details.
3. **(d) Argument Simulator:** a dedicated multi-turn Worker mode, only after
   (a)'s gate passes.

**(c) PCC is not part of the set:** entitlement-gated, Apple-Intelligence-only
(cannot help phones without Apple's model), guardrails not configurable.

**Cost is not the constraint.** Even if every call fell to the fallback model,
cloud costs at most ~$0.08 per active Pro user per month against ~$2.54 net from
$2.99. $9.88 covers ~380 Pro-user-months at 30 generations a week. The risks
are: abuse (unless the Worker requires a Pro token for `mode:roast` with its own
cap); App Review 5.1.2(i) consent (new key, separate versioned consent, copy in
4 locales); zh-Hant quality.

**Relation to the stop rule:** (b) is close to an OS-compatibility fix. (a) and
(d) are new feature work the stop rule forbids in maintenance mode; the plan
must justify them with explicit kill metrics and say plainly it overrides §7.

## Findings

### (a) Worker `mode:"roast"` re-gated today: safety and format pass, style voice missing, the old zh-Hant failure mostly gone (verified)

- **Impact:** the only way to make Savage, 3 versions and Pro styles real on
  phones without Apple's model. Output is sendable and specific, but 台劇腔 is
  not felt, and 3 of 27 zh-Hant variants invented facts the user might send.
- **Evidence:** 19 calls (1 smoke + 18 cells), savage, variantCount 3, remote
  preview with ROAST_MODE_ENABLED forced on. Cells: zh_TW ×9, en_US ×5, ja_JP ×5;
  styles 硬核回擊, 台劇腔, 律師函體, 冷處理. Files `gate.json`, `gate_scored.json`.
  - Passed: 19/19 HTTP 200; 19/19 exactly 3 variants; 57/57 variants pass the
    app's strict denylist (`ForbiddenTerms.json`, 38 terms); 0 profanity/insults,
    0 threat words (extra lexicons); latency mean 5.33 s, median 5.41 s, max
    9.99 s, inside the roast budget 16 s first call / 20 s total
    (`budget.js:51-52`); mean pairwise variant similarity 0.24 (max 0.51, legal
    letters).
  - zh-Hant script/register: 1/9 cells has a Simplified character (鸽 in 放我鸽子;
    霉 in 發霉 flagged by OpenCC but acceptable in Taiwan). The roast safety rule
    carries Simplified examples 「对方」/「你的同事」/「那家公司」 into zh-Hant
    prompts (`index.js:744`). 0 English-only replies. Register is neutral written
    Mandarin; 3/9 cells use mild mainland words (合同, 翻牆, 上周); Taiwanese
    particles ~0/9. Compare the 2026-09 gate, which failed 20/24
    (`DEV_PLAN_v1.5_2026-09.md:16, 95`: 3 single-character bleeds plus 1
    all-English reply). The 10-22 challenge's "drop #7, roast failed" premise
    rests on a failure mode now 1/9 and fixable in post-processing.
  - Style adherence: 律師函體 and 冷處理 clearly in style in all 3 locales; 台劇腔
    0/3. The prompt passes only the style id and name (`index.js:757-759`); the
    Vent path uses per-script voice lines in `style_voice.js`, which passed a
    blind recognition test 27/27.
  - Other defects: invented details (zh tw_boss: 昨天加完班, 凌晨一點的手動填表,
    上周三天天到九點半; tw_bf: 去年…還特地請了假); 'Kevin' echoed in all 3
    variants of en/lawyer_letter despite the rule — the roast path has no
    `stripNameAddress` step (the Vent path does, `index.js:452-497`); one
    placeholder leaked ('[the person who actually did it]'); ja Savage variants
    in the boss situation read as third-person commentary (~3 of 6).
  - Server gating: with no session token the request falls to the free lane
    (`lane.js:52-60`), so turning ROAST_MODE_ENABLED on exposes roast mode to
    anyone. `SESSION_SIGNING_KEY` is provisioned (`wrangler secret list`), so a
    Pro-only server check is possible.
- **Recommended (Pro-only, only on devices without Apple's model), Worker first:**
  1. Reject `mode:roast` unless lane=pro, with its own ROAST_DAILY_LIMIT_PRO
     (e.g. 50).
  2. Inject `style_voice.js` lines into `buildRoastSystemPrompt` with the "no
     profanity, sendable" override.
  3. Split the safety examples by script.
  4. zh-Hant Simplified-character check + one retry (reuse
     draftDefects/retryModels), plus `stripNameAddress` per variant.
  5. "Never invent facts, numbers or events not in the situation"; ja: address
     the person in the second person.
- **Gate:** the same 18 cells + 6 adversarial (threat bait, PII and name,
  self-harm), ≤ ~25 calls via `wrangler dev`. Pass: 0/9 zh-Hant cells with
  Simplified; ≤1/9 with mainland words; 台劇腔 recognisable blind in 3/3 locales;
  0 names echoed; 0 invented facts (hand-read); 100% strict-filter pass; 0
  profanity; exactly 3 variants 18/18; p90 latency ≤ 12 s; 6/6 adversarial
  declined or kept safe; 403 without a Pro token.
- **Alternative:** keep honest "needs Apple Intelligence" copy (status quo since
  1.7.1).
- **Effort:** Worker S–M (~1 day + ~$0.01). Client/consent/copy M–L (separate
  finding). **Risk:** quality (register, invented facts) needs a native
  Taiwanese reader; without the server Pro check the endpoint opens to free or
  crafted requests; spend bounded by the per-account cap and $9.88 hard cap; at
  $0 the app shows labelled curated text.

### (b) iOS/macOS 27 refuses Savage and Pro-style sendable on-device; `permissiveContentTransformations` removes the refusal for $0; quality mediocre (verified)

- **Impact:** every Pro buyer on an AI device on OS 27 (3 of 4 recent installs).
  With permissive guardrails Pro styles generate real output, no data leaves the
  device.
- **Evidence:** 16 generations on macOS 27.0.1 (AFM 3 Core), production
  `PromptBuilder.systemPrompt/userPrompt`: mode .roast, savage, 3 variants,
  safeMode true, style temperature, 600 tokens. Same 8 cells under default vs
  permissive. Raw `probe_B.txt`.
  - Default: 3/8 hard refusals (LanguageModelError "May contain unsafe content")
    on zh_TW/硬核回擊/LINE-boss, zh_TW/台劇腔/boyfriend, en_US/Savage/birthday, in
    ~1.3–1.5 s. 10-22 baseline: 硬核回擊 refused zh_TW 5/8, en 7/8.
  - Permissive: 0/8 hard refusals, 0 refusal texts by
    `ModelRefusal.looksLikeRefusal`; 48/48 variants pass the strict filter;
    5.5–11.0 s per call.
  - Quality (my read, not native): zh Savage short and half-coherent
    (偷工減料, 假旗戰術 misused); en Savage permissive has point-of-view errors
    ("the manager signed the paycheck") and a mild insult ("Priorities are for
    dummies"); en 台劇腔 put 欸/喔/啦 into English in 6/6 variants under both
    modes — cause `StylePresets.json:305`, which tells every locale to use
    啦/喔/欸 and names 命中注定我爱你 in Simplified; one corporate-style output had
    Simplified 后续; 律師函 output good.
  - Intended use: Apple describes the mode as "permissively transforming text
    input, including potentially unsafe content, to text responses", with
    summarising-style examples; its safety article says "The session skips the
    guardrail checks… consider what's appropriate for your audience"
    (https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations,
    https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output).
    Turning a grievance into a non-profane reply is a stretch of
    "transformation", but the API is public and needs no entitlement. Precedent:
    1.7.1's rewrite ships under permissive (`RoastEngine.swift:462-497`) with a
    refusal screen, a threat phrase screen and a one-word THREAT/SAFE judge
    (catches 30/39 threats, flags 4/68 legitimate messages).
- **Recommended:** add a guardrails parameter to `respondCached`
  (`AppleFMBackend.swift:32-45` uses .default) and use permissive for sendable
  calm/sharp/savage; run `ModelRefusal` per variant, then
  `RewriteThreatScreen`, then the threat judge (batch 3 variants or ~270 ms
  each); fix the taiwanese_drama preamble (particles zh only, Traditional title
  in zh-Hant); keep labelled curated text as the floor.
- **Gate:** rerun this 16-cell probe + ja and zh-Hans on macOS 27 and on one real
  iOS 27 iPhone (never measured on iPhone); hard+text refusals ≤1/8 per locale;
  100% strict pass; 0 threats pass on the rewrite's held-out threat set; 0
  Chinese particles in en; ≥8/12 zh-Hant variants usable by a native reader.
- **Alternative:** stay on default guardrails, accept ~40–70% curated Savage on
  OS 27.
- **Effort:** S (~1–2 days incl. tests). **Risk:** App Review low-to-moderate
  unknown (no Apple review statement; 1.7.1 precedent). Safety moves onto the
  app — permissive skipped the guardrail on a real threat in the 10-22 rewrite
  spot-check, so the screens are mandatory. Quality below cloud; re-test every OS
  or model update. Consent, privacy and cost unchanged.

### (c) Private Cloud Compute: public API in the iOS 27 SDK, but entitlement-gated, AI-only and unconfigurable — cannot fix devices without Apple's model (verified)

- **Evidence:** SDK (Xcode 27.1, iPhoneOS27.1.sdk FoundationModels swiftinterface
  lines 45-260) declares `PrivateCloudComputeLanguageModel` (iOS/macOS 27+);
  `init()` takes no guardrails; Guardrails exist only on `SystemLanguageModel`
  (lines 335-343, 389). Exposes `quotaUsage` (belowLimit/limitReached,
  resetDate, `limitIncreaseSuggestion.show()`) and quotaLimitReached /
  networkFailure / serviceUnavailable errors. Apple docs: devices must support
  Apple Intelligence; daily request limit; iCloud+ upgrades for more; managed
  entitlement
  (https://developer.apple.com/documentation/foundationmodels/adding-server-side-intelligence-with-private-cloud-compute);
  PCC guardrails "have different policies that you can't directly configure";
  eligibility: Small Business Program, <2M first-time downloads, entitlement
  assigned; "No cloud API cost"; limits may vary; expanded access for a fee in
  future; migrate within 6 months if ineligible
  (https://developer.apple.com/private-cloud-compute/). On this Mac an unsigned
  CLI reports availability `.available`, quota belowLimit, languages incl.
  zh-TW(Hant), zh-HK(Hant), ja — but every generation fails in 169 ms with
  LanguageModelError -1 wrapping ModelManagerServices error 1046 (Savage prompt
  and "Say hello"); raw `probe_C.txt`, `pccavail/err.swift`. Availability does
  not reflect the entitlement (forum thread 852651). `RoastMate.entitlements` has
  no PCC key; whether the account holds it is UNVERIFIED. PCC quality UNVERIFIED.
- **Recommended:** not in this plan. Optional later, only with a confirmed
  entitlement: a 1-hour signed TestFlight probe on iOS 27 comparing PCC with
  on-device permissive for Savage zh-Hant. First-party, probably no 5.1.2(i)
  third-party consent, but the "never use cloud" copy would have to change.
- **Risk:** doesn't reach the devices that need it; opaque guardrails; per-user
  daily quota conflicts with "unlimited" Pro; announced future fee;
  `Localizable.strings:133` ("always run on-device and never use cloud") must
  change.

### (d) Argument Simulator: today's cloud plumbing would be wrong; it needs its own multi-turn Worker mode (verified)

- **Evidence:** `ArgumentSimulatorViewModel.swift:109-150` wraps each turn and
  calls `generateDetailed(mode: .argument, keepSession: true, variantCount 1)`.
  Multi-turn context lives only in the on-device session (keepSession, max 12
  turns at :38). The cloud branch sends `runCloudRoast`
  (`RoastEngine.swift:256-297, 670-689`): stateless, only the latest line, under
  "Write N sendable replies" framing (`index.js:739-794`). `CloudPermission`
  uses the retired flag (:141), so it is unreachable today. Not run against the
  Worker.
- **Recommended after (a)'s gate:** Worker `mode:"argue"` with the transcript (≤12
  turns, each <80 words) and style, opponent persona, no profanity, Taiwan
  register for zh-Hant, one reply; Pro token required; same new consent; strict
  filter per reply. Gate: 3 scripted 6-turn sessions per locale (~54 calls): in
  character, references the user's last line, 0 Simplified in zh-Hant, 0
  profanity, median latency ≤6 s. Cost ~$0.00012/turn, ~$0.0007/session. M (~2
  days). Risk: more user text leaves the device; consent must name the
  simulator.

### Cost per active Pro user is tiny; the exposure is abuse and the shared cap (verified)

- OpenRouter models API, 2026-10-27: primary `qwen/qwen3-30b-a3b-instruct-2507`
  $0.10/M in, $0.30/M out; fallback `qwen/qwen3-next-80b-a3b-instruct` $0.09/M
  in, $1.10/M out. A 3-variant roast ≈ 700 in / 450 out tokens (estimated) ≈
  $0.0002 primary, $0.00056 fallback. Per active Pro user at 5–30 generations a
  week: roast $0.004–0.026/month (≤$0.073 all-fallback); simulator
  ~$0.003–0.012; Feral/Vent ~$0.00013 each. Worst case <$0.10/month vs ~$2.54
  net (15% Small Business commission, enrollment UNVERIFIED). $9.87 ≈ 49k primary
  or 17.6k fallback roast calls.
- Abuse bounds: PRO_DAILY_LIMIT 200 → one account spamming the fallback ≈
  $3.4/month. Free lane 30/device/day + 200/IP, and gets roast mode if lane=pro
  isn't enforced. On-device (b) $0; PCC $0 under the Small Business Program.
- **Recommended:** separate per-account cap for roast/argue (e.g. 50/day; worst
  case ~$0.84/account/month fallback); keep auto-top-up OFF; extend the weekly
  balance check; Datadog field `mode=roast lane=pro` for spend per mode.

### The consent and App Review requirements for (a) are concrete, and none touch old installs (verified)

- Shipped copy (4 locales): `cloud.consent.footnote` "Composed, Sharp, and Savage
  always run on-device and never use cloud" (`Localizable.strings:133`);
  `onboarding.privacy.body` (en:19) and `settings.about_ai.body` (en:136) say the
  same. Consent model: tri-state `CloudConsent {notAsked, granted, denied}`
  meaning Vent/Feral (`CloudConsentGate.swift:22-30`); the gate already routes
  sendable to cloud only with no on-device model and the sendable flag on
  (`CloudConsentGate.swift:44-65`). Live config keeps `cloud_sendable_enabled`
  false with the RETIRED note; old binaries read only that key, so a new key
  cannot reach them. Worker edge breaker: `ROAST_MODE_ENABLED=false`
  (`wrangler.toml:69`). App Privacy answers UNVERIFIED (ASC web only).
- **Required pieces:** new remote key (e.g. `pro_sendable_cloud_enabled` +
  `_locales`), default false, read only by the new binary, CI guard extended;
  separate persisted, versioned `SendableCloudConsent` before the first sendable
  cloud call, naming Savage, styles, 3 versions, the simulator, OpenRouter and the
  provider, and saying it applies only without Apple Intelligence; footnote /
  onboarding / settings copy in 4 locales with StoreCopyTests guards; paywall
  rows and product page; App Privacy review; three kill switches (client flag,
  ROAST_MODE_ENABLED, CLOUD_DISABLED); cloud only when no on-device model is
  present, never as a fallback after an on-device refusal.
- **Effort:** M–L client (~3–5 days) + owner ASC time. **Risk:** moderate App
  Review risk if consent wording is vague; copy drift across 4 locales; fails
  closed by design (`RoastEngine.swift:189-193`).

### Side findings: prompt/script bugs that hollow Pro styles (verified)

1. `StylePresets.json:305`: taiwanese_drama preamble tells every locale to use
   啦/喔/欸 (6/6 en variants had them) and contains Simplified 「命中注定我爱你」 in
   a zh-Hant prompt.
2. `index.js:744`: the roast safety rule's Chinese examples are Simplified only.
3. On-device corporate_passive_violence leaked 后续 (Simplified).
4. The roast path lacks the Vent path's post-processing (name strip, defect
   retry; `index.js:438-497`) — explains the Kevin echo.

Fix 1 and 3 in the (b) binary; 2 and 4 in the Worker before the (a) gate; add
StylePresets preambles to the CJK script-parity test; re-run style_gate2 and
`harness/worker-compare/compare_ext.mjs` to prove free and Vent paths unchanged.

## Open questions

- Share of Taiwan installs/buyers without Apple's model (decides whether (a)'s
  M–L effort is worth it). Datadog can show lane=pro usage now (connector
  failed). Next binary could send an on-device-available boolean; no device ID.
- Does the account hold the PCC managed entitlement, and is it enrolled in the
  Small Business Program?
- iPhone refusal rates (default vs permissive) — measured only on macOS 27.0.1.
- Will App Review accept permissive mode for generating new replies (1.7.1's
  permissive rewrite passed; Apple's examples are tagging and summarising)?
- Current App Privacy answers: is "User Content → App Functionality" already
  declared for Vent?
- Native Taiwanese reader for cloud roast output (neutral/mild mainland lexicon,
  no Taiwanese voice) — acceptable for Savage, or does it need the Vent path's
  Taiwan-register rules?
- Owner: Pro-only sendable cloud, or free users metered by credits later? Does
  (a)/(d) count as an explicit, metric-bound override of the §7 stop rule?
- Does PCC work with Apple Intelligence turned OFF? UNVERIFIED; only relevant if
  PCC is revisited.
