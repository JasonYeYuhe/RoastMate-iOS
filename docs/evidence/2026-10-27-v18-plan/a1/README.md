# A1 (硬核回擊 voice in 痛罵) — round 1, 2026-10-27: NOT DEPLOYED

Production stays on Worker **046f2134** (rollback target still 7846ac95). The
attempted lines are in `attempt1.patch` (final state of the 4 voice lines + test);
`cloud-worker/src` was restored to HEAD so the branch equals production.

## What ran
- Preview only: `npx wrangler dev --remote --port 8799`, stopped after the run.
- 20 Worker calls (the plan's cap): pilot 4 + 2, gate 9 + 5. All HTTP 200,
  1.6–6.3 s. Eval device ids `eval-a1-20261027-*`. Spend $0.0038.
- `cases.json` (7 situations, p7 unused), `run.json` (every request/response,
  tagged pilot1 / pilot2 / gate1 / final), `run_pairs.py`.
- No-diff check (`compare_ext.mjs`, new `EXPECT_CHANGED=savage_no_filter`):
  263,736 simulated requests, 4,752 prompts changed, all 硬核回擊 Vent/Feral;
  0 other diffs, 0 response/status diffs. `npm test` 164/164 with the patch.

## Iterations
1. "3–4 clipped charges … verdict of six words at most": shape obvious, but both
   verdicts were a bare swear word as its own sentence (「王八蛋。」, "Asshole.").
2. "3–6 word verdict, never one word" / zh 「三到八個字」: en fixed ("You're a
   selfish, thoughtless prick."); zh still one word (「爛人。」).
3. zh frame 「你就是個……」: every zh_TW draft ended 「你就是個爛人。」, and asking
   for 3–4 charges made the model invent charges (「你坐视不管」, 「自分のことばかり話す」).
4. Final: charges only from the situation (2–4, never added), label must fit the
   act. zh_TW still 3/3 「你就是個爛人」; p1 used 夸獎 (mainland form of 誇獎).

## Gate on the final pairs (`blind_sheet.json`, `blind_key.json`)
| check | result |
|---|---|
| blind pairs, Gemini 3.8 Flash (High) | **6/6** correct, 95–100 % confidence (gate ≥ 5/6: pass) |
| Feral swear present (score_gate2 lists) | savage 6/6, plain 6/6 (pass) |
| length ≤ 1.3× | all within (pass) |
| prompt diff outside savage | none (pass) |
| **quality (not in the plan's gate)** | **fail**: identical verdict 「你就是個爛人」 in 3/3 zh_TW; a Simplified form (夸獎) in zh_TW; fact escalation (住院→病重, 加班→熬通宵, 裝什麼風度); semicolons; 「我的父親」 for 我爸; ja verdict 「クソッ、そんな人間だ。」 unnatural |

The judge's own summary: the unstyled rants "sound significantly more
authentic". Gemini 4 Argon was not available (agy quota exhausted, resets in
~132 h from 2026-10-27 23:10 JST).

## Why not deployed
The formal gate passes, but the style would end every Taiwan draft with the same
sentence and adds accusations the user never made, in a draft they may send. That
is worse for the repeat payer A1 is for. Counted as **one failed round** under
plan §2.4 (a second failure cuts A1).

## Next round, if Jason approves the calls (≤ 12, ≈ $0.003)
- Verdict: name the offence-specific label without a fixed frame, e.g. "end on
  what kind of [role] they are" (landlord → 惡房東-type labels come from the role
  in the situation), and forbid repeating the charges' words; drop the
  「你就是個……」 frame.
- Facts: "copy the user's own facts; no adverbs of motive (偷偷, 假惺惺), no
  escalation of severity".
- Punctuation: commas only, no semicolons; 我爸 not 我的父親 (use the user's words).
- Keep the en line (worked 2/2).
- Gate adds: 0 repeated verdict across 3 zh_TW drafts; 0 Simplified (OpenCC);
  0 added facts by hand-read; a native reader if one is available.
