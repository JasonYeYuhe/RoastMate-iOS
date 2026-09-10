# RoastMate — handoff (paste into a fresh session)

You are picking up **RoastMate** (帮你骂 / `~/Documents/RoastMate`) — Swift 6,
iOS/macOS/watchOS, plus a Cloudflare Worker in `cloud-worker/`. Chinese-language-
first. Solo developer (Jason). Branch `feature/v1.4-track-b`, working tree clean.

## Status in one line

**v1.5.0 / build 21 is SUBMITTED and WAITING_FOR_REVIEW on BOTH platforms.**
Phase 1 is closed. The branch is pushed and the live config carries the new
kill-switch. **Phase 2 is a code moratorium — read §2 of the plan before
writing anything.**

Verified by read-back 2026-09-10:

| | iOS | macOS |
|---|---|---|
| version id | `6784f0de-b1db-472c-a63b-14bff774194d` | `a0a87e79-ad23-4e7b-aa2d-c58963c4fe5e` |
| state | `WAITING_FOR_REVIEW` | `WAITING_FOR_REVIEW` |
| build 21 attached | ✅ | ✅ |
| reviewSubmission | `030c8edb-8db1-4f2d-b74f-444d50d2525d` | `15bc5d9e-400e-43ad-b375-c0a13989716a` |
| What's New / description / keywords / reviewer notes | ✅ all match repo | ✅ all match repo |
| releaseType | AFTER_APPROVAL | AFTER_APPROVAL |

`AFTER_APPROVAL` means these go live automatically once approved. If that is
not wanted, change it BEFORE approval.

Live config now serves **12 top-level keys** (10 flags + 2 `_comment`), with
`share_card_visible: true`. The mirror Action's hardened validator passed on
the real payload ("config OK — 10 required keys present and well-typed").

## VERIFY BEFORE YOU ACT

The previous session re-checked every claim in this repo's docs against the
code before writing anything. ~31 assertions held; **12 did not**, including
two that had been adopted from an advisor and written into both the plan and
this handoff as settled fact. See `docs/DEV_PLAN_v1.6_2026-09.md` §7 for the
list. Do not trust this document either.

Cheap checks, corrected:
- **git:** `git rev-list --count v1.4.0..HEAD` — should be ≥15.
- **Version:** `sed -n '20,21p' project.yml` → `1.5.0` / `21`. The committed
  pbxproj carries its own copies (4 occurrences, all project-level); they are
  in sync, so `xcodegen generate` should produce a **zero**-line diff now.
- **Live flags:** `curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json`
  — **11 top-level keys: 9 flags + 2 `_comment` keys.** The old handoff said 9
  and a naive `keys|length` therefore reads as a failure. NOTE: the served file
  does not yet carry `share_card_visible`; `research/web/roastmate-config.json`
  does, and the mirror Action deploys it **on any branch push**.
- **Prod Worker:** UP (200 in 1.6s off Groq, 2026-09-09). To probe:
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

## What is already done

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

## What remains

**Nothing in Xcode.** Phase 1 shipped. What is left is Phase 2, which is
distribution work, not code:

1. **Watch the review.** Both platforms are `WAITING_FOR_REVIEW`. The one
   Guideline risk this binary was built to remove (2.1 / 4.0 — a reviewer on a
   non-Apple-Intelligence device seeing canned text presented as a response) is
   mitigated three ways: the output is labelled on every surface, it is never
   charged, and the reviewer notes say plainly what each device gets.
2. **P2.1** — mint a provider token in the ASC web UI, add the `pt=` to
   `ShareCardBadge`. One line, and the only code edit Phase 2 allows.
3. **P2.2** — creator access (TestFlight external group or promo codes with Pro
   unlocked) BEFORE contacting anyone. Blocks P2.3.
4. **P2.3 / P2.4** — outreach, then talk to 3–4 users.

**Kill-switches, now that they work.** If something goes wrong in production,
edit `research/web/roastmate-config.json` and push — the mirror Action deploys
to Pages on any branch and clients pick it up next launch. No Apple cycle.
`share_card_visible:false` takes the card down; `echoes_enabled`,
`roommate_group_enabled`, `vent_cloud_enabled`, `force_local_only` do the rest.

## Known, deliberately unfixed in v1.5.0

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

## Hard-won gotchas

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
