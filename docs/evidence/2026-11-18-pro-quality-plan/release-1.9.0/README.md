# 1.9.0 release checks (2026-11-21)

Build 30, `MARKETING_VERSION` 1.9.0, commit `58ae640`. Q1 passed its gate (`q1g2`, bench
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
