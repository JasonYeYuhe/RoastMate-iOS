# RoastMate — handoff for the v1.8 wave (start here)

You are picking up **RoastMate** (幫你罵 / 帮你骂 / RoastMate AI, `~/Documents/RoastMate`) —
Swift 6, iOS 18+ / macOS 14+, plus a Cloudflare Worker in `cloud-worker/`.
Taiwan is the target market. Solo developer (Jason). Branch
`feature/v1.4-track-b` (every release since v1.4 shipped from it; `main` stopped
in May and is far behind — don't merge or rebase onto it as a side quest).

**Read in this order:**
1. this file
2. `docs/NEXT_PHASE_PLAN_2026-11.md` — **since 11-08 the plan you are executing**
   (path A, chosen by Jason). Then `docs/DEV_PLAN_v1.8_2026-11.md`, which still
   governs the 11-15 rule read, the 01-31 read and the freeze. Read §2.1 (how it
   relates to the stop rule), §3 (scope), §6 (guardrails) and §9 (what the two
   reviews changed) before writing code.
3. project `CLAUDE.md` and the global `~/.claude/CLAUDE.md` (signing, simulators,
   build roots, cleanup)
4. `docs/evidence/2026-10-27-v18-plan/lens-1..4-*.md` — the measurements behind
   the plan, when an item needs its detail
5. `docs/HANDOFF_v1.7_NEXT_SESSION.md` — only the "Update 2026-10-23" and
   "Update 2026-10-22" sections and "Machine rules that bite"
6. `docs/HANDOFF_v1.6_NEXT_SESSION.md` — only "VERIFY BEFORE YOU ACT", "Debug
   builds are always Pro", "Hard-won gotchas", "Design rules"

**Do not trust this document either.** Every recent wave found 10+ claims in its
own docs that were false when checked; the 10-27 review of this plan found more
(plan §9). A claim about code is not true until you open the file; a claim about
production is not true until you measure it.

## Update 2026-11-08 (evening) — A1 post kit final, A5 readout scheduled

- **A1 done; waiting on Jason.** `docs/distribution/2026-10-23-p21-posts.md` is
  re-checked against 1.8.0 and final. Its top section lists every claim and how it
  was checked.
  - All claims hold.
  - Added: the yearly 7-day trial (ASC: `FREE_TRIAL`/`ONE_WEEK` in TWN, eligible
    new subscribers only) and the one free 痛罵 preview (`ProPreview.swift`).
  - The stale icon note is resolved: the live TW artwork shows 幫你罵.
  - PTT: the template now starts on line 1, and the disclosure moved into 程式簡介.
    The link is the full App Store URL, because rule 5-A⑴ bans shortened or
    altered links (re-read 11-08; the short `id…` URL is a 301 to the full one).
    No campaign link on PTT.
  - Threads: a campaign link (`ct=th1` / `th2`) only if Jason gives the `pt=`
    token. Otherwise the plain link. Campaign rows will probably stay empty at
    this volume (Detailed reports are thresholded), so A4 reads TW page views by
    date and Source Type.
- **Rewrite re-run on macOS 27.2 with 1.8.0 code** (two post examples × 5,
  `docs/evidence/2026-11-08-next-phase/a1-rewrite-recheck/`):
  - Both quoted rewrites pass every 1.8.0 screen.
  - 8/10 runs produced a rewrite.
  - **2/10 harmless rewrites were blocked by the new threat judge**, so the user
    sees the labelled example. The PTT post now says it 「偶爾也會改不出來」.
  - Parked in NEXT_PHASE_PLAN §9, not built.
- **A5 done:** `scripts/weekly_readout.py`, read-only.
  - Weekly table of downloads, page views and TW by source; subscription events;
    the latest SUBSCRIPTION snapshot; posts logged; a FINGERPRINT line.
  - Scheduled task `roastmate-weekly-readout` runs Mondays at about 10:30 JST,
    first run 11-09. It reports only on change, flags A4 at T + 7, says it on the
    first run after 11-22 if there are fewer than 3 posts, and then disables itself.
  - History: `~/Documents/RoastMate-research/weekly-readout-log.tsv`, seeded with
    the 11-08 baseline: 9 downloads, 46 page views (TW 20), 3 subscription events,
    billing retry 1, 0 posts.
- **How to log a post** (the readout counts these rows): one row per post in
  `~/Documents/RoastMate-research/creator-outreach-log.tsv`, laid out as
  `YYYY-MM-DD HH:MM (TW)<TAB>post:ptt-ios|post:threads-1|post:threads-2<TAB><post URL><TAB>-<TAB>-<TAB>link=plain|ct=th1…`.
  The third row's date is T.
- **Later 11-08: Jason confirmed all three texts and destinations** (PTT iOS
  `[廣宣]` on Monday 11-09 or 11-16; Threads #1; Threads #2 two to four days
  later), and allowed a Chrome read of `pt=`.
  - `pt=128677340`, read in ASC → Campaigns → "Generate a Campaign Link"
    (builds a URL only, saves nothing).
  - Threads links are now `…/tw/app/id6769317103?pt=128677340&ct=th1&mt=8`
    (`th2` for #2). curl: 301 keeps `pt`/`ct`, then 200.
  - Length with the link: #1 488, #2 484 (limit 500).
  - PTT stays on the plain full URL.
  - ASC shows a campaign only after at least 5 Apple Accounts installed through
    it, so A4 still reads Standard reports by date and Source Type.
- Still Jason's: post, then send each post's URL and Taiwan time. The agent logs
  the rows; the third row's date is T.

## Update 2026-11-08 — next phase CHOSEN: path A (reach push, no feature binary), D from 11-22

**Read `docs/NEXT_PHASE_PLAN_2026-11.md` first.** It is now the plan being executed.
The v1.8 plan still governs the 11-15 rule read, the 01-31 §2.3 read and the
12-05 freeze. Under path A there is **no 1.8.1 and no Worker deploy**.

- **Jason chose path A on 11-08**, with the hard pivot: fewer than 3 posts live by
  **11-22** → path D (maintenance mode). Both reviewers proposed the same, each
  on their own. Their answers are in `docs/evidence/2026-11-08-next-phase/`; the
  plan's §7 lists what was accepted and rejected after checking.
- **A2 done:** Billing Grace Period is ON (16 days, ALL_RENEWALS, production +
  sandbox; ASC API, read back). To undo: `PATCH /v1/subscriptionGracePeriods/6769317103`
  with `optIn: false`. The side effect is in the plan's header.
- **Next, in order:**
  1. **A1, now:** finalise the post kit for Monday PTT 11-09 / 11-16 (details below).
  2. **A5:** a weekly read-only readout task.
  3. **A3:** refresh the brief on 11-14; record the rule on 11-15.
  4. **A4:** the funnel check at T + 7.
  5. **11-22:** check the posts — 3 live → continue A; fewer → switch to D.
- **A1 in detail.** Re-check every claim in
  `docs/distribution/2026-10-23-p21-posts.md` against the 1.8.0 code and copy, and
  add the 7-day yearly trial and the one free 痛罵 preview.
  - Argon says the drafts have "zero false claims"; that is unverified here.
  - Fix the stale §4.5 note about the Simplified icon: the icon has been
    Traditional since 1.7.2 (`64c4867`).
  - Campaign links: the `pt=` provider token is Jason's (ASC → App Analytics →
    Campaigns), or the agent reads it in Chrome if he says so. Check PTT rule 5-A
    ("original, unshortened URL; no affiliate links") before putting `ct=`/`pt=`
    in the PTT post; if in doubt, PTT gets the plain URL.
  - Jason posts and confirms each text and place. The agent logs each URL and
    time (Taiwan time) in `~/Documents/RoastMate-research/creator-outreach-log.tsv`.
    The third post sets T.

## Update 2026-11-06 — 1.8.0 LIVE on iOS (29) and macOS (28)

- **iOS 1.8.0 (29) READY_FOR_SALE.** Submission `da992ccb…` is COMPLETE, with all 3
  items APPROVED (the version and both subscriptions). The public lookup for
  US/TW/JP shows 1.8.0, `currentVersionReleaseDate` 2026-11-05T03:00:16Z.
  macOS 1.8.0 (28) has been live since 11-02.
- **Tags (pushed):** `v1.8.0` → `cd1667d` (build 28: macOS live, iOS rejected) and
  `v1.8.0-ios29` → `f29e666` (iOS build 29).
- **`check_live_text.py`:** all 8 version localizations (iOS + macOS × 4 locales)
  MATCH `metadata/` for both description and promotionalText. All 8 subscription
  localizations are APPROVED with the new text, and no old "Unlimited" row is left.
- `roastmate-180-review-watch` is disabled; its job is done.
- `ondevice_permissive_enabled`: nothing to do. Absent means on. Add it to
  `roastmate-config.json` and the CI bool list only to kill the retry.
- **US renewal** (plan §8, row 11-04 → 11-06; recorded, not counted), re-read
  11-08: **the renewal charge failed; the subscriber did not cancel.**
  - The 11-04 Subscription Event report has "Billing Retry from Paid
    Subscription" (US, RoastMate Pro Monthly).
  - The 11-04, 11-05 and 11-06 snapshots show active 0, Billing Retry 1, Grace
    Period 0. No renewal appears in Sales 11-03 to 11-06.
  - So nobody is paying right now. Apple keeps retrying for up to 60 days, and
    auto-renew is still on.
  - Billing Grace Period is not enabled (Grace Period 0), so they have no Pro
    while the retries run. Turning it on is an ASC setting and Jason's call; it is
    listed as an option in the 11-15 brief, not done.
  - How the reports read: on 11-06 (JST) the 11-04 snapshot and event reports
    were 404 even though 11-04 Sales was already published. Subscription reports
    lag Sales by about a day, so a 404 there does not mean "nothing happened".
- **Jason, 11-08:** the zh-Hant native read of the new copy is done, with no
  problems. `RoastMate-iOS18` (79415AE4…) is deleted (checked).
- **Next:** the 11-15 brief is drafted with 11-08 numbers in
  `docs/evidence/2026-10-27-v18-plan/brief-2026-11-15.md`; refresh it on 11-14.
  On 11-15, record the v1.7 §7 stop rule's result word for word here. As of 11-08,
  0 P2.1 posts are logged, so the first branch fires unless three go up first
  (plan §2.1). No slot-feature code before Jason picks a slot. Freeze 12-05.

## Update 2026-11-04 — iOS 1.8.0 (29) RESUBMITTED, WAITING_FOR_REVIEW

- **Cause, from the reviewer's screenshot** (`release-1.8.0/review-Screenshot-1102-165859.png`):
  the App Store's own alert "Your account is temporarily unavailable. Try again
  later. [Environment: Sandbox]" — the review device's sandbox account, not our
  code. The 11-03 "scene-less purchase call" suspicion below is wrong (StoreKit
  presented its UI in our window). Build 29's `PurchaseAction` stays as the
  documented API; the comment in `StoreService.swift` now says so.
- Paid Apps Agreement **Active** (Oct 14, 2026 – Mar 19, 2027), checked in ASC.
- **Resubmitted 11-04 02:21 UTC** (Jason: "直接做"): build 29 attached to iOS 1.8.0,
  the rejected item marked `resolved: true` (PATCH `/v1/reviewSubmissionItems/{id}`
  — without it the submit 409s "Version is not ready to be submitted yet"), then
  `submitted: true` on the same submission `da992ccb…`. All 3 items (version +
  both subscriptions) READY_FOR_REVIEW. Rollback before review: Cancel Submission.
- **Resolution Center reply NOT sent, and no longer possible:** typed and checked
  exact, but the session's permission classifier blocked the click; once the
  submission went back to WAITING_FOR_REVIEW, ASC removed "Reply to App Review"
  from the page. **If it is rejected again: reply first, resubmit after.** The
  text is in `rejection-2026-11-02.md`; the reviewer notes are at 3979/4000 and
  locked while in review, so there is no other place for it now.
- `roastmate-180-review-watch` updated for build 29. When iOS is live:
  `git tag v1.8.0-ios29 f29e666 && git push origin v1.8.0-ios29`, then run
  `check_live_text.py` (old "Unlimited generations" rows should be gone).

## Update 2026-11-03 — iOS 1.8.0 (28) REJECTED 2.1(b); macOS 1.8.0 (28) LIVE; build 29 uploaded

- **macOS 1.8.0 (28) is READY_FOR_SALE** (approved 11-02). **iOS 1.8.0 (28) REJECTED**,
  submission `da992ccb…` UNRESOLVED_ISSUES: "when we tried to purchase the
  subscriptions the app showed an error message" (iPhone 17 Pro Max, iOS 27.2,
  sandbox; no screenshot mentioned). Full record, what was ruled out, and a draft
  Resolution Center reply: `docs/evidence/2026-10-27-v18-plan/release-1.8.0/rejection-2026-11-02.md`.
- **Suspected cause (not proven):** `product.purchase()` with no UI context.
  **Fix `f29e666`:** the paywall passes SwiftUI's `@Environment(\.purchase)` into
  `StoreService.purchase(_:using:)` / `purchaseCredits(_:using:)`; failures are
  logged in full. Release `PaywallFlowUITests` (SKTestSession, iOS 27.0) 2/2 pass.
  SKTestSession runs with dialogs disabled, so the window/scene path is checked
  only by a real sandbox purchase.
- **Build 29 uploaded** 11-03 16:58 JST (iOS only, Xcode 27.1; symbols for the new
  path verified in the archive). Build 28's iOS archive kept at
  `build/RoastMate-v180-b28.xcarchive`.
- **Tag:** `v1.8.0` still goes on `cd1667d` (macOS 28 is the live 1.8.0 binary).
  If iOS 29 ships, also tag `v1.8.0-ios29` on `f29e666`.
- **Before resubmitting (gate):** Jason's TestFlight purchase on his iPhone —
  build 28 (does it reproduce?) and build 29 (must succeed); Jason confirms the
  Paid Apps Agreement is Active (ASC → Business; no API). Resubmit = attach build
  29 to iOS 1.8.0 and re-submit the same submission `da992ccb…`, which keeps the two
  subscription-description items (the API can't re-add them). Rollback before
  review starts: cancel that submission.
- The Resolution Center reply is in Jason's name: only with his OK of the text.

## Update 2026-11-02 — still in review; tag target and post-launch check ready

Checked 11-01 17:00 UTC: both 1.8.0 rows WAITING_FOR_REVIEW (build 28); Worker
`046f2134`; remote config unchanged; `roastmate-180-review-watch` ran OK at 15:05Z.

- **Build 28 = `cd1667d`.** Checked against the shipped iOS dSYM, not taken from
  the commit log. `cd1667d` added 4 lines to `RoastMateApp.swift` (168 → 172),
  and `build/RoastMate.xcarchive`'s line table has entries at 169–171, so the
  archive contains them. The commits after it are docs only. Previous tags are
  lightweight. When both platforms are live:
  `git tag v1.8.0 cd1667d && git push origin v1.8.0`.
- **Store text:** the 1.8.0 description and promotional text match
  `metadata/<locale>/` in all 8 places (2 platforms × 4 locales).
- **Subscription descriptions:** the new text (8 rows) is PREPARE_FOR_SUBMISSION.
  The old "Unlimited generations" rows are still APPROVED, and the StoreKit sheet
  keeps showing them until approval. The iOS review submission has 3 items: the
  version plus two items the API doesn't label, which fits the two subscriptions.
  **After launch**, run
  `python3 docs/evidence/2026-10-27-v18-plan/release-1.8.0/check_live_text.py`
  (read-only). It should show only the new text as APPROVED, with no
  `<- old text` rows. If old rows are still there, the subscription edits weren't
  reviewed with the version, and the fix is in the ASC web UI (Jason).

## Update 2026-11-01 — 1.8.0 SUBMITTED (iOS + macOS, build 28)

- **WAITING_FOR_REVIEW on both platforms**, submitted 2026-11-01 08:03 UTC,
  release AFTER_APPROVAL. Built from `de2fbc6`+ (build 28, Xcode 27.1).
- The iOS submission also carries both Pro subscriptions' new descriptions
  (4 locales each, "Unlimited generations" gone), entered in the ASC web UI.
- **A9 privacy policy published** (Pages repo `f92765b`, "Last updated:
  November 1, 2026"; live, checked). Jason approved by delegation 11-01.
- Product page text (description + promotional text, 4 locales) written on both
  1.8.0 versions; reviewer notes set (3980/4000).
- OpenRouter "Allow free endpoints that train on request data" is OFF (Jason,
  11-01). Keep it off: the published privacy policy says vent text is not used
  for training, so any `:free` model that needs this switch is ruled out.
  **Jason confirmed 11-02: stay on the paid Qwen models** (no `:free` switch).
- **Still Jason's:** real-iPhone iOS 27 check via TestFlight build 28; a zh-Hant
  native read of the new copy.
- Review watch: scheduled task `roastmate-180-review-watch` (every 3h, read-only
  ASC API) reports state changes and disables itself once both are live.
- When live: tag `v1.8.0`. 11-15: read the v1.7 stop rule and write the one-page
  brief (plan §2.1) — no code for a slot item before Jason picks.
- Delete the temporary device: `xcrun simctl delete 79415AE4-D1AA-4C77-93BA-54C4CA2B17E2`.

## Update 2026-10-31 (afternoon) — 1.8.0 built, not yet submitted

Branch `feature/v1.4-track-b`. Production unchanged (Worker `046f2134`, remote
config untouched). 1.7.3 is live. Everything below is committed and pushed.

| item | state | evidence |
|---|---|---|
| A4 simulator | done: stateless opponent prompt + one persona call + A3 retry/screens per turn + repeat retry; no canned turns; C/E explains it needs Apple Intelligence | `evidence/.../a4/README.md`: 30, 28, 28 of 36 in the opponent's voice (gate 29 met once); 0 numbered; ≤1/18 refused |
| A5 styles | done: per-script examples for every Pro style, per-language preambles, Savage calibration, wrapper strip, near-dup drop | `a5/README.md`: vs a v1.7.3 control on this Mac, CJK in en 15 → 0, "I'd have said" 6 → 0, 0 Simplified |
| A7 + B3 | done: classic Echoes tile gone; roommate consent text true in 4 locales and re-asked (`echoesCloudConsentV2Raw`); Settings toggle only where the tile shows | `StoreCopyTests`; `EchoesFlowUITests` rewritten |
| A2 copy | done in the app; **ASC subscription descriptions still say "Unlimited generations"** — the API refuses edits to ACTIVE localizations; do it in the ASC web UI before submitting | `StoreCopyTests` |
| A6 purchase | done: yearly first, eligibility-gated trial line, hand-off, Pro-style sample → paywall | `PurchaseHandoffTests`; Release UI test `PaywallFlowUITests` |
| B4 | label alignment only (文青日記體, 對焦、綜效、落地); Worker name map updated in source, not deployed | — |
| B5 | done: one labelled Feral preview after a free user's first cloud Vent | `ProPreviewTests` |
| A8 | done: 幫你罵 / 帮你骂 home-screen name (app + Share + Controls; Mac LSHasLocalizedDisplayName), zh-Hant shortcut phrases, 5 zh-Hant samples first | built bundles checked |
| A9 | **draft only, needs Jason's approval** (legal page in his name) | `a9/README.md`, `a9/privacy.diff` |

Release material: `build/v1.8.0-release-notes{,-mac}.md` (gitignored),
`metadata/review_notes_asc_short.txt` rewritten for 1.8.0 (3980/4000).
Temporary device `RoastMate-iOS18` (iOS 18.5, clone of Soundpost-iOS18) for the
class-C UI run; delete it after: `xcrun simctl delete 79415AE4-D1AA-4C77-93BA-54C4CA2B17E2`.

Done since: version 1.8.0 (28); Release UI runs pass (`release-1.8.0/README.md`);
**build 28 uploaded for iOS and macOS** (Xcode 27.1, 10-31 18:57), so it is in
TestFlight for Jason's iOS 27 iPhone check. No version record, nothing submitted.
Still to do before submit: Jason approves A9 and checks the OpenRouter privacy setting;
ASC web: subscription descriptions; product-page lines + promo text
(`asc_product_page.py`, dry run first, `--app-id 6769317103`).

## Update 2026-10-31 — 1.7.3 LIVE; B3/B4/B5 decided (delegated)

- **1.7.3 is READY_FOR_SALE on iOS and macOS** (approved within a day); tag
  `v1.7.3` → `de4906d`. Now add `ondevice_permissive_enabled` to the CI bool
  list + `research/web/roastmate-config.json` only if a kill is needed (absent =
  on, so nothing is required).
- Jason delegated every decision to the agent on 10-31 ("你全权负责做决定吧").
  Still his: anything sent in his name, the privacy-policy diff (legal page in his
  name), the native reader, the iOS 27 iPhone check.
- **B3 = retire the Classic Echoes tile in 1.8.0** (both reviewers; refused 22/22
  on macOS 27, unlabelled canned transcript). Roommate group stays.
- **B4 = label alignment only** (豆瓣短文 → 文青日記體, MBA blurb → 對焦、綜效、
  落地; string-only, no Worker deploy). 京片兒 → 台式長輩文 needs a native reader;
  none is arranged, so it is not built (the plan's own no-reader branch).
- **B5 = yes:** one labelled 痛罵 preview after a free user's first cloud 發洩,
  once per iCloud account, recorded as a preview exception, not credits.
- Free disk 24 GB (DerivedData 29 GB, mostly other projects): no simulator boots
  until it is above 30 GB. Tests run in the standalone macOS runner meanwhile.
- Order: A4 → A5 → A7+B3 → A2 → A6 → B5 → B4 → A8; A9 diff for Jason's approval.

## Update 2026-10-30 — 1.7.3 SUBMITTED (iOS + macOS, build 27)

- **1.7.3 = A3 hotfix, WAITING_FOR_REVIEW on both platforms** (submitted
  2026-10-30 09:14 UTC, release AFTER_APPROVAL). Built from `de4906d`. Reviewer
  notes = `metadata/review_notes_asc_short.txt` (read back byte-identical).
- **Built with Xcode 27.1 (27A9275) at `/Applications/Xcode-27.1.app`**, via
  `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer`. The Mac App
  Store updated `/Applications/Xcode.app` to 27.2 (27B52, released 10-29) and ASC
  refused both uploads from it a day later. Keep 27.1 until ASC accepts 27B52.
- **New ASC requirement:** the age-rating questionnaire's `socialMedia` answer is
  mandatory; the submit 409'd until it was set. Answered `false` on the pending
  appInfo (no feeds/profiles/user interaction; matches messagingAndChat=false,
  UGC=false). Rating stays 18+.
- **Rollback:** before approval, cancel the review submissions; after release,
  `"ondevice_permissive_enabled": false` in `research/web/roastmate-config.json`
  (+ the CI bool list) turns the retry off without a binary.
- Next: watch review; when live, tag `v1.7.3`. Then 1.8.0 (A4 first).

## Update 2026-10-29 (overnight session) — read first

Branch `feature/v1.4-track-b`. Production unchanged: Worker `046f2134` (rollback
`7846ac95`), remote config untouched, nothing submitted. Eval spend $0.005 of $2.

- **A1 is cut.** Round 2 (6 preview calls) was recognisable 5/5 but read worse
  than the unstyled draft 5/5 in a blind read (`evidence/.../a1/README.md`). Two
  failed rounds = cut under §2.4. 硬核回擊 stays as deployed.
- **A3 is implemented** (`RoastEngine.permissiveRetry`, commit `b719bb2` + the
  next one). After a default refusal on a sendable call: two input checks
  (intimidation, identity attack: phrases + one-word model checks), one fresh
  permissive call, then per variant ModelRefusal → validateOutput →
  RewriteThreatScreen → threat judge. Remote key `ondevice_permissive_enabled`
  (absent/true = on). Measured on macOS 27.2: default guardrails accepted **0/50**
  sendable generations, so on 27.2 this path IS the product.
- **Threat judge prompt replaced** (also guards the live rewrite). Blind: 32/40
  threats caught (old 24/40), 8/40 legit blocked (old 10/40); 297 real roasts:
  20 blocked (old 39).
- **A3's gate as written ("0 threats reach the screen") is not met by the output
  screens alone**: blind, about 1 veiled threat in 4 passes. End to end on the
  safety set, 0 threats and 0 slurs shown after the input checks, but those
  inputs are mine. Honest blind numbers: intimidation requests stopped 24/36,
  identity-attack requests 30/30. **Whether that is good enough to ship A3 is
  Jason's call** (`harness/safety/{judgetune,intent,e2e}/README.md`).
- **A4 part done:** the Argument Simulator routes `crisisSignal` (hard → crisis
  support, soft → banner). The stateless opponent prompt is still to do.
- **Not run:** the simulator test suite / preflight. Free disk was 29 GB (< 30)
  with 23 GB in the Trash, so no simulator boot or full build. The iOS app and the
  touched tests type-check, and the 26 engine + config tests pass in a standalone
  macOS runner (`swiftc` of Shared + the test files with an XCTest stand-in).
  Run `ROASTMATE_TEST_DEVICE=RoastMate-UITests scripts/preflight.sh` once the
  Trash is emptied.
- **When 1.8.0 ships:** add `ondevice_permissive_enabled` to the CI bool list in
  `.github/workflows/mirror-research-form-to-pages.yml` and to
  `research/web/roastmate-config.json` (a production config edit: gate first).
- iCloud renamed `cloud-worker/node_modules/.../bin/workerd` and `esbuild` to
  `* 2` duplicates; restored by copying. If `wrangler` fails with "needs the
  @cloudflare/workerd-darwin-arm64 package", check for that first.

## Update 2026-10-27 (evening session)

- **This Mac is on macOS 27.2 (26B123), installed 10-27 14:12.** Every on-device
  number in the plan was measured on 27.0.1. On 27.2, default guardrails refuse
  the production prompts almost everywhere: Savage + Pro styles 36/40, Sharp + Pro
  12/12, simulator 36/36, **free Composed/Sharp 15/16**. The model itself is fine
  (neutral prompts pass). Permissive accepts 8/8 (3 variants, Traditional). If
  iOS 27.2 shipped too (UNVERIFIED), AI iPhones that updated now see curated text
  for nearly every on-device generation, free tier included.
  `docs/evidence/2026-10-27-v18-plan/baseline-macos272/README.md`.
- **The threat screens are weaker on 27.2:** 14/26 held-out threats reach the
  screen (14/19 veiled); 5/28 legitimate complaints blocked. A3's gate fails on
  today's screens, and the same judge guards the shipped 改成能發的 rewrite.
- **Safety set built:** `harness/safety_set.json` + runner `harness/safety/`.
- **The Argument Simulator never calls `crisisSignal`**
  (`ArgumentSimulatorViewModel.swift:73` runs only `validateInput`) — A4 must route it.
- **A1 round 1: not deployed.** Blind pairs 6/6, but every zh_TW draft ended
  「你就是個爛人」, invented charges, a 夸獎 leak. Production is still `046f2134`.
  `docs/evidence/2026-10-27-v18-plan/a1/README.md` has the next-round plan; it
  needs Jason's OK for ≤ 12 more preview calls (the plan capped A1 at 20).
- Harness paths are repo-relative (`$ROASTMATE_ROOT` overrides);
  `compare_ext.mjs` takes `EXPECT_CHANGED=<style ids>`.
- Gemini 4 Argon via agy: quota exhausted until ~11-02. Gemini 3.8 Flash works.
- Eval spend so far $0.004 (`spend_ledger.md`); OpenRouter $9.86.
- HEAD was `f5fec49` (plan committed), not `b737392` as the status below says.

## Status (verified 2026-10-27 unless dated)

- **Live:** iOS + macOS **1.7.2 build 26** since 2026-10-23 20:45Z (Traditional
  幫你罵 icon, app-owned plan copy). Tags `v1.7.0`, `v1.7.1`, `v1.7.2` (→ `64c4867`).
  `project.yml` is 1.7.2 / 26. HEAD `b737392`.
- **Worker:** `046f2134` (rollback `7846ac95`). Taiwan register for zh-Hant; Pro
  styles shape the voice of Vent/Feral (free styles unchanged); names never used
  to address the person. `wrangler.toml`: `ROAST_MODE_ENABLED="false"`,
  `CLOUD_DISABLED="false"`, `GROQ_ENABLED="false"`, `ALLOW_SANDBOX_RECEIPTS="false"`,
  `DAILY_LIMIT_PER_DEVICE=30`, `PRO_DAILY_LIMIT=200`.
- **Remote config** (`roastmate-config.json`, fetched 10-27): `vent_cloud_enabled`,
  `echoes_enabled`, `roommate_group_enabled`, `share_card_enabled` (since 10-23)
  true; `cloud_sendable_enabled` false and RETIRED forever; `force_local_only` false.
- **Money:** two payers ever, both Pro Monthly at full price, both on download day.
  TW cancelled day 0 (09-19, v1.5.0, iOS 27), lapsed 10-19. **US active, renews
  ~11-04** (iOS 26.6 at purchase; no 1.7.x update seen on a US iPhone — only Worker
  changes can reach them before renewal). **0 purchases since 10-04.** First-time
  downloads 10-07 → 10-24: 7 (4 iPhone, 3 Mac; TW 1). Impressions 301, page views 26.
- **Yearly plan** NT$690 / US$19.99 has a 7-day free trial in all 175 territories
  that the app never shows (`paywall.yearly.trial` is read by no Swift file).
- **OpenRouter:** $9.88 left (balance log 10-26), auto-top-up OFF (hard cap). The
  only live model path (`qwen/qwen3-30b-a3b-instruct-2507`, fallback
  `qwen/qwen3-next-80b-a3b-instruct`).
- **Distribution:** no P2.1 post logged as of 10-27 (drafts:
  `docs/distribution/2026-10-23-p21-posts.md`). The stop rule's T has not started,
  so on **11-15** the rule's first branch fires unless three posts go up first.
- **Live privacy policy** (`jasonyeyuhe.github.io/RoastMate/privacy.html`, "Last
  updated October 20, 2026"; source = the separate Pages repo
  `JasonYeYuhe/RoastMate`, **not** this repo's stale `docs/site/`): still says
  declining cloud gives a "gentler" on-device Vent/Feral (false — labelled
  examples) and that cloud is used "by default" (consent comes first); omits the
  roommate group and the style id. Fixing it is plan item A9.
- **ASC subscription descriptions** still say "Unlimited generations" (shown on the
  StoreKit purchase sheet). The API refuses edits while ACTIVE; Jason edits them in
  the ASC web UI before 1.8.0 is submitted (plan A2 submit gate).
- **In the working tree, untracked on 10-27:** `docs/DEV_PLAN_v1.8_2026-11.md`,
  this file, `docs/evidence/2026-10-27-v18-plan/` (lens reports, both Gemini
  reviews, the next-session prompt). If `git status` still shows them untracked,
  commit them first (docs only).
- **Disk:** 50 GB free on 10-27.

## Owner decisions already made (with dates)

- **2026-10-27:** "make all our current paid features better, because paying
  users keep shrinking." Invest in paid-feature quality now, as a bounded
  exception to the v1.7 stop rule (plan §2.1). The formal B0 confirmation of the
  plan's bounds is still due by 10-29.
- **2026-10-27 (from the plan as reviewed):** 1.8.1 is **not** pre-approved. On
  11-15 Jason reads the stop rule and fills at most one slot (B1-R, B1-S, B2 or
  B8) or none; if the rule fired, the default is none.
- **2026-10-23:** P2.1 posts go up after the 1.7.2 icon is live (it is). PTT
  [廣宣] only on Mondays. T = the date of the third post; log each post's URL and
  time. Creator batch 2 waits for Jason's confirmation of each send.
- **2026-10-23:** `share_card_enabled` ON (rollback: set it false).
- **2026-10-22:** Lifetime Pro — decide after 11-15.
- **2026-10-07:** never contact the three batch-1 creators again.
- **2026-09-30:** keep the iOS 18.5 simulator runtime while the deployment target
  is iOS 18.
- **2026-09-26:** mainland China delisted; Taiwan first; `cloud_sendable_enabled`
  retired forever (CI-enforced). Any new cloud path needs a new flag and a new
  versioned consent.

## Your job

Execute `docs/DEV_PLAN_v1.8_2026-11.md`: **A1** on the Worker in the first week,
then binary **1.8.0** (A2–A9 plus whichever of B3/B4/B5 Jason approves by 10-31),
**submitted by 11-12** so it is live before the 11-15 read. Then the 11-15 brief.
Do not start any 11-15 slot item before Jason picks one. Nothing outside plan §3
gets built; new ideas go to §8.

### First three steps

**Step 1 — verify, preserve the harness, rebuild the safety set (day 1).**

```bash
cd ~/Documents/RoastMate
git status --short && git log --oneline -3          # plan docs untracked? commit them (docs only)
sed -n 20,21p project.yml                           # 1.7.2 / 26
curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json
python3 scripts/asc_analytics.py --since 2026-10-24 # any purchase? US still active?
scripts/openrouter-balance.sh 5                     # exit 1 = below $5 → stop evals, tell Jason

# The 10-27 lens harness (sources + results, no binaries, no raw ASC TSVs — the lens3
# scripts re-fetch those) was copied into the repo on 10-27:
H=~/Documents/RoastMate/docs/evidence/2026-10-27-v18-plan/harness
grep -rn "/private/tmp\|scratchpad" "$H" | head    # fix these absolute paths at the top of each file
```

Then write `harness/safety_set.json` (plan §7.1): ≥ 24 threats (12 veiled), ≥ 24
legitimate complaints describing harassment/racism/violence, self-harm, PII and
slur bait, zh_TW + en (+ ja for A3). The 10-22 held-out set is gone with its
scratchpad; seed it from `RoastMateTests/RewriteThreatScreenTests.swift` and the
examples in `Shared/AI/RoastEngine.swift:528-531, 576-591`.

Baselines on this Mac (macOS 27, Apple Intelligence on). The probe compiles
production files (its header comment names them); build output goes to your own
scratchpad, never the repo:

```bash
R=~/Documents/RoastMate; OUT=<your scratchpad>/build; mkdir -p "$OUT"
swiftc -O -o "$OUT/lens1probe" "$H/audit/probe/main.swift" "$H/audit/probe/Stubs.swift" \
  $R/Shared/AI/PromptBuilder.swift $R/Shared/Models/Intensity.swift $R/Shared/AI/StylePreset.swift \
  $R/Shared/AI/SafetyFilter.swift $R/Shared/AI/ModelRefusal.swift
"$OUT/lens1probe" > "$OUT/baseline.jsonl" && python3 "$H/audit/probe/analyze.py" "$OUT/baseline.jsonl"
```

(Check `main.swift` for arguments first; if the compile list is incomplete, the
error names the missing file.) Store the summary in the evidence dir. Start the
evaluation-spend ledger there (plan §7.4).

**Step 2 — A1 in preview, then production (plan §3 A1).**

```bash
cd ~/Documents/RoastMate/cloud-worker
# edit src/style_voice.js STYLE_VOICES.savage_no_filter (en/hans/hant/ja) + test/style_voice.test.js
npm test
node ../docs/evidence/2026-10-22-churn-and-fixes/harness/worker-compare/compare_ext.mjs  # fix paths first; no diff outside savage_no_filter
npx wrangler dev --remote --port 8799               # preview; nothing deployed
# style gate: score_gate2.py / detect.mjs against the preview (≤ 20 calls), blind pairs ≥ 5/6
npx wrangler deploy                                 # only after the gate
npx wrangler deployments list                       # record the new version id here and in the plan
# rollback: npx wrangler rollback <full id of 046f2134…>
```

Say in one line what you are deploying and the rollback before `wrangler deploy`
(that is the autonomy rule below). A9's optional `provider.data_collection` change
rides this deploy only if Jason has checked the OpenRouter account setting and ≤ 6
preview calls show both models still route.

**Step 3 — start 1.8.0 with the Shared-code items (A3, A4, A5).**
Order: A4's stateless opponent prompt and A3's refusal → `respondFresh(guardrails:
.permissiveContentTransformations)` retry with per-variant screens (both in
`Shared/`, unit-tested), then A5's preambles/examples, then re-run the probe and
the safety set against the §2.2 targets. Then A2, A6, A7, A9, A8, and B3/B4/B5 as
decided. Tests:

```bash
ROASTMATE_TEST_DEVICE=RoastMate-UITests scripts/preflight.sh
```

Paywall, trial line, hand-off, preview and consent are checked **only in Release**
(`ENABLE_TESTABILITY=YES`) with a v1.7.2 control, on a disposable iOS 18.5 device
(class C) and on this Mac (class D).

## What is Jason's (not yours)

- **Decisions:** B0 by **10-29**; B3 (retire classic Echoes), B4 (two zh-Hant style
  names), B5 (one 痛罵 preview for free users) by **10-31**; the 11-15 slot on
  **11-15**. Remind him; don't decide for him.
- **Before 1.8.0 is submitted:** edit the Pro subscription descriptions in the ASC
  web UI (no "Unlimited generations" / 「無限生成」); approve the privacy-policy
  diff (A9) before it is pushed; check the OpenRouter account privacy setting.
- **Device and reader checks:** a native Taiwanese reader (~1 h, about 11-08; the
  agent prepares blind sheets, Jason asks); a 10-minute iOS 27 iPhone check of the
  1.8.0 TestFlight build (A3/A4/A5), plus iOS 26 if a device is at hand.
- **If a cloud slot item is chosen:** verify that production Pro tokens mint (plan
  §3 owner tasks); App Privacy answers.
- **Distribution:** P2.1 posts and creator batch 2 — his accounts; each send
  confirmed by him.
- **Money:** topping up OpenRouter by hand (below $5 while this plan evaluates);
  the Retention Messaging API access request (B7) if he wants it.
- Fixing the Datadog connector (optional).

**Autonomy.** Act without asking on anything reversible: code, tests, local
builds, Worker previews (`wrangler dev --remote`), commits and pushes to the
branch, ASC metadata on an editable version (dry run first). For outward-facing
steps the plan gates — a production Worker deploy, flipping a live flag,
submitting to App Review — verify the gate, say in one line what you are about to
do and what the rollback is, then do it. **The privacy policy push waits for
Jason's approval of the diff. Emails, messages and posts in Jason's name always
wait for his explicit confirmation of the exact recipient and text,** every time.

## Hazards (each has cost a session before)

- **Debug builds are always Pro** (`StoreService.isPro`). Every Debug test of the
  paywall, trial, credits, preview or hand-off passes vacuously. Release +
  `ENABLE_TESTABILITY=YES`, against a control on the previous tag.
- **`$ASC_APP_ID` may hold another app's id** (it was 6761163709 on 10-23). Never
  default an app id from the environment; pass `--app-id 6769317103` explicitly
  (`scripts/asc_product_page.py` no longer reads the env var). Filter every ASC
  report to App Apple ID 6769317103 so ColorArchive doesn't mix in.
- **New ASC versions don't inherit the promotional text.** Re-set it on 1.8.0 (and
  1.8.1) with `scripts/asc_product_page.py` (dry run first).
- **xcodebuild sometimes hangs after the tests finish.** Kill only the PID you
  started (never `pkill` by name), then `xcrun simctl shutdown <UDID>` for that
  run's device and check for orphaned `simruntime` daemons (ppid 1). Never stop a
  UI-test run without shutting its simulator down (load ~900 otherwise).
- **Trash and disk.** Cleanup only through `/usr/bin/trash`; the Trash frees nothing
  until Jason empties it. On "No space left on device", stop and ask him to empty
  it — don't trash more.
- **Datadog connector is not set up** (it failed on 10-22 and 10-27 with an
  unresolved "not-setup" host). Worker logs can't be read through it; use
  `npx wrangler tail` only for a live smoke test, and never read one person's
  `lane=pro` lines.
- **The harness is in the repo** (`docs/evidence/2026-10-27-v18-plan/harness/`,
  copied 10-27); its scripts still carry absolute scratchpad paths — fix them before
  running. The 10-22 threat held-out set is gone; plan §7.1 rebuilds a safety set.
- **`respondCached` reuses the default-guardrail session** (key has no guardrail
  part). A permissive retry goes through `respondFresh`; never through the cache.
- **Sandbox receipts get 403 in production** (`ALLOW_SANDBOX_RECEIPTS=false`). Test
  any Pro-only cloud path against a preview Worker with the sandbox var on.
- **`docs/site/` is stale.** The live marketing/privacy site is the separate repo
  `JasonYeYuhe/RoastMate`.
- **Unpaired CJK terms** have shipped three times. Every new string, preamble,
  example and style name is paired in 4 locales and guarded by the parity test.
- **`RoastMateTests` is hostless** — it can't see app-target types. Put logic under
  test in `Shared/`.
- **Codesign under a locked screen:** run the two-command probe from the global
  CLAUDE.md before any archive; sequence ASC API (.p8) work first, it is lock-immune.
- **Never flip `cloud_sendable_enabled`** (CI rejects it). New cloud paths get new
  keys read only by new binaries.
- **This Mac (macOS 27.0.1) is the only proxy for iOS 27.** iPhone behaviour is
  UNVERIFIED until Jason's TestFlight check.

## Keep / never clean up

- iOS 18.5 simulator **runtime** (22F77, ~8.8 GB). Devices on it are disposable:
  create one for a check, use it by UDID, delete it afterwards.
- `RoastMate-UITests` simulator (preflight); shared `iPhone 17 Pro` / `iPhone 17 Pro
  Max` (screenshots) — reuse, don't delete, don't shut down another session's.
- `build/` in this repo (shipped `.xcarchive`s, dSYMs, gitignored release notes that
  `scripts/asc_bind_version.py` reads) and `~/Library/Developer/Xcode/Archives`.
- `cloud-worker/node_modules`, `research/worker/node_modules`.
- `~/Documents/RoastMate-research/` (offer codes, outreach and balance logs; no git
  backup).
- `docs/evidence/**` (harnesses and gate results — the regression set).
- Keys and secrets: `~/private_keys/AuthKey_DMMFP6XTXX.p8`, `~/.appstoreconnect`,
  `~/Library/Application Support/CLI-Pulse-Secrets`.
- Production is never "cleanup": the `roastmate-vent` Worker, the Pages config
  (`research/web/roastmate-config.json` → mirrored), App Store Connect records.

## Cheap checks before you start

```bash
git -C ~/Documents/RoastMate log --oneline -3
sed -n 20,21p ~/Documents/RoastMate/project.yml
curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json
python3 ~/Documents/RoastMate/scripts/asc_analytics.py --since 2026-10-24
~/Documents/RoastMate/scripts/openrouter-balance.sh 5
xcrun simctl list devices available | grep -E "RoastMate-UITests|iPhone 17 Pro|18\.5"
```
