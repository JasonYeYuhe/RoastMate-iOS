# RoastMate (帮你骂)

An on-device AI **emotional expression** tool for iOS, macOS, and watchOS.
Users describe a situation in plain language; RoastMate generates witty,
safe, multi-style responses through Apple's Foundation Models framework.
No third-party AI service, no network requests, no data collection.

App Store name: **RoastMate**. Localized display name: **帮你骂 / 幫你罵**.

---

## Status

W1–W9 of the 10-week plan in
[`/Users/jason/.claude/plans/app-store-ios-watchos-pure-hare.md`](/Users/jason/.claude/plans/app-store-ios-watchos-pure-hare.md)
are complete. Remaining: ASC dashboard config, screenshot capture run,
GitHub Pages publish, TestFlight beta, final submit.

Run `scripts/preflight.sh` before any archive — it currently passes 71/71
sanity checks.

| | Status |
|---|---|
| iOS target | ✅ Builds |
| macOS target | ✅ Builds |
| watchOS target | ✅ Builds |
| iOS Share Extension (`RoastMateShare`) | ✅ Builds, embedded in iOS app |
| `RoastMateTests` (30 tests) | ✅ All pass |
| App icons (iOS / macOS / watchOS) | ✅ Wired up from `~/Downloads/icon_sizes` |
| 20+ styles in `StylePresets.json` | ✅ Wired up |
| 15 curated samples in `SampleRoasts.json` | ✅ Seeded into History on first launch |
| 4 locales (en / zh-Hans / zh-Hant / ja) | ✅ Strings tables complete |
| Onboarding + age gate + privacy explainer | ✅ Sheet flow |
| 5 generation modes (Roast / Reply / Translate / Argument / Social) | ✅ Plumbed through PromptBuilder + RoastEngine |
| Multi-turn Argument Simulator (Pro) | ✅ Chat-style transcript, up to 12 turns |
| Sample Gallery (15 entries, browse without typing) | ✅ Standalone view |
| App Intent for Siri / Spotlight / Shortcuts | ✅ `GenerateRoastIntent` |
| watchOS → iPhone Handoff | ✅ NSUserActivity round-trip |
| StoreKit 2 paywall UI | ✅ Wired (products need ASC + scheme config) |
| `Configuration.storekit` local sandbox file | ✅ Created; manual Xcode scheme step required (see below) |
| Privacy / Terms / Support links in Settings | ✅ Real URLs (host needed before submission) |
| Haptics (iOS generated/error, watchOS success) | ✅ Cross-platform helper |
| ASC metadata text (4 locales, all required fields) | ✅ `metadata/{locale}/*.txt` |
| App Store reviewer notes | ✅ `metadata/review_notes.txt` |
| Static site for privacy/terms/support | ✅ `docs/site/` (deploy to GH Pages) |
| Screenshot UI test target (XCUITest) | ✅ `RoastMateUITests/ScreenshotTests.swift` |
| `scripts/screenshots.sh` + `extract-screenshots.sh` | ✅ Per-locale × per-device runner |
| `scripts/preflight.sh` (71-check sanity gate) | ✅ Runs all builds + tests + structure |
| App Store screenshots PNGs in metadata/screenshots/ | ⏳ Run `scripts/screenshots.sh` |
| TestFlight + real-device QA | ⏳ W10 |
| ASC product config + ASC app record | ⏳ User-handled |

### Manual setup before first run

1. **StoreKit local config:** In Xcode, choose the **RoastMate** scheme →
   *Edit Scheme* → *Run* → *Options* → *StoreKit Configuration:* select
   `RoastMate/Configuration.storekit`. XcodeGen has no clean way to set
   this on auto-generated schemes; one-time UI step.
2. **App Store Connect:** Register the App ID `yyh.roastmate.app`, the
   watch ID `yyh.roastmate.app.watchkitapp`, the share extension ID
   `yyh.roastmate.app.share`, and the App Group `group.yyh.roastmate.app`.
3. **Privacy / Terms hosting:** Create a public GitHub repo at
   `JasonYeYuhe/RoastMate` (or push this whole project there), enable
   GitHub Pages with `docs/site/` as the source. The site is served at
   `https://jasonyeyuhe.github.io/RoastMate/`. The four pages (index,
   privacy, terms, support) already exist; just deploy.
4. **Screenshots:** Run `scripts/screenshots.sh` then
   `scripts/extract-screenshots.sh`. PNGs land in
   `metadata/screenshots/{locale}/{device}/`.

### Pre-submission

```bash
scripts/preflight.sh    # 71-check sanity gate (builds + tests + structure)
scripts/screenshots.sh  # capture App Store screenshots
./upload.sh             # archive + export + altool upload
```

---

## Build

Requirements: Xcode 26, macOS 26, XcodeGen 2.45+.

```bash
# (re)generate the Xcode project from project.yml
xcodegen generate

# iOS — simulator build
xcodebuild -project RoastMate.xcodeproj -scheme RoastMate \
  -destination 'generic/platform=iOS Simulator' -sdk iphonesimulator build

# macOS — debug build (skip signing for CI)
xcodebuild -project RoastMate.xcodeproj -scheme RoastMateMac \
  -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build

# watchOS — debug build
xcodebuild -project RoastMate.xcodeproj -scheme RoastMateWatch \
  -destination 'generic/platform=watchOS Simulator' -sdk watchsimulator \
  CODE_SIGNING_ALLOWED=NO build

# Unit tests
xcodebuild -project RoastMate.xcodeproj -scheme RoastMateTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

When `project.yml` changes, re-run `xcodegen generate`. **Do not edit
`RoastMate.xcodeproj` directly** — it is regenerated from `project.yml`.

---

## Architecture

```
RoastMate/
├── project.yml                       XcodeGen entry — single source of truth
├── RoastMate/                        iOS target sources, assets, PrivacyInfo
├── RoastMateMac/                     macOS-only: MenuBarExtra, services
├── RoastMateWatch/                   watchOS app
├── RoastMateTests/                   Unit tests (XCTest)
├── Shared/                           Cross-target sources, models, AI core
│   ├── Models/                       SwiftData @Model classes
│   ├── AI/                           RoastEngine + Foundation Models wrapper
│   ├── Services/                     LanguageManager, HistoryService, StoreService
│   ├── Resources/                    JSON catalogs (styles, samples, denylist)
│   ├── SharedModelContainer.swift    App-Group-backed SwiftData container
│   └── {en|zh-Hans|zh-Hant|ja}.lproj/Localizable.strings
└── docs/                             Submission checklist + prompt design notes
```

**Key design decisions**

1. **On-device only in V1.** All generation runs through
   `LanguageModelSession` (Apple Foundation Models). No third-party AI
   service is contacted. This directly addresses the App Store guideline
   5.1.1 rejection pattern that hit Kinen.
2. **App Group `group.yyh.roastmate.app`** shared between iOS, macOS,
   and watchOS so history, settings, and Pro state stay in sync.
3. **Single source of truth for styles.** `Shared/Resources/StylePresets.json`
   defines all 20+ styles. Sessions reference styles by string id;
   updating styles requires no SwiftData migration.
4. **Three-layer safety filter.** Input denylist → Foundation Models
   built-in guardrails → output denylist. See `Shared/AI/SafetyFilter.swift`.
5. **App Store reviewer friendliness.** On first launch, 15 curated
   samples are seeded into History (`isSampleData = true`). Reviewer can
   browse the entire feature surface without typing. Cleanable via
   Settings → "Clear sample data".

---

## What's next (W10 — submission)

- Register App ID + watch ID + share extension ID + App Group + IAP
  products in App Store Connect.
- Deploy `docs/site/` to GitHub Pages at
  `https://jasonyeyuhe.github.io/RoastMate/`.
- Run `scripts/screenshots.sh` then `scripts/extract-screenshots.sh`
  on a Mac with the iPhone 17 Pro Max + 17 Pro simulators installed.
- TestFlight to 10 external testers (zh / en / ja speakers).
- `scripts/preflight.sh` must pass.
- `./upload.sh` to push the IPA.

---

## License

Personal project, all rights reserved.
