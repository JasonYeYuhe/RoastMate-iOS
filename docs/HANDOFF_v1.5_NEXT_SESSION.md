# RoastMate — v1.5 handoff (paste into a fresh session)

You are picking up **RoastMate** (帮你骂 / `~/Documents/RoastMate`) — Swift 6,
iOS/macOS/watchOS, plus a Cloudflare Worker in `cloud-worker/`. Chinese-language-
first. Solo developer (Jason). The v1.4 wave shipped; your job is v1.5.

## Read first
1. `docs/DEV_PLAN_v1.5_2026-09.md` — the plan. Already reviewed by Gemini 3.1 Pro
   + 3.7 Flash and **rewritten** after Flash returned RETHINK. §9 is the synthesis.
2. `docs/DEV_PLAN_v1.4_2026-09.md` — the wave you're building on.

## VERIFY BEFORE YOU ACT — the last handoff was confidently wrong

The v1.4 handoff asserted Track B was unshipped work. It was **live in
production**, and had been for four months. Do not trust any state claim in a
document, including this one.

Check for yourself:
- **App Store:** ASC API key `DMMFP6XTXX` at `~/private_keys/AuthKey_DMMFP6XTXX.p8`,
  issuer `c5671c11-49ec-47d9-bd38-5e3c1a249416`, app `6769317103`. Reuse
  `scripts/asc_*` patterns. As of 2026-09-05: **iOS + macOS v1.4.0 (build 20)
  READY_FOR_SALE**.
- **Prod Worker:** smoke `POST /v1/vent` (schema is `situation`, not `text`;
  **set a browser/CFNetwork-plausible User-Agent or Cloudflare 1010s you**).
  Expect 200 on Groq `qwen/qwen3.6-27b`. Deployed version was `df0123b3`.
- **git:** branch `feature/v1.4-track-b`, tag `v1.4.0`. Working tree was clean.
- **Flags:** `research/web/roastmate-config.json` is the source of truth →
  mirrored to GH Pages by an Action. **Editing `docs/` deploys nothing.**

## Start here: Track A.1 (the one thing that unblocks the wave)

The share card currently renders one polished line on a gradient. Both reviewers
independently concluded that is a commodity artifact nobody will share, because
v1.3.1 correctly deleted the raw vent — and with it the *setup* of the joke.

A.1 restores setup→punchline **without** user text on the canvas: have the model
emit a short sanitized, abstracted scenario line and render it above the comeback.

```
【对方】半夜两点催交付物
【我的回击】收到，为保证质量，紧急事项建议工作时间沟通。
```

The setup line is **model output**, so it must go through the same
`Redactor.redactForPublicShare` + strict `SafetyFilter.validateOutput` path as
`sentText`. Never render user-typed text.

Then A.2 (real-device visual pass — this has **never** been done) and A.3 (flips).

## Hard-won gotchas — read before editing

- **`EventLedger` has NO network egress.** No URLSession, no endpoint. Data only
  leaves if a user opts in, opens Settings and manually shares a JSON file. Never
  design a metric on it. This killed the first draft of the v1.5 plan.
- **`scripts/preflight.sh` once reported "unit tests failed" BECAUSE they
  succeeded** (`grep -q` + `pipefail` → SIGPIPE). Fixed, and it now prints
  failing test names + a log path. Neighbouring checks survive only because
  `| tail -N |` drains first — safe by accident.
- **`RemoteConfig.swift` has two parallel structs** (Values + Patch) with
  near-identical lines. A non-anchored `str.replace` matches a PREFIX — `: Bool`
  also matches the start of `Bool?` — which silently broke patch decoding and
  would have stopped a remote kill reaching devices. **Use line-targeted edits.**
- **The unit-test bundle is HOSTLESS** (`link: false`, deliberate — otherwise
  `Shared/` double-links). App-target types like `ShareCardRenderer` can **never**
  be called from a test. Don't try to write a render-snapshot test.
- **watchOS has no CoreImage**, and `Shared/` is globbed into the watch target.
  Guard with `#if canImport(CoreImage)`. Only preflight's 5-target sweep catches it.
- **New files need `xcodegen generate`** (project.yml globs; pbxproj enumerates).
- **ASC review notes cap at 4000 chars.** Full notes are ~7k; the submitted
  version is `metadata/review_notes_asc_short.txt`. Cut whole sections; nibbling
  comes out neutral or longer.
- **Never flip `ROAST_MODE_ENABLED` on live traffic to test the sendable path.**
  Use `npx wrangler dev --remote --var ROAST_MODE_ENABLED:true --port 8799` and
  point `eval-runner --endpoint` at it. Confirm prod still 403s before and after.

## Design rules (do not regress)

- **One home per rule.** `CloudPermission.resolve`,
  `CloudVentService.generate(_:auth:)`, `GeneratedRoastKind.isShareable`. Each was
  previously duplicated or private to one caller, and each time a second caller
  silently missed it — that is literally two of this project's shipped bugs.
- **Fail closed.** `RoastEngine.generate(cloudVentEnabled:)` defaults `false`.
  Load-bearing; do not remove.
- **Fix checks that cry wolf.** Four were fixed last wave. A gate you skim
  launders real failures.
- Never render the raw vent on a shareable image. No 3rd-party SDK. Don't move
  Vent/Feral off cloud (Apple FM refuses/neuters that register — measured).

## Jason's, not yours

1. **Provider spend ceilings at Groq + OpenRouter.** Nothing is wrong with them;
   the point is that today the only spend caps are our own code, and that code
   had three real defects last wave. Account-level, behind his login.
2. **Dedicated In-App-Purchase key** if the refund check is ever wanted (Apple
   requires that key type; the Admin key won't work). Track S is CUT for now.
3. **App Privacy label** — confirm it lists **Purchases**.

## House workflow

- Consult **both** advisors on major decisions — Codex (`codex:codex-rescue`) and
  Gemini (`mcp__gemini__ask_gemini`, models `pro` and `flash`) — and synthesize.
  **Verify their claims against real code**: last wave Flash was wrong on
  Durable Object pricing and consumables, Pro returned DO-NOT-SHIP over a
  "syntax error" that was legal Swift 6, and Codex hit a usage limit and returned
  nothing. They also caught two P0s that would otherwise have shipped.
- Full delegation on reversible steps; verify-then-report before anything
  outward (ASC submit, git push, enabling a credential, flipping a live flag).
- Update `docs/` and auto-memory as increments land.

Start by reading the plan, verifying the state above, and reporting back the
confirmed state plus your proposed Week-1 plan before writing code.
