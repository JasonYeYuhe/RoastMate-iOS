# Lens 4 — Pro surfaces most payers can't see, and Taiwan fit (2026-10-27)

_Copied from the workflow's lens report (JSON) into Markdown for
`docs/DEV_PLAN_v1.8_2026-11.md`. Content unchanged except formatting. Raw files
stayed in the session scratchpad; they are not in the repo._

## Method

Checked 2026-10-27 against HEAD b737392. 8 production Worker calls; 30 on-device
generations on this Mac (macOS 27, Apple Intelligence on). Nothing deployed or
committed; nothing written to App Store Connect or the repo.

Evidence files (scratch):
`/private/tmp/claude-501/-Users-jason-Documents-RoastMate/1d05a9de-aa8a-416a-9d69-7c7fdc5c212f/scratchpad/v18/lens4/`
— `rm_zhtw_scored.json` (8 Worker transcripts with scores), `rm_probe.py` and
`rm_analyze.py` (probe and scorer), `echoprobe/run1.txt`, `echoprobe/run2.txt`
(on-device classic Echoes), `echoprobe/main.swift`, `echoprobe/p2/main.swift`
(probe sources compiling the production `EchoesPromptBuilder` and
`EchoesParser`).

## Framing

The only active payer is on en_US. They can't see Echoes or the roommate group,
and nothing in this lens reaches them before their ~11-04 renewal. The value of
this lens is giving the NEXT Taiwan payer a Pro tier worth keeping; the last one
(TW) cancelled on day 0.

## Ranked by payer impact

1. The roommate group (虛擬室友群) is the one Pro Explore surface that is
   cloud-generated on every device. It is hidden from zh-Hant by a zh-Hans-only
   check. The production Worker already handles zh_TW: 8/8 transcripts passed a
   port of the strict `EchoesParser` contract — but every one contained
   Simplified characters (all in the BRIDGE line copied from the prompt's
   Simplified examples), mainland markers appeared, and 0 of 4 Feral transcripts
   had a swear word. Worker-first prompt work plus one binary for strings,
   personas, fallback and consent sheet.
2. Classic Echoes (替你出气) is empty for everyone who can see it: on macOS 27,
   default guardrails refused 22/22 (16 zh_TW, 6 zh-Hans), including a harmless
   stapler complaint; permissive gives 0/12 parseable transcripts. Its Feral
   cloud consent asks permission for a cloud path the code never uses
   (`useCloud` hard-coded false). Users get the same canned, unlabelled transcript
   every time. Do not open it to zh-Hant as it is.
3. Echoes/roommate copy, consent and Settings text is false today for zh-Hans: it
   says 「完全本机生成」 on the cloud roommate screen, names Groq, says Casual stays
   on-device; the Settings toggle shows in every locale. All of it would ship to
   zh-Hant on opening.
4. zh-Hant has 0 of the 29 `echoes.*` strings, including the consent sheet; the
   persona lookup repeats the region-only `contains("hant")` bug.
5. Pro styles in zh-Hant: 京片兒 is dead in the cloud for zh-Hant (a test pins it
   as unstyled); 豆瓣短文 / Reddit 解釋 / MBA 黑話 names contradict the Taiwan voices
   the Worker already uses; on-device prompts carry Simplified few-shot examples;
   台劇腔 is 18th of 24 chips. Relocalizing in place (same ids) keeps
   「全部 24 種風格」 true.
6. The sample gallery has 0 zh-Hant responses.
7. The home-screen name is "RoastMate" in every locale while the store name is
   幫你罵; Siri phrases are Simplified only.

**The v1.7 §5 gate** (≥10 TW+HK downloads a week) measures audience size. TW had
1 first-time download since 10-07, so it can't fire in this plan's horizon. For a
goal of keeping and converting payers, replace it with: a quality gate (20 zh-Hant
roommate scenarios, parse-fallback ≤10%, **0 Simplified characters** — not "0
fully-Simplified transcripts", which today's 8/8 would pass — mainland markers
≤2/20, a swear word in ≥80% of Feral, one native Taiwanese reader ≥4/5); a cost
cap (Worker first, at most one binary that also carries fixes 2–4); a remote kill
(restrict-only `roommate_group_locales`, modelled on `cloudSendableLocales`). The
plan should say plainly this is feature work the stop rule would forbid, chosen
by the owner, bounded to that one binary, and does not reset the stop rule's T.

## Findings

### Open the cloud roommate group (虛擬室友群) to zh-Hant — Worker-first, then one binary (verified)

- **Impact:** highest positive for Taiwan. On phones without Apple's model (and
  on 27, where Apple refuses many prompts), Savage, 3 versions, the simulator and
  sendable styles fall back to canned lines; the roommate group runs on the
  Worker, so it would be real Pro value on every Taiwan device. No zh-Hant, en or
  ja payer can see it today.
- **Evidence:** gate is `isZhHansLocale()` (`ExploreView.swift:64, 77, 138-148`),
  matching 'hans'/'zh-cn'/'zh' — zh_TW, zh-Hant_TW, zh_HK fail it. Measured
  2026-10-27: 8 production `/v1/vent` calls with mode 'roommate' (free tokenless
  lane), 4 Taiwan situations × vent/feral, locales zh_TW and zh-Hant_TW, model
  `qwen/qwen3-30b-a3b-instruct-2507`; all HTTP 200 in 1.9–10.9 s (mean 5.3 s);
  8/8 pass a Python port of `EchoesParser`'s strict roommate contract
  (`EchoesParser.swift:55-74`: 8–10 lines, A/B/C each ≥2, one final BRIDGE).
  Defects (one non-native reader): (a) 8/8 contain Simplified — 8/8 「与其」 in the
  BRIDGE line copied from the prompt's Simplified template, plus 群里/憋着, 晒,
  话语权 in 3; the language directive is already Traditional
  (`language.js:9-20`) but the prompt opens 「你在写一段 zh-Hans 群聊记录」
  (`index.js:894`) and every example is Simplified/mainland (`index.js:802-903`).
  (b) Mainland markers: 背鍋 4/8, 甩回去 8/8; Taiwan terms mostly only where they
  echo the input (已讀不回, 限動, 群組). (c) Feral: 0/4 with any swear word (the
  register line asks for 狗东西/神经病/操). (d) 1/8 has a roommate speaking as the
  user. (e) 8/8 BRIDGE lines name the English mode 'Sharp'/'Savage', which the
  Worker requires verbatim (`index.js:888`), while the zh UI calls them 銳利/狠
  (zh-Hant.lproj:426-429); same in zh-Hans. The 10-22 audit measured roommate
  only in zh-Hans (2 calls).
- **Options:** (a) Worker: per-script roommate builder modelled on
  `src/vent_prompt.js` — Taiwan register, Traditional examples incl. the BRIDGE
  line, reuse the VOICES.hant mainland-marker ban, localized mode name in the
  bridge (e.g. 「不如用『狠』把話丟回去 →」), Feral asks for at least one Taiwan
  swear word, never a count; gate with harness/cloud on 20 zh-Hant scenarios
  (~$0.01). (b) Binary: gate → `AppLanguage.contentBucket` (plan §8 one home per
  rule; also fixes the zh_CN/zh_SG miss) plus a restrict-only remote
  `roommate_group_locales` (modelled on `RemoteConfig.swift:49-64`), bundled with
  the strings/personas/fallback/consent fixes below. (c) Not on the paywall until
  it has run a week without a kill. (d) Retire the §5 gate; replace with the
  quality gate above and a one-binary cost cap.
- **Effort:** Worker 0.5–1 day; binary ~3–4 days incl. tests and an
  `EchoesFlowUITests` zh-Hant variant. **Risk:** needs a native reader; consent
  text change needs App Review; roommate ≈ 2× a vent in tokens (per-call cost
  UNVERIFIED, negligible at current volume); still feature work the stop rule
  forbids.

### Classic Echoes (替你出气) is empty for every payer who can see it — don't open it to zh-Hant (verified)

- **Evidence (macOS 27, AI available):** production `EchoesPromptBuilder` and
  `EchoesParser` compiled into a probe using production's session
  (`AppleFMBackend.swift:48-56, 62-65`; standard guardrails via
  `FMBackend.swift:85-94`; temperature 0.85/0.95, 600 tokens). Production prompt,
  zh_TW input: 8/8 refused ("May contain unsafe content"). zh-Hant-adapted prompt:
  8/8 refused. Production prompt, zh-Hans input on zh_CN: 6/6 refused in
  487–1458 ms, including 「同事借了我的订书机一直没还。」 — the instructions
  themselves trip the guardrail. Every refusal → the curated transcript
  (`EchoesEngine.swift:156-160`). Permissive: 8/8 returned text, 8/8 failed to
  parse (literal `[ROLE/A]`, mostly one voice, 3 lines; fully Simplified with
  zh_TW input 8/8). Hant prompt + permissive: 0 Simplified but 4/4 parse failures.
  Classic never uses the cloud (`let useCloud = false`,
  `EchoesEngine.swift:108-117`), yet the Feral tone opens a cloud consent sheet
  and the blurb says 「可选云端生成」 (zh-Hans.lproj:548). The curated transcript is
  fixed text (`FallbackRoasts.swift:84-110`); `EchoTranscript` has no curated flag
  (`EchoesTypes.swift:102-130`); EchoesView shows no curated label. Classic can't
  be hidden remotely without killing the roommate group
  (`roommateGroupAllowed = roommate_group_enabled && echoes_enabled`,
  `RemoteConfig.swift:220-222`). A real-device Echoes eval was never recorded
  (`docs/ECHOES_EVAL_2026-05-29.md`, "STILL PENDING"). iPhones UNVERIFIED.
- **Options:** (a) retire classic, keep the roommate group as the single Echoes
  surface (smallest; removes an empty Pro tile); (b) move classic to the Worker
  (1–2 voices; needs accurate versioned consent since Casual would leave the
  device); (c) minimum: label the curated transcript with `CuratedNoticeBanner`,
  stop showing the cloud consent for classic, add a separate remote flag.
- **Effort:** retire/label S (<1 day); cloud port M. **Risk:** retiring removes a
  tile zh-Hans users may use (no data); permissive doesn't help (parse failures,
  Simplified output, App Review risk per
  `evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md`).

### Echoes/roommate copy and consent are false today (zh-Hans) and would ship to zh-Hant (verified)

- **Evidence:** `EchoesView.swift:141-149` shows the tone picker and blurb on the
  roommate screen too. Casual blurb 「微微毒舌，发泄一下就够。完全本机生成。」
  (zh-Hans.lproj:547) / "On-device only." (en.lproj:551), while both roommate
  tones go to the Worker (`EchoesEngine.swift:95-101, 215-240`). Consent body
  「Cloudflare 代理 + Groq / OpenRouter」 and 「日常档永远只在你本机生成」
  (zh-Hans.lproj:563; en.lproj:563). Groq is off (`wrangler.toml:36`); the live
  privacy policy names OpenRouter only. The Settings toggle
  「Echoes 痛罵檔走雲端」 and footer 「日常語氣一律只在這台裝置上處理」
  (zh-Hant.lproj:565-566; `SettingsView.swift:61-73`) render in every locale with
  no tile check (the 10-22 synthesis recommended hiding it; still unconditional).
- **Options:** scene-aware blurbs; consent body names OpenRouter and both tones
  for the roommate group; fix the Settings footer, in 4 locales; show the toggle
  only where an Echoes tile can show; version the consent (new key, re-ask);
  StoreCopyTests: no 'Groq' and no 'on-device' wording in any string reachable
  from the roommate scene.
- **Effort:** S (~0.5–1 day). **Risk:** re-asking adds a tap for existing zh-Hans
  roommate users; leaving it is a live 5.1.2(i) accuracy defect.

### zh-Hant has 0 of 29 `echoes.*` strings, no personas, no Traditional fallback; persona lookup repeats the region-only bug (verified)

- **Evidence:** `echoes.*` key counts en 29, zh-Hans 29, zh-Hant 0, ja 0; only the
  roommate entry strings exist in zh-Hant (zh-Hant.lproj:531-541). The roommate
  screen uses ~16 `echoes.*` keys (`EchoesView.swift:53, 103, 112, 141-149, 255`;
  `EchoesFeralConsentSheet.swift:22-56`; `EchoesViewModel.swift:159`). Missing
  keys: the in-app-language path returns the raw key; the system-language path
  falls back to en (`project.yml:14`); SwiftUI-environment behaviour UNVERIFIED.
  Only `echoes-personas-zh-Hans.json` exists; `EchoesPersonaCatalog.swift:84-99`
  picks by `contains("hant")`, so zh_TW would still load zh-Hans. Curated
  fallbacks are Simplified only (`FallbackRoasts.swift:84-136`).
- **Options:** 29 zh-Hant strings in Taiwan wording (室友 not 舍友, 群組 not 群里;
  tone names aligned with 痛罵); `echoes-personas-zh-Hant.json`; persona lookup and
  Explore gate → `AppLanguage.contentBucket`; a Traditional labelled curated pool;
  a parity test (every `echoes.*`/`roommate.*` key exists in every locale where
  the tile can render). **Effort:** S–M (~1.5 days).

### Pro styles for Taiwan (verified)

- **Evidence:** `STYLE_VOICES.bjing_taunt` has only `hans`; a test pins zh_TW +
  京片兒 to the unstyled prompt (`cloud-worker/test/style_voice.test.js:519-520`).
  The Worker's zh-Hant voices already Taiwanize douban (文青日記體), mba_boss
  (對焦/綜效/優化/落地/盤點/KPI), reddit_eli5 (論壇科普腔); the zh-Hant UI still
  reads 豆瓣短文 「週六下午的日記體」, MBA 黑話 「對齊、閉環、拉通」, Reddit 解釋
  (zh-Hant.lproj:378-379, 393-397, 408-409). On-device preambles are English and
  every Chinese example is Simplified; `examplesForPrompt` filters on Han presence,
  not script (`PromptBuilder.swift:531-545`) — measured effect small (1 Simplified
  character in 1 of 7 non-refused zh_TW outputs; 3/10 refused;
  `docs/evidence/2026-10-22-churn-and-fixes/results/probe_zh_TW_run2.txt`).
  `localesSupported` has no consumer. Picker = raw JSON order
  (`RoastGeneratorView.swift:22, 257-280`). 「全部 24 種風格」 at zh-Hant.lproj:154,
  157, 158, 171, 178 and `metadata/zh-Hant/description.txt:5, 15, 34`. Market-fit
  judgement of the other Pro styles (UNVERIFIED by a native reader): fine in
  Taiwan; free 小紅書吐槽 is a mainland platform.
- **Options:** (A, recommended) relocalize in place, same ids, zh-Hant only:
  京片兒 → 「台式長輩文」 (LINE 長輩圖 blessing voice; new Worker hant voice +
  on-device zh-Hant preamble); Reddit 解釋 → 「懶人包體」 (rewrite hant voice);
  豆瓣短文 → 「文青日記體」 (string-only); MBA 黑話 blurb → 「對焦、綜效、落地」
  (optional name 「顧問簡報腔」); optional 律師函體 → 「存證信函體」, free 小紅書吐槽 →
  「Dcard 抱怨文」 or 「脆廢文」; PTT 鄉民/推文體 only with explicit slur bans; order
  Taiwan-relevant Pro styles first. Touches `StylePresets.json` (optional
  per-bucket preamble/examples), `StylePreset.swift`, `PromptBuilder.swift`
  (bucket-aware preamble and examples), zh-Hant style.* keys, `style_voice.js`
  (hant for bjing_taunt and reddit_eli5), `style_names.js` (regenerate, keep
  retired zh-Hant names as aliases — clients ≤1.7.0 send only styleName,
  `style_names.js:8-11`), `test/style_voice.test.js:519-520`, a PromptBuilder
  test (no Simplified example in a zh-Hant prompt), style gate + on-device probe,
  `metadata/zh-Hant/description.txt`. (B) New ids + `localesSupported` filtering
  (more code across picker, Explore, Share, Watch, menu bar, Intents,
  saved-selection and history fallback; count-free copy in 4 locales).
- **Effort:** M (2–3 days). **Risk:** native taste check needed; on-device
  refusals on 27 hide part of it; missing aliases silently unstyle older clients;
  under (A) an id means different things per locale.

### Sample gallery: 10 English, 5 Simplified, 2 Japanese, 0 Traditional responses (verified)

- `SampleRoasts.json` responseLocale counts en 10, zh-Hans 5, ja 2, zh-Hant 0;
  only the situation is localized (`SampleRoast.swift:29-37`);
  `SampleGalleryView` doesn't filter (`SampleGalleryView.swift:6, 42, 87`); the
  generator's sampleSection also renders samples (`RoastGeneratorView.swift:43`).
- **Option:** 4–6 zh-Hant samples incl. Pro styles that work in Taiwan, taken from
  real harness output; filter/prioritise by `AppLanguage.contentBucket`. S.

### Home-screen name and Siri gaps (verified in code)

- `INFOPLIST_KEY_CFBundleDisplayName` is 'RoastMate' for all targets
  (`project.yml:48, 127, 157`), no InfoPlist.strings; store name 幫你罵
  (`metadata/zh-Hant/name.txt`). App Shortcut phrases are zh-Hans + en/ja only
  (`GenerateRoastIntent.swift:116-138`). A different "RoastMate" app is #1 in
  TW/US/HK/JP (DEV_PLAN_v1.7 §1.4).
- **Option:** zh-Hant/zh-Hans InfoPlist.strings with 幫你罵 / 帮你骂 and zh-Hant
  Shortcut phrases. S (<0.5 day).

## Open questions

- Is classic Echoes refused the same way on iPhones (iOS 26.x / 27)?
- Owner: retire classic Echoes, move it to the Worker, or label it?
- Will Jason replace the v1.7 §5 gate with a quality gate + one-binary cap, and
  state it as an exception to the 11-15 stop rule that doesn't reset T?
- Consent re-ask: existing zh-Hans roommate grants were given under text naming
  Groq and saying Casual stays on-device — new versioned key?
- Native Taiwanese reader for the roommate output and the proposed style names;
  is PTT 鄉民體 acceptable given slur risk?
- Once zh-Hant is open and gated, should the roommate group be sold on the
  paywall?
- SwiftUI missing-key behaviour under the in-app language override (moot if the
  strings ship).
