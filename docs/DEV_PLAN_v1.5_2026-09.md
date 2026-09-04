# RoastMate — Next-Phase Development Plan (v1.5: activation & distribution)

_Drafted 2026-09-05 after v1.4.0 shipped LIVE. **Rewritten after review by Gemini
3.1 Pro + Gemini 3.7 Flash — Flash returned RETHINK and was right.** See §9._

---

## 0. Where we are (verified in code 2026-09-05)

- **iOS + macOS v1.4.0 LIVE.** Voice `AVAudioSession` repair (the mic captured
  nothing from v1.2.0 until now — confirmed on a real device), M-b Pro roommate
  lane, hardened Comeback Card.
- **Card growth layer DARK** behind `share_card_enabled`: QR + badge +
  `ct=sharecard_v14` built and tested, switched off.
- **Sendable cloud DARK.** zh-Hans 48/48, ja 24/24, en 24/24 passed; zh-Hant
  20/24 failed. Per-locale gating exists so the three passing locales can flip.
- **The dam is real and measured** — atomic DO counter, observable `/v1/auth`,
  edge kill-switch.
- **Track D (distribution) deferred in every wave since Phase 5**, which named it
  the locked priority.

## 1. What the review changed, and why the first draft was wrong

The first draft called v1.5 a "measurement wave with a kill criterion." Both
reviewers attacked it and the code agrees with them.

**The fatal defect: `EventLedger` has no automated egress.** Verified — there is
no `URLSession`, no endpoint, no upload anywhere in it. Counters live in
App-Group `UserDefaults`, and data only reaches the developer if a user opts in
(~2–5%), opens Settings, taps Prepare Export, and manually shares a JSON file.
Over a 14-day window that is **N = 0**, not small-N.

The v1.4 wave added `share_card_generated` / `share_card_shared` counters, and
this plan then built a kill criterion on top of them **without checking how the
data gets off the device**. A table of exact thresholds created an illusion of
rigor over a number that cannot be collected. That is the failure mode to
remember.

**Second correction: "measurement wave" was procrastination dressed as rigor.**
Flipping switches and waiting 14 days measures nothing when nobody is
discovering the app. There is no traffic to measure. What is missing is not
data — it is *users*. So this is an **activation and distribution wave**.

**Third: testing the current card is a strawman.** Both reviewers independently
reached the same conclusion and proposed the same fix (§2 A.1). Deleting the
raw vent deleted the *setup* of the joke. A lone polished line on a gradient —
"收到，已按要求修改，后续建议工作时间沟通" — is a corporate email snippet, not a
meme. Testing an artifact we already know is neutered, in order to conclude it
does not work, is theatre.

## 2. Tracks

### Track A — Fix the artifact, then activate (must precede any seeding)

- **A.1 Restore the setup→punchline structure, privately.** Do NOT render the
  user's raw vent. Have the model emit a short **sanitized, abstracted scenario
  line** alongside the comeback, and render that above it:

  > 【对方】半夜两点催交付物
  > 【我的回击】收到，为保证质量，紧急事项建议工作时间沟通。

  This restores the contrast that made the artifact worth sharing while keeping
  the private draft off the canvas. The abstracted line is model output, so it
  goes through the same `Redactor` + strict `SafetyFilter` path as `sentText`.
  _AC:_ no raw vent on any canvas; the setup line passes the same gates.
- **A.2 Real-device visual pass** — 4 locales × 2 formats × light/dark. Never
  done: unit tests can't link `ShareCardRenderer` (hostless bundle) and the
  simulator has no Apple Intelligence to produce a `.sendableReply`.
- **A.3 Flip** `share_card_enabled`, then `cloud_sendable_enabled` +
  `cloud_sendable_locales: ["zh-Hans","ja","en"]` + Worker `ROAST_MODE_ENABLED`.
  Card first — two variables at once makes the signal unreadable.

### Track B — Distribution, actually executed

- **B.1 Per-creator campaign tokens.** `ShareCardBadge.campaignToken` is a single
  hardcoded `sharecard_v14` compiled into the binary, so seeded-creator installs
  and organic card shares land in the **same bucket** — you could not tell 22
  installs from one creator apart from 22 organic shares. Create distinct ASC
  campaign links per creator (`xhs_seed_01…`) for their captions/bios, and
  reserve the in-binary token for the organic loop only.
- **B.2 ASO pass.** Keywords 帮你骂 / 嘴替 / 吵架 / 回怼 — title and subtitle.
  **Note: these require a binary release**, not a remote flip; the first draft
  wrongly called this "no code". Bundle with the A.1 build.
- **B.3 Creator seed, 5–10 micro-creators.** Realistically 2–3 calendar weeks of
  outreach for 5–10 published posts — start it in week 1, not week 2.
  Xiaohongshu weights **Saves > Comments > Likes**, seeds to a 100–500 pool, and
  keeps high-velocity posts alive for weeks. Design the card to be *saved* — a
  comeback someone wants to find again — not merely liked.
- **B.4 User conversations: 3–4, not 8.** Eight formal interviews is 25–35 hours
  and will not happen alongside everything else. Three high-intent conversations
  beat eight that never occur.

### Track C — Quality (cheap, keep)

- **C.1 zh-Hant sendable.** 20/24. Residual: 3 single-char bleeds + one response
  entirely in **English** — a dropped instruction, not script bleed. Try a
  zh-Hant few-shot example before concluding the model can't do it.
- **C.2** Verify the ASC App Privacy label lists **Purchases**.

### ~~Track S — server-side integrity~~ — CUT, with the reasoning recorded

The first draft proposed App Store Server Notifications V2 and a server-side
credit ledger. **Both are cut.** The reviewers disagreed on severity and the
code settles it:

- **Credits gate CLIENT-side generation only.** Verified: `spendOneCredit` is
  called in `FeatureGenerator` and `RoastGeneratorViewModel`; the **Worker has
  no credit concept at all**. Its caps (`DAILY_LIMIT_PER_DEVICE=30`,
  `APP_DAILY_LIMIT_PER_IP=200`) are entirely independent. So a user who spoofs
  the local SwiftData wallet unlocks *on-device* generation, which costs **$0**,
  and still hits the same server caps. Worst-case cloud exposure is fractions of
  a cent per day. Gemini Pro called this a P0 blocker for the growth loop; that
  was wrong, and the cost math is why.
- **ASSN V2 is sound but not now.** The architecture reuse is real — `verifier.js`
  already carries `SignedDataVerifier` + the Apple root CA, and an ASSN V2
  notification is the same JWS shape, so no dedicated IAP key is needed for
  inbound. But it is 2–3 weeks of webhook, replay-store and sandbox work to
  defend a refund edge case at ~50 lifetime auth sessions. If refunds ever
  bite, the **polling path already exists** behind `ASS_API_ENABLED` — provision
  the key and flip it.

Building either before anyone arrives is the same mistake this project has made
for three waves: retreating into comfortable backend work instead of facing
distribution.

## 3. Sequencing (≈4 weeks, one person)

1. **Wk 1:** A.1 setup-line + A.2 device pass + B.2 ASO metadata → **one build**.
   Start B.3 creator outreach immediately (it has the longest lead time).
2. **Wk 2:** ship the build; A.3 flips (card first); B.1 per-creator tokens.
3. **Wk 3:** creator posts go live; B.4 conversations; C.1 if time.
4. **Wk 4:** read §4, write the decision down.

## 4. Decision criteria — server-observable ONLY

The first draft's thresholds depended on `EventLedger` and were uncollectable.
These are all readable without any user action:

| signal | source | threshold |
|---|---|---|
| App Store impressions / product page views | App Analytics | measurable lift vs the pre-ASO 14-day baseline |
| per-creator product page views | ASC campaign links `xhs_seed_*` | ≥100 across 5 posts |
| organic card loop | in-binary `ct=sharecard_v14` | any non-zero attributed installs |
| repeat usage | Worker `/v1/vent` by deviceId (Datadog) | returning devices trend up |

**Capture the pre-ASO baseline in week 1, before the build ships** — otherwise
"lift" is unmeasurable.

Note Apple attributes campaign tokens only for users who opted into sharing
analytics (~20–30%) and suppresses low-volume rows, so treat any campaign number
as a **floor**, never a rate. Most Chinese users will see a card and *search*
「帮你骂」 rather than scan a QR — which lands as Organic Search, invisible to the
token. That is another reason ASO matters more than the QR.

## 5. Guardrails (do not regress)

- Never render the raw vent onto a shareable image. A.1's setup line is **model
  output**, not user text, and goes through Redactor + strict SafetyFilter.
- `RoastEngine.generate(cloudVentEnabled:)` stays defaulted **false** — fail closed.
- One home per rule: `CloudPermission`, `CloudVentService.generate(_:auth:)`,
  `GeneratedRoastKind.isShareable`.
- No 3rd-party SDK, no analytics SDK. Zero-tracking is the moat — and it is
  precisely *why* §4 must use server- and store-side signals.
- Fix checks that cry wolf; never learn to skim a red gate.

## 6. Open decisions for Jason

1. **A.1 scope** — is the abstracted setup line worth a build, or ship ASO alone
   and leave the card as-is? (Recommend: worth it. Without it the loop is
   untestable, and both reviewers converged on this independently.)
2. **If §4 comes back flat**, is shelving the growth loop acceptable? Worth
   answering before the data arrives.
3. **Creator budget** — paid seeding, or organic outreach only?

## 7. References (verified 2026-09-05)

- `burakdede/storekit-cloudflare-workers` — StoreKit 2 backend on Workers + D1
  with ASSN V2 and a replay ledger. Closest published architecture to ours; the
  reference to use **if** S is ever revived.
- `amsintelligence/swift-masker` — on-device PII redaction, iOS 18+/Swift 6.
  Documented to degrade on non-Latin scripts including Chinese, matching our own
  measurement. Worth reading, not adopting wholesale.
- Apple: ASSN V2 recommended over polling; notifications are Apple-signed JWS;
  handle duplicate and out-of-order delivery.
- Xiaohongshu: Saves > Comments > Likes; 100–500 seed pool; velocity sustains
  circulation for weeks.
- ASO for indies: compounding, cheap, and most competitors do it badly.

## 8. Definition of done

The A.1 card actually has a setup line and a human has looked at 16 renders. ASO
metadata shipped and the pre-ASO baseline captured. 5–10 creator posts live with
per-creator attribution. §4 read and the decision written down with numbers.
Nothing left silently DARK.

## 9. Review synthesis — Gemini 3.1 Pro + 3.7 Flash (2026-09-05)

| # | source | sev | finding | applied |
|---|---|---|---|---|
| 1 | Flash | **P0** | `EventLedger` has NO automated egress — the §4 share-rate metric is N=0, not small-N | §4 rebuilt on server/store-observable signals only |
| 2 | Both | **P0** | The quote card is neutered; testing it as-is is a strawman. Both independently proposed an abstracted setup line | New Track A.1 |
| 3 | Flash | **P0** | One hardcoded campaign token blends creator and organic installs | B.1 per-creator ASC links |
| 4 | Flash | P1 | Track S defends phantom fraud; credits gate on-device generation ($0) and server caps are independent | Track S CUT, math recorded |
| 5 | Pro | P1 | Claimed the client wallet was a P0 blocker for Track G | **Rejected** — code shows the Worker has no credit concept; Flash's cost math is correct |
| 6 | Flash | P1 | ASO title/subtitle needs a binary release, not a remote flip | B.2 bundled into the A.1 build |
| 7 | Flash | P1 | 8 interviews ≈ 25–35h and won't happen; creator outreach needs 2–3 weeks lead | B.4 cut to 3–4; B.3 starts week 1 |
| 8 | Flash | P2 | Chinese users will search the name rather than scan a QR → Organic Search, invisible to the token | §4 treats campaign numbers as a floor |
| 9 | Pro | P1 | ASSN V2 without an IAP key is sound (verifier.js already has the root CA) | Confirmed, but deferred — recorded in Track S for when it matters |

**Both reviewers' shared verdict, in different words:** the plan retreated into
backend work it enjoys instead of the distribution work it has avoided for three
waves. Flash's RETHINK was correct and this rewrite follows it.
