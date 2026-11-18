# Review — Gemini 3.8 Flash (High), 2026-11-18, of DEV_PLAN_PRO_QUALITY draft 1

Asked via `mcp__gemini__ask_gemini` (agy, model `gemini-3.8-flash-high`), workspace =
repo, read-only instruction. Draft 1 is commit `99c68d7`. Its claims were checked
before use: see the plan's §10. Condensed faithfully below; file links shortened
to repo paths.

## 1. Verdict

"Not worth doing as written." 12–19 days plus consent and legal work collide with
Apple's year-end slowdown, for 0 paying subscribers and ~1.5 downloads a week.

- **Keep:** Q0 (the bench); Q1 steps 1–2 (they remove non-answers like
  "Sleepwalking?" with no backend, privacy or review exposure); Q4 (1–2 days,
  local, fixes persona inversion).
- **Cut:** Q1 step 3 (`@Generable`), as incompatible with permissive guardrails.
- **Revise Q2:** keep Q2b (strong words, about 1 day). Rescope or drop Q2a
  (3 takes): client and Worker enforce one draft.
- **Q3b cut, Q3a deferred:** both need versioned consent, a privacy-policy
  rewrite and unverified token minting.

Ranking by value per day: Q4 > Q1 (steps 1–2) > Q2b > Q2a > Q3a ≫ Q3b.

## 2. Claims it called false or unsupported

1. §1 table: 發洩 is free (paywall `zh-Hant.lproj:163` doesn't list it); the
   roommate group is hidden outside zh-Hans and on no zh-Hant/en paywall.
2. Vent is one draft: `index.js:707-713` (`vc = 1` unless `mode === "roast"`);
   a single `{ text }` reply (:505-510); `RoastEngine.swift:218-219`
   (`effectiveVariantCount = intensity.isPrivateDraft ? 1 : variantCount`).
3. Token: `CloudVentClient.swift:63-78` falls back to `authToken: nil` when there
   is no token or a refresh 401s; `lane.js:46-54` gives `lane: "free"` without
   Authorization; `index.js:180-182` doesn't check the lane for `mode:"roast"`.
4. "ASC accepts Xcode 27.2 for iOS since 11-08" has no record in the repo; the
   handoff (:618-621) says keep 27.1 until ASC accepts 27B52.
5. `@Generable`: `FMBackend.swift:53-80` has only String APIs, and Apple's doc
   (quoted in `evals/runs/2026-08-30-apple-fm-pcc-guardrail-veto.md:109`) says
   permissive content transformations "only works for generating a string
   value". Savage/Pro need the permissive path on 27.2+.
6. Control from `v1.8.0-ios29`: `Shared/` at HEAD is identical except one comment
   in `StoreService.swift`. The harness file isn't in the tag, so a separate
   worktree is unnecessary, or needs the harness ported.

## 3. Gates

- Agent-read blind pairs are self-grading and gameable. Gate on automated
  metrics instead.
- Non-answer: < 10 CJK characters or < 5 Latin words; or ends in ?/？ with no
  declarative clause; or no verb (NLTagger). Target 0/36.
- Grounded: shares a non-stopword noun or a character 4-gram with the situation.
  Target ≥ 90 %.
- Distinct takes: character-bigram Jaccard < 0.35 (zh/ja), word-bigram < 0.40
  (en), for every pair in 100 % of calls.
- Negative security test: no Authorization on `mode:"roast"` / `"rewrite"` →
  401/403, automated in `test/lane.test.js`.

## 4. Risks it said the plan misses

- 5.1.2(i): `settings.about_ai.body` promises sendable modes and rewrites stay
  on-device; Q3 breaks that promise and needs versioned consent.
- 2.1(b): 1.8.0 build 28 was rejected on 11-02; touching purchase paths invites
  another rejection.
- The privacy policy must name third-party processing for any Q3 path.
- Safety: Q1 prompt changes could raise veiled threats or false positives; the
  judge blocks 8/40 legit and misses 8/40 threats.
- Budget: repeated 3-take runs "will exhaust the $2 limit rapidly".
- 01-31: the read is already headed for traffic-limited KILL; 1.9.0 changes no
  distribution metric.
- Schedule: 12-09 leaves no room for one rejection before the year-end shutdown
  (typically Dec 20–27).

## 5. Better ideas

1. **Threat-judge false positives on rewrites:** about 1 in 5 legit rewrites end
   in the labelled example (`docs/evidence/2026-11-08-next-phase/a1-rewrite-recheck/README.md`).
   Calibrate `threatJudgeInstructions` (`RoastEngine.swift:853-875`), $0, local.
2. **Style de-homogenization in `PromptBuilder.swift`:** lens 1 found "I'd have
   said:" 9/12 and a repeated 職場冷暴力 frame.
