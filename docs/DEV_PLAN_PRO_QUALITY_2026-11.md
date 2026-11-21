# RoastMate — Pro quality plan, binary 1.9.0 (2026-11-18 → ~12-14)

**Status: CHOSEN (Jason, 2026-11-18, AskUserQuestion), draft 2 below unchanged.**
- Jason's three decisions:
  - **Override confirmed:** build 1.9.0 under this plan.
  - **Q3 = none:** no cloud lane for C/E. The on-device promise in
    `settings.about_ai.body` stays true.
  - **Q2a = yes:** Pro gets 3 takes of 痛罵.
- Scope: **Q0 → Q4 → Q1 → Q5 → Q2b → Q2a.** Cutoff **12-04**, submit **12-07**.
- Draft 1 (`99c68d7`) was reviewed by Gemini 3.8 Flash (High), read-only. The raw
  answer is `docs/evidence/2026-11-18-pro-quality-plan/review-gemini38flash.md`.
  Each of its claims was checked; §10 lists what changed and what was rejected.

## Status 2026-11-21 (Q1 gate passed; release checks next) — evidence: `docs/evidence/2026-11-18-pro-bench/README.md`

| item | state |
|---|---|
| Q0 bench | done: harness, `score.py` (25 tests), fixed inputs, sealed unseen sets (Gemini, unread), 1.8.0 baseline |
| Q2b strong word, zh-Hant/ja Vent | **passed** (attempt 2) and **in production** |
| Q2a 3 takes of 痛罵 | **cut** — gate failed twice (swears per take, then names 4/249); takes code removed |
| Q5 judge false positives | **cut** — no candidate reached the gate on dev data; no gate attempt |
| Q4 simulator | **cut** — gate failed twice (fixed 30/28/30 then 32/28/31; unseen 23 then 31); better than control every run; code back to 1.8.0, kept in history |
| Q1 on-device quality | **passed** gate attempt 2 (`q1g2`, 11-21; attempt 1 failed 3 fixed-set lines on 11-19) and **goes into 1.9.0**; cost: fewer versions shown (fixed set 343/648 calls show 3, control 589). After the gate: a rule whose English tagger model is missing (iOS on-demand asset) is skipped, not failed; Korean keeps 1.8.0's behaviour (README "After the gate") |
| Cloud Vent/Feral safety (found 11-19, pre-existing) | fixed in the Worker and **in production** |

**Production Worker deploys (2 of 2 used):** `c1253b1c-6fec-4627-9f6c-fcc73f48c430` (Q2b,
names, safety) then `eb7b671c-56a7-48a0-a22d-ffbcb43e43fc` (widened threat patterns after
the smoke test caught "I will be waiting"). Rollback: `npx wrangler rollback
c1253b1c-6fec-4627-9f6c-fcc73f48c430`, or `046f2134-5424-4069-b6f3-28b053ccd594` for
1.8.0's Worker.

**Ideas noted, not built (plan rule: no new work):**
- Q5 follow-up: on a THREAT verdict for 改成能發的, retry the rewrite once instead of
  showing the labelled example. It lowers the user-facing harm without loosening the judge.
- The Worker's name detector misses bare given names (宗翰, 直樹, "Brenda" opening a
  sentence); they leak at about 1 in 20 Feral drafts in production.

## 0. Why this plan exists, and which rules it overrides

On 11-18 Jason asked for a plan to make every paid feature a little better
(「我想把我们目前付费的功能都做得更好一点」).

**This is Jason overriding his own rules, on purpose, in chat.** It is recorded
here so nobody later reads it as drift:
- **v1.7 §7 stop rule:** it fired on 11-15 (0 posts → "stop feature work";
  handoff "Update 2026-11-15").
- **v1.8 §2.1:** 1.8.1 = at most one §3 (B) item, explicitly re-approved; code
  freeze 12-05; "no self-extension".
- DEV_PLAN_v1.9 §5 listed exactly this ("a bigger feature plan before 01-31") as
  not recommended. Jason has now chosen it, which is his call.

**What the override does not touch:**
- **The v1.8 §2.3 read on 01-31** (the task fires 02-04) keeps its definitions and
  its §2.1 consequences.
  - At ~1.5 first-time downloads a week it will almost surely be recorded as
    traffic-limited and KILL (DEV_PLAN_v1.9 §0).
  - 1.9.0 changes no distribution number.
  - After a KILL, maintenance mode follows. This plan does not extend itself past
    1.9.0.
- **D's maintenance duties:** the weekly readout and the balance check, the kill
  switches, the refusal probe after OS point releases, and App Review answers.
- **Every privacy and safety guardrail in §7.**

**Expectation, stated plainly.** No revenue effect of this work can be seen before
01-31. Success here means passing **measured quality gates**: each paid feature
beats 1.8.0 on the same Mac, with the same inputs and the same metrics. It does
not mean more subscribers.

## 1. Where the paid features are today (measured)

Device classes:
- **A/D:** iPhone or Mac with Apple Intelligence, OS 26/27.
- **C/E:** no Apple model (iOS 18, AI off or unsupported, older iPhones, Intel
  Macs).

Sources:
- lens 1 (10-27, macOS 27.0.1);
- the A4/A5 gates (10-31, 27.2);
- the rewrite recheck (11-08, `docs/evidence/2026-11-08-next-phase/a1-rewrite-recheck/`);
- today's 27.2.1 probe (`docs/evidence/2026-11-18-macos2721-probe/`, production
  `RoastEngine`).

The paywall line (`zh-Hant.lproj:163`) reads: 痛罵 · 狠 · 全部 24 種風格 · 每則回擊
3 個版本 · 吵架模擬器 · 無限歷史 · 不扣點數. 發洩 itself is free (it costs credits).
**The Pro part of 發洩 is a Pro style's voice on the draft.**

| paid feature | A/D | C/E | the gap |
|---|---|---|---|
| **痛罵 (Feral), cloud** | real, with consent. 20/20 OK, a swear 20/20, zh-Hant Taiwan terms 10/10, 0 Simplified (lens 1) | same | One draft only (`RoastEngine.swift:218-219`, `index.js:707-713`). 硬核回擊 reads like the unstyled draft (A1 cut after 2 rounds). ja unverified. Its 改成能發的 is **canned on C/E**. |
| **Pro style voice on 發洩/痛罵, cloud** | real; 冷處理/職場冷暴力/台劇腔 distinct | same | Vent's "1–2 strong words" (zh/ja) is not reliable: today's zh_TW smoke draft had none (n=1). |
| **狠 (Savage), on-device** | real only through A3's permissive retry (default guardrails 0/40 on 27.2.1) | canned | **Quality:** short, abstract lines (「返金期限を逃している。」). ja misreads who is at fault (1.7.3 note). |
| **16 Pro styles in Composed/Sharp/Savage + 3 versions** | real, de-templated by A5 (0 CJK in en, 0 "I'd have said") | canned (the paywall says so) | **Quality:** today's en 高情商 Composed returned "Sleepwalking?" / "Recipe planning?" / "Emergency cleanup?", three non-answers labelled as model output. |
| **改成能發的 after a Pro draft, on-device** (free itself, but the step after 痛罵) | real | canned | **The judge blocks ~1 in 5 legit rewrites** (11-08: 2/10 → labelled example). Shipped judge on the blind set: 8/40 legit blocked, 32/40 threats caught. Owner confusion: 「我的碗盤」 for the roommate's dishes, 2/5. |
| **吵架模擬器** | opponent's voice 28–30/36 (gate 29 met in 1 of 3 runs, A4) | honest "needs Apple Intelligence" | 硬核回擊 inverts on raise/trash; the en raise persona inverts every run. |
| **無限歷史 / 不扣點數** | real | real | none |
| **虛擬室友群 (roommate group), cloud, Pro** | zh-Hans only | zh-Hans only | Invisible to every TW/US/JP payer and absent from their paywall. |

Out of scope, because 1.8.0 already fixed it:
- A2: honest copy per device;
- A3: the refusal retry;
- A4: the simulator rewrite;
- A5: de-templating (that is also why Gemini's "style de-homogenization" idea is
  stale, §10 #9);
- A6: trial and hand-off;
- A7: Echoes consent;
- B5: the 痛罵 preview.

## 2. How "better" is measured (applies to every item)

- **One bench, built first (Q0).** It reuses the A4/A5/realengine harnesses: the
  production `Shared/` compiled into a minimal `.app` on this Mac (recipe in
  `docs/evidence/2026-11-18-macos2721-probe/README.md`).
  - **Control:** `Shared/` as of `v1.8.0-ios29`. HEAD's `Shared/` is identical to
    it except one comment.
    - Build the control from `git archive v1.8.0-ios29 Shared`, plus the harness
      from HEAD.
    - Rerun it on the day of the final candidate run, so OS or model drift hits
      both.
  - **Candidate:** branch HEAD.
  - Cloud items run against a **preview** Worker (`wrangler dev --remote`).
- **The ship gate is automatic metrics, with written formulas.** They are
  implemented in a `score.py` with unit tests before tuning starts.
  - **Non-answer:** a variant is one if any of these holds:
    - fewer than 8 Han/kana characters (zh/ja), or fewer than 5 words (en);
    - it ends in ?/？ with no declarative clause before it;
    - NLTagger finds no verb in it.
  - **Grounded:** shares at least one content word (en: noun or verb lemma via
    NLTagger) or one character bigram outside a stop list (zh/ja) with the
    situation.
  - **Script checks:** 0 Simplified-only characters in zh_TW (`postprocess.js`
    list), 0 CJK in en, 0 Latin in zh/ja beyond the whitelist.
  - **Near-duplicates:** character-bigram Jaccard ≥ 0.35 (zh/ja) or word-bigram
    ≥ 0.40 (en).
  - Refusal → curated rate; latency.
  - **Feral/Vent only:** a swear or strong word present; names removed (the
    existing `draftDefects`); the length ceiling.
- **The agent's blind read is a veto only.**
  - Pairs are randomized and the key is kept apart.
  - It can block a change it reads as worse. It can never pass one on its own.
  - LLM-as-judge stays rejected (Phase 2).
  - A native zh-Hant reader (Jason's, optional) confirms. With none by submit,
    ship on the metrics and record the gap.
- **Unseen inputs.**
  - The fixed input set is written before tuning.
  - Before the final run, 6 new situations per locale are added. They are never
    used for tuning, and the gates must hold on them too.
- **Safety never regresses.** Any item that touches prompts or the judge reruns:
  - the blind set: threats caught ≥ 32/40, veiled ≥ 20/28;
  - the 297 real outputs;
  - the safety e2e set (`harness/safety/e2e`);
  - none of them may get worse than the 11-18 numbers.
- **Cut rule (v1.8 §2.4):** an item whose gate fails twice is cut from 1.9.0, not
  tried a third time.
- **Spend.** OpenRouter evaluation ≤ $2 in total, at ≈ $0.00013 a call. The whole
  plan needs well under 200 cloud calls (≈ $0.03), so 3-take runs do not threaten
  the cap. On-device calls are $0.

## 3. Scope, ranked by value to a paying user per day of work

**Recommended: Q0, Q4, Q1, Q5, Q2b, then Q2a. Q3 is Jason's call, and the
recommendation is none (§3 Q3).**

### Q0 — the bench (first; ~1 day)

- **What:** the runner, `score.py` (with tests), the control and candidate
  builds, and a fixed input set:
  - 12 situations × zh_TW/en/ja × every intensity × 6 styles (2 free, 4 Pro,
    including 硬核回擊 and 台劇腔);
  - A4's 36 simulator turns;
  - 12 drafts for rewrites;
  - 6 cloud situations × 3 locales for Q2.
- **First output:** the 1.8.0 baseline on 27.2.1, in
  `docs/evidence/<date>-pro-bench/`. Every gate compares against it.

### Q4 — 吵架模擬器 reliability (A/D; ~1–2 days)

- **What:** fix 硬核回擊's preamble pulling the opponent onto the user's side, and
  the en "raise" persona inversion. The work stays inside `opponentTurn` and
  `opponentPersona`.
- **Gate:**
  - ≥ 29/36 opponent turns in **3 of 3** runs, plus the unseen setups;
  - 0 numbered lists;
  - ≤ 1/18 refused per locale;
  - ja no worse than A4.

### Q1 — on-device sendable quality: Composed / Sharp / 狠 / Pro styles / 3 versions (A/D; ~3–4 days)

- **What:**
  1. **A non-answer screen** using §2's formulas. It drops non-answer and
     ungrounded variants. If fewer than 2 survive, it retries once with the reason
     in the prompt. Then it shows what survived, or labelled curated text.
  2. **A per-mode prompt rework** for Composed and Sharp, which A5 did not touch:
     - examples that answer in full sentences;
     - "name one concrete thing from what happened";
     - ja: the user is the one who was wronged.
- **Dropped from draft 1:** guided generation (`@Generable`). Apple's doc says
  permissive content transformations "only works for generating a string value"
  (`evals/runs/2026-08-30-…-veto.md:109`). Savage and Pro styles need the
  permissive path on 27.2+.
- **Gate:**
  - non-answers ≤ 2 % of variants, and 0 one-word variants;
  - grounded ≥ 90 %;
  - refusal → curated, script checks and near-dups no worse than control;
  - median latency ≤ control + 2 s;
  - safety no regression (§2);
  - holds on the unseen situations.

### Q5 — fewer false blocks on 改成能發的 and permissive variants (A/D; ~1–2 days)

- **Why now:** on 11-11 Jason ruled the judge's false positives "not a 1.8.0
  regression" and parked them "for a next plan". This is that plan. They replace
  ~1 in 5 legit rewrites with the labelled example.
- **What:**
  - calibrate `threatJudgeInstructions` (`RoastEngine.swift`; tuning history in
    `harness/safety/judgetune/README.md`);
  - in the rewrite prompt, keep who owns what (「我的碗盤」 errors).
- **Gate:**
  - blind set: threats caught ≥ 32/40, veiled ≥ 20/28 (no regression), and
    legit blocked ≤ 4/40 (from 8/40);
  - real outputs blocked ≤ 10/297 (from 20);
  - a **fresh** blind set of 40 written before tuning (Gemini writes it to a
    file, as in 10-29; scored before anyone reads it) must also show no threat
    regression;
  - rewrite owner errors 0/10 on the 11-08 situations.
- **Risk:** loosening the judge lets veiled threats through, which is why the
  no-regression line is hard.

### Q2 — 痛罵 and styled 發洩 (cloud; every payer on every device)

- **Q2b, a strong word when the intensity promises one (~1 day, Worker prompt):**
  - Measure Vent and Feral strong-word rates per locale in Q0. Fix the prompt only
    where the rate is below the documented intent (zh/ja Vent "1–2 strong words",
    2026-05-23 tune).
  - ja Feral gets a pass graded by the metrics, marked UNVERIFIED-by-native.
  - Gate: ≥ 80 % for zh/ja Vent; no rise in names, length or Simplified.
- **Q2a, Pro gets 3 takes of 痛罵 (~3 days).** It makes the paywall's "3 versions"
  true for the one Pro generator that is real everywhere.
  - **Both sides change.** Today one draft is enforced on the client
    (`RoastEngine.swift:218-219`) and on the Worker (`index.js:707-713`, a single
    `{ text }` reply). History already stores several variants for sendable
    modes.
  - **Worker:**
    - `variantCount` is honoured for `mode:"vent"` only when `lane=pro`. The free
      lane and old binaries stay at 1.
    - Q0 decides the design by the metrics and the veto read: one call returning
      3 drafts, or 3 calls at T ≈ 0.95.
    - Every take passes `stripNameAddress` and `draftDefects`.
  - **Client:**
    - 3 cards, each with its own 改成能發的;
    - the B5 preview stays one draft;
    - a Pro user without a token gets 1 draft, the free-lane behaviour, because
      the Worker returns 1.
  - **Gate:**
    - every pair of takes distinct (Jaccard below §2's thresholds) in ≥ 95 % of
      calls;
    - each take passes postprocess;
    - 0 names; 0 Simplified in zh-Hant;
    - the swear rate per take ≥ the single-draft rate;
    - p90 latency ≤ 8 s.
- **Worker deploys:** at most 1 production deploy for Q2, after the preview gate
  and before the binary. It is backward compatible. Rollback = `npx wrangler
  rollback <id>`.

### Q3 — a cloud lane for Pro on devices without Apple's model (C/E). **NOT CHOSEN (Jason, 11-18: none).** Kept for a future plan.

On C/E, 4 of the 7 paywall lines are canned, and Q3 is the only way to make them
real there. But it costs:
- **A broken on-device promise.** `settings.about_ai.body` (`zh-Hant.lproj:142`)
  says the sendable modes and 改成能發的 run on-device and "我們永遠看不到". That
  copy, the onboarding text and the privacy policy change, and a versioned
  5.1.2(i) consent is needed.
- **Unknown value.** The C/E share of payers is unknown, and no analytics will be
  added.
- **Schedule risk** before the year-end slowdown.

Scope, if chosen:
- **Q3a, cloud 改成能發的 for Pro on C/E** (v1.8 B1-R, `DEV_PLAN_v1.8` :712-753,
  scope and gate unchanged):
  - Worker `mode:"rewrite"`, Pro lane only, `REWRITE_MODE_ENABLED`, with a
    server-side threat judge;
  - a restrict-only key `pro_cloud_rewrite_enabled` (default false, read only by
    1.9.0);
  - a versioned consent; copy in 4 locales; the privacy-policy diff (Jason); App
    Privacy (Jason).
  - Effort: 3–4 days.
- **Q3b, cloud sendable modes for Pro on C/E** (v1.8 B1-S, :755-784): another 5–7
  days. **Not recommended** this time: it was already called premature in v1.8,
  and it would push the date.
- **Hard requirements (new, from the review):**
  - **No tokenless fallback for these modes.** `CloudVentClient.swift:63-78`
    deliberately falls back to the free lane for Vent. The new modes must not:
    no token → a labelled message.
  - **The Worker rejects** `mode:"rewrite"` (and the Pro roast lane) without a
    valid Pro token. Today `index.js:180-182` checks only `ROAST_MODE_ENABLED`,
    and `lane.js` gives tokenless requests `lane: "free"`. This gets an automated
    negative test in `cloud-worker/test/` (no Authorization → 401/403).
  - **Production Pro tokens must mint.**
    - Agent's half (read-only, no user data): `npx wrangler secret list` (names
      only) shows the signing key, and `/v1/auth` with a malformed receipt
      returns the designed 4xx.
    - Jason's half, only if that is inconclusive: a $0 offer-code redemption on
      his own Apple ID, one Feral, then cancel. It carries the r320
      mis-crediting caveat (DEV_PLAN_v1.9 §3).
- **Gate:** v1.8's B1-R gate (≤ 25 preview calls), plus the negative tests. The
  client end-to-end check runs in a Release build against a **preview** Worker
  with `ALLOW_SANDBOX_RECEIPTS=true`, never production.
- **Worker deploys:** shares Q2's single production deploy when possible, with
  the new mode's flag false until 1.9.0 is live. Then one flag flip, with a
  one-sentence rollback.

### Not recommended this time

| item | why not |
|---|---|
| Roommate group to zh-Hant (v1.8 B2) | zh_TW transcripts had Simplified 8/8; 0 of 29 `echoes.*` strings in zh-Hant (consent included); ~1 TW install every 3 weeks; 3–4 days. A new feature for TW, not a better existing one |
| 硬核回擊 voice (A1) | failed its gate twice; the cut rule |
| Style de-homogenization (Gemini) | A5 already did it (a5/README: "I'd have said" 6 → 0, CJK in en 15 → 0). The review cited pre-A5 evidence |
| Lifetime Pro (B8), new styles | pricing or more surface, not better existing features |

## 4. Order and dates

| when | what |
|---|---|
| 11-19 → 11-20 | Q0 bench + 1.8.0 baseline (on-device + 18 preview Worker calls); score.py tests; Q3's token check if Q3 is chosen |
| 11-20 → 11-22 | Q4 |
| 11-22 → 11-27 | Q1; in parallel, Q2b on a preview Worker |
| 11-27 → 11-29 | Q5 |
| 11-29 → 12-02 | Q2a (Worker preview → gate → 1 production deploy; client) |
| (12-02 → 12-05) | Q3a, only if chosen |
| **12-04** | **cutoff: any item without a passed gate leaves 1.9.0** (12-06 with Q3a) |
| 12-04 → 12-06 | preflight; Release UI checks (`PaywallFlowUITests`; `DeviceHonestyUITests` on iOS 18.5 and 27); final bench (control + candidate + unseen); StoreCopy and parity tests |
| **12-07** | **submit 1.9.0, iOS + macOS** (12-09 with Q3a). This leaves about 2 weeks for one rejection cycle before Apple's year-end slowdown, whose 2026 dates are UNVERIFIED |
| after live | Q3 flag flip, if Q3 is in; promo text refresh in 4 locales and D+2's keywords/subtitle on 1.9.0 (Jason approves the words); `git tag v1.9.0` |

## 5. Builds and release mechanics

- **Xcode.**
  - iOS: `/Applications/Xcode.app` (27.2, 27B52). ASC accepts it for iOS: Soundpost
    builds 23 (archived with 27B52 on 11-08) and 24 are `VALID` in the ASC builds
    API (checked 11-18).
  - macOS: unverified. Try 27B52 first. Export refusal is harmless, because
    nothing reaches ASC. If it is refused, rebuild with
    `DEVELOPER_DIR=/Applications/Xcode-27.1.app/Contents/Developer`.
  - A VALID 27B52 macOS build is the evidence that lets Jason remove Xcode 27.1.
- **Scripts:**
  - `scripts/preflight.sh` (`RoastMate-UITests`);
  - `scripts/build-upload-asc.sh`;
  - `scripts/asc_bind_version.py` for iOS and with `--platform MAC_OS`, with
    release notes in `build/v1.9.0-release-notes{,-mac}.md`;
  - reviewer notes from `metadata/review_notes_asc_short.txt`;
  - `scripts/asc_submit_review.py`.
- **Version text.**
  - New versions don't inherit the promotional text: re-set it with
    `asc_product_page.py` (dry run first).
  - `text --version 1.9.0` also writes D+2's queued keywords and subtitle. Jason
    approves those words first.
- **App Review.** 1.8.0's 2.1(b) rejection on 11-02 was the reviewer's sandbox
  account error, not the paywall (handoff "Update 2026-11-04"). The Release
  paywall test still runs before submit, and the reviewer notes are refreshed.
- **Machine rules:**
  - build roots under `~/Library/Caches/RoastMate-build/` or the scratchpad,
    never in `~/Documents`;
  - simulators by UDID with the `/tmp/lock-*` rule; never deleted or erased;
  - run the two codesign lock probes before any archive (global CLAUDE.md).

## 6. Jason's part

1. ~~Confirm the §0 override; pick Q3 and Q2a.~~ Done 11-18: override
   confirmed, Q3 none, Q2a yes.
2. (Q3 not chosen: no privacy-policy or App Privacy change in 1.9.0.)
3. Optional: one native zh-Hant reader for about an hour. The agent prepares
   blind sheets and never messages anyone.
4. The exact words of the 1.9.0 promo text and of the ASO keywords/subtitle.
5. Optional: a 10-minute iPhone check of the TestFlight build.

## 7. Guardrails (unchanged)

- **Product limits.**
  - No third-party SDK, no new analytics, counters or attribution (v1.7 §6).
  - `cloud_sendable_enabled` never turns on. New cloud paths get new keys that
    default false and are read only by the new binary.
  - Every cloud path asks for consent before its first call (5.1.2(i)); a new
    path means a new consent version.
- **Testing.**
  - Debug builds are always Pro. Paywall, credits, preview and trial are checked
    only in Release with `ENABLE_TESTABILITY=YES`.
  - Unpaired CJK strings have shipped three times. Every new string comes in 4
    locales, under the parity test.
- **Money and the Worker.**
  - Evaluation spend ≤ $2.
  - At most 2 production Worker deploys, plus rollbacks and flag flips.
  - Never read one person's Worker logs.
- **Kill switch.** A threat, self-harm content or a slur reaching a user means
  `ondevice_permissive_enabled:false` (or the new key) the same day.
- **Public text and ASC.**
  - Public text goes live only after Jason approves the exact words.
  - ASC changes: one sentence on what and how to roll back, first.
  - The ASC app id is 6769317103, never `$ASC_APP_ID`.
- **Git.** Commit and push at once. The scheduled tasks stay untouched.

## 8. Pre-mortem

1. **The on-device model is the ceiling.** Q1's prompts plateau, as A5's "still
   mediocre" did. The non-answer screen ships on its own if the prompt work fails
   twice, because it removes the worst output whatever the model does.
2. **Q5 loosens the judge and a veiled threat gets through.** The no-regression
   lines on two blind sets are hard gates, and the kill switch exists.
3. **3 takes make 痛罵 thinner.** The metrics and the veto read decide between 1
   call and 3. If neither design passes, Pro keeps one draft.
4. **The bench flatters the candidate.** The unseen situations and the same-day
   control rerun guard against that.
5. **A cloud path misroutes (Q3).** Token required, negative tests, keys default
   false, preview-only end-to-end.
6. **Scope creep.** The 12-04 cutoff removes unfinished items, not the date.

## 9. Open questions

- What share of payers is on C/E? Unknown (B6 cut, no analytics). Q3's value is a
  judgment.
- Will Apple's year-end slowdown in 2026 fall later than 12-20? UNVERIFIED. The
  submit date assumes it does not.

## 10. Review synthesis — Gemini 3.8 Flash (High), 2026-11-18

Each claim was checked in the code or evidence before it was accepted.

| # | claim | verdict |
|---|---|---|
| 1 | `@Generable` is incompatible with the permissive path | **Accepted, verified** (veto doc :109: "only works for generating a string value"). Q1 step 3 dropped |
| 2 | Vent is one draft on both sides (`RoastEngine.swift:218-219`, `index.js:707-713`) | **Accepted as a scope fact.** Draft 1 already proposed changing it; draft 2 names both files. "Breaks the data models" rejected: history already stores several variants for sendable modes |
| 3 | The client falls back to the tokenless free lane (`CloudVentClient.swift:63-78`); the Worker doesn't check the lane for `roast` (`index.js:180-182`) | **Accepted, verified.** Q3 gains "no tokenless fallback" for new modes and automated negative tests |
| 4 | "ASC accepts 27.2 for iOS" is unsupported | **Rejected, but the source is now cited.** The evidence lived in other projects. Checked 11-18 with the ASC API: Soundpost builds 23 (archived 11-08 with 27B52; the local archive's `DTXcodeBuild` = 27B52) and 24 are `VALID`. macOS stays unverified |
| 5 | A separate tag worktree is unnecessary or broken | **Partly accepted.** `Shared/` is identical to the tag; the control is built from `git archive` of the tag's `Shared/` plus the HEAD harness |
| 6 | Agent-read blind pairs are gameable | **Accepted.** Metrics with written formulas gate; the agent's read is a veto only |
| 7 | Concrete non-answer, grounding and distinctness formulas | **Accepted with tuning** (8 Han/kana characters rather than 10: valid zh lines such as 「LINE已讀不回，又在催租。」 are 11). Distinctness thresholds 0.35/0.40 adopted |
| 8 | Judge false positives on rewrites (~1 in 5) are a better target | **Accepted** as Q5, with hard no-regression lines on threats. It was parked on 11-11 "for a next plan" |
| 9 | Style de-homogenization (`PromptBuilder.swift`) | **Rejected:** A5 already fixed the cited symptoms. The review cited lens 1, which predates A5 |
| 10 | Q1 prompt changes could raise veiled threats | **Accepted:** a safety no-regression gate on every prompt/judge item |
| 11 | Q3 breaks the on-device promise in `settings.about_ai.body` | **Accepted,** and already in v1.8 B1-R's copy list. Now stated in Q3's costs |
| 12 | Q3b cut, Q3a deferred | **Accepted as the recommendation** (none). Jason decides |
| 13 | 12-09 leaves no room for a rejection before the year-end shutdown | **Accepted:** cutoff 12-04, submit 12-07 (12-09 only with Q3a) |
| 14 | 3-take runs will exhaust the $2 eval cap | **Rejected:** ≈ $0.00013 a call; the plan needs < 200 cloud calls (≈ $0.03) |
| 15 | 2.1(b) risk from touching purchase paths | **Rejected as stated:** the 11-02 rejection was a sandbox account error. The Release paywall test runs anyway, and no purchase path changes |
| 16 | The 01-31 read is headed for KILL regardless | **Accepted;** already in §0. Unchanged consequence |
| 17 | The §1 table listed 發洩 as paid and the roommate group as on the paywall | **Accepted in part:** the row now says the Pro part is the style voice; the roommate row notes it is absent from TW/US/JP paywalls |
