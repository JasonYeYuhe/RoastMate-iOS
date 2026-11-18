# RoastMate — Pro quality plan, binary 1.9.0 (2026-11-18 → ~12-16)

**Status: DRAFT 1, written 2026-11-18. Gemini 3.8 Flash review pending (§10).
Jason picks the scope in §3 before any code.**

## 0. Why this plan exists, and which rule it overrides

On 11-18 Jason asked for a plan to make every paid feature a little better
(「我想把我们目前付费的功能都做得更好一点」).

**This is Jason overriding his own rules, on purpose, in chat.** Recorded here so
nobody later mistakes it for drift:
- **v1.7 §7 stop rule.** It fired on 11-15 (0 posts → "stop feature work";
  handoff "Update 2026-11-15").
- **v1.8 §2.1.**
  - 1.8.1 = at most one §3 (B) item, explicitly re-approved.
  - Code freeze 12-05.
  - "No self-extension."
- DEV_PLAN_v1.9 §5 listed exactly this ("a bigger feature plan before 01-31") as
  "not recommended" because it breaks those rules. Jason has now chosen it anyway.
  That is his call to make.

**What the override does not touch:**
- **The v1.8 §2.3 read on 01-31** (the task fires 02-04) keeps its definitions and
  its §2.1 consequences. KILL → maintenance mode afterwards. This plan does not
  extend itself past 1.9.0.
- **D's maintenance duties:**
  - the weekly readout and the balance check;
  - the kill switches;
  - the refusal probe after OS point releases;
  - App Review answers.
- **Every privacy and safety guardrail in §7.**

**Expectation, stated plainly.** At about 1.5 first-time downloads a week, no
revenue effect of this work can be seen before 01-31. Success here means
**measured quality gates**: each paid feature is better than 1.8.0 on the same
Mac, on the same inputs, judged blind. It does not mean more subscribers.

## 1. Where the paid features are today (measured)

Device classes:
- **A/D:** iPhone or Mac with Apple Intelligence, OS 26/27.
- **C/E:** no Apple model: iOS 18, AI off or unsupported, older iPhones, Intel
  Macs.

Sources:
- lens 1 (10-27, macOS 27.0.1);
- the A4/A5 gates (10-31, 27.2);
- today's 27.2.1 probe, `docs/evidence/2026-11-18-macos2721-probe/` (production
  `RoastEngine`).

| paid feature (paywall: 痛罵 · 狠 · 24 種風格 · 3 個版本 · 吵架模擬器 · 無限歷史 · 不扣點數) | A/D | C/E | the gap |
|---|---|---|---|
| **痛罵 (Feral), cloud** | real (with consent). 20/20 OK, a swear 20/20, zh-Hant Taiwan terms 10/10, 0 Simplified (lens 1) | same | One draft only. 硬核回擊 reads like the unstyled draft (A1 cut after 2 rounds). ja quality unverified. Its 改成能發的 is **canned on C/E**. |
| **發洩 with a Pro style, cloud** | real; 冷處理/職場冷暴力/台劇腔 distinct | same | A strong word is not reliable: today's zh_TW smoke draft had none (n=1). |
| **狠 (Savage), on-device** | real only through A3's permissive retry (default guardrails 0/40 on 27.2.1) | canned | **Quality.** Short, abstract lines ("返金期限を逃している。"); ja misreads who is at fault (1.7.3 note). |
| **16 Pro styles in Composed/Sharp/Savage** | real, de-templated by A5 (0 CJK in en, 0 "I'd have said") | canned (the paywall now says so) | **Quality.** Today's en 高情商 Composed returned "Sleepwalking?" / "Recipe planning?" / "Emergency cleanup?": three non-answers, all labelled model output. |
| **3 versions** | real (near-dup 0/52, A5) | canned | Same quality problem ×3. |
| **吵架模擬器** | opponent's voice 28–30/36 (gate 29 met in 1 of 3 runs, A4) | honest "needs Apple Intelligence" | 硬核回擊 inverts on raise/trash. The en raise persona inverts every run. |
| **無限歷史 / 不扣點數** | real | real | none |
| **虛擬室友群 (roommate group), cloud** | zh-Hans only | zh-Hans only | Invisible to every TW/US/JP payer. zh_TW transcripts had Simplified 8/8 (lens 4). |

What 1.8.0 already fixed, and therefore stays out of scope:
- A2 honest copy per device;
- A3 refusal retry;
- A4 simulator rewrite;
- A5 de-templating;
- A6 trial and hand-off;
- A7 Echoes consent;
- B5 痛罵 preview.

## 2. How "better" is measured (applies to every item)

- **One bench, built first (Q0).** It reuses the A4/A5/realengine harnesses: the
  production `Shared/` compiled into a minimal `.app` on this Mac. It runs:
  - the **candidate** (branch HEAD);
  - a **control**: the `v1.8.0-ios29` tag, compiled in a temporary worktree in
    the scratchpad;
  - the same inputs for both.

  Cloud items run against a **preview** Worker (`wrangler dev --remote`).
- **Automatic checks** on every output:
  - non-answer: too short for its script, or a bare question / noun phrase;
  - grounding: shares no concrete detail with the situation;
  - Simplified in zh_TW, CJK in en, Latin in zh/ja;
  - near-duplicates; refusal → curated; latency;
  - for Feral and Vent: a swear or strong word present, names removed, length
    ceiling.
- **Blind pairs, read by the agent.**
  - Each pair is control vs candidate, order randomized, key stored apart.
  - "Better" means the candidate wins at least 2 of 3 decided pairs, per locale.
  - LLM-as-judge stays rejected (Phase 2 decision). Gemini reviews plans, it does
    not grade output.
- **Native zh-Hant reader** (Jason's, optional). Same as in v1.8: if none by
  submit, ship on the machine gates and record the gap.
- **Cut rule (v1.8 §2.4):** an item whose gate fails twice is cut from 1.9.0,
  not tried a third time.
- **Spend:** ≤ $2 of OpenRouter evaluation in total (≈ $0.00013 a call). On-device
  calls are $0.

## 3. Scope, ranked by how many payers each item reaches

### Q0 — the bench (first; ~1 day; agent)

What it holds:
- the runner and scorer above;
- control and candidate builds;
- a fixed input set: 12 situations × zh_TW/en/ja, every intensity, 6 styles
  (2 free, 4 Pro including 硬核回擊 and 台劇腔); 36 simulator turns (A4's set);
  12 drafts for rewrites.

Its first output is the **1.8.0 baseline on 27.2.1**, written to
`docs/evidence/<date>-pro-bench/`. Every later gate compares against it.

### Q1 — on-device sendable quality: Composed / Sharp / 狠 / Pro styles / 3 versions (A/D; every AI-device payer, every locale)

- **The fix, in order (stop at the first that passes):**
  1. **A non-answer screen.** Drop a variant that is too short for its script,
     is a bare question, or shares no concrete detail with the situation. If
     fewer than 2 variants survive, retry once with the reason stated in the
     prompt. Then show what survived, or labelled curated text.
  2. **A per-mode prompt rework** for Composed and Sharp, which A5 did not touch:
     - examples that answer the situation in full sentences;
     - "name one concrete thing from what happened";
     - ja: "the user is the one who was wronged" (who-is-at-fault errors).
  3. **Guided generation (`@Generable`, 3 fields) instead of parsing numbered
     text.** Only if 1 and 2 fail. It is iOS/macOS 26+ API behind the existing
     `FMBackend` protocol. UNVERIFIED whether it changes refusal behaviour under
     permissive guardrails, so it gets its own gate.
- **Gate:**
  - non-answers ≤ 5 % of variants (baseline from Q0);
  - grounded ≥ 90 %;
  - no regression in refusal → curated, Simplified, CJK in en or near-dups;
  - median latency ≤ control + 2 s;
  - blind pairs: candidate wins ≥ 2/3 per locale.
- **Effort:** 3–5 days. No Worker. No new strings unless a labelled notice changes;
  any new string comes in 4 locales with the parity test.

### Q2 — 痛罵 and styled 發洩 (cloud; every payer on every device)

- **Q2a, Pro gets 3 takes of 痛罵.** This makes the paywall's "3 versions" true
  for the one Pro generator that is real everywhere.
  - Q0 decides the design: one call returning 3 drafts, or 3 calls at T ≈ 0.95.
    Whichever wins the blind read and stays within the cost cap (≤ 3 ×
    $0.00013).
  - Worker:
    - `variantCount` honoured for `mode:"vent"` only when `lane=pro`. The free
      lane stays 1.
    - Backward compatible: old binaries send no count and get 1.
    - Every draft goes through `stripNameAddress` and `draftDefects`.
  - Client:
    - 3 cards, each with its own 改成能發的;
    - the preview (B5) stays one draft.
- **Q2b, a strong word when the intensity promises one.**
  - Measure Vent and Feral swear / strong-word rates per locale in Q0. Fix the
    prompt only where the rate is below the documented intent (zh/ja Vent: "1–2
    strong words", 2026-05-23 tune).
  - ja Feral gets a prompt pass with the agent's read plus the automatic checks.
    It is marked UNVERIFIED-by-native.
- **Not in Q2:** 硬核回擊's voice. A1 failed twice, and the cut rule holds.
- **Gate:**
  - 3 takes: distinct (bigram Jaccard < 0.5) in ≥ 90 % of calls; each passes the
    existing postprocess; 0 names; 0 Simplified in zh-Hant; a swear in each Feral
    take ≥ the single-draft rate; p90 latency ≤ 8 s.
  - Blind: a 3-take set preferred over 1 draft in ≥ 2/3.
  - Strong words: ≥ 80 % for zh/ja Vent, with no rise in names or length.
- **Worker deploys:** 1 production deploy for Q2, after the preview gate, before
  the binary. Rollback = `npx wrangler rollback <id>`.
- **Effort:** Worker 1 day; client 2 days.

### Q3 — a cloud lane for Pro on devices without Apple's model (C/E). **Jason decides Q3a vs Q3a+Q3b.**

On C/E, 4 of the 7 paywall lines are canned. These items are the only way to make
them real there, and they are the biggest gap left. The cost is privacy and copy
work, not just code.

- **Q3a, cloud 改成能發的 for Pro on C/E** (v1.8 B1-R, scope and gate unchanged,
  `DEV_PLAN_v1.8` :712-753):
  - Worker `mode:"rewrite"`, Pro lane only, `REWRITE_MODE_ENABLED`;
  - a server-side threat judge;
  - a new restrict-only client key `pro_cloud_rewrite_enabled` (default false,
    read only by 1.9.0);
  - a versioned consent, because the old copy promised the rewrite never leaves
    the device;
  - copy in 4 locales; a privacy-policy diff (Jason approves); App Privacy
    re-checked (Jason).
  - Effort: Worker 1 day, client 2–3 days.
- **Q3b, cloud Composed / Sharp / 狠, Pro styles and 3 versions for Pro on C/E**
  (v1.8 B1-S, scope and gate unchanged, :755-784):
  - main generator only;
  - new key `pro_sendable_cloud_enabled` plus `_locales`, default false;
  - `cloud_sendable_enabled` stays false forever, as CI enforces.
  - Effort: Worker 1 day, client 4–6 days. It shares Q3a's consent, token and
    403 work.
- **Prerequisite for both: production Pro tokens must mint.** A Pro user with no
  token must never be silently sent to the free lane.
  - First, the agent's half, read-only, with no user data:
    - `npx wrangler secret list` (names only) shows the signing key;
    - `POST /v1/auth` with a malformed receipt returns the designed 4xx, not
      "not configured".
  - If that is not conclusive, Jason's half:
    - a $0 offer-code redemption on his own Apple ID, one Feral, then cancel;
    - it carries the r320 mis-crediting caveat (DEV_PLAN_v1.9 §3).
- **Gate:** v1.8's B1-R and B1-S gates, ≤ 25 preview calls each. The client
  end-to-end check runs in a Release build against a **preview** Worker with
  `ALLOW_SANDBOX_RECEIPTS=true`, never production.
- **Worker deploys:** 1 production deploy, with `REWRITE_MODE_ENABLED` and the
  Pro roast lane **false** until 1.9.0 is live. Then one flag flip each, with a
  one-sentence rollback.

### Q4 — 吵架模擬器 reliability (A/D)

- Fix 硬核回擊's preamble pulling the opponent onto the user's side, and the en
  "raise" persona inversion. The work stays inside `opponentTurn` and
  `opponentPersona`.
- **Gate:** ≥ 29/36 opponent turns in **3 of 3** runs; 0 numbered lists;
  ≤ 1/18 refused per locale; ja set no worse than in A4.
- **Effort:** 1–2 days.

### Not recommended this time (each can be argued)

| item | why not |
|---|---|
| Roommate group to zh-Hant (v1.8 B2) | zh_TW transcripts had Simplified 8/8; 0 of 29 `echoes.*` strings exist in zh-Hant (consent included); reaches ~1 TW install every 3 weeks; 3–4 days. It is a new feature for TW, not a better existing one |
| 硬核回擊 voice (A1) | failed its gate twice; the cut rule |
| Lifetime Pro (B8) | pricing, not quality; `payer_read.py` would need work first (v1.9 §4) |
| New styles | more surface; the existing 16 are not yet good on-device |

## 4. Order and dates

| when | what | notes |
|---|---|---|
| 11-19 → 11-20 | Q0 bench + 1.8.0 baseline; the Q3 token check (agent half) | baseline committed |
| 11-20 → 11-27 | Q1 (on-device). In parallel, Q2 Worker on a preview | one build root per checkout building at once |
| 11-27 → 12-04 | Q2 client; Q3a (and Q3b if chosen); Q4 | Q2 Worker production deploy once its gate passes |
| 12-04 → 12-08 | preflight; Release UI checks (`PaywallFlowUITests`, `DeviceHonestyUITests` on iOS 18.5 and 27); bench rerun; StoreCopy/parity tests; privacy policy and App Privacy (Jason) | Debug builds are always Pro |
| **12-09** | **submit 1.9.0, iOS + macOS** | Apple's year-end slowdown dates are UNVERIFIED for 2026, so submit early |
| after live | flip Q3's keys (one sentence + rollback each); promo text refresh in 4 locales (Jason approves the words); D+2's keywords/subtitle ride this version (Jason approves the words) | read back every change |

If a Q item has not passed its gate by **12-07**, it leaves 1.9.0 and the rest
ships. The 01-31 read is unchanged.

## 5. Builds and release mechanics

- **Xcode.**
  - iOS: `Xcode.app` (27.2, 27B52), which ASC accepts for iOS since 11-08.
  - macOS: try 27B52 first. Export refusal is harmless, since nothing reaches ASC.
    If it is refused, use `DEVELOPER_DIR=/Applications/Xcode-27.1.app/...`.
  - A VALID 27B52 macOS build is also the evidence that lets Jason remove
    Xcode 27.1.
- **Scripts:**
  - `scripts/preflight.sh` on `RoastMate-UITests`;
  - `scripts/build-upload-asc.sh`;
  - `scripts/asc_bind_version.py`, iOS and `--platform MAC_OS`, with release
    notes in `build/v1.9.0-release-notes{,-mac}.md`;
  - reviewer notes from `metadata/review_notes_asc_short.txt`;
  - `scripts/asc_submit_review.py`.
- **Text on the new version:**
  - the new versions don't inherit the promotional text: re-set it with
    `asc_product_page.py`, dry run first;
  - `asc_product_page.py text --version 1.9.0` also writes D+2's queued
    keywords and subtitle. Jason approves those words first.
- **Machine rules:**
  - build roots under `~/Library/Caches/RoastMate-build/` or the scratchpad,
    never in `~/Documents`;
  - simulators by UDID with the `/tmp/lock-*` rule;
  - run the two codesign lock probes before any archive (global CLAUDE.md).

## 6. Jason's part

1. **Now:** pick the scope (Q3: none / Q3a / Q3a+Q3b) and confirm the override
   in §0.
2. If Q3: the privacy-policy diff and the App Privacy answers. The token check's
   second half only if the agent's half is inconclusive.
3. Optional: one native zh-Hant reader for about an hour. The agent prepares
   blind sheets and never messages anyone.
4. The exact words of the promo text and the ASO keywords/subtitle, before they
   go live.
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
    only in Release with `ENABLE_TESTABILITY=YES`, against a control.
  - Unpaired CJK strings have shipped three times. Every new string comes in 4
    locales, guarded by the parity test.
- **Money and the Worker.**
  - Evaluation spend ≤ $2.
  - At most 2 production Worker deploys, plus rollbacks and flag flips.
  - Never read one person's Worker logs.
- **Kill switch.** A threat, self-harm content or a slur reaching a user means
  `ondevice_permissive_enabled:false` (or the new key) the same day.
- **Public text and ASC.**
  - Public text (promo, keywords, subtitle, privacy policy) goes live only after
    Jason approves the exact words.
  - ASC changes: one sentence on what and how to roll back, first.
  - The ASC app id is 6769317103, never `$ASC_APP_ID`.
- **Git.** Commit and push at once. The scheduled tasks stay untouched.

## 8. Pre-mortem

1. **The on-device model is the ceiling.** Q1's prompt work plateaus, as A5's
   "still mediocre" did. Mitigation: the non-answer screen comes first, because it
   removes the worst output whatever the model does. Guided generation is
   gated. A failed gate means no Q1 change ships, not a third round.
2. **3 takes make 痛罵 worse,** because each take is thinner. Mitigation: the blind
   read decides between 1 call and 3. If neither wins, keep one draft.
3. **Q3 slips the date.** It is the largest item and needs Jason's approvals.
   Mitigation: Q3a alone is the default if time is short. Q3b is cut first.
4. **A cloud path leaks or misroutes.** Mitigation:
   - the token is required, with no tokenless fallback;
   - the keys are restrict-only and default false;
   - the server-side judge;
   - preview-only end-to-end checks.
5. **The bench flatters the candidate.** Mitigation: a fixed input set written
   before tuning starts. If tuning reads any of it, extra unseen situations are
   added before the final run.

## 9. Open questions

- What share of payers is on C/E? It is unknown: B6 was cut, and no analytics will
  be added. Q3's value rests on Taiwan's older-iPhone base and on the TW payer's
  experience. It is a judgment, not a measurement.
- Does guided generation behave differently under permissive guardrails?
  UNVERIFIED. Q1 step 3 measures it if it gets there.

## 10. Review synthesis — Gemini 3.8 Flash

(pending)
