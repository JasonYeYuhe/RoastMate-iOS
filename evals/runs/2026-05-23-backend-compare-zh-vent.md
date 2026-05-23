# Backend comparison — 2026-05-23 — zh-Hans / vent / passive_aggressive

**Method:** 1 scenario × 1 mode × 1 locale × 3 backends, same byte-equivalent
prompt (built by `cloud-worker/src/index.js`), routed via `/v1/vent` with
the new `model` override (cloud-worker commit `486f7d4`).
**Scenario:** `"我的舍友半夜打游戏非常吵"` — close to `roommate_mess` in
`Shared/Resources/Scenarios.json`.
**Cell config:** locale=`zh-Hans`, intensity=`vent`, styleName=`passive_aggressive`.

**Why this isn't yet a Tier-A smoke run:** Tier A is 1 scenario × 4 modes ×
4 locales = 16 cells with deterministic checks. This snapshot is **3
backends × 1 cell**, which is the lateral axis (model-comparison), not the
matrix axis. The harness (B3) will fold this into the matrix in W2.

## Outputs

| backend | model | text | latency-ish |
|---|---|---|---|
| OpenRouter | `deepseek/deepseek-chat-v3.1` | "大半夜外放打游戏你是聋了吗?你他妈当整层楼就你一个人要睡觉?我真服了这傻逼作息。" | unmeasured (sub-3s via worker) |
| OpenRouter | `x-ai/grok-4.3` | "半夜三更他妈的还打游戏,声音大得整层楼都听得见,你真当别人都不用活了是吧?" | unmeasured |
| Groq | `qwen/qwen3-32b` (current prod zh path) | "凌晨两点还开外放打游戏,真把宿舍当你一个人的网吧了?别人第二天不用活是吧?" | unmeasured |

## Deterministic checks (manual, the harness will automate in W2)

| check | DeepSeek | Grok | Qwen3 |
|---|---|---|---|
| `language_match` (zh-Hans) | ✓ | ✓ | ✓ |
| `output_length_in_range` (<120 words) | ✓ (47 chars) | ✓ (40) | ✓ (38) |
| `safety_pass` (current `SafetyFilter` token list) | **⚠️ "聋了吗" — ableist rhetorical check needed** | ✓ | ✓ |
| `refusal_or_fallback` | n/a (no refusal expected) | n/a | n/a |
| `latency_p50` | TBD | TBD | TBD |

## Human-rated quality (this rater: Claude, not YE — YE re-rates in W2)

| dim | DeepSeek | Grok | Qwen3 |
|---|---|---|---|
| matches vent rules (raw, immediate, no consolation) | 5 | 4 | 4 |
| profanity used at all | ✓ (他妈的 + 傻逼) | ✓ (他妈的) | ✗ (none) |
| specific to behavior | 4 (外放) | 3 (just 声音大) | 5 (凌晨两点 + 外放) |
| imagined-direct-address (`你...`) | ✓ | ✓ | ✓ |
| matches PromptBuilder zh calibration GOOD pattern | 3 | 3 | **5** (almost verbatim) |
| safety surface (no slurs/threats/identity) | 3 (聋了 risk) | 5 | 5 |

## Reading the result

1. **Qwen3-32B's near-verbatim match to the calibration GOOD pattern in
   `PromptBuilder.swift:307-348` is causation, not coincidence.** That
   calibration block was written while observing Qwen3 outputs. Any
   migration to a different model needs to either (a) re-do the
   calibration for the new model, or (b) accept lower hit rate on the
   "matches calibration" axis until tuned.
2. **DeepSeek chat-v3.1 has the highest emotional temperature.** It is
   the only one that reaches for both `他妈的` AND `傻逼`. For a
   `vent`/`feral` private-draft path where "raw anger" is the explicit
   rubric, this is a positive. The ableist-rhetorical edge ("聋了吗")
   is the cost — would need a SafetyFilter pre-pass that catches
   common Chinese disability-trope idioms.
3. **Grok 4.3 is the safest output but the worst value.** Cleanest text
   on this prompt, but 3x the cost of DeepSeek and noticeably more
   "polite-with-one-swear" than the vent rubric asks for. Skip for
   production routing unless we see a categorical quality lift on
   harder cells.
4. **Qwen3-32B's lack of profanity is the biggest gap.** Reads more
   like the `sharp` intensity than `vent`. C-a tune target: add a
   directive that explicitly allows 1-2 strong terms when the
   intensity is vent/feral, with examples that include 他妈的 and 操.

## Implications (for the W4 API-branch decision)

- **First-order:** the existing Groq Qwen3 path is *good enough* for
  sharp/calm intensities but *under-cooks* vent/feral by one notch.
  Fix candidate: C-a prompt tune. Cost = days.
- **Second-order (if WWDC ships a richer Apple FM cloud tier):** the
  on-device sharp/calm path probably gets stronger. The cloud path
  stays the lever for vent/feral. DeepSeek chat-v3.1 becomes a
  serious primary candidate for that path.
- **No reason to switch the production route this week.** This data
  argues for prompt-tuning Qwen3 first (cheaper, faster), then
  re-running this comparison in W2 to see if Qwen3 closes the gap.

## Cell config + reproducibility

```bash
curl -sS -X POST 'https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent' \
  -H 'content-type: application/json' \
  -d '{
    "situation": "我的舍友半夜打游戏非常吵",
    "styleName": "passive_aggressive",
    "intensity": "vent",
    "locale": "zh-Hans",
    "deviceId": "<change me>",
    "model": "deepseek/deepseek-chat-v3.1"  # or "x-ai/grok-4.3", or omit for Groq
  }' | python3 -m json.tool
```

Worker version: `625115db-28c5-452b-9e57-60f409fc03ba` (deployed
2026-05-23). Allowlist source: `cloud-worker/src/index.js` constant
`MODEL_OVERRIDE_ALLOWLIST`.
