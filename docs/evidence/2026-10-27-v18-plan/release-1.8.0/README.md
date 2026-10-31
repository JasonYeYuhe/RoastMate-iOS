# 1.8.0 release checks (2026-10-31)

Build 28, `MARKETING_VERSION` 1.8.0. Not uploaded or submitted yet.

| check | result |
|---|---|
| preflight (Debug, RoastMate-UITests, iOS 27.0) | 494 unit tests, 1 failure = the known `ShareCardTests` 张伟 NLTagger case (same on v1.7.2); UI 7 run, 0 failures (incl. the rewritten `EchoesFlowUITests`) |
| `PaywallFlowUITests`, **Release** (`ENABLE_TESTABILITY=YES`), iOS 27.0, SKTestSession | both pass back to back: Pro-style sample → Generate opens the paywall (not the orange error); yearly listed first; trial line shown when eligible; purchase → success alert → the sample's Pro style selected → the tapped Generate runs (here it stops at the cloud-consent sheet, Vent on a model-less simulator; nothing is sent); trial line absent once the intro offer was used |
| `DeviceHonestyUITests`, Release, **iOS 18.5** (`RoastMate-iOS18`, class C) | simulator explains it needs Apple Intelligence in en and zh-Hant, no paywall: pass; curated paywall header claims the Feral style voice, no "24 styles": pass |
| same, iOS 27.0 | pass (after making the test scroll to the Feral chip) |

Screenshots: `ios18_5-A4-simulator-{en,zh-Hant}.png`, `ios27-A2-paywall-curated-en.png`
(yearly first, $19.99 prominent, ≈ $1.67/month smaller, device-aware monthly row).

Not checked here: a real iPhone on iOS 27 (owner task, via TestFlight) and a
zh-Hant native read of the new copy (owner task). The macOS Release paywall was
not looked at (screen access to the app was declined earlier).
