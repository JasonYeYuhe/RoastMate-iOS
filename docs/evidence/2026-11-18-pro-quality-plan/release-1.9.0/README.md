# 1.9.0 release checks (2026-11-21)

Build 30, `MARKETING_VERSION` 1.9.0, app code as of `58ae640` (archived from `cb659f4`, which only changed UI tests). Q1 passed its gate (`q1g2`, bench
README); Q2a, Q4 and Q5 were cut. The server half (Q2b, Vent/Feral safety) is already in
production (Worker `eb7b671c`).

| check | result |
|---|---|
| preflight (Debug, `RoastMate-UITests`, iOS 27.0) | 80 pass, 0 fail. Builds: RoastMate, RoastMateMac, Watch, Share, Controls. Unit 519, 0 failures, 7 skipped: the 6 English-tagger cases of `AnswerScreenTests` (see below) and `RoommateEvalTests` (real device only). UI 11, 0 failures, 5 skipped: `PaywallFlowUITests` ×2 and A2 (Release only), A4 (this simulator has the on-device model, see below), `ScreenshotTests` |
| English-tagger cases on macOS | throwaway macOS package of `Shared/` + `AnswerScreenTests`, `FMBackendErrorMappingTests`, `CloudVentEngineTests`: 64/64, nothing skipped, both English models present |
| `PaywallFlowUITests`, **Release** (`ENABLE_TESTABILITY=YES`), iOS 27.0, SKTestSession | 1.9.0: 2/2 pass (35.9 s, 28.3 s). Control `v1.8.0-ios29`, same device and flags: 2/2 pass (35.0 s, 27.7 s) |
| `DeviceHonestyUITests`, Release, **iOS 18.5** (`RoastMate-iOS18`, class C) | A4: the simulator explains it needs Apple Intelligence in en and zh-Hant, no paywall: pass. A2: the paywall header is the curated one ("Feral in the Pro style you pick…"), no "24 styles": pass. Two test fixes first (below) |

Two things this run turned up:
- **The iOS 27.0 simulator now has Apple's on-device model.** `SystemLanguageModel.default`
  reports `available` in it on this Mac (macOS 27.2.1, host Apple Intelligence on); on
  10-31 it did not (A4 passed on iOS 27.0 then). So A4 cannot run there: it now skips
  itself when the simulator opens the working tool. iOS 18.5 has no FoundationModels at
  all and is the real class-C check.
- **The English NLTagger models never load in the iOS simulator's app process**, so the
  answer screen's English rules could not be tested there and 20 unit tests failed in the
  first preflight. Fixed by skipping a rule whose model is missing (bench README, "After
  the gate"); the English cases run on macOS instead.

A2 needed two test fixes on iOS 18.5, neither an app change (no UI code changed since 1.8.0):
- the Feral chip starts off-screen (x 538 in a 402-pt window), and on iOS 18.5
  `isHittable` throws for it ("Activation point invalid") instead of returning false, so
  the scroll loop 1.8.0 added for iOS 27 failed before its first swipe. It now compares
  frames;
- StoreKit's products stayed "Loading…" on this fresh clone, so the yearly plan row the
  test used as its "paywall is open" signal never appeared and the test skipped. It now
  keys on the header text itself, matching the start of `paywall.body.curated` (the old
  "Pro style you pick" also matched the Feral feature row). The screenshot shows the
  curated header and "Loading…" plan rows.

Screenshots: `ios18_5-A4-simulator-{en,zh-Hant}.png`, `ios18_5-A2-paywall-curated-en.png`.

Not checked here: a real iPhone on iOS 27 (owner task, via TestFlight; the one thing it
would show that nothing here can is whether a real iPhone's app process has the English
tagger models), a real iOS 18 device, and the macOS Release paywall.

## Upload and submission (11-21)

- Signing probes before archiving: console locked, login keychain `no-timeout`, a test
  `codesign` with Apple Distribution succeeded.
- `scripts/build-upload-asc.sh`, Xcode 27.2 (27B52) for both: iOS build 30 and macOS
  build 30 both `VALID` in the ASC builds API. **macOS 27B52 was accepted**, so per plan §5
  Xcode 27.1 is no longer needed for macOS uploads. The live 1.8.0 archives were kept as
  `build/RoastMate-v180-b29.xcarchive` and `build/RoastMateMac-v180-b28.xcarchive` (the
  script deletes `build/<scheme>.xcarchive` before archiving).
- Jason approved the exact words on 11-21: What's New ×4 (`build/v1.9.0-release-notes{,-mac}.md`,
  identical), the queued keywords (en-US, zh-Hant, ja) and zh-Hant subtitle, promo text and
  descriptions unchanged from 1.8.0, and "submit now, release 12-07".
- `asc_bind_version.py` (IOS, MAC_OS), `asc_product_page.py text` (dry run, then `--apply`;
  read-back OK: 4 changes on iOS incl. the subtitle, 3 keyword changes on macOS), reviewer
  notes from `metadata/review_notes_asc_short.txt` (3785/4000, read-back matches),
  `releaseType` SCHEDULED with `earliestReleaseDate` 2026-12-07 00:00 JST
  (2026-12-06T07:00:00-08:00).
- `asc_submit_review.py`: iOS submitted 13:55:10Z, macOS 13:55:25Z. Read-back: both 1.9.0
  `WAITING_FOR_REVIEW`, SCHEDULED, build 30; both 1.8.0 still `READY_FOR_SALE`.

Still to do: on a rejection, reply in Resolution Center before resubmitting; once 1.9.0
is live, `git tag v1.9.0` on `cb659f4`.
