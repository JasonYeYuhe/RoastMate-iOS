# 2026-10-22 — why payers leave, and the fixes that followed

Copied out of the session scratchpad so the evidence and the regression
harness survive. Everything here was produced read-only against production
(App Store Connect reads, ≤ ~150 Worker calls in total, on-device probes on a
macOS 27.0.1 M1 Pro with Apple Intelligence).

## Read first

- `synthesis.md` — the diagnosis (four investigation lenses merged) followed by
  the adversarial challenge, including Gemini 3.8 Flash's disagreements.
  Headline facts: the TW payer cancelled on day 0 (v1.5.0); iOS/macOS 27
  refusals surfaced as errors from 1.6.0 (first SDK-27 build) on; zh-Hant cloud
  replies used mainland slang (27/29); "Make it sendable" was refused 6/6 under
  default guardrails; the paywall never reacted to a purchase.

## What shipped from it

| what | where | commit |
|---|---|---|
| Worker: Taiwan register, no quota templates, output cleanup, names never used to address the person, timeout budget | deployed 7846ac95 | 4ed652f |
| App 1.7.1 (25): LanguageModelError → curated, permissive-guardrail rewrite with refusal/threat screens, purchase feedback, device-honest paywall, Taiwan crisis lines first, Vent default without the on-device model | submitted 2026-10-22 | 0b76d33 |
| Worker: Pro styles shape Vent/Feral voice (free styles unchanged), surname + title treated as a name | deployed 046f2134 | 26add7d |
| Paywall plan rows use app-owned copy (ASC still says "Unlimited generations") | next binary | 7301437 |

## Gates (results/)

- `worker_gate.md` + `results/cloud_samples.json` (before) / `results/worker_after.json`
  (after): zh-Hant mainland markers 27/29 → 1/14, Taiwanese terms 13/14,
  0 Simplified, 0 markdown, top opener ≤ 30 %, en ≤ 3 sentences.
- `style_gate.md` (first round, NOT-READY) and `style_gate2.md` +
  `results/style_gate2.json` (final): 16/16 Pro styles, blind recognition 27/27 on
  close triples, Feral swear word 29/29, 35/36 within the 1.3× ceiling, 0 names.
- `results/perm_rewrite.txt` (default vs permissive guardrails) and
  `results/after_rewrite.txt` (new rewrite prompt): 0/6 → 46/60 usable (strict).
- `results/probe_zh_TW_run2.txt` / `results/after_sharp.txt`: the 凌晨兩點 example
  copied 6/6 → 0/12.

## Re-running before the next Worker or prompt change (harness/)

The scripts were written in a scratchpad; their absolute paths point there.
Adjust the paths at the top of each file before running.

- `harness/cloud/` — `sample_cloud.py` replays the saved situations against a
  Worker URL (use `npx wrangler dev --remote` from `cloud-worker/` to test an
  undeployed change; `scripts/openrouter-balance.sh` shows how the remote preview
  binds secrets without deploying). `analyze.py` scores mainland/Taiwan markers,
  Simplified characters, Latin runs, markdown, list dumps and length. About
  $0.004 per full run.
- `harness/worker-compare/compare_ext.mjs` — runs HEAD's and the working tree's
  handlers on stubbed upstreams across locales × intensities × styles and
  reports any prompt/response difference. Use it to prove a change touches only
  what it should. `detect.mjs` / `score_gate2.py` score style drafts.
- `harness/on-device/` — Swift probes that compile production `PromptBuilder.swift`
  against Apple's on-device model (`fmprobe/` for Sharp/Savage, `fmperm/` for the
  rewrite under permissive guardrails, `errtype.swift` prints which error type an
  on-device refusal arrives as — the SDK-27 `LanguageModelError` finding). They
  need a Mac with Apple Intelligence on; a simulator cannot run them.

## Still open (see the handoff)

- Native Taiwanese / Japanese reader for the new cloud output.
- A real iOS 27 iPhone check of 1.7.1 (only macOS 27 was probed).
- ASC subscription descriptions ("Unlimited generations") — web UI or next binary
  (the app-owned copy is already in the tree).
