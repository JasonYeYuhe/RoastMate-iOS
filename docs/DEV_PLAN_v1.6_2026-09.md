# RoastMate — Next-Phase Plan: one binary, then stop coding

_Drafted 2026-09-06 against live code, the live Worker, the live served config
and the live ASC API. **Rewritten after review by Gemini 3.1 Pro and Gemini 3.8
Flash — both returned a harsher verdict than the first draft and both were
right.** See §6. Supersedes the unfinished parts of `DEV_PLAN_v1.5_2026-09.md`._

---

## 0. Where we actually are

**Live:** iOS + macOS v1.4.0 build 20, READY_FOR_SALE — re-verified against the
ASC API 2026-09-09. (Auto-memory still said WAITING_FOR_REVIEW; both platforms
cleared review on 2026-09-03.) Careful: **`READY_FOR_SALE` is not a
discriminator** — all 17 historical version records on both platforms read
`READY_FOR_SALE` and `downloadable=true`, back to v1.0. The proof that 1.4.0 is
current is the conjunction of newest-created + `APPROVED` submission item +
zero versions in any non-terminal state. Anything that greps for the first
`READY_FOR_SALE` match will pick an arbitrary row.

**On the branch, in nobody's hands** — 9 commits ahead of the `v1.4.0` tag
(`git rev-list --count v1.4.0..HEAD`; the first draft of this plan said 7,
hand-counted and wrong, which is the exact failure this project keeps having):

| commit | what |
|---|---|
| `95ea05c` | config-mirror trigger repaired + JSON guard; preflight per-bundle test gate |
| `500ffdb` | **zh-Hant PII leak** — 9 of 13 title literals were Simplified-only |
| `4da03f6` | roommate-group kill fired no telemetry; 5 comments contradicted the code |
| `1be3445` | A.1 setup chips, DARK behind `share_card_setup_enabled` |
| `415d78f` | ASO metadata staged (currently a **no-op** — nothing pushes it) |
| `02f0f3c` | **safety denylist Simplified-only** — 強姦 / 自殘 / 我要殺 unguarded |
| `05f305d` | research tile was a dead link (`roastmate.app` is NXDOMAIN) |

**The measured size of the business**, from the ASC Analytics API:

> **4,919 impressions → 197 product page views → 23 first-time downloads, lifetime.**

Sessions, retention, purchases and subscriptions: **zero instances** in both
report requests.

---

## 1. The verdict this plan was rewritten around

The first draft argued: fix the product floor before distribution, because
seeding creators into a product that hands most arrivals canned text is a
leaking bucket. It then spent four weeks on a cloud-routing rewrite, an
opencc detector, Groq capacity analysis and Worker CI.

**Both reviewers independently called that an excuse, and they are right.**
The evidence is in this repo's own history: a Keychain-backed device-ID service,
a SwiftData credit ledger with baseline snapshots, Durable Object atomic
counters, an LLM eval harness — all built for **23 downloads**. Four consecutive
waves have retreated into Xcode because Xcode is controllable and outreach is
not.

But the reviewers also agreed the *specific* defect at the centre is real and
disqualifying:

> **The app charges a credit, runs no model, returns one of five hardcoded
> strings, and presents it as if the AI wrote it. There is no refund and no
> signal.**

That is not a growth concern. It is taking money for something not delivered,
and it will produce one-star reviews from the first cohort that arrives.

**So the synthesis is: the floor fix is one day, not one wave.** Everything else
in the old Track F was scope creep. Fix the defect, put it in the same binary,
ship, and then stop writing code.

---

## 2. The plan

### Phase 1 — One binary (target: 2 days)

Everything here ships as **v1.5.0 / build 21**. Nothing is deferred to a second
review cycle, because a second cycle costs a week to save a 15-line change.

- **P1.1 — Stop charging for canned output.** ✅ DONE (`4a392c4`).
  `RoastGeneratorViewModel` spent the credit *before* the engine ran, and the
  curated path reports success, so there was no refund.

  **Two corrections to this item, both load-bearing, both verified in code:**

  1. **The second site is `FeatureGenerator.swift:97`, NOT
     `ArgumentSimulatorViewModel`.** Gemini Pro's finding #5 was wrong.
     `ArgumentSimulatorViewModel` never calls `spendOneCredit` — the surface is
     Pro-gated and charges nothing. There are exactly two spend sites in the
     app. `FeatureGenerator` backs Reply Helper, Emotion Translator and Social
     Roast, so patching the file this plan named would have fixed a bug that
     does not exist and left three shipping surfaces leaking.
  2. **Neither of the two options offered here was right.** "Check
     `isOnDeviceModelAvailable` before charging" *inverts the cloud path*:
     `CloudConsentGate.decide` makes a device cloud-eligible precisely BECAUSE
     it has no on-device model, so that predicate would zero revenue the moment
     `cloud_sendable_enabled` flips — it stops billing exactly when real
     provider cost starts. It also misses three of the four ways curated text
     is produced (backend unavailable, generation error, all candidates
     filtered), two of which happen on FM-capable devices. And "refund after"
     is the LARGER change, not the smaller one: `CreditLedgerEntry.Kind` is
     `grant | spend | legacyBaseline`, `recordGrant` hard-requires a StoreKit
     txID, and the starter-trickle tier writes no ledger entry at all.

  **Shipped instead:** `RoastEngine.generateDetailed` returns
  `GeneratedOutput{texts, provenance}`; callers pre-check with the existing
  read-only `canSpendNow()` and spend *after* generation, only for `.model`
  output. Same mechanism drives P1.2.
- **P1.2 — Tell the user when output is curated.** ✅ DONE (`4a392c4`).
  **The trap as described is wrong, in a way that would have cost time.**
  `roast.error.unavailable` is not "reachable only via
  `RoastError.modelUnavailable`" — `.modelUnavailable` is constructed
  *nowhere in the repo*. It is a dead enum case, so the string has never
  rendered in any shipped build in any of its four locales, and there is no
  suppressing `catch` to go looking for. On a no-FM device nothing throws at
  all: the engine returns curated text and the view model sets `.results`.

  The conclusion (needs a non-error surface) was right, and it is cheaper than
  scoped: the copy already exists and is correctly translated in all four
  locales, and `.results` already had the banner idiom (`crisisBanner`,
  `rewriteError`). Shipped as `CuratedNoticeBanner` on **three** renderers —
  the plan counted one. macOS matters most: it deploys to 14.0 while
  `AppleFMBackend` is 26+, so every generation on a Mac below 26 is curated.
- **P1.3 — `FallbackRoasts` has no zh-Hant pool.** ✅ DONE (`4a392c4`).
  Fixed by routing through `AppLanguage.contentBucket(for:)` rather than adding
  a fourth inline locale switch — `contentBucket` also handles what a
  script-subtag check cannot, since `zh_TW` / `zh_HK` / `zh_MO` carry no `Hant`
  subtag and `identifier.contains("Hant")` was never a valid substitute.
- **P1.4 — App Review hazard.** ✅ DONE — `metadata/review_notes_asc_short.txt`
  rewritten for 1.5.0 (3,947 / 4,000 chars; it had 56 to spare, so §1 was
  trimmed to fit the new paragraph).

  **One correction: do NOT tell the reviewer "no Apple Intelligence = canned
  text".** That is inaccurate and would invite a 2.1 rejection of its own.
  Vent and Feral are *unconditionally* cloud-eligible and `vent_cloud_enabled`
  is true live, so a consenting reviewer on a no-FM device gets real,
  input-specific output from those modes. Only Calm/Sharp/Savage degrade.

  **Also worse than the plan says, and now fixed by P1.2:** `rewriteAsSendable`
  on a no-FM device returned a random *roast* line dressed as the polished
  rewrite of the user's vent draft — with a Share button. And the onboarding
  copy still asserts these modes "run on-device with Apple's Foundation
  Models", which is false on the floor the app deliberately ships to. **That
  onboarding string is NOT fixed and is the one remaining P1.4 item.**

  ⚠️ Reviewer notes are a MANUAL browser paste. Nothing in `scripts/` writes
  `appStoreReviewDetail`.
- **P1.5 — Share-card kill-switch (`share_card_visible`).** ✅ DONE (`4a392c4`).
  Larger than "~20 lines": ten threading points across the two parallel structs
  plus `isRestrictive` (the omission that made the roommate-group kill fire no
  telemetry) and the served JSON. It also required a CI fix — the mirror
  workflow derived its bool-type set with `endswith("_enabled")`, so
  `share_card_visible` would have been presence-checked but never type-checked,
  and since the whole payload decodes as one patch via `try?`, one
  `"true"`-as-string makes EVERY flag in the file fail to apply.

  Kept over Flash's objection: "live for months without incident" is exactly the reasoning
  that let the zh-Hant leak run, and **two** defects landed on this surface this
  week with no way to mitigate either remotely. The card renders model-derived
  text onto a branded public image; it should have an off switch.
- **P1.6 — Ship.** ⚠️ **The path as written here is iOS-ONLY and will silently
  leave macOS on 1.4.0.** `build-upload-asc.sh` defaults
  `DESTINATION=generic/platform=iOS`, and both Python scripts default
  `--platform IOS`. macOS v1.4.0 is equally live, and every release since
  v1.1.0 shipped both. **Run the whole path twice.**

  Two more preconditions the plan omits: `asc_bind_version.py --notes` is
  REQUIRED and hard-exits unless all four locales are present (now written to
  `build/v1.5.0-release-notes.md`); and it hardcodes
  `releaseType=AFTER_APPROVAL`, whereas v1.1.0 and v1.2.0 shipped MANUAL —
  patch it if 1.5.0 wants a manual release gate.

  Version bump + `xcodegen generate` are ✅ DONE (clean 4-line pbxproj diff).
  Remaining: bump `project.yml:20-21` → `1.5.0` / `21`, run `xcodegen
  generate` (the committed pbxproj carries its own copies; editing project.yml
  alone does nothing). Re-probe codesign first — it worked under a locked console
  today, but that has failed before and the check costs a second. Then
  `build-upload-asc.sh` → `asc_bind_version.py` → `asc_submit_review.py`.
- **P1.7 — Paste the ASO copy by hand.** ⚠️ **Blocked today, and mis-scoped.**
  Verified against the live ASC API:
  - **Nothing is editable.** Every version record on both platforms is
    `READY_FOR_SALE`; `description` and `keywords` are version-scoped and
    cannot be edited on a live version. A 1.5.0 version record must exist
    first, so **P1.7 comes AFTER P1.6, not in parallel**. The "~10 minutes" is
    typing time once that record exists.
  - **It is 2 fields, not 4.** `name`, `subtitle`, `promotionalText` and
    `whatsNew` are already live and byte-identical to the repo. Only
    `description` and `keywords` are stale.
  - **It is 2 platforms.** iOS and macOS carry independent localizations, both
    stale. True count: 2 × 4 locales × 2 platforms = **16 pastes**. The plan's
    "4 × 4" reaches 16 by the wrong decomposition and covers only iOS.
  - No field is over its Apple cap; tightest is en-US subtitle at 28/30.

### Phase 2 — Xcode moratorium (the rest of the month)

**No code changes.** Not the opencc detector, not Groq, not Worker CI, not the
secondary features, not cloud-routing. If something breaks in production, the
kill-switches now work.

- **P2.1 — Mint a provider token.** Create one campaign in the ASC web UI to
  generate the account's `pt=`, then add it to `ShareCardBadge`. Today the code
  asserts "`ct` alone is what App Analytics buckets on"; Apple requires `pt=`
  alongside, so the shipped QR is very likely unattributable. (This is the one
  code edit allowed in Phase 2, and it is one line.)
- **P2.2 — Creator access.** Decide how a creator actually evaluates this app.
  Right now they would download it, burn three credits, and hit a paywall. Set up
  a TestFlight external group or promo codes with Pro unlocked **before**
  contacting anyone. The first draft omitted this entirely and it blocks
  everything else in Phase 2.
- **P2.3 — Outreach.** 5–10 micro-creators on Xiaohongshu. Write the DM script,
  the persona list and the tags first. Xiaohongshu weights Saves > Comments >
  Likes, so design for a comeback someone wants to find again.
- **P2.4 — Talk to 3–4 users.** Not 8. Eight will not happen.

### Cut, explicitly, with the reasoning recorded

| cut | why |
|---|---|
| opencc detector re-baseline (old Q.1) | Rewriting the eval detector to move an internal score from 18/24 to 20/24 is worth nothing at 23 downloads. The finding stays recorded: the "18→20 improvement" is a measurement artifact, so **do not trust the 20/24 number** if this is ever revived. |
| Groq capacity work (old Q.2) | Real finding — 8K TPM / 200K TPD means ~60–150 vents/day total, and `wrangler.toml:27` is wrong by ~30× — but at 0 vents/day it changes nothing. Fix the comment when you next touch the file. |
| Worker CI (old Q.3) | 52 tests pass locally. No traffic. Not now. |
| Cloud-routing rewrite (old F.2–F.5) | The largest piece of the old plan and the clearest displacement activity. **Correction to the old draft:** it claimed `rewriteAsSendable` is "the only generation path with no cloud branch". False — classic Echoes hardcodes `useCloud = false`, and the Share extension, Siri intent and Watch all call `generate()` without `cloudVentEnabled:`, which defaults false. Several paths have none. That makes the rewrite *larger* than scoped, which is another reason to cut it. |
| Per-creator campaign attribution as a metric | Detailed-report rows are hard-suppressed below 5, and those reports captured **0 of 197** lifetime page views. Unmeasurable at this size. Keep the outreach; drop the metric. |
| `asc_push_metadata.py` | Paste it by hand. |
| Registering `roastmate.app` | `05f305d` repointed the tile at the live Pages form. Buy the domain when there is a reason beyond tidiness. |

---

## 3. Decision criteria — honest about a 23-download app

| signal | source | what would count |
|---|---|---|
| the three zh-Hant fixes reach users | ASC version state | v1.5.0 READY_FOR_SALE |
| nobody is charged for canned output | code + a no-FM device | P1.1 verified on a real device |
| ASO copy is actually live | ASC API read-back | live keywords == `metadata/` |
| store discovery | App Analytics impressions | any movement off the 4,919 lifetime baseline |
| does anyone share the card | asking humans | ≥1 unprompted share |
| does anyone want this | 3–4 conversations | written down, with quotes |

**Deliberately absent:** anything from `EventLedger` (no egress), per-creator
campaign rows (suppressed), and the v1.5 plan's "repeat usage by deviceId via
Datadog" — `ddLog` is coded and documented never to carry a deviceId, so that
criterion repeats the exact mistake its own plan diagnosed.

---

## 4. Guardrails

- Never render the raw vent on a shareable image.
- `RoastEngine.generate(cloudVentEnabled:)` stays defaulted **false**.
- One home per rule: `CloudPermission`, `CloudVentService.generate(_:auth:)`,
  `GeneratedRoastKind.isShareable`, `Redactor.maskToken`.
- No third-party SDK.
- **Earned three times this week, then four more times in one sweep:** any list
  of CJK literals must carry both script forms, and the test must guard the
  *rule*, not the instances.

  **The predicted fourth instance was found — there were four, and three of
  them were inside `SafetyFilter.swift`, the file the third fix (`02f0f3c`)
  had just edited.** That commit added only the test accessor; the
  Simplified-only arrays 25 lines above and 60 below went unread. Fixed in
  `4a392c4`:
  - `ventHardRail` (was a function-local inside `validateVentOutput`, which is
    exactly why no test could see it) — the ONLY denylist applied to private
    drafts and the last gate on cloud vent output. Missing `殺了你`, `自殺`.
  - `defaultDenylist` — same two gaps.
  - `softSelfHarmPhrases` — missing `活著沒意思`, `活著沒意義`, `解脫算了`;
    and `撑不下去了` could not match what `撐不下去` already did.
  - `hardSelfHarmPhrases` — **the REVERSE defect**: `了結自己` shipped
    Traditional-only, leaving zh-Hans unguarded.

  **Restate the rule accordingly: the bug class is an UNPAIRED term, not
  specifically a Simplified one.** The parity test now walks every list via
  `SafetyFilter.matchingListsForTesting()`, in BOTH directions, skipping kana.
  Verified by mutation, not just by going green.

  **Still open, same class, different shape:** `PromptBuilder` gates Traditional
  on `locale.identifier.contains("Hant")` at four sites (plus `SampleRoast`,
  `Scenario`, `EchoesPersonaCatalog`), which is FALSE for `zh_TW` / `zh_HK` —
  the identifiers a real Taiwan/HK device actually reports. That affects the
  PRIMARY model path, not just the fallback, so it is higher-impact than P1.3
  was. `AppLanguage.contentBucket` is the fix; see the Phase 2 note.
- Fix checks that cry wolf; never learn to skim a red gate.

---

## 5. Open decisions for Jason

1. ~~**P1.1 — refund after, or check before charging?**~~ **SETTLED
   2026-09-09: neither.** Spend *after* generation, gated on provenance. Both
   offered options were wrong — see P1.1 in §2 for why (checking before zeroes
   revenue when `cloud_sendable_enabled` flips; refunding is the larger change,
   not the smaller). Shipped in `4a392c4`.
2. **Does zh-Hant exist as a product, or only as a store locale?** Still open,
   but two of the supporting facts were wrong and the question is now narrower:
   - "**blocked** for sendable cloud" overstates it. No `cloud_sendable_locales`
     key is served and `cloud_sendable_enabled` is `false`, so **all four
     locales are dark for the same reason**; nothing is zh-Hant-specific. A nil
     list explicitly means "every locale".
   - "no canned-text pool" and "weaker safety lists" are **fixed** in
     `4a392c4`.
   What remains genuinely zh-Hans-only: Echoes and the roommate group (their
   curated transcripts are hardcoded Simplified, though `ExploreView` gates
   those surfaces to zh-Hans so no Traditional user reaches them), and the
   PromptBuilder region-blind checks noted in §4 — which mean a `zh_TW` device
   is told to reply in 简体中文 on the **model** path.
3. **Provider spend ceilings — largely a non-issue, corrected 2026-09-09.**
   Groq is the **free tier** ($0, rate-limited: exceeding 8K TPM / 200K TPD
   returns 429, it does not bill). OpenRouter is **not** free —
   `qwen/qwen3-30b-a3b-instruct-2507` costs $0.0481/1M in, $0.1930/1M out, and
   the config deliberately avoids `:free` variants because the shared free pool
   402s/404s when a tier retires (that is what took the cloud path down on
   2026-08-31). But it is **prepaid at $10**, which is a hard ceiling by
   construction — that buys roughly **30,000–115,000 vents** depending on length,
   against 23 lifetime downloads.
   **The only thing to check is whether OpenRouter auto-topup is enabled.** If it
   is, the $10 stops being a ceiling; if not, there is nothing to do here. A
   30-second check in the account, not a work item. An earlier draft called this
   a "$33/day worst case" and treated it as urgent — that assumed uncapped
   billing and was wrong.
4. **The dedicated IAP key** — only needed if refunds ever bite.

---

## 6. Review synthesis — Gemini 3.1 Pro + 3.8 Flash (2026-09-06)

| # | source | finding | applied |
|---|---|---|---|
| 1 | Both | The 4-week scope is displacement activity; the floor fix is 1 day | Plan cut to one binary + a moratorium |
| 2 | Both | **F.1 must ride the v1.5.0 binary** — shipping ASO to attract users while still charging for canned text is self-defeating | P1.1 moved into Phase 1 |
| 3 | Both | Cut Track Q entirely (opencc, Groq, Worker CI) | Cut, with findings recorded |
| 4 | Both | Cut the cloud-routing rewrite | Cut |
| 5 | Pro | `ArgumentSimulatorViewModel` has the same credit-drain flaw | P1.1 extended |
| 6 | Pro | Secondary features would get real-but-context-blind cloud output, not canned — `mode:"roast"` is hardcoded, dropping the caller's mode | Corrected; strengthens the cut |
| 7 | Flash | **`FallbackRoasts` has no zh-Hant pool** — third instance of the bug class | New P1.3 |
| 8 | Flash | `roast.error.unavailable`'s copy promises curated output but its only caller suppresses all output | New P1.2, with the trap named |
| 9 | Flash | App Review rejection hazard on a no-AI device (2.1 / 4.0) | New P1.4 |
| 10 | Flash | Creators cannot evaluate the app — paywall after 3 credits, no TestFlight/promo path | New P2.2, blocks outreach |
| 11 | Flash | "Only path with no cloud branch" is false — Echoes/Share/Siri/Watch also have none | Corrected in §2 |
| 12 | Flash | The commit count was hand-counted and wrong (7 vs 9) | Corrected in §0 |
| 13 | Flash | Cut the share-card kill-switch | **Rejected** — "live for months without incident" is the reasoning that let the zh-Hant leak run, and two defects landed on that surface this week with no remote mitigation. Kept as P1.5, ~20 lines. |
| 14 | Flash | Cut `asc_push_metadata.py`, paste by hand | Accepted |

**Both reviewers' shared verdict, in different words:** ship one honest binary
this week, then close Xcode and go find out whether anyone wants this.

⚠️ **Two of the findings above are FALSE and were adopted anyway** (see §7).
Row 5 (`ArgumentSimulatorViewModel`) and row 8 (the `roast.error.unavailable`
wiring) did not survive verification against the code. Both came from an
advisor, were plausible, and were written into this plan *and* the handoff as
settled fact. That is the mechanism this project keeps losing to: the advisors
are useful and neither is authoritative, and a claim about code is not true
until someone opens the file.

---

## 7. Verification pass, 2026-09-09 — what the plan got wrong

Every checkable claim in this plan and the v1.6 handoff was re-checked against
real code, the live Worker, the live served config and the live ASC API before
any code was written. ~31 assertions held. These did not:

| # | claim | reality |
|---|---|---|
| 1 | `ArgumentSimulatorViewModel` has the same credit flaw (§6 row 5) | **FALSE.** It never spends a credit; it is Pro-gated. The second site is `FeatureGenerator.swift:97`. |
| 2 | `roast.error.unavailable` is suppressed by a `catch` (§6 row 8) | **FALSE.** `RoastError.modelUnavailable` is constructed nowhere. The string is dead, not suppressed. |
| 3 | Check `isOnDeviceModelAvailable` before charging (§5 decision 1) | **Would zero revenue** the moment `cloud_sendable_enabled` flips — no-FM is precisely what makes a device cloud-eligible. |
| 4 | "Refunding is smaller" (§5 decision 1) | **Inverted.** No refund primitive exists; the ledger is append-only, CloudKit-merged and txID-keyed. |
| 5 | Assume a fourth Simplified-only list | **Four more**, three inside the file the last fix edited — including a P0 on the vent hard rail. |
| 6 | preflight validates the wrong review-notes file | True but understated: it had **no length gate at all**, on any file. Fixed. |
| 7 | The served config has 9 keys | 9 flag keys **plus two `_comment` keys** = 11 top-level. The handoff's own `jq 'keys\|length'` check reads as a failure. |
| 8 | `mode:"roast"` 403s (handoff probe recipe) | Only when paired with a *sendable* intensity — `intensity` is mode-coupled and `validate()` runs first, so the handoff's flat schema yields `400 invalid_intensity` and reads like an outage. `deviceId` also has an 8-char minimum. |
| 9 | The ship path is three commands | iOS-only; macOS silently left behind. Plus a required 4-locale notes file that did not exist, and a hardcoded `releaseType`. |
| 10 | P1.7 is "~10 minutes" | Blocked until a version record exists; and it is 2 fields × 4 locales × **2 platforms**. |
| 11 | v1.4.0 is WAITING_FOR_REVIEW (auto-memory) | READY_FOR_SALE on both platforms since 2026-09-03. |
| 12 | project.yml: app types reachable via `@testable import` | False — the bundle is hostless. The comment contradicted its own config. Fixed. |

**Two dead ends this pass avoided by checking first:** routing P1.2 through
`.error` (renders zero cards → blocks the default action on every no-FM device,
Guideline 2.1 — worse than the bug), and persisting provenance on
`GeneratedRoast` (a CloudKit **production** schema deploy, whose failure path
re-creates the container unnamed and reads history *and the purchased-credit
ledger* back empty).
