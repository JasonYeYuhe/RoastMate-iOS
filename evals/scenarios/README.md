# `evals/scenarios/` — B2 fixture inputs

**Status:** W1 skeleton — full population happens in W2 per
`docs/PHASE_2_PLAN_2026-06.md` §3.2 + `docs/EVAL_HARNESS.md` § "Tier B".

## What lives here

- **`base.json`** — the 5–8 scenarios from `Shared/Resources/Scenarios.json`
  picked for the Tier B baseline matrix. Format identical to the source
  Scenarios.json (so the harness can re-use the existing decoder).
- **`additions-en.json`** — 5 en-flavored scenarios that surface
  English-specific failure modes (workplace jargon, American-coded
  political/cultural framing, idiom-density).
- **`additions-ja.json`** — 5 ja-flavored scenarios that surface
  Japanese-specific failure modes (keigo register, indirect refusal,
  group-context formality).

Each entry MUST carry all 4 locales (`en`, `zh-Hans`, `zh-Hant`, `ja`).
The "additions" are extra scenarios, not locale-only.

## Schema

```json
{
  "version": 1,
  "scenarios": [
    {
      "id": "boss_credit",
      "category": "boss",
      "defaultStyleId": "passive_aggressive",
      "defaultIntensity": "sharp",
      "prompt": {
        "en":      "...",
        "zh-Hans": "...",
        "zh-Hant": "...",
        "ja":      "..."
      }
    }
  ]
}
```

## Selection rules (base.json)

Pick scenarios that:
1. Cover ≥3 distinct categories.
2. Span ≥3 distinct `defaultIntensity` levels (calm/sharp/feral if available).
3. Span ≥3 distinct `defaultStyleId` values.
4. Avoid the longest-prompt outliers — Tier B targets ≤10 min wall-clock,
   and the longest prompts inflate latency disproportionately.

Suggested initial picks from the 10 in `Shared/Resources/Scenarios.json`:

| id | category | reason |
|---|---|---|
| `boss_credit` | boss | passive-aggressive style, common workplace trigger |
| `boss_lastmin` | boss | high-eq style, captures hedge/over-hedge axis |
| `ex_backafter` | ex | literary_lu_xun style, tests stylistic range |
| `ex_blame` | ex | high-eq under sharp intensity, key tone test |
| `family_$id` | family | TBD W2 — pick one with strong PII-redaction surface |
| `groupchat_$id` | groupchat | TBD W2 — pick one with multi-party context |

## Failure modes the additions should provoke

**`additions-en.json`:**
- workplace euphemism that needs sharp deconstruction
- politically-charged take that requires non-partisan refusal
- gendered language that should mirror the speaker's framing
- regional idiom that doesn't translate (test cross-locale outputs)
- short ambiguous trigger (test that the model doesn't auto-elaborate)

**`additions-ja.json`:**
- 敬語 register where 上司 must be addressed
- indirect 不満 framing (Japanese conflict avoidance pattern)
- 飲み会 / group-chat 既読 context
- 家族 obligation framing (different valence than en `family`)
- short ambiguous trigger (parallel to en counterpart for cross-test)

## Out of scope (B2)

- App-Store review crowdsourced scenarios.
- HK/Cantonese, KR, other-locale additions.
- Hand-rating fixture outputs (that's the human-rating column the
  HARNESS captures, not part of B2).
