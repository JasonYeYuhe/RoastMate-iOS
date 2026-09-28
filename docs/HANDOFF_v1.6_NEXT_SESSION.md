# RoastMate — handoff (paste into a fresh session)

You are picking up **RoastMate** (帮你骂 / `~/Documents/RoastMate`) — Swift 6,
iOS/macOS/watchOS, plus a Cloudflare Worker in `cloud-worker/`. Chinese-language-
first. Solo developer (Jason). Branch `feature/v1.4-track-b`.

## Status in one line

**v1.6.0 / build 22 is LIVE on iOS and macOS** — approved and released
2026-09-27 22:33 UTC (~15h after submission). Verified 2026-09-28: both 1.6.0
records `READY_FOR_SALE`, both reviewSubmissions `COMPLETE` with their item
`APPROVED`; the public store (iTunes lookup) serves 1.6.0 in TW / HK / MO
(幫你罵), SG, JP, US; **CN returns nothing** (delisting effective). Tag
`v1.6.0` → `d7efd49`. Worker `200d240c` (rollback `df0123b3`). Live config: 
`vent_cloud_enabled:true`, `cloud_sendable_enabled:false`,
`share_card_enabled:false` — as intended.

OpenRouter MEASURED 2026-09-28: $10 bought, $0.0409 used lifetime (+$0.006
since 09-24, mostly verification probes → ~$0.00013 per vent). **Auto-top-up
is OFF (Jason confirmed 2026-09-28)** — so the balance is a hard spend cap
(good: no runaway bill) AND the point where cloud Vent/Feral/roommate stop,
because Groq is dead and nothing sits behind OpenRouter. Per the code, the app
then degrades to labelled curated examples and charges nothing (cloud error →
local path → curated provenance) — graceful, but the headline feature goes dark
silently. Re-measure with the read-only probe (recipe in the OpenRouter section)
and top up by hand below ~$2.

**Phase 2 can start: the gate "don't DM creators until 1.6.0 is live" is met.**
The 30/90 clock for Vent-free starts 2026-09-27.

(History: submitted 2026-09-27 — iOS version `e178273a-…` / reviewSubmission
`0a6caf1c-…`, macOS `2a80bf7b-…` / `dd535168-…`, releaseType AFTER_APPROVAL.)

## v1.6.0 — what it is, and the decisions behind it (2026-09-26/27)

Jason delegated the open business decisions ("你全权负责 做决定吧"). Made, with
evidence, in `docs/DISTRIBUTION_KIT_v1.md` → "DECISIONS 2026-09-26":

1. **Mainland China delisted** — CHN `CANNOT_SELL` (verified 2026-09-27). Unfiled
   generative-AI service; one API call restores it the day 备案 exists. Taiwan,
   Hong Kong, Macau, Singapore, Japan, US: available.
2. **Vent no longer needs Pro** (this binary). Still metered by credits, still
   behind the 5.1.2(i) consent. Feral / Savage stay Pro.
3. **`cloud_sendable_enabled` is retired forever** — CI rejects anything but
   false (`afd3cbf`), because every shipped consent sheet promises
   Calm/Sharp/Savage never use cloud.
4. **Interviewees get 1-year codes** (the research form promises a year);
   creators get 3-month codes. Both files are outside the repo.
5. **The "Make it sendable" rewrite is free** (recorded in `CreditCatalog`). It
   runs on-device, costs nothing, and was never charged by any code.

What the binary changes (`d7efd49`, full reasoning in the commit message):
- `Intensity.vent.requiresPro == false`; paywall no longer sells Vent.
- **Taiwan / Hong Kong get Traditional.** MEASURED: a zh-Hant-TW phone's
  `Locale.current.identifier` is `"zh_TW"` — no "Hant" — so every
  `contains("Hant")` check told them to answer in Simplified. All routed through
  `AppLanguage.contentBucket` now; Worker mirror in `cloud-worker/src/locale.js`.
- Explore tools (Reply Helper etc.) now ask for cloud consent instead of silently
  returning curated Vent.
- `CloudPermission`: a declined-cloud Vent is curated even WITH the on-device
  model (guardrails refuse vent), so it is free and never paywalled; new
  `Decision.skipsPaywall` = "curated even if the user allowed cloud?", so an
  empty wallet sees the paywall BEFORE the consent sheet instead of a dead-end
  error after it. Matrix-tested in `CloudPermissionTests`.

**Worker (deployed 2026-09-27, `200d240c`):** keyword identifiers such as
`zh_TW@calendar=roc` used to get **400 invalid_locale** — `validate` capped the
raw identifier at 16 chars — so Vent silently never reached the cloud for those
users; keywords are now stripped (`baseLocale`). The Traditional vent prompt no
longer shows the model a Simplified sentence as the ideal answer
(`src/calibration.js`). Measured on production, same Taiwan/HK inputs: old Worker
2/8 responses with Simplified (one ENTIRELY Simplified); routing fix alone 2/11;
with the paired calibration **0/16**.

### How v1.6.0 was verified

- **Release-build control, iOS 18.5 sim (no on-device model), clean install,
  free user taps Vent** — `docs/evidence/2026-09-27-v160-vent-free-release-control.png`:
  `v1.5.0` → Pro paywall at the chip ("The only way to unlock Vent · Feral ·
  Savage"). `v1.6.0` → consent sheet → Allow → a real cloud draft about the
  typed situation, no curated banner, Feral still locked, wallet "2 free today"
  → "1 free today". The probe was a throwaway XCUITest, never committed.
  Two gotchas cost three reruns: the `BEGINSWITH 'Vent'` query matches the
  **"Vent by voice"** mic button first (match the chip's blurb instead), and a
  root-level `TextEditor` keyboard cannot be dismissed in SwiftUI UI tests and
  sits over the intensity row — choose the intensity BEFORE typing, and never
  swipe near the keyboard (it swipe-TYPES into the field).
- Five-lens adversarial review of the diff, each finding re-checked by a
  skeptic: 15 survived, 3 refuted, nothing P0/P1; every surviving code/copy
  finding is fixed in `d7efd49` except those listed under "Known, deliberately
  unfixed in v1.6.0" below.
- Worker: 59/59 `node --test`; each new test mutation-checked (reverting the fix
  makes it fail).
- **preflight: 78 pass / 2 fail — both failures are this Mac, not the code**,
  proven by running the identical tests from the `v1.5.0` tag on the same
  simulator: 3 engine tests fail inside Apple's model service
  (`PrompteTemplateError.promptTemplateNotFound` — the iOS 26.5 simulator borrows
  the Darwin-27 host's model), `ShareCardTests.testCatchesBareTwoCharChineseName`
  (NLTagger on this runtime) and `ScreenshotTests.test_paywall` ("timed out while
  synthesizing event") fail identically on v1.5.0. The Echoes bridge UI test
  failed once under load and passes on a rerun (92 s). New suites
  (`CloudPermissionTests`, `TraditionalLocaleTests`, `IntensityTests`) pass.
  **On a healthy machine this gate should read 80/0 — if it doesn't, re-run the
  v1.5.0 control before believing either number.**

## 🔴 Production state — the Groq primary is dead (found 2026-09-15)

`qwen/qwen3.6-27b` returns **404** on Groq (confirmed in the Worker's own log:
`Groq primary failed: groq:404`). It served fine on 2026-09-09. Users see no
outage — every vent is served by the OpenRouter fallback in 2–4s — but
**OpenRouter is now the only working path**.

What that changes: Jason's open question "is OpenRouter auto-topup on?" is no
longer a cost question. OpenRouter is prepaid at $10. If auto-topup is OFF and
the balance drains — which successful Phase 2 outreach is exactly what would
cause — OpenRouter returns 402 and **vent, feral and the roommate group go down
together**, because nothing is behind it. That is the 2026-08-31 outage shape.

Deliberately NOT fixed, with evidence (see the note in `cloud-worker/wrangler.toml`):
the only Qwen left on Groq is `qwen/qwen3.8-27b`, a **Preview** model. Tested via
`wrangler dev --remote` against the live key: accessible and vents properly in
zh, but the key is on the FREE tier and 429'd a second request 7s after the
first, and the one zh sample inverted the situation's pronouns. Under real
traffic it would 429 into OpenRouter anyway, and a model that returns 200 with
worse text silently REPLACES the fallback rather than backing it up. Groq's only
non-Enterprise production models are GPT-OSS, which this repo already rejected
for neutering vent output. So: check auto-topup, not the model.

## VERIFY BEFORE YOU ACT

The previous session re-checked every claim in this repo's docs against the
code before writing anything. ~31 assertions held; **12 did not**, including
two that had been adopted from an advisor and written into both the plan and
this handoff as settled fact. See `docs/DEV_PLAN_v1.6_2026-09.md` §7 for the
list. Do not trust this document either.

Cheap checks, corrected:
- **git:** `git rev-list --count v1.4.0..HEAD` — should be ≥15.
- **Version:** `sed -n '20,21p' project.yml` → `1.6.0` / `22`. The committed
  pbxproj carries its own copies (4 occurrences, all project-level); they are
  in sync, so `xcodegen generate` should produce a **zero**-line diff now.
- **Live flags:** `curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json`
  — **12 top-level keys: 10 flags + 2 `_comment` keys**, including
  `share_card_visible: true`. A naive `keys|length` will not equal the flag
  count. The mirror Action deploys it on a push to **any branch that touches
  `research/web/**`** (paths-filtered) — so a docs-only push does NOT re-run it,
  and a missing new run after a docs push is correct, not a failure.
- **Prod Worker:** UP, but served by **OpenRouter** since the Groq primary
  died (see the production-state section above). To probe:
  `mode:"roast"` 403s **only when paired with a sendable intensity** —
  `intensity` is mode-coupled (`vent`/`feral` for vent, `calm`/`sharp`/`savage`
  for roast) and `validate()` runs before the roast gate, so
  `{mode:"roast", intensity:"vent"}` returns **400 invalid_intensity** and
  looks like an outage. `deviceId` has an 8-char minimum. A misspelled `mode`
  silently coerces to `"vent"`. Space probes 5–8s apart (Groq is 8K TPM).
- **ASC:** key `DMMFP6XTXX`, issuer `c5671c11-49ec-47d9-bd38-5e3c1a249416`,
  app `6769317103`, key at `~/private_keys/AuthKey_DMMFP6XTXX.p8`. **iOS AND
  macOS v1.4.0 build 20 are both READY_FOR_SALE** (cleared review 2026-09-03 —
  auto-memory saying WAITING_FOR_REVIEW is stale). Nothing is in an editable
  state, so 1.5.0 is a CREATE, which `asc_bind_version.py` handles itself.
  ⚠️ `READY_FOR_SALE` is not a discriminator — all 17 historical records read
  it, back to v1.0.

## What is already done (v1.5.0 — for the v1.6.0 work see the top)

Commits `4a392c4`, `76a8672`, `e3c4575`, `d6df0e2`, `36271e7`, `ae55fa8`.

- **P1.1** — credit is spent AFTER generation, only for `.model` output.
  `RoastEngine.generateDetailed` returns `GeneratedOutput{texts, provenance}`.
  Both spend sites fixed: `RoastGeneratorViewModel` and **`FeatureGenerator`**
  (Reply Helper / Emotion Translator / Social Roast) — *not*
  `ArgumentSimulatorViewModel`, which spends nothing.
- **P1.2** — `CuratedNoticeBanner` on **every** surface that can render curated
  text: the iOS generator, FeatureGenerator, the macOS menu bar, the Argument
  Simulator, History and Thread detail, the Share extension (inline — that
  target does not compile the app's Views/Components tree) and the Siri intent
  (prefixed into the spoken value). Two strings: `roast.notice.curated` and
  `rewrite.notice.curated`, both cause-neutral. **Not**
  `roast.error.unavailable` — its "On-device AI isn't available" opener is
  false on two of the three curated causes.
- **P1.3** — `FallbackRoasts` routes through `AppLanguage.contentBucket` and
  has a `zhHant` pool.
- **P0 (found in the sweep)** — `SafetyFilter`'s `ventHardRail`,
  `defaultDenylist`, `softSelfHarmPhrases` and `hardSelfHarmPhrases` script
  gaps, plus a bidirectional parity test over `matchingListsForTesting()`.
- **P1.4** — reviewer notes rewritten (3,975/4,000); onboarding + Settings copy
  states the real invariant (charged only for a real, input-specific response)
  rather than a claim a remote flag flip could falsify. Onboarding pages are
  now scrollable — the longer string truncated the 5.1.2(i) revoke sentence on
  an iPhone SE.
- **P1.5** — `share_card_visible`, threaded through both structs,
  `isRestrictive`, the served JSON, the CI validator, and gated at the button
  AND the sheet's *presentation* (not its content — that would show a blank
  modal).
- **The wallet no longer gates free output.** A generation that can reach no
  model returns curated text, which costs nothing, so neither the view model's
  gate nor the view's intent-triggered paywall fires for it. One predicate:
  `CloudPermission.Decision.willBeCurated`.
- preflight gates the reviewer-notes file that actually ships, on
  **characters** (CJK), against the 4000 cap.

**Gate:** `ROASTMATE_TEST_DEVICE=RoastMate-UITests ./scripts/preflight.sh` →
80 pass, 0 fail; **374 unit + 7 UI tests**; all 5 targets build.

## What remains — Jason's, and none of it is code

1. ~~Wait for v1.6.0 to be live~~ — **done 2026-09-27 22:33 UTC**, verified.
2. **Send three DMs** — Taiwan plan in the kit's DECISIONS section
   (Threads / Instagram, zh-Hant copy with the auto-renew disclosure, 3-month
   codes). Read replies before sending more. Do not send before step 1: a
   creator's audience is free users, and before v1.6.0 they cannot reach Vent.
3. **Have 3–4 conversations**, thank-you = a 1-year code from the interviewee file.
4. ~~OpenRouter auto-top-up~~ — **confirmed OFF 2026-09-28**, $9.96 left. Top
   up by hand when it nears ~$2 (≈15,000 vents of headroom at current prices).

Not decisions any more: storefront (Taiwan first, CN delisted) and 发泄-free
(shipped in v1.6.0) — see the top.

**Kill-switches, now that they work.** Edit `research/web/roastmate-config.json`
and push — the mirror Action deploys on any branch touching `research/web/**`.
`share_card_visible:false` takes the card down; `echoes_enabled`,
`roommate_group_enabled`, `vent_cloud_enabled`, `force_local_only` do the rest.
`vent_cloud_enabled:false` now also turns free Vent into curated-only (and free).
**Do not flip `share_card_enabled`** until `sharecard.findus` stops pointing CN
users at a competitor (needs a binary). **Never flip `cloud_sendable_enabled`.**

## Known, deliberately unfixed in v1.6.0

- **The Echoes gate may hide Echoes from real mainland phones.**
  `ExploreView.isZhHansLocale` checks `contains("hans") || hasPrefix("zh-cn")`;
  by the same rule that makes Taiwan report `zh_TW`, a mainland phone probably
  reports `zh_CN` (no "hans", and the prefix uses a hyphen). UNMEASURED for
  zh-Hans — measure on a zh-Hans-CN simulator before touching it. Left alone
  because fixing it widens a feature, and CN is now delisted.
- **Shared vent rule text still quotes Simplified examples** (Swift
  `PromptBuilder.ventPreamble`, Worker `index.js` rule block). Measured harmless
  on the cloud path after the calibration fix (0/16 bleed); one borderline
  variant character (晒 for 曬) was seen once.
- **Share / Siri / Watch stay Calm/Sharp only** — they cannot show the consent
  sheet, so they cannot reach cloud Vent. Intentional.
- **A free user who declined cloud on an Apple-Intelligence phone can still get
  unlimited on-device rewrites** by generating curated Vent drafts and tapping
  "Make it sendable". Accepted: on-device, zero cost, and rewrites are free by
  decision.
- **The wallet race below now also covers cloud Vent**: two surfaces peeking the
  last credit at once can both run, so at most one free-tier generation per
  wallet exhaustion goes unbilled — now possibly a cloud one (~$0.0003 of
  OpenRouter). Still bounded, still in the user's favour, same fix as below.

## Known, deliberately unfixed in v1.5.0 (still true)

**The wallet peek is not a reservation.** `canSpendNow()` is a pure read, so
two generator surfaces sharing one `UserSettings` can both pass it against the
last credit before either charges, and the loser's `spendOneCredit` failure is
discarded by `_ =`. Reachable by starting a generation on the Roast tab and
another in Explore → Reply Helper while it is in flight; on macOS the menu-bar
popover and the main window each hold their own view model.

Bounded: non-Pro only, calm/sharp only, FM-capable device only (a no-FM device
produces `.curated`, which is correctly free), at most one unbilled generation
per wallet exhaustion, and it fails in the user's favour.

**Do not "fix" it by honouring the discarded result** (`guard spendOneCredit
else { state = .error(...) }`). That is correct only while every billable
free-tier generation is on-device. The moment `cloud_sendable_enabled` flips,
that branch shows "out of credits" for text already sent to the Worker and
already paid for — the exact shape P1.1's own reasoning rejects, since there is
no refund primitive. The correct fix is a `reserve` / `commit` / `release`
trio on the wallet, with the peek reading `canSpendNow()` minus in-flight
reservations. That is real scope; it was not landed the night before a
submission.

## First post-release numbers — measured 2026-09-20

Ten days after v1.5.0 went live. From the ASC Analytics API (there is no script;
recipe below). Window 2026-09-04 → 09-19, DAILY granularity:

| | |
|---|---|
| first-time downloads in window | **5** (3 of them after the 09-10 release) |
| territory of those 5 | **CN 4, TW 1** |
| update events | 4 |
| ratings / reviews | **0** |

Two honest readings:

1. **v1.5.0 did not change acquisition, as expected** — ~2 first-time downloads
   in the 6 days before, ~3 in the 10 days after. Nothing about discovery
   changed, so this is the flat baseline the plan's "any movement off 4,919
   impressions" criterion is measured against. The 30/90 clock is running from
   09-10.
2. **Every single new user is Chinese-speaking, and 4 of 5 are mainland CN.**
   n=5, so this is a hint, not a finding — but it is the only demand signal that
   exists, and it points at the market `PHASE_5_STRATEGIC_2026-09.md` §8 puts out
   of scope. See open decision "target storefront" in
   `docs/DISTRIBUTION_KIT_v1.md`.

Also worth noting: **0 ratings and 0 reviews**, so the one-star risk the whole
v1.5.0 binary existed to prevent has not materialised — though at this volume
that is not evidence of much either.

**Recipe (no script exists):** ONGOING request
`53b320a6-68d1-4796-930f-62521ea5e749` →
`/v1/analyticsReportRequests/{id}/reports` → pick `App Downloads Standard` →
`/instances` → `/segments` → each segment is a gzipped TSV at a signed URL.
Processing dates repeat the same underlying day, so **de-duplicate rows before
summing or you will double-count**. `Download Type` separates
`First-time download` from `Auto-update` / `Manual update` — the lifetime "23"
figure counts first-time only.

## ✅ Creator access exists — offer codes minted 2026-09-24

Delegated four times, so done with the documented recommendation (kit §2):

| | |
|---|---|
| offer | `36f7f5d7-2d26-49d0-a0ac-1b315560d33e` on **Pro Monthly** (`6769322501`) |
| terms | `FREE_TRIAL`, `THREE_MONTHS` × 1, `REPLACE_INTRO_OFFERS`, eligible NEW + EXISTING + EXPIRED, **all 175 territories** |
| batch | `596464` — **500** one-time codes, expire **2026-12-31** |
| codes | `~/Documents/RoastMate-research/offer-codes-creator-outreach-2026-09.csv` (600/700, **not in the repo**) |
| distributed | **none** |

Why 500 and not 25: Apple's API rejected 25, 50, 100 and 250
("The given number of codes N is invalid") and accepted 500 — that is the
floor for this endpoint. Undistributed codes do nothing. Monthly, not yearly,
so a forgotten cancellation after the free 3 months costs $2.99, not $19.99 —
say that plainly in the DM (kit §3 already does).

To pull the plug: `PATCH /v1/subscriptionOfferCodeOneTimeUseCodes/596464`
`{"attributes":{"active":false}}` kills the batch; the same PATCH on the offer
id kills the offer.

**API shape that finally worked** (docs are JS-rendered and unhelpful): the
`prices` relationship is REQUIRED, one inline `subscriptionOfferCodePrices` per
territory (get the list from the USA price point's `/equalizations`), and for
`FREE_TRIAL` each entry carries ONLY `territory` — a `subscriptionPricePoint`
is rejected.

## ✅ The research recruit channel works — verified end to end 2026-09-16

v1.5.0 is the first build whose Settings tile actually reaches this form, and it
had never been exercised. Probed against production (`roastmate-research`):

- CORS preflight from `https://jasonyeyuhe.github.io` → 204 with the allow
  header; an unknown origin gets no allow header, so a browser blocks it.
- Step 1 `POST /` → **201** with a participant code, row persisted in
  `RESEARCH_ANSWERS`.
- Step 2 `POST /book` → **201**, row persisted in `RESEARCH_CONTACTS`.
- Anti-spam: `/book` with an invented code → **404**, as designed.
- **Privacy separation holds in production**: the answers row contains no
  email; the email lives only in the separate contacts namespace. That was the
  Codex v1 design requirement and it is real, not just intended.

The test rows were deleted afterwards; **both namespaces are back to 0 keys**, so
the first real submission will be the first row. (`wrangler kv key delete
--namespace-id <id> <key> --remote` — note `--force` is NOT a valid flag and
silently prints help instead of deleting.)

Also corrected on that page: it claimed to be recruiting **20** users in all four
locales, which is false at this size (the plan targets 3-4). It now says "a small
number" / 几位 / 幾位 / 数名 — no number to go stale.

## 🔴 Verifying anything about credits or the paywall: DEBUG builds are always Pro

`StoreService.isPro` is hard-coded `true` under `#if DEBUG`
(`Shared/Services/StoreService.swift:52`, and forced again in
`refreshSubscriptionStatus`). Every `xcodebuild test` defaults to Debug. So in any
Debug build the free-tier path — credit spend, the wallet gate, the paywall, the
1-vs-3 variant count — **cannot execute**, and a test of it passes vacuously.

This nearly produced a false verification on 2026-09-16: the P1.1 check "passed"
for BOTH v1.5.0 and the broken v1.4.0 in Debug. Tell-tale: 3 result cards
(`isPro ? 3 : 1`) and no wallet chip on screen.

Recipe that works (both builds, clean install, iOS 18.5 sim):
```
xcodebuild test -scheme RoastMate -configuration Release ENABLE_TESTABILITY=YES \
  -destination "platform=iOS Simulator,id=<iOS 18 sim>" -only-testing:RoastMateUITests/<Test>
```
`ENABLE_TESTABILITY=YES` is required only because the hostless unit-test bundle
also gets built and needs `@testable`; it does not turn `DEBUG` on. **Always run a
control against the broken build first** — if the control doesn't fail, the test
is blind. Result + evidence: plan §3, `docs/evidence/`.

## OpenRouter balance — MEASURED 2026-09-24: $9.97 of $10 remains

The dashboard never rendered, but the Worker's own key can read the account:
a read-only preview (`wrangler dev --remote` with a scratch config sharing the
worker NAME — that is what binds the deployed secrets; a bare script path does
not) called `GET /api/v1/credits` and `/api/v1/auth/key`. Nothing deployed;
production deployments unchanged; scratch files removed.

| | |
|---|---|
| credits purchased | $10.00 |
| usage, lifetime | **$0.0347** |
| remaining | **$9.9653** |
| key | paid tier, no per-key limit |

So the auto-top-up toggle is **moot at any volume Phase 2 can produce**: at the
measured per-vent cost this is on the order of 50,000+ vents, and lifetime
usage after four months is three and a half cents. The availability risk
("Groq is dead, OpenRouter is the only path, a drained balance takes vent down")
is real in shape but not near. **Re-check when usage crosses ~$5** — same probe.

## Hard-won gotchas

Added 2026-09-27:
- **`wrangler deployments list` prints OLDEST first.** Read the tail. Current
  prod `200d240c`; previous `df0123b3` (`npx wrangler rollback df0123b3-6f25-4604-b913-0bb5beaf789d`).
- **Probing the Worker from Python gets Cloudflare error 1010** (bot signature
  on the default urllib User-Agent). Send an app-like UA, e.g.
  `RoastMate/22 CFNetwork/1568 Darwin/24.0`. The response field is `text`.
- **Test Worker changes with `npx wrangler dev --remote --port 8799`** from
  `cloud-worker/` — the real worker NAME binds the deployed secrets, so it hits
  the real model without touching production.
- **Load average ~900 = orphaned simulator daemons.** Stopping a test run that
  owns a booted simulator can kill its `launchd_sim` and leave ~160 daemons
  (ppid 1) spinning. `ps -A -o stat=,ppid=,comm= | awk '$1 ~ /^R/ && $2==1' |
  grep -c simruntime`; kill only the ones whose start time matches YOUR sim's
  boot. Never TaskStop a UI-test run mid-flight without shutting its sim down.
- **This Mac (16 GB) is often swapping** under several agent sessions; run heavy
  jobs (preflight, archives, UI tests) one at a time.

- **Isolated simulator for preflight:**
  `ROASTMATE_TEST_DEVICE=RoastMate-UITests ./scripts/preflight.sh`. The device
  is `0A2F860D-FAF1-40A9-872B-F1D607E06349` (the old handoff's short id does
  not resolve — `xcrun simctl list devices | grep RoastMate-UITests`). The
  default device is shared and another agent's run manufactures UI failures
  that read exactly like real defects. Do NOT re-run a failing UI test on a
  *bigger* device to check: these tests use `isHittable` + scroll-to-visible,
  so a larger screen is a strictly easier instrument.
- **The unit-test bundle is HOSTLESS** (`link: false`, deliberate).
  `@testable import RoastMate` is in all 35 test files and resolves nothing.
  View models, views, `ShareCardRenderer`/`Composer` cannot be tested. Put
  anything you want covered in `Shared/`, which IS compiled in. (project.yml's
  comment used to claim the opposite; corrected in `4a392c4`.)
- **New files need `xcodegen generate`.** Don't run it while a build is in
  flight — it rewrites the project under it.
- **`RemoteConfig.swift` has two parallel structs** (Values + Patch), each with
  its own `CodingKeys`. A new flag has **ten** threading points, and
  `isRestrictive` is the one people forget — omitting it is what made the
  roommate-group kill fire zero telemetry.
- **The config CI validator types its bool/int lists explicitly now.** It used
  to derive them with `endswith("_enabled")`. If you add a flag, add it to the
  right list in `.github/workflows/mirror-research-form-to-pages.yml`.
- **watchOS has no CoreImage** and `Shared/` is globbed into the watch target.
  Guard with `#if canImport(CoreImage)`. To compile-check watchOS without a
  provisioning profile: add `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=""` — otherwise you get six entitlement errors that look
  like build failures and are not.
- **Never flip `ROAST_MODE_ENABLED` on prod to test.** Use
  `npx wrangler dev --remote --var ROAST_MODE_ENABLED:true --port 8799`.
- **Editing `docs/site/` deploys nothing** — the live site is a separate repo
  (`JasonYeYuhe/RoastMate`). `research/web/*` is what gets mirrored.

## Design rules (do not regress)

- Never render the raw vent on a shareable image.
- `RoastEngine.generate(cloudVentEnabled:)` stays defaulted **false**.
- **Anything that spends a credit must call `generateDetailed` and check
  provenance.** The `generate` shim exists for surfaces with no wallet and no
  banner; using it at a charging site silently reintroduces P1.1.
- One home per rule: `CloudPermission`, `CloudVentService.generate(_:auth:)`,
  `GeneratedRoastKind.isShareable`, `Redactor.maskToken`,
  `AppLanguage.contentBucket`, `CuratedNoticeBanner`.
- **The CJK rule, restated after the sweep: the bug class is an UNPAIRED term,
  not a Simplified-only one.** `了結自己` shipped Traditional-only. Any list of
  CJK literals used for MATCHING must carry both forms, the test must guard the
  rule (`SafetyFilter.matchingListsForTesting()`), and a new list must be added
  to that accessor in the same commit.
- **Still open, same class:** `PromptBuilder` (4 sites), `SampleRoast`,
  `Scenario` and `EchoesPersonaCatalog` gate Traditional on
  `locale.identifier.contains("Hant")`, which is FALSE for `zh_TW` / `zh_HK` —
  what a real Taiwan/HK device actually reports. This hits the **model** path,
  so it is higher-impact than P1.3 was. `contentBucket` is the fix. It is
  deliberately NOT in this binary: it changes prompts, and Phase 1 was scoped
  to the honesty defect. Do it first if the moratorium ever lifts.
- No third-party SDK. Zero-tracking is the moat.
- Fix checks that cry wolf; never learn to skim a red gate.

## Jason's, not yours

1. **OpenRouter auto-topup** — the only real spend question. Groq is free tier
   ($0, 429s over limit). OpenRouter is prepaid at $10, which is a hard ceiling
   *unless* auto-topup is on. 30-second check in the account.
2. **The dedicated IAP key**, only if refunds ever bite.
3. **Minting the ASC provider token** (P2.1) — web UI only.
4. **Confirm the App Privacy label lists Purchases** — not exposed on the API.

## House workflow

- Consult **both** advisors on major decisions — Gemini
  (`mcp__gemini__ask_gemini`, `gemini-3.1-pro-preview`) and Codex
  (`codex:codex-rescue`) — then synthesize. **Then verify their claims against
  real code.** This wave, Pro asserted a credit bug in a file that charges
  nothing, and the claim survived two reviews and two documents because nobody
  opened the file. They disagree usefully; neither is authoritative; neither
  has read the code you are about to change.
- Full delegation on reversible steps; verify-then-report before anything
  outward-facing (ASC submit, git push, flipping a live flag).
- Update `docs/` and auto-memory as increments land.
