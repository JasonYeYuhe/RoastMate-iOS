# Lens 1 — what each paid feature gives a payer today (2026-10-27)

_Copied from the workflow's lens report (JSON) into Markdown for
`docs/DEV_PLAN_v1.8_2026-11.md`. Content unchanged except formatting. This repo
is public, so nothing here identifies a subscriber beyond country. Raw files
stayed in the session scratchpad (paths below); they are not in the repo._

## Method

Measured 2026-10-27 on this Mac (macOS 27.0.1, M1 Pro, Apple Intelligence on):

- 88 on-device calls through the production `PromptBuilder`, `SafetyFilter` and
  `ModelRefusal`, exactly as `RoastEngine` runs them.
- 20 production Feral calls (20 Worker calls in total, under the 30 limit).
- 1 read-only App Store Connect analytics pull.
- Nothing was written to the repo or App Store Connect.

Raw files (scratch):
`/private/tmp/claude-501/-Users-jason-Documents-RoastMate/1d05a9de-aa8a-416a-9d69-7c7fdc5c212f/scratchpad/v18/audit/`
— `ondevice_all.jsonl`, `ondevice_summary.txt`, `cloud_feral.json(l)`,
`cloud_feral_scores.txt`, `argument_roles.json`, `asc_readout_1007.txt`, and
`probe/` (`main.swift`, `Stubs.swift`, `analyze.py`).

## Status by device class

A = iPhone with Apple Intelligence on iOS 27; B = same on iOS 26; C = no Apple
model (iOS 18, AI off or unsupported, older iPhones); D = Mac with AI; E = Mac
without AI. This Mac is class D on OS 27 and is the only proxy for A; iPhone
behaviour is UNVERIFIED.

| Pro benefit | Status |
|---|---|
| **Feral** | REAL on A–E once the user allows cloud. 20/20 HTTP 200, median 1.9 s. A real swear word in 20/20. zh-Hant: 0 mainland terms, Taiwan terms 10/10, 0 Simplified characters, 0 names. 0/18 over the styled length limit. Japanese reads awkward to me (UNVERIFIED with a native reader). If the user declines cloud, Feral is CURATED. It is a single draft, and its 「改成能發的」 (make it sendable) step is CURATED on C/E. |
| **Savage (on-device)** | WEAK on A/D. Refused → curated: zh_TW 6/16, en 2/16, zh_CN 2/4, ja 0/4. The Taiwan-flavoured styles fail most in zh_TW: 硬核回擊 3/4, 台劇腔 3/4. B: UNVERIFIED for Pro styles (macOS 26.6.2 refused 1/32 with free styles, 2026-08-30). C/E: CURATED. |
| **16 Pro styles in sendable modes** | WEAK on A/D. 台劇腔 in Sharp refused 4/4 in zh_TW; outputs that come back are templated (gap 3). C/E: CURATED, the same 5 lines whatever the style. |
| **16 Pro styles in Vent/Feral (cloud)** | REAL on A–E. 冷處理, 職場冷暴力 and 台劇腔 clearly distinct. 硬核回擊 read like the free unstyled default (2/2 pairs, my judgment). The copy on C/E says styles need Apple Intelligence. |
| **3 versions** | WEAK on A/D. All 30 answered calls returned 3 versions, but 3/30 were near-duplicates, en Cold Reply versions began "I'd have said:" 9/12, stock templates repeat. A refused call gives 3 of the 5 canned lines. C/E: CURATED. |
| **Argument Simulator** | WEAK on A/D. 36 turns: 10 refused → canned roast lines. Of 26 model turns: 14 speak as the opponent, 7 flip to the user's side, 5 confused. B: UNVERIFIED. C/E: CURATED — a canned roast line as the "opponent" every turn. |
| **Unlimited history** | REAL on all classes. |
| **No credits** | REAL on all classes; on C/E it only matters for Vent/Feral (curated output is free anyway). |
| **Echoes / roommate group** | HIDDEN for zh-Hant, en and ja — both payers ever. Visible only in zh-Hans. |

## Five biggest gaps (ranked by how many payers they hit)

1. Without Apple's model (C/E), 4 of the 7 Pro bullets are canned lines: Savage,
   styles in sendable modes, 3 versions and the simulator.
2. Feral, the only Pro generator real everywhere, is undersold and thin. The C/E
   paywall says styles need Apple Intelligence — false for 痛罵 since Worker
   046f2134. Its rewrite is curated on C/E, and 硬核回擊 adds little.
3. When the on-device model answers, quality is templated: every en Taiwanese
   Drama version opens with 欸/喔/啦 (18/18); Corporate Passive Violence repeats
   the same stock frame (en 12/12, zh 10/12); Cold Reply prefixes "I'd have
   said:" (9/12).
4. On OS 27 with AI, the Taiwan styles are mostly refused, but the AI-device
   paywall sells everything without a caveat.
5. The simulator's prompt contradicts itself (input asks for the opponent; the
   system prompt asks for the user's comeback), so it fails on every device.

Distribution: since 10-07, 7 first-time downloads (4 iPhone, 3 Mac); 0
purchases; 1 TW churn.

## Findings

### F1 — On C/E, Savage, Pro styles in sendable modes, 3 versions and the simulator are labelled canned lines (verified)

- **Impact:** every payer on iOS 18, older iPhones, AI off/unsupported, Intel
  Macs and macOS 14/15 gets 4 of 7 Pro bullets as the same 5 lines per language,
  ignoring input and style. On these devices Pro is really Feral + unlimited
  history + no credits. 3 of the 7 first-time downloads since 10-07 were Macs and
  4 iPhones; their AI capability is UNVERIFIED.
- **Evidence:** no model → curated: `RoastEngine.swift:296-303`. Curated pool 5
  lines/language, ignores style and input: `FallbackRoasts.swift:7-13, 36-63`.
  Sendable cloud path off on both sides: `cloud_sendable_enabled` retired, Worker
  refuses `mode:"roast"` unless `ROAST_MODE_ENABLED` (`index.js:180`). Simulator
  resolves cloud as sendable (`ArgumentSimulatorViewModel.swift:141-149`), so on
  C/E the "opponent" is a canned roast line. Rewrite on C/E is curated
  (`RoastEngine.swift:476-479, 602-609`). Disclosed since 1.7.1:
  `PaywallView.swift:121-124` (`paywall.body.curated`, zh-Hant.lproj:158),
  `metadata/zh-Hant/description.txt:40`. Device mix: `asc_readout_1007.txt`.
- **Options:** (a) re-centre Pro on C/E around what already reaches the cloud
  under the existing consent: 2–3 Feral takes, a style picker in 痛罵, a better
  draft — no new data flow. (b) A Pro-only cloud path for sendable modes: NEW
  remote flag read only by new binaries, NEW versioned consent naming the modes
  and provider, copy in 4 locales, App Privacy review, CI guard, kill switch.
  ROAST_MODE zh-Hant failed the v1.5 gate 20/24 — re-gate first. (c) Accept and
  keep the disclosure; measure device mix via a Worker "on-device model
  available" field first.
- **Effort:** (a) S–M; (b) M–L. **Risk:** (a) low; (b) 5.1.2(i) and App Privacy
  exposure, old consent sheets promise sendable modes never use cloud, draws on
  the $10 hard cap (~$0.0004 per 3-variant tap).

### F2 — Feral, the only Pro generator real on every device, is undersold and thin (verified)

- **Impact:** every payer uses Feral and it measures well, but on C/E the
  paywall and post-purchase screen say styles need Apple Intelligence and will
  show examples — false for 痛罵/發洩 since Worker 046f2134. 硬核回擊 in Feral
  reads like the unstyled default. Feral is one draft; on C/E its "make it
  sendable" follow-up is curated.
- **Evidence (20 production Feral calls with styleId, tokenless free lane):**
  lane only sets quota; `index.js:671-676` accepts feral on any lane and
  `buildVentSystemPrompt` takes no lane, so the prompt equals a Pro user's.
  20/20 HTTP 200; latency 0.76–8.2 s, median 1.9 s; model
  `qwen3-30b-a3b-instruct-2507`. Swear word 20/20. zh_TW: 0 mainland terms,
  Taiwan terms 10/10, 0 Simplified (two 吃 hits are an OpenCC false positive).
  0/18 over the styled limit; 0 names. Distinct styles: Corporate Passive
  Violence (再次提醒…敬請知悉), Cold Reply (three short lines, 從此不再理你),
  Taiwanese Drama (melodramatic metaphors). Copy that denies styles:
  zh-Hant.lproj:158 「24 種風格…需要 Apple Intelligence」 and :179
  「各種風格…會顯示預設範例」; same in en.lproj:158. Style voice is tier-only on
  the Worker (`style_voice.js:195-198`). Files: `cloud_feral.json`,
  `cloud_feral_scores.txt`. Japanese grammar awkward in places (#16, #18) —
  non-native reading, UNVERIFIED.
- **Options:** fix `paywall.body.curated`, `success.body.curated` and plan rows
  (binary); make 硬核回擊 distinct in Feral (Worker, `style_voice.js`
  STYLE_VOICES); 2–3 Feral takes for Pro; native Taiwanese and Japanese reader
  gate; decide on server-side Pro gating of Feral (today any client can request
  Feral with a Pro styleId tokenless; not payer-facing).
- **Effort:** S for copy and Worker style tweak; M for multi-take. **Risk:** low;
  copy must stay true on every device (plan §8) and follow the paired-term rule.

### F3 — On-device Savage/Pro-style output is templated, mixed-script or near-duplicate (verified)

- **Impact:** payers on AI devices get text they would have to edit: en
  Taiwanese Drama opens every version with a Chinese particle; Corporate Passive
  Violence repeats the same stock frame; en Cold Reply prefixes "I'd have
  said:"; some zh Cold Reply lines are nonsense (e.g.
  「五千塊？我寧願餵你給 Instagram 的晚餐。」).
- **Evidence (macOS 27.0.1):** Savage 40 calls, 30 answered, all 30 with 3
  versions; near-duplicate (≥0.6 similarity) in 3/30. Taiwanese Drama en: 18/18
  versions open with 欸/喔/啦 (Savage 12/12, Sharp 6/6) — caused by the preamble
  "using 啦/喔/欸 particles" in `Shared/Resources/StylePresets.json`
  (taiwanese_drama). Corporate Passive Violence: en 12/12 use "per my last email
  / as a reminder / to ensure visibility / happy to align" (the preamble lists
  exactly these), "per per" twice; zh_TW 10/12 use 感謝您…依據…期待 and invent
  times (凌晨三點). Cold Reply en: 9/12 open "I'd have said:" — from the roast
  guidance "what the user *wishes* they had said" (`PromptBuilder.swift:247`).
  Savage has no calibration block; only sharp and calm do
  (`PromptBuilder.swift:92-97, 424-512`). zh_TW priming is Simplified-only: the
  zh examples of Pro styles are Simplified and `examplesForPrompt` passes them to
  zh_TW (`PromptBuilder.swift:531-546`) — outputs were still 0-Simplified in this
  run. Unpaired-term bug class. Files: `ondevice_all.jsonl`,
  `ondevice_summary.txt`.
- **Options:** language-aware preambles (particles for zh only; stock phrases as
  "for example"); Traditional (and Japanese) examples per Pro style guarded by the
  paired-term test; strip a leading "I'd have said:"/「」 wrapper and reword the
  roast guidance; a Savage calibration (three situations, shape only); detect
  near-duplicates and regenerate once or show 2. Gate: re-run `probe/` with ≥3
  distinct openers per style per locale, 0 Chinese in en, 0 Simplified in zh_TW.
- **Effort:** S–M (ships in the binary). **Risk:** low; the small model is
  sensitive to prompt length — measure each change; redo at every Apple model
  release.

### F4 — On OS 27 with AI, Apple refuses most Savage/Sharp calls with the Taiwan-flavoured Pro styles; the AI-device paywall has no caveat (verified)

- **Impact:** a Taiwanese payer on iOS/macOS 27 (3 of 4 installs since 10-15 per
  the 10-22 synthesis) who picks 硬核回擊 or 台劇腔 usually gets the labelled
  curated example. The AI-device paywall still lists 狠 · 全部 24 種風格 · 3 個版本 ·
  吵架模擬器.
- **Evidence (macOS 27.0.1):** refusals arrive as
  `FoundationModels.LanguageModelError` in ~0.5 s and map to curated
  (`RoastEngine.swift:349-364`; `AppleFMBackend.swift:98-101`). Savage zh_TW 6/16
  (硬核回擊 3/4, 台劇腔 3/4, 職場冷暴力 0/4, 冷處理 0/4); en 2/16 (all 硬核回擊);
  zh_CN 2/4; ja 0/4. Sharp 台劇腔 zh_TW 4/4; 辯論收尾殺 0/4. Simulator zh_TW 8/18
  turns refused. The 10-22 run measured 硬核回擊 Savage zh_TW 5/8 and en 7/8, so
  combined zh_TW 8/12, en 9/12. Unconditional AI-device paywall:
  `PaywallView.swift:122-124` (`paywall.body`, zh-Hant.lproj:157). iOS 26
  contrast: macOS 26.6.2 refused 1/32 Savage with free styles
  (`evals/runs/run-applefm-base-calm-sharp-savage/cells.jsonl`); Pro styles on 26
  UNVERIFIED; iPhone on 27 UNVERIFIED.
- **Options:** retune preambles and the Savage prompt against the OS 27 model
  (gate: refusals ≤1/8 per locale per style); or an AI-device caveat on the
  zh-Hant paywall; do not reuse `permissiveContentTransformations` for
  generation without checking Apple's intended use; keep the harness as a
  regression set per OS release.
- **Effort:** M, recurring. **Risk:** low data risk; tuning may not converge (the
  10-22 challenge advised deferring it).

### F5 — The Argument Simulator's prompt contradicts itself (verified)

- **Impact:** every payer who opens the simulator. On C/E it never works. On A/D
  only ~4 in 10 turns are a believable opponent. Store copy:
  `metadata/zh-Hant/description.txt:17` 「AI 扮演對方」.
- **Evidence:** input says "Play the OTHER side"
  (`ArgumentSimulatorViewModel.swift:111-117, 124-128`), but `.argument` guidance
  says "Produce the response *the user* should give back"
  (`PromptBuilder.swift:252-253`), the task line says "responses I could give in
  this argument" (`PromptBuilder.swift:310-311`), and every sendable prompt asks
  for numbering (`PromptBuilder.swift:143`). Runs at `.sharp`, so zh users also
  get the Sharp calibration written as the user setting boundaries
  (`PromptBuilder.swift:434-442`). Measured: 36 turns (2 locales × 3 setups × 2
  styles × 3 turns): 10 refused (zh_TW 8/18, en 2/18); 12/36 raw outputs were
  numbered lists despite "One reply only"; of 26 model turns, 14 opponent, 7
  user-side flips (e.g. en Cold Reply: "Marriage isn't a checklist."), 5 confused
  (e.g. 「這不是討論議題，這是一份委託。」). Files: `argument_roles.json`,
  `ondevice_all.jsonl` (part=argument).
- **Options:** a dedicated opponent prompt (own mode or system/task text, no
  numbering for n=1, no Sharp calibration, style applied to the opponent's
  voice); on C/E hide or relabel the tile (a cloud move needs gap #1's route).
  Gate: ≥80% opponent turns on the 36-turn set, ≤1/8 refusals per locale.
- **Effort:** S (prompt); M–L (cloud). **Risk:** low for the prompt.

### F6 — Echoes and the roommate group are hidden from every non-zh-Hans payer (verified)

- **Impact:** both payers ever and every zh-Hant/en/ja user cannot see two
  Pro-badged Explore tools. Not on the zh-Hant/en paywall, so hidden value, not
  a broken promise. For zh-Hans: roommate runs in the cloud; classic Echoes runs
  on-device with default guardrails and is curated on C/E.
- **Evidence:** `ExploreView.swift:57, 68` call `isZhHansLocale()`
  (`ExploreView.swift:138-148`; zh_TW/en/ja → false). Classic Echoes on-device
  only (`EchoesEngine.swift:116` `useCloud=false`; 133-170); roommate through the
  cloud (`EchoesEngine.swift:95-101`). zh-Hans store privacy text names 虚拟舍友群
  (`metadata/zh-Hans/description.txt:50`). Quality not re-measured (UNVERIFIED).
- **Options:** leave (zh-Hant roommate cut by both v1.7 reviewers); remove the
  Pro framing in zh-Hans; or port the roommate group to zh-Hant (L, own gate).

### F7 — What is solidly REAL: Feral through the cloud, unlimited history, no credits (verified)

- Feral 20/20 OK with Taiwan register (`cloud_feral_scores.txt`). History: only
  free users pruned to 30 (`HistoryService.swift:61-62, 95-96`). No credits: Pro
  skips the wallet (`RoastGeneratorViewModel.swift:104-160`; `variantCount isPro
  ? 3 : 1` at :171). The Pro token path falls back to tokenless on auth failure
  (`CloudVentClient.swift:62-76`). Whether the production Pro lane (200/day)
  actually mints tokens is UNVERIFIED; free-lane cap is 30/day per device
  (`lane.js:46-53`).
- **Option:** Feral + styles + history as the cross-device core of Pro; consider
  Feral multi-take, style surfacing, saved/pinned drafts.

## Open questions

- Share of payers/prospects on C/E (Taiwan iPhones without AI; the 3 new Mac
  installs on Intel or macOS 14/15)? Decides gap #1 vs #4. ASC gives only
  iPhone vs Desktop; a Worker "on-device model available" field or Datadog would
  answer it (the connector failed again).
- Does an iPhone on iOS 27 refuse Pro-style Savage at the macOS rates? Refusal
  rates for Pro styles on iOS 26?
- Has the active payer (US, iOS 26.6 at purchase) used Feral, Savage or the
  simulator? Datadog `lane=pro` would show it, but reading it isolates one
  person's usage.
- Native Taiwanese and Japanese readers for Feral and on-device Savage.
- Does production `/v1/auth` mint Pro tokens? If not, Pro users silently run on
  the free 30/day lane. UNVERIFIED.
- Owner decision: invest in on-device Savage/styles/simulator (re-tuned at every
  Apple model release, canned on C/E) or in the cloud core (Feral takes, styles in
  痛罵, a new-consent cloud sendable path whose zh-Hant ROAST_MODE output failed
  the v1.5 gate 20/24)?
