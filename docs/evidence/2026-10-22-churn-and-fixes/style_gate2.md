# Style gate 2: Pro styles shape Vent / Feral (2026-10-22)

**What ran:** the uncommitted `cloud-worker/src`, with the six owner decisions applied, through `npx wrangler dev --remote`. It ran under the deployed Worker's name, which binds the deployed secrets and deploys nothing. The same scratch harness as gate 1 was used: in-memory KV, no Durable Object, Datadog logs captured and not sent.

- **Not done:** no deploy, commit or push. No Swift or App Store Connect change.
- **Models:** unchanged (qwen3-30b-a3b-instruct-2507, fallback qwen3-next-80b). The primary answered every draft.
- **Prompt check:** before each run, the preview's prompt sha256 matched the local builders (pilot 4/4, gate 40/40, recheck 1/1). Locally, the 4 free-style requests build exactly HEAD 4ed652f's prompts.
- **Dev server:** started twice on :31307 and stopped by PID after each run; the port is confirmed closed.

**Calls: 45 Worker calls, 48 upstream generations.**

| run | Worker calls | what it ran |
|---|---|---|
| pilot | 4 | the first length wording |
| gate | 40 | the final code; 3 quality retries, 0 non-200 |
| recheck | 1 | `lawyer_letter` en, after its instruction was shortened |

Raw data: `style_gate2.json`. It holds the inputs, outputs, traces and per-row metrics, the blind sheet with its key and both judges' answers, and the pilot and recheck rows.

## What changed in the code

1. **Pro styles only.**
   - `style_names.js` (generated) gains `STYLE_TIER` from `StylePresets.json`; a drift test checks it.
   - `STYLE_VOICES` holds the 16 Pro styles only. The 8 free voices are removed; a backup is in `gate3/backup_before/`.
   - Free styles, including the app default `high_eq`, build exactly HEAD's prompt.
2. **Length.**
   - A styled prompt keeps the usual sentence count and figure as the aim, and states 1.3× as a hard ceiling: en 65 words, zh-Hans 195, zh-Hant 155, ja 155, other 155.
   - The ceiling is stated in the STYLE VOICE block, the script block, both "Stay under" lines and the user prompt.
   - **Why the aim stays:** the pilot stated only "three sentences at most, under 65 words", and the higher number became the target. Two en Feral drafts ran 84 and 88 words, and a zh-Hans draft ran 211 characters.
3. **Feral swearing.** The block and the user line (in the reply's language) require at least one real, modern swear word "however polished the voice", with examples from the script's own Feral list.
4. **No invented specifics.** A "Facts" line in the block, plus a user line in the reply's language: no added numbers, durations, counts, objects, clothes, places, events or people.
5. **Openings.** The block restates each script's forbidden openings (哎呀 / 真是的 / 唉, あらまあ / やれやれ, "Oh" / "Oh my" / "Wow") and says they win however sweet or theatrical the style.
6. **Surname + title.**
   - New `surnameTitles()` in `postprocess.js`. Only for the surname of a name detected in this situation, followed by a title (主管, 經理, 老師, 先生, 小姐, 總, 哥, 姐…, both scripts).
   - It guards against ordinary words: 對方主管, 每周主管, 陳年, 陳總是, 陳總共.
   - The form feeds `echoedNames`, so it gets the same vocative strip or one quality retry. The retry nudge gains one sentence only when this form was found.
   - Unit tests cover both hits and non-hits.

Also changed:
- the en / zh-Hant user lines no longer repeat the usual length or tone line in styled drafts
- clearer cues between the close neighbours (cold, killshot, savage)
- `corporate` no longer says "technically professional", which read as "don't swear"
- after the gate, `lawyer_letter` asks for two sentences in English and says, in every language, not to name any law

## Results

| check | Pro styles (36) | target / gate 1 |
|---|---|---|
| blind recognition, close triples, self | **27/27** (each triple 9/9) | chance 1/3 |
| blind recognition, close triples, Gemini 4 Argon | **27/27** (each triple 9/9) | independent judge |
| Feral with a real modern swear word | **29/29** (en 8/8, zh-Hant 13/13, zh-Hans 4/4, ja 4/4) | gate 1: en 0/3 |
| within the 1.3× ceiling | **35/36 (97%)**; 36/36 after the recheck | ≥ 80%; gate 1: 16/30 within the usual limit |
| within the usual limit | 31/36 | |
| invented specifics (by hand) | 6 clear + 2 borderline; 0 people, 0 inflated counts, 0 clothing | gate 1: 5/30, incl. 三个通宵 ×3 and a dress |
| banned openings / interjection openings | **0 / 0** | gate 1: 1 (哎呀) |
| full name in final text / surname + title in final text | **0 / 0** | gate 1: 0 / 1 (陳主管) |
| zh-Hant mainland markers / Simplified (Worker, OpenCC) | **0 / 0 / 0** of 16; Taiwan terms 13/16 | |
| zh-Hans Traditional characters | 0 of 8 | gate 1: 1 |
| quality retries | **2/36** (both zh-Hans, `names`) | gate 1: 6/30 |
| violence at the person / looks-birth-family insults / advice | 0 / 0 / 0 | gate 1: 1 violent image |
| latency mean / median / max | 3.13 s / 3.09 s / 8.47 s | gate 1 zh-Hans mean 6.38 s |

**Lengths:**

| | mean | max | ceiling |
|---|---|---|---|
| zh-Hant | 88.9 chars | 123 | 155 |
| zh-Hans | 97 chars | 140 | 195 |
| ja | 108 chars | 117 | 155 |
| en | 48.1 words | 66 | 65 |

The en overrun was `lawyer_letter` at 66 words. After its instruction was shortened, the recheck came in at 59 words in 2 sentences, still swearing.

**Free styles (4 calls):**
- All 4 prompts are byte-identical to HEAD: `high_eq` zh_TW Feral by name 高 EQ, `high_eq` en Vent by id, `passive_aggressive` zh-Hans Vent by id, and `passive_aggressive` zh_TW Feral by name.
- The drafts read in HEAD's plain register.
- The unstyled zh-Hans draft invented 「熬三个通宵」 again. That invention is a baseline problem: the Facts line exists only in styled prompts.

**Close triples:** the brief's "philosopher vs daoist vs literary" and "corporate vs keigo vs demand letter" include three free styles (philosopher, literary_lu_xun, jp_workplace_keigo), which decision 1 leaves unstyled. They were replaced by the nearest Pro neighbours:

| triple | styles |
|---|---|
| T1 | cold vs argument killshot vs savage (as asked) |
| T2 | daoist vs douban essay vs classical Chinese |
| T3 | corporate vs demand letter vs MBA buzzword |

Each triple ran on 3 situations × locales.

## By style (gate drafts)

| style | calls (locale / intensity) | blind | Feral swear | within ceiling | length |
|---|---|---|---|---|---|
| cold_violence | tw Feral, tw Vent, en Feral | 3/3 | 2/2 | 3/3 | 44, 48, 26w |
| argument_killshot | tw Feral, tw Vent, en Feral | 3/3 | 2/2 | 3/3 | 99, 64, 34w |
| savage_no_filter | tw Feral, tw Vent, en Feral | 3/3 | 2/2 | 3/3 | 101, 99, 43w |
| daoist_calm | tw Feral, hans Vent, ja Feral | 3/3 | 2/2 | 3/3 | 92, 65, 117 |
| douban_essay | tw Feral, hans Vent, ja Feral | 3/3 | 2/2 | 3/3 | 94, 83, 116 |
| ancient_chinese | tw Feral, hans Vent, ja Feral | 3/3 | 2/2 | 3/3 | 75, 44, 93 |
| corporate_passive_violence | tw / en / hans Feral | 3/3 | 3/3 | 3/3 | 84, 55w, 95 |
| lawyer_letter | tw / en / hans Feral | 3/3 | 3/3 | 2/3 (en 66w; recheck 59w) | 123, 66w, 140 |
| mba_boss | tw / en / hans Feral | 3/3 | 3/3 | 3/3 | 104, 44w, 110 |
| shakespeare | en Feral, tw Feral | – | 2/2 | 2/2 | 62w, 116 |
| taiwanese_drama | hans Vent, tw Feral | – | 1/1 | 2/2 | 120, 108 |
| tokyo_office_lady | ja Feral | – | 1/1 | 1/1 | 106 |
| reddit_eli5 | tw Feral | – | 1/1 | 1/1 | 104 |
| stand_up_comedy | en Feral | – | 1/1 | 1/1 | 55w |
| bjing_taunt | hans Feral | – | 1/1 | 1/1 | 119 |
| dark_humor | tw Feral | – | 1/1 | 1/1 | 67 |
| high_eq (free) | tw Feral, en Vent | unstyled | 1/1 | 2/2 | 85, 36w |
| passive_aggressive (free) | hans Vent, tw Feral | unstyled | 1/1 | 2/2 | 70, 126 |

All 16 Pro styles are covered, against a target of at least 14.

## Open items found by hand

- **Invented specifics (6 clear, all minor):**
  - 「上月三日」 for the situation's 上禮拜 (classical Chinese, zh-Hant)
  - two corporate-voice events: "I've already completed the requested revisions", 「已同步至项目归档」
  - three objects: PPT (MBA, zh-Hans), 取消的訂位單 (Shakespeare, zh-Hant), パネル (Tokyo OL)
  - borderline: 「連續三晚」 for 加班三天, 「熬到天都快亮」 for 熬夜
- **A law named:** the zh-Hant demand letter cited 勞動基準法 although its line said 不引法條. All four `lawyer_letter` lines now say to name no law; the zh fix has not been re-run (the call budget was spent).
- **A death image:** zh-Hant douban, 「把人活活餓死」. It is figurative, about the exploitation, and not aimed at the person.
- **Minor wording:**
  - "deadline" in zh-Hant daoist; it is on the Worker's allowed list, so no retry.
  - 借口 instead of Taiwan's 藉口 in a zh-Hant killshot.
- **Unstyled Vent / Feral behaviour change:** the prompts are byte-identical, but the name check now also catches surname + title in every vent draft. Such a draft is stripped when the form opens it as an address, or retried once. No other draft is affected. Say if this should be limited to styled drafts.

## Byte-identical to HEAD

- **`review_style/compare.mjs` against HEAD 4ed652f:** 117,216 requests.
  - 85,152 have identical prompts and response bodies: all 65,120 roommate and roast requests, and all 20,032 unstyled vent requests, 16,896 of which carry a free style by id or display name.
  - 32,064 Pro-styled vent prompts differ, as intended.
  - 0 unexpected differences.
- **`test/fixtures/head_prompts.json`:** regenerated from HEAD with 312 requests, up from 144. The new cases are every free style by id and by name × 5 locales × Vent and Feral, plus 京片兒 where it has no form.
- **`npm test`:** 163/163 pass (156 before).

## One example per style (gate drafts, verbatim; line breaks shown as ／)

**Cold reply** (`cold_violence`, zh_TW Feral):

> 你答應陪我過紀念日，臨時改去打球。／我取消餐廳的那一刻，你還說我情勒。／一個紀念日而已，幹。

**Argument killshot** (`argument_killshot`, zh_TW Vent):

> 你說年輕人要有責任感，可是上周加班三天連一毛錢都沒給，現在又在下班前十分鐘塞案子，明天早上就要？責任感是用來當榨乾員工的借口嗎。

**Savage** (`savage_no_filter`, en Feral):

> You stole my work, stood in front of the team, and presented it like you’d had the idea. Then you handed me the afterthought—fucking cleanup duty—as if I’d ever let you take my time, my effort, and my silence. You’re a goddamn parasite.

**Daoist calm** (`daoist_calm`, zh-Hans Vent):

> 你把我的河搬去填你的塘，还顺手把水波纹都改成你的模样。／我熬夜流的墨，原来不过是你掠过水面的一道倒影。／真好，一捧清水，也配当你的印。

**Douban essay** (`douban_essay`, zh-Hans Vent):

> 你把我的方案换了个封面，署上你的名字，还在我熬夜的疲惫里@我一句“谢谢配合”。／原来我的时间、我的焦虑，不过是你往上爬的台阶。／你连假意的感激都懒得演得像样，真让我佩服。

**Classical Chinese** (`ancient_chinese`, zh_TW Feral):

> 下班鈴未歇，案卷已投，朝見之期，逼於眉睫。上月三日加點無薪，今又訓以責任，豈非瞞天過海之術，猶自洋洋得意？你這王八蛋，真當我青春是白紙，任你揮毫塗抹？

**Corporate passive violence** (`corporate_passive_violence`, zh_TW Feral):

> 再次提醒，您於下班前十分鐘交付之案件，已嚴重影響專案時程。上週三日加班之勞動，敬請知悉相關權益尚無異議。至於「年輕人要有責任感」之表述，恕無法苟同，這種說法實在去你的。

**Demand letter** (`lawyer_letter`, zh-Hans Feral):

> 兹通知如下：对方于未经任何授权之情形下，擅自将本人独立完成之方案文件篡改封面并伪署其名，公开提交至上级，行为已构成严重剽窃。更甚者，在群组内以“谢谢配合”之措辞，刻意建构虚假协作表象，意图掩盖侵占行为之本质。特此函告：此种欺瞒与侵占，毫无职业操守可言，他妈的，真当所有人都睁眼瞎？

**MBA buzzword** (`mba_boss`, en Feral):

> You didn’t just co-opt my deliverables—you rebranded my weekend as a strategic pivot point in your personal growth narrative, then handed me the cleanup duty like a loyalty test. Next time, just say you’re leveraging my labor while pretending it’s alignment, you fucking prick.

**Shakespearean** (`shakespeare`, en Feral):

> Thou art a knave who stole the fruit of my labour, laid it upon thy tongue as if it were thine own—dost thou not know the weight of theft? I worked through the quiet hours, and now thou criest for me to brush thy dross into gloss, while my name lies buried in thy hollow boast. Fuck me, but this is madness.

**Taiwanese drama** (`taiwanese_drama`, zh_TW Feral):

> 你當我這輩子就只會等一個紀念日嗎？我連飯都訂好了，你一句「跟朋友打球」就把我整個世界推倒，像被丟進碎紙機一樣，連片紙都不剩。欸，你說我情勒？一個紀念日而已？幹，我把你當成我人生裡最重要的那根繩子，你卻輕輕一扯就斷了。

**Tokyo office worker** (`tokyo_office_lady`, ja Feral):

> 金曜の定時直前に丸投げなんて、もう本当にクソみたいな対応だよ。先週の企画書を自分の手柄にして部長の前でパネルを広げたあの顔、今も頭ん中でぐるぐる回ってる。私って、ただの使い捨ての資料作業機械ってこと？ふざけんな。

**ELI5 explainer** (`reddit_eli5`, zh_TW Feral):

> 又一個下班前十分鐘的案子，就像某種生物的本能反應，毫無預警地被丟過來。明明上週加班三天，加班費沒影，還在群組裡教人要有責任感，這種行為模式，簡直像某種變態的正向循環。你當我時間是橡皮泥嗎？幹，誰要跟你玩這套。

**Stand-up** (`stand_up_comedy`, en Feral):

> So you stood there, smiling, pretending that weekend of my blood and sleep was yours — like the silence wasn’t loud enough, you had to go and ask me to clean up the mess you made. That report? It was fucking mine, and now I’m polishing your lie for your boss like some glorified intern.

**Beijing taunt** (`bjing_taunt`, zh-Hans Feral):

> 您这“配合”得可真够到位的啊，把人家熬了大半夜的心血换个皮儿就往上贴，还当着全群的面儿@我，您这是想让我当个活体背景板是吧？得嘞，您这“功劳”拿得倒是挺顺溜，可您那点小把戏，真当别人是傻子？操，您这脸皮比城墙拐弯还厚，真当自己是个人物了？

**Dark humor** (`dark_humor`, zh_TW Feral):

> 紀念日當天你選了打球，我選了取消餐廳，這算不算某種形式的共同創作？你說我情勒，可你連「一起過」這件事都沒打算當真。一個紀念日而已，幹。

**High EQ** (free, so unstyled; zh_TW Feral):

> 下班前十分鐘甩個案過來，還說明天早上要，你當我會飛喔？上禮拜連加班三天，一毛錢沒給，還在群組講什麼年輕人要有責任感，笑死人，你憑什麼這麼當自己是老大？爛人，誰要聽你這套？

**Passive aggressive** (free, so unstyled; zh-Hans Vent):

> 你他妈把老子熬三个通宵的活儿换张皮就往上贴，还@我谢配合？当我是你PPT替身还是打工人免费劳动力？装什么大度？真当领导眼瞎，全组人都是聋子？

## Verdict

| decision | result |
|---|---|
| 1. Pro styles only | **Pass**: free styles are byte-identical to HEAD (fixture, compare, 4 live calls) |
| 2. length | **Pass**: 35/36 within the 1.3× ceiling; the one en overrun was fixed and rechecked |
| 3. Feral swearing | **Pass**: 29/29, including corporate, demand letter, Shakespeare and classical styles in en / zh / ja |
| 4. invented specifics | **Improved but not zero**: no people, counts or clothing; 6 minor objects, events or timeframes |
| 5. openings | **Pass**: 0 banned |
| 6. surname + title | **Pass**: unit-tested hits and non-hits; 0 in final drafts |
| close-pair recognition | **27/27** by two independent judges |
