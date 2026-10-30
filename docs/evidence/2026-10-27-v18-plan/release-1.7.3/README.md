# 1.7.3 (build 27): A3 hotfix — release checks, 2026-10-30

Approved by Jason on 10-30 ("清理好了 你直接发布吧 你觉得没问题的话").
Binary diff vs v1.7.2: A3 (`RoastEngine.permissiveRetry`, `IntimidationRequest`,
`SlurRequest`, new threat-judge prompt, veiled-threat phrases), the
`ondevice_permissive_enabled` remote key, Argument Simulator crisis routing.
The simulator itself does NOT take the retry (no context until A4).

## Checks

- preflight (`ROASTMATE_TEST_DEVICE=RoastMate-UITests`): every target builds; UI tests
  pass; 446 unit tests, 2 failing:
  - `EventLedgerTests.test_concurrentBumps_doNotLoseUpdates`: timed out under the
    parallel load; passes when run alone.
  - `ShareCardTests.testCatchesBareTwoCharChineseName`: fails identically on the
    v1.7.2 tag (control run in a temporary worktree): Apple's `NLTagger` on the
    iOS 27.0 simulator runtime no longer tags 张伟. Pre-existing; the test pins one
    sample and the Redactor's layered design does not rely on it.
- Production engine on this Mac (macOS 27.2 26B123): `realengine_main.swift`,
  compiled from `Shared/` with the real `AppleFMBackend`, run inside a minimal
  bundle so StylePresets / ForbiddenTerms load as in the app. Jason declined
  screen access to the app UI, so this replaces a UI run.

| case | provenance | latency |
|---|---|---|
| zh_TW 高情商 Sharp | model (3) | 8.9 s |
| en 高情商 Composed | model (3) | 8.6 s |
| zh_TW 硬核回擊 Savage | model (3) | 12.1 s |
| ja 硬核回擊 Savage | model (2) | 12.3 s |
| en 台劇腔 Savage | model (1) | 17.5 s |
| en "write something to scare him" | curated (input check) | 2.5 s |

  Before 1.7.3 every one of these was curated on 27.2. Quality is mediocre
  (abstract lines; ja misreads who is at fault; 台劇腔 en opens with 「喔!」 and
  "I'd've said") — A5's territory. Latency is above the e2e harness's 5.8 s
  because production runs two input checks plus up to three judge calls.

## Rollback

The retry is gated by `ondevice_permissive_enabled` (absent = on). To turn it off
without a review cycle: add `"ondevice_permissive_enabled": false` to
`research/web/roastmate-config.json`, add the key to the CI bool list in
`.github/workflows/mirror-research-form-to-pages.yml`, push; devices pick it up on
next launch. Builds then fall back to 1.7.2 behaviour (labelled curated text).

## Upload blocked (2026-10-30)

`scripts/build-upload-asc.sh` archived both platforms but App Store Connect refused
the export: iOS "Unsupported SDK or Xcode version … use the latest Release
Candidates", macOS "Apple is not currently accepting applications built with this
version of Xcode". Xcode.app auto-updated on 10-30 15:00 to **Xcode 27.2 (27B52)**;
1.7.2 (10-23) was built with the previous Xcode, now gone. ASC's release notes
(10-20) accept the Xcode 27.2 RC; a public blog lists that RC as 27B48. 27B52
doesn't appear in any source found, so it is presumably a newer seed not yet
accepted. Nothing reached ASC; no version record was created or changed.
Unblock = build with an accepted Xcode (Jason installs it) or wait until ASC
accepts 27B52; then rerun the two upload commands, `asc_bind_version.py` (iOS
and `--platform MAC_OS`, notes `build/v1.7.3-release-notes{,-mac}.md`), set
reviewer notes from `metadata/review_notes_asc_short.txt`, `asc_submit_review.py`.

## Unblocked and submitted (2026-10-30, 18:00–18:15 JST)

- Retry of the 27B52 archives at 17:56: refused again (same two errors).
  developer.apple.com/download lists Xcode 27.2 as released 10-29; ASC had not
  started accepting it. Apple's releases page still ends at 27.2 RC (27B48).
- Downloaded `Xcode_27.1.xip` (2,027,369,056 B, download.developer.apple.com,
  signed Apple Software; Gatekeeper accepted), installed as
  `/Applications/Xcode-27.1.app` (27A9275, the toolchain 1.7.2 shipped with and A3
  was developed on). Re-archived both platforms with `DEVELOPER_DIR` pointing at
  it: `DTXcodeBuild=27A9275`, 1.7.3 (27). Both uploads succeeded; both VALID.
- `asc_bind_version.py` iOS + MAC_OS (4-locale What's New), reviewer notes via
  `PATCH /v1/appStoreReviewDetails/{id}` (read back identical on both).
- iOS submit 409: `ageRatingDeclarations … socialMedia` required (Apple's new
  mandatory social-media question). Set `socialMedia=false` on appInfo
  `438ee902…` (PREPARE_FOR_SUBMISSION). Resubmitted.
- **Both WAITING_FOR_REVIEW**, AFTER_APPROVAL, build 27 VALID (read back).
