# 1.9.0 Pro-quality bench (Q0), built 2026-11-18

Plan: `docs/DEV_PLAN_PRO_QUALITY_2026-11.md` §2 and §3 Q0. Every 1.9.0 gate compares
a candidate against the **1.8.0 control on the same Mac with the same inputs and the
same formulas**. This folder is that bench.

Machine: MacBook Pro M1 Pro, macOS 27.2.1 (26B131), Apple Intelligence on. On-device
calls cost $0. Cloud calls go to a **preview** Worker only (`npx wrangler dev --remote
--port 8799` in `cloud-worker/`); the preview's code is production `046f2134` plus one
style-name alias (`文青日記體`, 8fd5878), which the bench never sends.

## Files

| file | what |
|---|---|
| `inputs.json` | the fixed input set, written 11-18 before any tuning; never edited after the baseline |
| `sealed/` | held-out sets **Gemini 3.8 Flash wrote straight to files** (11-18); nobody reads them before the final run. sha256 prefixes: `inputs_unseen.json` 19fe8fd030649c5d, `sim_unseen.json` 4197bde7a192cf77, `blind_set_fresh.json` 533afbcf7a78cb44 |
| `bench_main.swift` | the harness: compiled with a `Shared/` tree, calls the production `RoastEngine` |
| `build.sh` | `Shared/` + harness → a minimal `.app` (bundle resources as in the app), outside `~/Documents` |
| `run_all.sh` | runs the on-device modes with one build into `runs/<tag>_<mode>.jsonl` |
| `cloud.py` | Q2's Vent/Feral calls against the preview Worker |
| `score.py`, `test_score.py` | the written formulas (below) and their unit tests (`python3 -m unittest test_score`) |
| `runs/` | raw outputs. `control180_*` = 1.8.0 (`v1.8.0-ios29`'s `Shared/`) |
| `spend.md` | evaluation spend ledger (cap $2) |

## How to run

```bash
S=<scratchpad>; B=~/Documents/RoastMate/docs/evidence/2026-11-18-pro-bench
mkdir -p $S/control && git -C ~/Documents/RoastMate archive v1.8.0-ios29 Shared | tar -x -C $S/control
$B/build.sh $S/control/Shared $S/control.app            # control
$B/build.sh ~/Documents/RoastMate/Shared $S/cand.app     # candidate (branch HEAD)
$B/run_all.sh $S/control.app control180 [sendable sim rewrite judge_blind judge_real safety]
$B/run_all.sh $S/cand.app   candNN       …               # + unseen sim_unseen judge_fresh at the end
python3 $B/score.py sendable $B/runs/control180_sendable.jsonl --by intensity
python3 $B/cloud.py $B/runs/<tag>_cloud.jsonl            # preview Worker on :8799
```

## The input set

- **Sendable (Q1):** 12 situations × zh_TW / en_US / ja_JP (written natively, not
  translated; two per locale carry a name) × Calm / Sharp / Savage × 6 styles
  (free: 高 EQ, 陰陽怪氣; Pro: 硬核回擊, 台劇腔, 冷處理, 職場冷暴力) = **648 calls**, 3
  versions each, through `RoastEngine.generateDetailed` (A3's retry and screens
  included). The full cross, as the plan lists it; ~75 min per run.
- **Simulator (Q4):** A4's set verbatim: zh_TW + en (lens 1's 36 turns) and ja (A4's
  18), 3 setups × 2 styles (冷處理, 硬核回擊) × 3 turns, persona call included.
- **Rewrites (Q5):** 12 vent drafts through `rewriteAsSendableDetailed` (高 EQ). r01/r02
  are the 11-08 recheck's two cases, 5 runs each (the owner gate); the rest 2 runs.
  `wrong_owner` phrases were written with the drafts, before any output was seen.
- **Judge (Q5):** the blind set (80, Gemini 10-29) and the 297 real outputs, through
  `RewriteThreatScreen` then the shipped judge prompt under permissive guardrails.
- **Safety e2e (§2):** `harness/safety_set.json`'s 30 situations (savage_no_filter at
  the listed intensity, crisis check first as the app does) and its simulator cases,
  2 runs, through the production engine.
- **Cloud (Q2):** 6 situations × 3 locales × Vent and Feral, styles rotating through
  2 free and 4 Pro (36 calls; the plan's "~18" was per intensity).

## The formulas (`score.py`), as the plan wrote them, with the choices it left open

- **Non-answer** (a shown model variant):
  - fewer than 8 Han/kana characters (zh/ja) or fewer than 5 words (en);
  - or a bare question: it ends in ?/？ and no clause before it ends in anything but a
    question mark (a full stop, a comma, a colon… makes a declarative clause);
  - or **en only**: NLTagger finds no verb. *NLTagger has no lexical classes for zh or
    ja on this Mac (every token comes back `OtherWord`, measured 11-18), so the verb
    rule cannot apply to them.*
  - **One-word** (Q1's "0 one-word variants"): en ≤ 1 word, zh/ja ≤ 3 Han/kana.
- **Grounded:** en: shares a noun or verb lemma (NLTagger, emitted by the harness) with
  the situation, minus a light-verb stop list (be, have, do, get, make…). zh/ja: shares
  a character bigram (never across punctuation) outside a stop list; for ja a bigram
  counts only with a kanji or as two katakana. Latin words the user typed (LINE, IG)
  count as content too.
- **Script:** Simplified-only characters in zh_TW (the Worker's `postprocess.js` list,
  read from that file); any Han/kana/Hangul in en; stray Latin in zh/ja (the Worker's
  `strayLatin`: 3+ letters, not allow-listed, not typed by the user).
- **Near-duplicate call:** any pair of shown versions with character-bigram Jaccard ≥
  0.35 (zh/ja) or word-bigram Jaccard ≥ 0.40 (en).
- **Curated rate** = calls whose provenance is curated; latency median and p90 per call.
- **Vent/Feral:** swear (the 10-22 gate's per-script lists) and strong word (swear + the
  Worker's own Vent vocabulary + the mild lists; `STRONG_EXTRA`); a situation name in
  the draft; over the length ceiling (zh-Hant/ja 155 chars, zh-Hans 195, en 65 words);
  Simplified; stray Latin.
- **Simulator:** generated / not generated, numbered lists, and an automatic persona
  role check (the persona names the other party's role and is not "You are the
  employee/user"). **The opponent-voice count (OPP) is a read:** no formula in the plan
  covers it and A4 set the 29/36 bar by reading. To keep it from flattering the
  candidate, control and candidate turns are shuffled into one sheet, labelled without
  knowing which build wrote them, and the key is kept apart (`labels/`). Both the read
  and the automatic checks must pass.
- **Rewrite:** curated rate; owner errors = a `wrong_owner` phrase in a model-written
  rewrite. The gate is r01/r02 only (plan: "0/10 on the 11-08 situations").
- **Judge:** threats caught (veiled), legit blocked.
- **Safety:** per category outcome counts, plus automatic flags (threat hints,
  ForbiddenTerms, PII) and every shown text from the bait categories, for a hand read.
  A flag counts only after it is read.

## 1.8.0 baseline (control180, 2026-11-18, macOS 27.2.1)

(filled in below as each part finishes)

## Q2b — one strong word in zh-Hant / ja Vent (cloud), 11-18: **PASSED on attempt 2**

Baseline (`control180_cloud.jsonl`): Vent drafts with a strong word zh_TW 1/6, ja 0/6, en
1/6; Feral swear zh_TW 6/6, ja 6/6, en 4/6. The 10-22 rewrite had made strong words
optional in zh-Hant Vent ("挑一個,或一個都不用") and ja Vent named none, against the
05-23 intent the plan cites ("1–2 strong words"). en and zh-Hans were left alone (no
documented intent for en; zh-Hans is not in the bench).

Change (`cloud-worker/src/vent_prompt.js`, `calibration.js`):
- zh-Hant and ja Vent ask for **one** word that shows real anger, inside or at the end of
  a sentence, never as the opener, never a second one, never a list; the styled voices
  (冷處理, 職場冷暴力, 台劇腔) are told it still applies;
- the example words rotate with the situation (`rotatePick`, at most 4 shown): with a
  fixed order the first word, 很扯, turned up in 7/12 drafts (10-22: 靠北 9/14);
- the same instruction, with the same rotated words, is restated last in the user
  prompt, where this model weighs the prompt most;
- only the 52 zh-Hant/ja Vent prompts of the 312 pinned ones changed
  (`test/fixtures/head_prompts.json` re-pinned and checked case by case); Feral, roast,
  roommate, en and zh-Hans prompts are byte-identical. Worker tests 165/165.

| run (preview Worker) | zh_TW strong | ja strong | names | over length | Simplified |
|---|---|---|---|---|---|
| dev 1 (system line only) | 10/12 | 5/12 | 4/24 | 0 | 0 |
| dev 2 (+ rotation, + user line) | 12/12 | 11/12 | 4/24 | 0 | 0 |
| gate 1, fixed / **unseen 1** | 6/6 / 5/6 | 6/6 / **3/6 ✗** | 5/24 (control 6/24) | 0 | 0 |
| gate 2, fixed / unseen 2 | 6/6 / 8/8 | 6/6 / 8/8 | 2/28 (control: the same 2 fixed ja items; 0/16 unseen) | 0 | 0 |
| control (same preview, committed prompt), unseen 2 | 3/8 | 0/8 | 0/16 | 0 | 0 |

- Gate 1 failed on unseen ja: the misses were in the formal styles and used strong
  phrases outside the fixed lexicon (何様のつもり, 許されません), which was not widened
  after the fact. Attempt 2 named the rotated example words in the user line and asks
  for one of them; it was scored on a second sealed set (`sealed/cloud_unseen2.json`),
  because set 1's outputs had been read.
- Template check: the most frequent word is in 5/16 drafts (ふざけんな) and 4/12
  (ありえねえ); no shape repeats like 10-22's 「…喔？」.
- Veto read (agent, zh read non-natively): nothing worse than control. One forced word
  in dev 2 (「把人當機車使」) did not recur. ja names remain a pre-existing defect at
  the control's rate.
- Not deployed. It goes to production once, with Q2a (plan §3 Q2).
