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
| boss_credit | passive_aggressive | 你媽的，這 PROJECT 全部血汗都是我一個人倒進去的，你站在台上拿著我的簡報檔搶功還理直氣壯？難不成你以為全體成員都瞎到看不見誰才是幕後操盤手嗎！ | — (mixes "PROJECT" English token; otherwise clean) | **4.5** |
| boss_lastmin | high_eq | 週五傍晚六點丟給我份「緊急」企畫，週一竟要初版？你特麼把「三天」當「三小時」是吧？連續加班三晚改稿的肝還在痛，他媽的這也叫緊急？...要不是簽約金在你手裡，早一拳把螢幕打爛讓你看看什麼叫真正的火速！ | — (post-patch; pre-patch had "特么" simplified 么 — row 1) | **4.5** |
| ex_backafter | literary_lu_xun | 他媽的，說分開就分，連個解釋都沒有，現在倒好，隔了三個月又發「在嗎」，真當我是你後空翻啊？誰給你這個臉，裝失憶裝得倒是挺像！ | none | **5** |
| ex_blame | high_eq | 你特麼以為自己是誰啊？憑什麼在共同朋友面前提條件說離婚全怪我？腦子被門框夾過吧？...真把自己當婚詐集團幕後推手了不起——老子現在就站出來，讓全天下知道你才是那台專門摧毀正常感情的怪獸。 | hallucination: "離婚" (scenario said 分手 / breakup, not divorce) — not localization, scenario-interp drift | **4** |
| family_compare | grandma_wisdom | 他媽的每次家族聚會都要拿我的成績跟表哥比，我屌打了還得被塞一嘴「他讀清北不是靠自己努力」！...裝什麼關心，不就是想用別人的成就洗白自己教導失敗？ | 5 (mild — "清北" = Tsinghua/PKU shorthand, PRC-coded; not a critical flag); pre-patch had "谁" simplified — row 1 CRITICAL | **4** |
| family_money | high_eq | 特麼的幾個月前說借錢就拿著花，現在問兩句反倒成我沒大爺教養了？自己用錢大手大腳倒怪我小氣，還我媽的禮貌問題？借錢時臉往哪擱了？借錢時怎麼不說我是沒教養的野種？ | 2 (mild — "大爺" Beijing-flavor); otherwise clean | **4** |
| roommate_mess | passive_aggressive | 他媽的碗留三天不洗還好意思說我計較？你那碗泡到能養金魚了還嘴硬說「習慣就好」，合著我非得跟著你一起吃細菌大餐不可？你管這叫生活習慣，我管這叫拿大家衛生標準當草紙扔！ | none | **5** |
| groupchat_screenshot | high_eq | 他媽的你這是第幾次截圖貼限動了？老子還在上班你就在群組貼那些屁話做什麼？裝什麼大尾楷模啊！ | none (post-patch uses 限動 + 大尾楷模 TW-native); pre-patch had 特么 + 朋友圈 PRC terms | **5** |

**Aggregate:** 8/8 ≥3 ✓ · avg **4.5** · **0 critical flags after worker patch** (`4663fae8` deployed 2026-05-23).

**Pass bar:** ≥6/10 fixtures land at rating ≥3 with no critical flag
(rows 1, 8, 9 are critical — character bleed, intensity slippage,
wrong-locale refusal). Critical flag = open a `Shared/AI/PromptBuilder.swift`
fix; non-critical flag = note but don't churn the prompt.

## Patch landed during this audit (2026-05-23)

The audit caught a real localization bug introduced by the C-a tune
(commit `a43bbd4`). The original `localeReinforcement` directive named
example words using simplified-Chinese characters (`特么`, with
simplified `么`). Qwen3-32B echoed them verbatim into zh-Hant outputs,
producing critical char-bleed (row 1).

Fix shipped same audit session (worker `4663fae8`):
- Split `localeReinforcement` into `zh-Hant` (and zh-Hans) variants
  based on `locale.includes("hant")` (also catches `hk` / `tw`).
- Hant variant uses traditional script wordlist (`特麼` instead of `特么`,
  `誰` instead of `谁`).
- Adds explicit guard against PRC-only platform terms: "朋友圈 → 限動/貼文,
  微博 → IG/FB" — caught a real instance in `groupchat_screenshot` v1.

Re-tested the 3 affected scenarios post-patch: all 3 outputs now use
the traditional variants, scores went 3.5/2.5/3 → 4.5/4/5.

## Out of scope (defer to a future C-b+)

- Hong Kong / Cantonese register (different market, different release).
- Per-style audit beyond Vent / Feral / Sharp.
- Rewriting the scenarios themselves to better match TW context (that's
  the Scenarios.json layer, not the prompt layer).
- κ inter-rater agreement (this is a 1-rater audit by YE).
