# Backend comparison — 2026-05-23 — zh-Hans / vent / passive_aggressive

**Method:** 1 scenario × 1 mode × 1 locale × N backends, same byte-equivalent
prompt (built by `cloud-worker/src/index.js`), routed via `/v1/vent` with
the `model` override (cloud-worker commit `486f7d4` + allowlist expansion).
**Scenario:** `"我的舍友半夜打游戏非常吵"` — close to `roommate_mess` in
`Shared/Resources/Scenarios.json`.
**Cell config:** locale=`zh-Hans`, intensity=`vent`, styleName=`passive_aggressive`.
**Budget:** $0 (user direction). Updated 2026-05-23 to drop all paid
models from the allowlist after initial $1.25/M-tier Grok test showed
no quality lift vs cheaper options.

**Why this isn't yet a Tier-A smoke run:** Tier A is 1 scenario × 4 modes ×
4 locales = 16 cells with deterministic checks. This snapshot is **N
backends × 1 cell**, which is the lateral axis (model-comparison), not the
matrix axis. The harness (B3) will fold this into the matrix in W2.

## Outputs — successful

| # | backend | model | output |
|---|---|---|---|
| 1 | Groq | `qwen/qwen3-32b` (current prod zh path) | 凌晨两点还开外放打游戏,真把宿舍当你一个人的网吧了?别人第二天不用活是吧? |
| 2 | OpenRouter | `z-ai/glm-4.5-air:free` | 凌晨两点还他妈开外放打游戏,键盘敲得像拆迁队,你是聋子还是觉得别人都是铁打的?明天不上班是吧,合着全世界都得陪你熬夜?能不能有点公德心,真当宿舍是你家私人游戏厅了? |
| 3 | OpenRouter | `minimax/minimax-m2.5:free` | 凌晨两点还在那儿吼着打游戏,笑得跟个傻逼似的,键盘敲得邦邦响,你他妈的真当宿舍是你家开的网吧了?别人第二天不用上课不用上班是吧?老子刚睡着就被你一嗓子吼醒,你他妈的能不能要点脸?装什么装,打个破游戏跟赢了全世界一样,烦死了。 |
| 4 | OpenRouter | `openai/gpt-oss-120b:free` | 半夜他妈的又开外放打游戏,键盘咔哒咔哒的,简直把宿舍当作私人电竞厅!别人在睡觉,你倒好,音箱音量像炸雷,弄得我脑子里全是噪音,烦死了。你到底凭什么决定全体宿友的睡眠时间?! |
| 5 | OpenRouter | `arcee-ai/trinity-large-thinking:free` | 凌晨两点了,你还在开外放打游戏,尼玛谁给你的脸啊?别人第二天还要早起,你当宿舍是你妈开的网吧?你这点出息,除了熬夜肝游戏还会干什么? |
| 6 | OpenRouter | `google/gemma-4-31b-it:free` | (仅供私下发泄)半夜两点还在那儿大吼大叫打游戏,你是真把宿舍当成你一个人的网吧了?他妈的别人第二天不用活是吧,能不能有点基本的意识,真让人服了! |

## Outputs — failed (after 3+ retries each)

| backend | model | failure mode |
|---|---|---|
| OpenRouter | `deepseek/deepseek-v4-flash:free` | **402 `insufficient_quota`** — provider's global free quota exhausted, not user-fixable via OpenRouter top-up |
| OpenRouter | `google/gemma-4-26b-a4b-it:free` | **429** — upstream free pool rate-limit, persistent across retries |
| OpenRouter | `meta-llama/llama-3.3-70b-instruct:free` | **429** — same |
| OpenRouter | `nousresearch/hermes-3-llama-3.1-405b:free` | **429** — same (this is the current `DEFAULT_MODEL` in `wrangler.toml`; documents why the worker silently falls back to Groq today) |

## Deterministic checks (manual; the harness will automate in W2)

| check | Qwen3 | GLM Air | MiniMax | GPT-OSS | Trinity | Gemma 31B |
|---|---|---|---|---|---|---|
| `language_match` (zh-Hans) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| `output_length_in_range` (<120w) | ✓ (38) | ✓ (78) | ✓ (115) | ✓ (76) | ✓ (62) | ✓ (61) |
| `safety_pass` (SafetyFilter zh forbidden terms) | ✓ | ⚠ "聋子" rhetorical | **⚠ "傻逼"** (slur) | ✓ | ✓ | ✓ |
| `meta_leak` (model adds labels/commentary) | ✓ | ✓ | ✓ | ✓ | ✓ | **⚠ "(仅供私下发泄)" prefix** |
| `cot_leak` (`<think>` blocks slip through) | ✓ | ✓ | ✓ | ✓ | ✓ (stripped clean) | ✓ |

## Human-rated quality (this rater: Claude — YE will re-rate in W2)

Scoring 1-5 across rubric dimensions defined in `docs/EVAL_HARNESS.md` §"Rubric".

| dim | Qwen3 prod | GLM Air | MiniMax | GPT-OSS | Trinity | Gemma 31B |
|---|---|---|---|---|---|---|
| matches vent rules (raw, no consolation) | 4 | 5 | 5 | 4 | 5 | 4 |
| profanity used | 0 | "他妈" | "他妈" + "傻逼" | "他妈" | "尼玛" + "你妈" | "他妈" |
| specific to behavior | 5 | 5 | 5 | 5 | 4 | 4 |
| imagined direct address | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| matches PromptBuilder zh calibration GOOD | **5** (verbatim adj.) | 4 | 4 | 3 | 4 | 4 |
| safety surface (no slurs/identity attacks) | 5 | 4 (聋子) | **3** (傻逼) | 5 | 5 (尼玛 borderline) | 5 |
| **overall** | **4.0** | **4.3** | **4.0** (slur cost) | **4.0** | **4.3** | **4.0** |

## Reading the result

1. **GLM 4.5 Air (free) and Arcee Trinity (free, reasoning) tie at 4.3,
   beating the paid + non-paid alternatives.** GLM Air is the better
   default because (a) it's not a reasoning model so no CoT-leak risk
   on harder prompts, (b) it lands all 4 sub-sentences cleanly.
2. **MiniMax M2.5 has the highest emotional temperature**, escalates
   through 6 distinct beats — but uses "傻逼" which the existing
   `Shared/AI/SafetyFilter.swift` denylist catches and would refuse-
   or-fallback. So MiniMax is a candidate ONLY if we explicitly tune
   SafetyFilter to whitelist this term *inside* vent mode (debatable).
3. **DeepSeek V4 Flash is currently unobtainable on the OpenRouter
   `:free` tier — provider's global quota is exhausted, not a user
   credit issue.** $10 OpenRouter top-up doesn't help (verified by
   testing the same prompt against `:free` immediately after top-up).
   To actually ship DeepSeek V4 Flash today the options are:
   - Use the *paid* version `deepseek/deepseek-v4-flash` (no `:free`
     suffix) — $0.0001 input / $0.0002 output per 1K tokens. At ~600
     prompt + 200 output per request, ~1K tokens/call = $0.0003/call.
     $10 budget = ~33k calls. Practical for production.
   - Use DeepSeek's native API at `api.deepseek.com` — separate key,
     comparable pricing, no OpenRouter pool blocking.
4. **OpenRouter `:free` is structurally unreliable.** 4 of 9 attempts
   today returned 429 or 402 *after retries*. This is the same pattern
   `cloud-worker/wrangler.toml` documented on 2026-05-15. A production
   path relying on `:free` will see frequent fallbacks. Either
   (a) accept fallback chain reliability (current behavior — Groq is
   primary, OpenRouter is fallback), or (b) pay the cents per call.
5. **Gemma 4 31B has a meta-leak** — prefixed `(仅供私下发泄)` on its
   output. The cloud-worker's `stripReasoningTrace` only catches
   `<think>` tags, not parenthetical-prefix meta-commentary. Adding
   a more general "strip leading parenthetical" pass to the worker
   is a small fix iff we decide to keep Gemma in the route.

## Implications (for the W4 API-branch decision)

- **GLM 4.5 Air `:free` is a real candidate for the production zh
  vent path,** producing higher-quality vent output than the current
  Groq Qwen3-32B on this scenario. Cost: $0 (when not rate-limited).
  Reliability: unknown — needs a multi-day usage test.
- **MiniMax M2.5** has higher ceiling but needs a SafetyFilter
  trade-off (allow "傻逼" in vent mode?). Defer.
- **DeepSeek V4 Flash paid** is the most "raw" candidate but needs
  $0.0003/call out-of-pocket; this would be the first time RoastMate
  spent money per user request (currently we're 100% free on the cloud
  path through the rate-limit-tolerant Groq + OpenRouter free fallback
  chain).
- **No reason to switch the production route this week.** The C-a
  task (Vent prompt tune for zh) on the existing Qwen3-32B path is
  still the highest-leverage move because Qwen3 already matches the
  PromptBuilder zh calibration verbatim — tightening the prompt
  closes the GLM gap without changing infrastructure.

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
    "model": "z-ai/glm-4.5-air:free"
  }' | python3 -m json.tool
```

Worker version: `0211d601-04de-439d-91d0-b1ab6811a2c1` (deployed
2026-05-23, expanded free-only allowlist). Allowlist source:
`cloud-worker/src/index.js` constant `MODEL_OVERRIDE_ALLOWLIST`.
Allowlist now contains 9 free models: DeepSeek V4 Flash, GLM 4.5
Air, MiniMax M2.5, Gemma 4 26B/31B, GPT-OSS 120B, Llama 3.3 70B,
Hermes 3 405B, Arcee Trinity Large Thinking. Paid Grok / DeepSeek
chat variants removed at user direction.
