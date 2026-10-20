# v1.7 Phase 1 — decisions brief for review (2026-10-07)

Context: `docs/DEV_PLAN_v1.7_2026-10.md` (read §1, §3, §8, §9) and
`docs/HANDOFF_v1.7_NEXT_SESSION.md`. Raw recon (three investigators + a
completeness critic, with file:line evidence): `docs/evidence/2026-10-07-v17-phase1-recon.json`.

## Where things stand

- **Phase 0 shipped.** Prod Worker `90d8f1c5` (rollback `200d240c`), commit
  `f835a59`. Groq hop off; OpenRouter primary `qwen3-30b-a3b-instruct-2507` +
  secondary `qwen3-next-80b-a3b-instruct`. Measured: OpenRouter's native
  `models` list 400s the whole request when any id is unknown, so it does NOT
  cover a retired model; the Worker now retries with the tail of the list.
  Evidence `evals/runs/2026-10-07-p01-fallback.md`.
- **Phase 1 (v1.7.0) not started in code.** Working tree has: the fixed
  screenshot pipeline (uncommitted: `scripts/screenshots.sh`,
  `scripts/extract-screenshots.sh`, `RoastMateUITests/ScreenshotTests.swift`)
  and a draft Taiwan keyword list (`metadata/zh-Hant/keywords.txt`).
- The Mac's disk filled up mid-session (an 85 GB Trash); now freed. Nothing
  has been built in Release yet.
- Business: 2 paying subs (TW 09-19, US 10-04), ~2 first-time downloads/week,
  112 impressions → 4 page views since 09-28. Stop rule read on 11-15 (§7).

## What the recon found that the plan did not know

1. **Screenshot pipeline — three bugs, not one.** The committed PNGs are
   2026-05-15 output of an older test (`2fdb9e6`). (A) `LOCALE` was passed to
   `xcodebuild` without the `TEST_RUNNER_` prefix, so the runner never saw it
   and every locale was captured in English. (B) The old onboarding-skip looked
   up `app.buttons["common.next"]` — a key, not a label. Current code skips
   onboarding correctly under `-uitest` (RootView.swift:47-52). (C) The keyboard
   stayed up after typing; every tab tap hit the keyboard → identical frames +
   a dictation alert. Fixed in the working tree and verified on en, ja, zh-Hant
   (zh-Hans blocked by the full disk).
2. **The "locked Vent" in the live screenshots is Vent's own permanent
   `lock.open` icon** (`StyleChip.swift:86-87`), not the Pro lock (`lock.fill`,
   :49-52). Fresh screenshots will show the same open padlock next to 發洩.
3. **No offline way to show a Vent result card.** Vent always calls the live
   Worker. The roommate scene has a `-uitestRoommateFixture` launch-arg hook
   (`AppLaunchEnvironment.swift:39-54`, honoured in Release too); Vent has none.
4. **App Review 2.3.8:** screenshots must be 4+ even though the app is 17+. The
   Worker's zh/ja Vent prompt *requires* 1-2 strong words, so a raw Vent reply
   on screenshot #1 will usually contain profanity (他媽的 etc. — see the eval
   file). The app's Safe Mode only shapes the on-device prompt; it is not sent
   to the Worker and does not mask cloud output.
5. **ja store name is "RoastMate", not "RoastMate AI"** (P1.2 assumed both en
   and ja were "RoastMate AI"). For the search term "RoastMate" the #1 result in
   TW/US/HK/JP is an unrelated 2014 cooking app; "RoastMate AI" ranks us #1 in
   all four; 幫你罵/帮你骂 rank us #1 in TW/HK/US.
6. **Same copy-vs-code defect class, outside P1.1's stated scope:**
   - zh-Hant and ja lack `settings.echoes_feral_cloud` + `.footer`; the toggle
     (`SettingsView.swift:78-85`) is ungated → every Taiwan/Japan user sees two
     raw keys in Settings → AI & Privacy (one of the two payers is in Taiwan).
   - All 4 subtitles claim on-device AI ("On-device AI comeback writer",
     本地 AI 幫你說出心裡話…) while Vent — the headline free feature and the
     planned screenshot #1 — is cloud.
   - `description.txt` (all 4 locales, ~line 31) sells "Generate three styles in
     parallel" — no such feature (Pro gets 3 variants of ONE style; Vent/Feral
     get 1). It says "20+ styles" (there are 24) and its Pro list omits Feral
     and Savage.
   - `quota.exhausted.body` says "You've used all 5 free generations today" —
     the 5/day quota is legacy (credit wallet since v1.1) but the string is still
     the message of the Pro-style / Pro-intensity safety-net guards
     (`RoastGeneratorViewModel.swift:95,99`).
   - Live `promotionalText` is EMPTY in all 8 version localizations (iOS+macOS).
     It is editable on the live version without review.
7. **Paywall header facts** (`paywall.body`, Localizable.strings:157): names
   Vent (free since 1.6.0), omits Feral, says "20+ styles". Pro never spends
   credits, but the Worker caps the Pro cloud lane at 200/day, so "unlimited
   generations" is a soft claim. Pro also gets 3 variants per sendable reply —
   a real benefit no copy names. On devices without Apple's on-device model,
   Savage / Pro styles / argument simulator return curated examples (disclosed
   in the paywall's Savage row, not in the header).
8. **History tab seeds are mixed-language in every locale**
   (`HistoryService.swift:137` seeds each sample in its response locale).
9. **ASC upload API:** `appScreenshotSets`/`appScreenshots` (what the plan
   names) are deprecated in favour of the App Asset Library
   (`appAssetLibraryImages` + `appAssetLibraryPlacements`). No repo script
   uploads screenshots or writes keywords/subtitle/name today
   (`asc_bind_version.py` writes whatsNew only). Apple's spec page also has an
   ambiguous line about a required "Dynamic Island (medium display)" set.

## Decisions proposed (each has alternatives)

- **D1 — ja name / card wordmark.** (a) Rename the ja store name to
  "RoastMate AI" in 1.7.0; wordmark "RoastMate AI" for en+ja, 幫你罵 / 帮你骂 for
  zh. (b) Keep ja name "RoastMate", ja wordmark "RoastMate AI" (card ≠ store
  name). (c) Keep ja name, ja wordmark "RoastMate" (searchers find the cooking
  app first). *Proposed: (a).*
- **D2 — Screenshot #1 source.** (a) Add a `-uitestVentFixture` hook (≈15
  lines, mirrors the roommate fixture, behind the same consent gate) and feed it
  a REAL Worker reply per locale chosen because it has no profanity (generate
  several via `wrangler dev --remote`, pick verbatim, no editing). (b) Let the UI
  test call the live Worker (non-deterministic, likely profane → 2.3.8 risk).
  (c) No result card: screenshot #1 = generator filled with a scenario, Vent
  selected (no app change, weaker shot). *Proposed: (a).*
- **D3 — Vent's `lock.open` icon.** (a) Change it to a non-padlock symbol
  (one line) so Vent never reads as locked in a thumbnail or in the app.
  (b) Leave it. *Proposed: (a).*
- **D4 — Extra copy fixes in the 1.7.0 binary/metadata.** (a) All of item 6:
  raw keys, subtitles drop "on-device", description fixes, legacy
  quota.exhausted text. (b) Only the user-visible ones (raw keys + subtitle).
  (c) Plan scope only. *Proposed: (a).*
- **D5 — Promotional text.** (a) Write honest, Taiwan-vocabulary promo text in
  4 locales and set it on the live 1.6.0 versions now (no review needed), carry
  it into 1.7.0. (b) Set it only with 1.7.0. (c) Leave empty. *Proposed: (a).*
- **D6 — Paywall header.** "Feral · Savage · all 24 styles · 3 versions per
  reply · argument simulator · unlimited history · no credits needed" (drops
  "unlimited generations"). Guard: unit test fails if any locale's
  `paywall.body` names Vent or omits Feral. *Proposed as written.*
- **D7 — Screenshot set.** 4 shots per locale × en-US, zh-Hant, ja, zh-Hans,
  6.9" (1320×2868): Vent result, generator with Vent selected, Explore,
  Settings (privacy). Drop History (mixed-language seeds, not fixed in this
  binary). Upload via the App Asset Library; remove the inherited 6.5"
  Simplified set from 1.7.0 only. *Proposed as written.*
- **D8 — zh-Hant keywords.** Draft (70/100 chars):
  `靠北,慣老闆,情勒,奧客,回嗆,嗆聲,嘴砲,抱怨,發洩,出氣,吵架,吐槽,反擊,神回覆,罵人,職場,主管,同事,室友,委屈,情緒,社畜,不爽`
  — dropped 嘴替, 回懟, 懟人, 陰陽怪氣, 高情商, 聊天. 靠北 is mildly vulgar
  Taiwanese slang (keywords are hidden; 2.3.8 names icons/screenshots/previews).
  *Proposed as written.*
- **D9 — Timeline.** Target submission 10-10 (plan). Needs: the fixture hook,
  an ASC asset-library uploader + metadata writer (new script), a Release
  screenshot run, preflight, two archives.
