# RoastMate — Next-Phase Plan: one binary, then stop coding

_Drafted 2026-09-06 against live code, the live Worker, the live served config
and the live ASC API. **Rewritten after review by Gemini 3.1 Pro and Gemini 3.8
Flash — both returned a harsher verdict than the first draft and both were
right.** See §6. Supersedes the unfinished parts of `DEV_PLAN_v1.5_2026-09.md`._

---

## 0. Where we actually are

**Live:** iOS + macOS v1.4.0 build 20, READY_FOR_SALE.

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

- **P1.1 — Stop charging for canned output.** `RoastGeneratorViewModel` spends
  the credit *before* the engine runs, and the curated path reports success, so
  there is no refund. Either move the spend after generation, or check
  `RoastEngine.isOnDeviceModelAvailable` before charging. **Apply the same fix to
  `ArgumentSimulatorViewModel`**, which has the identical flaw and which the
  first draft missed.
- **P1.2 — Tell the user when output is curated.** Note the trap: the string
  `roast.error.unavailable` reads *"Showing curated responses instead"*, but it
  is reachable only via `RoastError.modelUnavailable`, which the view model
  catches into an `.error` state that renders **zero cards**. The copy promises
  curated output; the wiring suppresses it. So this needs a non-error surface —
  a note attached to the results — not the existing throw path.
- **P1.3 — `FallbackRoasts` has no zh-Hant pool.** `case "zh": return zh` routes
  every Traditional user to the Simplified array. **This is the third instance of
  the Simplified-only bug class this week**, after `Redactor` (`500ffdb`) and
  `ForbiddenTerms.json` (`02f0f3c`). Add a `zhHant` pool.
- **P1.4 — App Review hazard.** A reviewer on a device without Apple
  Intelligence types a prompt and gets a canned line that ignores their input.
  That is a Guideline 2.1 / 4.0 rejection risk on its own, and P1.1–P1.3 are also
  the mitigation for it. Say plainly in the reviewer notes which devices get
  on-device generation and what the others get.
- **P1.5 — Share-card kill-switch (`share_card_visible`).** ~20 lines. Kept over
  Flash's objection: "live for months without incident" is exactly the reasoning
  that let the zh-Hant leak run, and **two** defects landed on this surface this
  week with no way to mitigate either remotely. The card renders model-derived
  text onto a branded public image; it should have an off switch.
- **P1.6 — Ship.** Bump `project.yml:20-21` → `1.5.0` / `21`, run `xcodegen
  generate` (the committed pbxproj carries its own copies; editing project.yml
  alone does nothing). Re-probe codesign first — it worked under a locked console
  today, but that has failed before and the check costs a second. Then
  `build-upload-asc.sh` → `asc_bind_version.py` → `asc_submit_review.py`.
- **P1.7 — Paste the ASO copy by hand.** 4 locales × 4 fields in the ASC web UI,
  ~10 minutes. The first draft proposed writing `asc_push_metadata.py`; both
  reviewers called that procrastination and they are right. `415d78f` ships
  nothing until someone does this.

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
- **Earned three times this week:** any list of CJK literals must carry both
  script forms, and the test must guard the *rule*, not the instances.
  Simplified-only lists have now shipped in `Redactor`, `ForbiddenTerms.json`
  and `FallbackRoasts`. Assume there is a fourth.
- Fix checks that cry wolf; never learn to skim a red gate.

---

## 5. Open decisions for Jason

1. **P1.1 — refund after, or check before charging?** Checking before is more
   honest and touches the paywall path; refunding is smaller.
2. **Does zh-Hant exist as a product, or only as a store locale?** It is
   zh-Hans-only for Echoes and the roommate group, blocked for sendable cloud,
   had weaker safety lists until this week, has no canned-text pool, and scores
   18/24 on the sendable eval — yet it has its own ASO keywords and a live
   listing. Either invest or say plainly it is metadata-only.
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
