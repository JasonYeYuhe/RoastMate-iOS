# RoastMate — handoff (paste into a fresh session)

You are picking up **RoastMate** (帮你骂 / `~/Documents/RoastMate`) — Swift 6,
iOS/macOS/watchOS, plus a Cloudflare Worker in `cloud-worker/`. Chinese-language-
first. Solo developer (Jason). Branch `feature/v1.4-track-b`, HEAD `05f305d`,
9 commits ahead of the `v1.4.0` tag, working tree clean, everything pushed.

## Read first

1. `docs/DEV_PLAN_v1.6_2026-09.md` — the plan. Reviewed by Gemini 3.1 Pro and
   3.8 Flash; both returned a harsher verdict than the first draft and the plan
   was rewritten around it. §6 is the synthesis. **§2 Phase 1 is your whole job.**
2. `docs/DEV_PLAN_v1.5_2026-09.md` — the previous wave, mostly superseded.

## The one-line version

Ship **one honest binary** (v1.5.0 / build 21), then stop writing code and go
find out whether anyone wants this app. It has **23 lifetime downloads**.

## VERIFY BEFORE YOU ACT

The last two sessions found **nine** claims in this repo's own docs and comments
that contradicted the code. Two of them were in the handoff telling the session
what was true. Do not trust this document either.

Cheap checks:
- **git:** `git rev-list --count v1.4.0..HEAD` (should be 9 + whatever you add).
- **Live flags:** `curl -s https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json`
  — should carry **9 keys**, all at baked defaults. The mirror works again as of
  2026-09-06; it had been dead since May.
- **Prod Worker:** `POST /v1/vent` with a browser-plausible User-Agent (or
  Cloudflare 1010s you). Schema is `situation` + `intensity` + `locale` +
  `deviceId` + `mode`. `mode:"roast"` should 403 `mode_unavailable`.
  **Space probes 5–8s apart** — Groq's limit is 8K TPM and back-to-back probes
  self-inflict a fallback that looks like an outage. This fooled the last session.
- **ASC:** key `DMMFP6XTXX`, issuer `c5671c11-49ec-47d9-bd38-5e3c1a249416`,
  app `6769317103`, key at `~/private_keys/AuthKey_DMMFP6XTXX.p8`. v1.4.0 build
  20 is READY_FOR_SALE on both platforms.

## Phase 1 — the whole job, in order

Everything below ships in ONE binary. Do not defer any of it to a second review
cycle; that costs a week to save a few lines.

1. **P1.1 Stop charging for canned output.** `RoastGeneratorViewModel` spends the
   credit before the engine runs, and the curated path reports success — so a
   user on a device without Apple Foundation Models pays for one of five
   hardcoded strings. **`ArgumentSimulatorViewModel` has the identical flaw.**
   Decide with Jason: refund after, or check `RoastEngine.isOnDeviceModelAvailable`
   before charging (§5 decision 1).
2. **P1.2 Say when output is curated.** Trap: `roast.error.unavailable` reads
   "Showing curated responses instead", but its only caller is
   `RoastError.modelUnavailable`, which the view model catches into an `.error`
   state that renders **zero cards**. The copy promises curated output; the
   wiring suppresses it. You need a non-error surface.
3. **P1.3 `FallbackRoasts` has no zh-Hant pool** — `case "zh": return zh` sends
   Traditional users the Simplified array. Third instance of this bug class in a
   week (see the guardrail below).
4. **P1.4 App Review hazard.** A reviewer on a non-Apple-Intelligence device sees
   canned text ignoring their prompt — Guideline 2.1 / 4.0 risk. P1.1–P1.3 are
   the mitigation; also say plainly in the reviewer notes what each device gets.
5. **P1.5 Share-card kill-switch** (`share_card_visible`), ~20 lines. The card
   renders model-derived text onto a branded public image and currently has no
   off switch — `share_card_enabled` gates only the QR badge.
6. **P1.6 Ship.** `project.yml:20-21` → `1.5.0` / `21`, then `xcodegen generate`
   (the committed pbxproj carries its own copies). Then `build-upload-asc.sh` →
   `asc_bind_version.py` → `asc_submit_review.py`.
7. **P1.7 Paste the ASO copy by hand** into ASC — 4 locales × 4 fields, ~10 min.
   **`415d78f` ships nothing until you do this**; no script pushes metadata.

Then **Phase 2 is a code moratorium.** Read §2 before writing anything.

## Hard-won gotchas

- **Run preflight with an isolated simulator:**
  `ROASTMATE_TEST_DEVICE=RoastMate-UITests ./scripts/preflight.sh`. The device
  `RoastMate-UITests` (`0A2F860D`) already exists — an `iPhone 17 Pro` clone. The
  default device is shared and another agent's run will manufacture UI failures
  that read exactly like real defects (measured with a peer session 2026-09-05).
  Do NOT re-run a failing UI test on a *different* device model to check: these
  tests use `isHittable` + scroll-until-visible loops, so a bigger screen is a
  strictly easier instrument and a pass there transfers nothing.
- **preflight now reports unit and UI suites separately.** It used to say "unit
  tests failed" when the unit suite was green and a UI test was flaky. If it says
  a suite failed, it now actually knows.
- **New files need `xcodegen generate`** (project.yml globs; pbxproj enumerates).
  Don't run it while a build/test is in flight — it rewrites the project under it.
- **The unit-test bundle is HOSTLESS** (`link: false`, deliberate). App-target
  types (`ShareCardRenderer`, `ShareCardComposer`, every view) can never be
  imported. `@testable import RoastMate` is present in all 35 test files and
  resolves nothing. Put anything you want tested in `Shared/`.
- **To look at a share card**, compile the view standalone and render a PNG:
  `swiftc -O -parse-as-library Shared/Services/ShareCard{Models,Badge,Scenario}.swift
  RoastMate/Sources/Features/ShareCard/ShareCardView.swift main.swift` then
  `ImageRenderer` on macOS. Localized `Text("key")` shows the raw key there (no
  bundle) — fine for geometry, and conservative since keys are longer.
- **`RemoteConfig.swift` has two parallel structs** (Values + Patch) with
  near-identical lines. Edit by line number, and check BOTH. A careless insert
  put a parameter after the closing paren last session.
- **watchOS has no CoreImage** and `Shared/` is globbed into the watch target.
  Guard with `#if canImport(CoreImage)`. Only preflight's 5-target sweep catches it.
- **ASC review notes cap at 4000 chars.** The submitted file is
  `metadata/review_notes_asc_short.txt` (3,944 chars — 56 to spare). preflight
  validates the *wrong* file (the 6,991-char `review_notes.txt`); fixing that
  gate is a fine warm-up task.
- **Never flip `ROAST_MODE_ENABLED` on prod to test.** Use
  `npx wrangler dev --remote --var ROAST_MODE_ENABLED:true --port 8799` and point
  `eval-runner --endpoint` at it. Confirm prod still 403s before and after.
- **Editing `docs/site/` deploys nothing** — the live marketing site is a
  separate repo (`JasonYeYuhe/RoastMate`). `research/web/*` is mirrored to it by
  the Action, and that Action now triggers on **any** branch.

## Design rules (do not regress)

- Never render the raw vent on a shareable image.
- `RoastEngine.generate(cloudVentEnabled:)` stays defaulted **false**. Fail closed.
- One home per rule: `CloudPermission`, `CloudVentService.generate(_:auth:)`,
  `GeneratedRoastKind.isShareable`, `Redactor.maskToken`.
- **Any list of CJK literals must carry BOTH script forms, and the test must
  guard the RULE, not the instances.** Simplified-only lists have now shipped in
  `Redactor`, `ForbiddenTerms.json` and `FallbackRoasts`. Assume a fourth exists;
  if you find it, fix it the same way (`SafetyFilterTests`
  `testEveryCJKDenylistTermHasBothScriptForms` is the pattern).
- No third-party SDK. Zero-tracking is the moat.
- Fix checks that cry wolf; never learn to skim a red gate.

## Jason's, not yours

1. **Provider spend ceilings at Groq + OpenRouter.** There is no global spend
   counter in the Worker; every cap is per-device/per-IP. Worst case on
   Cloudflare's free 100k req/day is roughly **$33/day**.
2. **The dedicated In-App-Purchase key**, only if refunds ever bite.
3. **Minting the ASC provider token** (P2.1) — web UI only, no API surface.
4. **Confirm the App Privacy label lists Purchases** — not exposed on the API.

## House workflow

- Consult **both** advisors on major decisions — Gemini via
  `mcp__gemini__ask_gemini` (models `pro` = `gemini-3.1-pro-high`, and
  `gemini-3.8-flash-high`) and Codex via `codex:codex-rescue` — then synthesize.
  **Verify their claims against real code**: this wave, Pro missed that the app
  ships to iOS 18 where its recommendation was impossible, and Flash caught four
  real errors in a plan Pro had called "exceptionally accurate". They disagree
  usefully; neither is authoritative.
- Full delegation on reversible steps; verify-then-report before anything
  outward-facing (ASC submit, git push, flipping a live flag).
- Update `docs/` and auto-memory as increments land.

Start by verifying the state above, then work §2 Phase 1 in order.
