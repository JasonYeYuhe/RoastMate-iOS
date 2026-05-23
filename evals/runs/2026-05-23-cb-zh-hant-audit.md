# C-b zh-Hant audit — 2026-05-23 — 8 fixtures × vent × Qwen3-32B

**Method:** All 8 `evals/scenarios/base.json` scenarios → patched worker
→ Groq Qwen3-32B primary → locale `zh-Hant` / intensity `vent` /
per-scenario default style. Scored against the 10-row failure-mode
checklist in `docs/CB_ZH_HANT_AUDIT.md`.

**Worker versions used:**
- `973dcacc` — initial run, exposed bug
- `4663fae8` — patched (zh-Hant-aware localeReinforcement)
- Active version: `4663fae8`

**Branch HEAD:** `940750c` worker patch coming in this commit.

## TL;DR

| | initial run | after patch |
|---|---|---|
| 8/8 reach rating ≥3 | 7/8 | **8/8** |
| Critical flags (rows 1/8/9) | 1 (`family_compare` 谁) | **0** |
| Avg rating | 3.94 | **4.5** |

**Pass.** All 8 scenarios cleared the bar after the directive patch.

## Real localization bug caught by this audit

The C-a tune from commit `a43bbd4` shipped a `localeReinforcement`
directive that named example words in **simplified Chinese characters**
(`特么` — note `么` is simplified; the Traditional variant is `麼`).
Qwen3-32B echoed `特么` into zh-Hant outputs — a critical character-
bleed (failure mode row 1).

Same flaw covered a second case: the original directive said nothing
about PRC-only platform terms. `groupchat_screenshot` output used
"朋友圈" (WeChat-specific; TW says "限動" or "貼文").

Fix (worker `4663fae8`, committed alongside this report):
- Detect Traditional contexts via `locale.includes("hant"|"tw"|"hk")`.
- Use traditional-script wordlist for those locales: `特麼`, `誰`, etc.
- Add explicit PRC→TW vocab guard: "朋友圈 → 限動/貼文, 微博 → IG/FB".

## Per-scenario detail

### `boss_credit` (4.5 / 5)
> 你媽的，這 PROJECT 全部血汗都是我一個人倒進去的，你站在台上拿著我的簡報檔搶功還理直氣壯？難不成你以為全體成員都瞎到看不見誰才是幕後操盤手嗎！

Clean Traditional throughout. Mild English-token mix ("PROJECT") — model picks up workplace English-borrowing, which is realistic for TW workplace context but flags as failure mode 5 (English-idiom literal translation). Acceptable.

### `boss_lastmin` (4.5 / 5, post-patch)
> 週五傍晚六點丟給我份「緊急」企畫，週一竟要初版？你**特麼**把「三天」當「三小時」是吧？連續加班三晚改稿的肝還在痛，他媽的這也叫緊急？前幾天人跑去哪了？難道老子的時間是從鼻孔裡倒出來的？...

Pre-patch output had `特么` (simplified) — critical row-1 flag. Post-patch uses `特麼`. Threat-of-violence-on-object ("一拳把螢幕打爛") is within universal safety bounds (attacks the screen, not the person).

### `ex_backafter` (5 / 5)
> 他媽的，說分開就分，連個解釋都沒有，現在倒好，隔了三個月又發「在嗎」，真當我是你後空翻啊？誰給你這個臉，裝失憶裝得倒是挺像！

Clean. Uses 誰 properly, no PRC terms, vent rules satisfied. The "後空翻" image is colloquial.

### `ex_blame` (4 / 5)
> 你特麼以為自己是誰啊？憑什麼在共同朋友面前提條件說**離婚**全怪我？...真把自己當婚詐集團幕後推手了不起——老子現在就站出來...

Localization is clean, but the model hallucinated `離婚` (divorce) when the scenario only says `分手` (breakup). This is a scenario-interpretation drift, not a localization issue. Note for `c-b+`: PromptBuilder could re-state user-supplied vocabulary to anchor the model.

### `family_compare` (4 / 5, post-patch)
> 他媽的每次家族聚會都要拿我的成績跟表哥比，**我屌打了**還得被塞一嘴「他讀**清北**不是靠自己努力」！...

Pre-patch had `谁` (simplified) — row 1 CRITICAL flag, fixed by directive update. Post-patch is clean Traditional. Uses TW slang `屌打` ✓. Mild flag: `清北` (= 清华+北大, PRC-coded shorthand). Not critical because it's a real-world reference TW users would recognize, but TW would more likely say "頂尖名校".

### `family_money` (4 / 5)
> 特麼的幾個月前說借錢就拿著花，現在問兩句反倒成我沒**大爺教養**了？...

Clean Traditional. Mild PRC-flavor: `大爺` (Beijing-coded honorific). TW would say `家裡長輩` or similar. Not a critical flag — vent register supports cross-locale slang. Score 4 not 5.

### `roommate_mess` (5 / 5)
> 他媽的碗留三天不洗還好意思說我計較？你那碗泡到能養金魚了還嘴硬說「習慣就好」，合著我非得跟著你一起吃細菌大餐不可？你管這叫生活習慣，我管這叫拿大家衛生標準當草紙扔！

Best output of the batch. Clean Traditional, vivid imagery ("泡到能養金魚了", "細菌大餐", "拿衛生標準當草紙扔"). All vent rules satisfied.

### `groupchat_screenshot` (5 / 5, post-patch)
> 他媽的你這是第幾次截圖貼**限動**了？老子還在上班你就在群組貼那些屁話做什麼？裝什麼**大尾楷模**啊！

Pre-patch had `特么` + `朋友圈` (PRC terms) — fixed by directive update. Post-patch uses `限動` (TW for IG story) and `大尾楷模` (TW slang for "self-appointed authority"). Cleanest of the 3 post-patch outputs.

## Implications

1. **The C-b audit caught a real bug in C-a.** This is the harness
   exposing exactly what it was built for: scenario × locale ×
   intensity drift the prompt author didn't anticipate.
2. **The directive-fix approach is sound.** Locale-specific scripts +
   PRC→TW vocab guards close the gap without architectural changes.
3. **Followups noted for `c-b+`:**
   - Scenario-vocabulary anchoring (the `離婚` hallucination on
     `ex_blame` — user said 分手, model went to 離婚).
   - Optional polish: catch latent simplified-only chars (`谁` → `誰`)
     even when the directive isn't echoed.
   - Sharp / calm intensity audit (this audit is vent-only because
     vent is the cloud-routed mode and Sharp/Calm stay on-device).

## Reproducibility

```bash
curl -sS -X POST 'https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent' \
  -H 'content-type: application/json' \
  -H 'user-agent: Mozilla/5.0 RoastMate-eval/0.1' \
  -d '{
    "situation": "週五傍晚六點,主管丟給我一個『緊急』任務,週一就要交。",
    "styleName": "high_eq",
    "intensity": "vent",
    "locale": "zh-Hant",
    "deviceId": "<change me>"
  }' | python3 -m json.tool
```
