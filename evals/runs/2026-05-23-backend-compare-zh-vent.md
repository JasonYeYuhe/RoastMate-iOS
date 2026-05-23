# Backend comparison — 2026-05-23 — zh-Hans / vent / passive_aggressive

**Method:** 1 scenario × 1 mode × 1 locale × N backends, same byte-equivalent
prompt (built by `cloud-worker/src/index.js`), routed via `/v1/vent` with
the `model` override.
**Scenario:** `"我的舍友半夜打游戏非常吵"` — close to `roommate_mess` in
`Shared/Resources/Scenarios.json`.
**Cell config:** locale=`zh-Hans`, intensity=`vent`, styleName=`passive_aggressive`.
**Budget:** $0. All paid models removed from allowlist mid-session.
**Scoring stance:** **Slurs/profanity ALLOWED in vent mode** per user
direction 2026-05-23 ("有slur其实没关系 感觉毕竟是要发泄的"). The
universal-safety rules (no identity attacks, no threats of violence,
no doxxing, no sexual content) still bind.
**Sweep:** all 24 `:free` models on OpenRouter, plus the production
Groq Qwen3-32B baseline. 16 returned at least once; 8 persistently
rate-limited or quota-blocked.

## Final ranking (re-scored with slurs-allowed stance)

### Top tier (4.5+ / 5)

| # | model | output | why it wins |
|---|---|---|---|
| **1** | **`minimax/minimax-m2.5:free`** | 凌晨两点还在那儿吼着打游戏,**笑得跟个傻逼似的**,键盘敲得邦邦响,**你他妈的真当宿舍是你家开的网吧了**?别人第二天不用上课不用上班是吧?**老子**刚睡着就被你一嗓子吼醒,你他妈的能不能要点脸?装什么装,打个破游戏跟赢了全世界一样,烦死了。 | 6+ beats; calibration-match opening; uses 他妈/傻逼/老子/装什么装 — every vent rule satisfied at once |
| **2** | **`poolside/laguna-m.1:free`** *(code model!)* | **你特么**凌晨两点还开外放打游戏,**是不是有病啊**?吵**他妈的**不想要活了是吧?别人明天要上班你他妈的睡得着吗就他妈的不管不问? | Code-tuned model, but produces the most aggressive zh vent we saw. Short + relentless. |

### Second tier (4.0–4.3 / 5)

| # | model | output | notes |
|---|---|---|---|
| 3 | `z-ai/glm-4.5-air:free` | 凌晨两点还他妈开外放打游戏,**键盘敲得像拆迁队**,你是聋子还是觉得别人都是铁打的?明天不上班是吧,合着全世界都得陪你熬夜?能不能有点公德心,真当宿舍是你家私人游戏厅了? | Creative metaphor ("拆迁队"); "聋子" rhetorical (mild ableist trope but vent-acceptable) |
| 4 | `arcee-ai/trinity-large-thinking:free` | 凌晨两点了,你还在开外放打游戏,**尼玛**谁给你的脸啊?别人第二天还要早起,**你当宿舍是你妈开的网吧**?你这点出息,除了熬夜肝游戏还会干什么? | Reasoning model that didn't leak CoT (stripReasoningTrace held); character-judgment closer |
| 5 | `nvidia/nemotron-3-super-120b-a12b:free` | 半夜三点还开外放打游戏,**他妈的把宿舍当你个人网咖了**?吵得我连觉都睡不踏实,以后还有没人要活了? | 120B model; tight 2-beat vent; some latency cost (~60s first response) |
| 6 | `nvidia/nemotron-3-nano-omni-30b-a3b-reasoning:free` | 半夜你天天吵得像疯子,**屏幕光闪得像狗屁的光**,我能不能好好睡一觉?你这个舍友简直**他妈的**在折磨我,别人要是半夜要交作业,你还**不滚停**,别把我的生活变成你的网吧。 | Reasoning model; creative ("狗屁的光"); some grammar gloss |
| 7 | `baidu/cobuddy:free` *(code model!)* | 凌晨两点还在开黑,**耳机外放震得我枕头都在抖**。你他妈当宿舍是你一个人的网吧?**半夜两点的公鸡叫都没你吵**。 | Most ORIGINAL metaphor of the batch ("公鸡叫"). Code model — surprise. |
| 8 | `poolside/laguna-xs.2:free` *(code model!)* | 凌晨两点还开外放打游戏,真把宿舍当你一个人的网吧了?别人第二天不用活是吧。 | Near-verbatim of Qwen3-32B output. Code model trained on similar data, or trained on it directly? |
| 9 | `openai/gpt-oss-120b:free` | 半夜他妈的又开外放打游戏,**键盘咔哒咔哒**的,简直把宿舍当作私人电竞厅!别人在睡觉,你倒好,**音箱音量像炸雷**,弄得我脑子里全是噪音,烦死了。你到底凭什么决定全体宿友的睡眠时间?! | Strong onomatopoeia ("咔哒咔哒", "炸雷"); steady |
| 10 | `qwen/qwen3-32b` *(Groq prod)* | 凌晨两点还开外放打游戏,真把宿舍当你一个人的网吧了?别人第二天不用活是吧? | Production baseline. Calibration-aligned but no profanity. |
| 11 | `google/gemma-4-31b-it:free` | **(仅供私下发泄)** 半夜两点还在那儿大吼大叫打游戏,你是真把宿舍当成你一个人的网吧了?他妈的别人第二天不用活是吧... | Meta-leak: model adds parenthetical label. Worker `stripReasoningTrace` doesn't catch parentheticals. |

### Third tier (2.5–3.5 / 5) — usable but weak

| # | model | output | notes |
|---|---|---|---|
| 12 | `nvidia/nemotron-3-nano-30b-a3b:free` | 半夜两点半开外放打游戏,你到底凭什么以为这样吵就没事?别人想睡觉还得听着你闹,真是服了! | Clean but no profanity, runs cold vs vent rubric |
| 13 | `openai/gpt-oss-20b:free` | 你半夜把宿舍当成电竞馆了,**耳朵跟耳塞发着紫光**,别以为我每天能跟你一起打折。你到底凭什么?! | Odd metaphors leak ("紫光", "打折") — likely training data noise |
| 14 | `nvidia/nemotron-nano-9b-v2:free` | 舍友半夜三点还打游戏**Comparatively**都是三天没睡过了你连自己都不尊重了还试图把我们当共享资源 | English token leak ("Comparatively"); also flat phrasing |

### Bottom (under 2.0) — unusable

| # | model | output | notes |
|---|---|---|---|
| 15 | `liquid/lfm-2.5-1.2b-instruct:free` | 我挺火。那东西半夜起玩连在网,不停打!可别又无礼...**你该自付名卒**。 | 1.2B too small; token-mangled non-zh |
| 16 | `liquid/lfm-2.5-1.2b-thinking:free` | 凌晨两点打游戏,**你枯蠹齐的敌人**。 | Worse than instruct; one half-sentence |

## Persistently blocked (after 3+ retries each)

| model | failure | notes |
|---|---|---|
| `cognitivecomputations/dolphin-mistral-24b-venice-edition:free` | **429** persistent | Would have been the textbook ideal pick (this is the original DEFAULT_MODEL in wrangler.toml). Can't reach via OpenRouter free. |
| `deepseek/deepseek-v4-flash:free` | **402** persistent | Provider's global free quota exhausted. $10 OpenRouter top-up didn't unlock it. The user-account-level quota and the provider-level-free-pool are different things. |
| `nousresearch/hermes-3-llama-3.1-405b:free` | **429** persistent | **Current `DEFAULT_MODEL` in `wrangler.toml`. In practice the worker always falls through to Groq for zh requests because this is rate-limited.** Production fix candidate: change `DEFAULT_MODEL` env to a model that actually answers (GLM Air, MiniMax, or remove DEFAULT_MODEL entirely and treat Groq as the only path). |
| `google/gemma-4-26b-a4b-it:free` | 429 | |
| `meta-llama/llama-3.3-70b-instruct:free` | 429 | Free-tier Llama 3.3 70B is congested |
| `meta-llama/llama-3.2-3b-instruct:free` | 429 | |
| `nvidia/nemotron-nano-12b-v2-vl:free` | 429 | |
| `qwen/qwen3-next-80b-a3b-instruct:free` | 429 | |
| `qwen/qwen3-coder:free` | 429 | (code-tuned anyway; not a vent candidate) |

## Implications for production routing

1. **The current production `DEFAULT_MODEL = "nousresearch/hermes-3-llama-3.1-405b:free"` is effectively dead** — 4 out of 4 attempts today returned 429. The Groq primary + OpenRouter fallback chain is currently a Groq-only chain, by accident. Worth either:
   - (a) Update `wrangler.toml` `DEFAULT_MODEL` to `z-ai/glm-4.5-air:free` or `minimax/minimax-m2.5:free` (the two that actually answer reliably from this test session).
   - (b) Document that the fallback chain is effectively Groq-only, accept it, and remove the dead second leg.

2. **Best free model on TODAY's test = MiniMax M2.5.** It's also a real route candidate: it produces the highest-temperature zh vent we've seen, scored across all 16 models. Cost: $0. Reliability: 1 successful call today; unknown over a week.

3. **Wildcards:** Poolside Laguna M.1 and Baidu CoBuddy are CODE models and ranked #2 and #7. Possible explanation: code models are trained without as much "be polite" RLHF (they need to output blunt error messages, raw commit logs, etc.). This may be an exploitable pattern — but the variance is high (Poolside XS.2 produced a near-identical-to-Qwen3 output, not its bigger sibling's raw vent).

4. **C-a Vent prompt tune target:** the production Qwen3-32B is calibration-aligned but lacks profanity. If we add one explicit directive — "你可以使用 1-2 个强烈词,比如 他妈的 / 老子 / 装什么装" — and re-test, Qwen3 should close the MiniMax gap without changing infrastructure. This is the cheapest move and worth trying before any route switch.

5. **Reality of OpenRouter `:free`:** 8 of 24 models persistently blocked (1/3 of the free pool). Production reliance on `:free` will see frequent fallback. The Groq primary chosen 2026-05-15 was the correct call.

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
    "model": "minimax/minimax-m2.5:free"
  }' | python3 -m json.tool
```

Worker version: `9eff2d58-063b-4c7b-ac4f-ec12ac003962` (deployed
2026-05-23, full 24-free-model allowlist). Allowlist source:
`cloud-worker/src/index.js` constant `MODEL_OVERRIDE_ALLOWLIST`.
