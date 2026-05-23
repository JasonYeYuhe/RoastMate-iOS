# C-b — zh-Hant tone audit (focused checklist)

**Status:** W2 deliverable per `docs/PHASE_2_PLAN_2026-06.md` §3.3 — Codex
framing: *"focused review checklist + 6-10 representative fixture
outputs, NOT a broad localization project."*

## Goal

Catch tone drift specific to **繁體中文** (Traditional, Taiwan-flavor)
output across the three roast modes that show up most often:

- **Vent** (the safe pre-send buffer)
- **Feral** (deliberately sharp, intensity = `sharp`)
- **Sharp** (single-line comeback, default style intensity)

NOT in scope: rewriting prompts, adding new style presets, broad
localization revision, switching to HK-Cantonese, or hand-translating
the Scenarios.json zh-Hant column. If the audit reveals a systemic
prompt issue, that becomes a follow-up C-b+ item.

## Checklist — known failure modes to look for

For each fixture output, mark each row pass/flag/fail.

| # | failure mode | what triggers a flag |
|---|---|---|
| 1 | **simplified→traditional character bleed** | Any 简化字 in output (e.g. `话` instead of `話`, `应` instead of `應`). Apple FM occasionally leaks zh-Hans chars when prompt is zh-Hant. |
| 2 | **mainland slang in TW context** | `老铁`, `给力`, `卷`, `内卷`, `躺平` — these are PRC-coded; TW reads them as foreign-flavored. Prefer TW-native equivalents (`兄弟`, `屌`, `拚`, `競爭過頭`, `擺爛`). |
| 3 | **register over-formal** | TW spoken Chinese leans casual; outputs that read like 大陸書面語 (e.g. `予以回應`, `就此而論`) miss the conversational tone the app needs. |
| 4 | **register over-cute** | The opposite drift: anime-flavored or 注音文-flavored sentence-final particles (`啦啦啦`, `捏`, `齁`) when the scenario is workplace/serious. |
| 5 | **English idiom literal-translation** | `打開心扉` for "open up", `回到正軌` for "back on track" — workable but smells of MT. Prefer scenario-native phrasing. |
| 6 | **punctuation: 全形 vs 半形** | TW convention = 全形 `,。、;:?!`. Output mixing half-width into a TW string is a mild flag (the renderer copes, but reads off). |
| 7 | **honorifics / `您`** | `您` is much more common in PRC; in TW writing `你` is the default even with strangers, with `您` reserved for explicit deference. Over-use of `您` flags the wrong register. |
| 8 | **intensity slippage on `sharp`** | Sharp should bite; if the zh-Hant output softens to "我有些不太認同" while en/zh-Hans/ja kept the edge, the prompt is hedging in zh-Hant specifically. |
| 9 | **refusal copy in wrong locale** | Crisis/safety refusal must render in zh-Hant native phrasing, not bare English fallback or zh-Hans wording. |
| 10 | **PII auto-redaction** | Names, phones, emails in zh-Hant context should redact cleanly (the existing redactor is locale-agnostic; verify it doesn't trip on TW phone format like `0912-xxx-xxx`). |

## Fixture outputs (to fill in W2)

Pick 6-10 scenarios from `Shared/Resources/Scenarios.json` covering at
least `boss`, `ex`, `family`, `groupchat`, `roommate`. For each:

1. Run `RoastEngine` at locale `zh-Hant`, intensity `sharp`, style
   `passive_aggressive` (or whichever the scenario defaults to).
2. Capture the output verbatim (no edits).
3. Score each output against the 10 checklist rows above.
4. Fill the table below.

| scenario id | style | output (verbatim) | flags hit | overall rating (1-5) |
|---|---|---|---|---|
| boss_credit | passive_aggressive | _to fill_ | _e.g. 1,7_ | _e.g. 3_ |
| boss_lastmin | high_eq | _to fill_ | | |
| ex_backafter | literary_lu_xun | _to fill_ | | |
| ex_blame | high_eq | _to fill_ | | |
| family_$id | _to fill_ | _to fill_ | | |
| groupchat_$id | _to fill_ | _to fill_ | | |
| roommate_$id | _to fill_ | _to fill_ | | |

**Pass bar:** ≥6/10 fixtures land at rating ≥3 with no critical flag
(rows 1, 8, 9 are critical — character bleed, intensity slippage,
wrong-locale refusal). Critical flag = open a `Shared/AI/PromptBuilder.swift`
fix; non-critical flag = note but don't churn the prompt.

## Out of scope (defer to a future C-b+)

- Hong Kong / Cantonese register (different market, different release).
- Per-style audit beyond Vent / Feral / Sharp.
- Rewriting the scenarios themselves to better match TW context (that's
  the Scenarios.json layer, not the prompt layer).
- κ inter-rater agreement (this is a 1-rater audit by YE).
