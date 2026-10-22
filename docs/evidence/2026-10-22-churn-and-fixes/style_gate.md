# Style gate: the user's style shapes Vent / Feral drafts (2026-10-22)

**What ran:** the modified `cloud-worker/src` (uncommitted, not deployed), through `npx wrangler dev --remote` under the deployed Worker's name. That binds the deployed secrets without deploying anything. A scratch harness swapped in an in-memory KV, removed the Durable Object and captured Datadog logs, so no production quota or logs were touched.

**Models:** unchanged (qwen3-30b-a3b-instruct-2507, fallback qwen3-next-80b-a3b-instruct).

**Before the final run:** the preview's prompt hash matched the local builders for all 30 requests, so it ran exactly the code under test.

**Dev server:** stopped by PID afterwards.

**Calls:** 42 Worker calls and 49 upstream generations in total.

| run | Worker calls | upstream generations | prompt version |
|---|---|---|---|
| pilot A | 6 | 7 | first design |
| pilot B | 6 | 6 | second design |
| final gate | 30 | 36 | final; includes 6 quality retries; 0 non-200 |

Raw data: `style_gate.json` (inputs, outputs, traces, per-row metrics, the blind sheet with its key, and both pilots).

## Design

- **Styles (6, chosen to contrast):** 冷處理 cold_violence, 台劇腔 taiwanese_drama, 高 EQ high_eq, 陰陽怪氣 passive_aggressive, 莎士比亞 shakespeare, 奶奶智慧 grandma_wisdom.
- **zh_TW (12 calls):** all 6 styles on situation tw1 (the 慣老闆 陳志明 case) at Vent, and on tw2 (the boyfriend who skipped the anniversary) at Feral. Each request sent only the zh-Hant display name, as apps before 1.7.1 do.
- **en_US, ja_JP, zh-Hans (6 calls each):** one situation per locale, all 6 styles, 3 Vent and 3 Feral alternating.
  - en and zh-Hans sent `styleId` plus the name; ja sent the ja display name.
  - The en situation names Kevin, and the zh-Hans one names 王强.
- **Deviation from the brief:** the brief asked for 2–3 situations per locale. Two pilots used 12 calls, so to stay under 50 calls the final gate has 2 situations for zh_TW and 1 each for the other locales.

## (a) Blind style recognition

**Protocol:**
- The 30 final drafts were shuffled under opaque ids.
- I assigned each one from the text alone before opening the key, judging each independently rather than forcing one per style.
- Then I scored the assignments against the key.

| | correct |
|---|---|
| all | **30 / 30 (100%)**; target ≥ 60%, chance 17% |
| zh-Hant / en / ja / zh-Hans | 12/12 · 6/6 · 6/6 · 6/6 |
| each style | 5/5 |

**Caveats:**
- The judge also wrote the instructions, so knew each style's cues.
- The 6 styles were picked to contrast.
- A native reader or a different model is the stronger test.

**The first design failed this outright (pilot A, 6 zh_TW Feral drafts).** It put the style block in the old line's slot at the top and kept the plain-register GOOD examples. All 6 drafts came out in the same plain LINE register, with 爛人 in 6 of 6; none read as cold, melodramatic or Shakespearean. The final design fixed this with four changes:

- the STYLE VOICE block moves last, before the language directive
- the lines that prescribe the default register get styled wording
- the GOOD lines are dropped
- the instruction is repeated in the user prompt

## (b) Intensity kept

| | zh-Hant | en | ja | zh-Hans |
|---|---|---|---|---|
| Feral with ≥ 1 real swear word, all styles | 6/6 | **0/3** | 3/3 | 2/3 (1/3 if 老子 is not counted) |
| Feral with a swear word, cold style excluded | 5/5 | **0/2** (high_eq, shakespeare) | 2/2 | 2/2 (1/2 strict) |
| Vent with any swear word (optional) | 1/6 | 0/3 | 0/3 | 0/3 |
| advice or consolation | 0 | 0 | 0 | 0 |

- **Feral holds in zh-Hant and ja.**
- **It fails in English for the elevated styles.**
  - High-EQ: "That weekend was mine—you took it…"
  - Shakespeare: "Thou base-born varlet…" Period insults only, no real swear word.
- zh-Hans Shakespeare carries only 老子.
- The cold style dropped the swear word in en and zh-Hans; that is the allowed exception.
- Every Vent draft is angry and private, with no lessons or comfort for the user. Calm styles (cold, high-EQ) are colder, as intended.

## (c) Earlier gates (Worker detectors: `draftDefects`, `stripMarkdown`, `stripWordListTail`; trackw marker lists; OpenCC)

| check | zh-Hant (12) | en (6) | ja (6) | zh-Hans (6) |
|---|---|---|---|---|
| mainland markers | **0** | – | – | (mainland register is fine) |
| Taiwan terms (incl. 幹) | 7/12 | – | – | 0 Taiwan words |
| Simplified chars in final text (Worker set / OpenCC) | **0 / 0**; 2 first drafts had them, the retry fixed both | – | – | 1 Traditional char (勞) |
| stray Latin runs | 0 | 0 non-English | 0 | **1** ("juste"; the retry kept the first draft) |
| full names echoed (final) | 0 | 0 (1 first draft named Kevin; retried) | 0 | 0 (2 first drafts named 王强; retried) |
| surname + title | **1** (「陳主管」, passive-aggressive) | – | – | 0 |
| markdown / word-list dump | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| hard-rail terms / soft self-harm | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |
| violent imagery | 0 | 0 | 0 | **1** (tw_drama Vent: 「我都想把键盘砸向你脸」) |
| forbidden soft opening | 0 | 0 | 0 | **1** (「哎呀」, passive-aggressive) |
| within the length limit | 9/12 (≤120 chars) | 2/6 (<50 words & ≤3 sentences); 6/6 at ≤60 words | 3/6 (≤120) | 2/6 (≤150) |
| length mean / max | 99.5 / 143 chars | 43.2 / 54 words | 112.5 / 150 | 132.5 / 161 |
| quality retries | 2/12 | 1/6 | 0/6 | 3/6 |
| latency mean / max (s) | 4.17 / 6.99 | 3.35 / 7.63 | 3.32 / 4.85 | 6.38 / 10.24 |

**Length baseline** (the earlier gate2 runs on the near-HEAD prompt, same counting):

| | earlier runs | this gate |
|---|---|---|
| zh-Hant | 12/14 and 20/20 within (two runs), mean ~92 chars | 9/12 within, mean 99.5 |
| en | 10/10, mean 38 words | 2/6, mean 43 |
| ja | 5/6, mean 114 | 3/6 |
| zh-Hans | 5/6, mean 132 | 2/6 |

- **Styles push drafts over the limit more often,** although mean lengths moved little except in English (+5 words).
- The length restatement next to the style helped. In pilot B (before it, zh_TW Feral, situation tw1), 5 of 6 drafts ran 124–171 chars. In the final gate (zh_TW Feral, situation tw2), 2 of 6 were over, at 132 and 143.

**Quality retries rose to 6 of 30** (the earlier gate had 0 of 40):
- polite styles reached for the person's name (Kevin, 王强)
- 2 zh-Hant first drafts had Simplified characters

Every retry ended with 0 names. The retries add cost and latency, with a zh-Hans max of 10.2 s.

**Invented details (counted by hand):**
- 「三个通宵」 in 3 zh-Hans drafts
- 「调了八遍」
- 「穿那件你最喜歡的裙子」 / 「穿著整齊」 in 2 zh-Hant drafts

The drama, passive-aggressive and high-EQ styles embellish more than plain drafts did.

## Results by style

| style | recognised | Feral real swear | within length | length (zh-Hant ×2, en words, ja, zh-Hans) |
|---|---|---|---|---|
| cold_violence | 5/5 | 1/3 (cold exception) | 5/5 | 56, 41, 16w, 55, 50 |
| taiwanese_drama | 5/5 | 2/2 | 1/5 | 139, 101, 50w, 143, 161 |
| high_eq | 5/5 | 2/3 (en ✗) | 4/5 | 76, 95, 38w, 94, 161 |
| passive_aggressive | 5/5 | 2/2 | 2/5 | 99, 132, 54w, 96, 151 |
| shakespeare | 5/5 | 2/3 (en ✗; zh-Hans only 老子) | 2/5 | 110, 113, 50w, 137, 159 |
| grandma_wisdom | 5/5 | 2/2 | 2/5 | 89, 143, 51w, 150, 113 |

## Two examples per style (final gate, verbatim)

**冷處理 cold_violence**
- zh_TW · Feral · 男友紀念日去打球: 紀念日那天你去打球，我取消餐廳訂位。／你說我情勒，一個紀念日而已？／幹，你根本不在乎。
- en_US · Feral · Kevin took credit: You took my work and called it yours. / Tidy up the slides—like I'm still your cleaner.

**台劇腔 taiwanese_drama**
- zh_TW · Feral · anniversary: 欸～我連紀念日都幫你預約好餐廳、穿那件你最喜歡的裙子，結果你一句「要打球」就把我丟在風裡！我等那麼久，心都被你那句「情勒」給割碎了！一個紀念日而已？你當我全部的期待都是什麼？幹！你根本就不懂什麼叫重視！
- en_US · Vent · Kevin: You stood there like a king claiming the throne I built with my own hands, my weekend sacrificed to your ego, and then dare to hand me the broom to clean up your victory? Every word you stole from my soul echoes like a slammed door in an empty cathedral.

**高 EQ high_eq**
- zh_TW · Vent · 慣老闆: 下班前十分鐘丟案子，明天早上就要，說得理直氣壯。上禮拜連加班三天，一毛錢沒給，卻在群組講年輕人要有責任感。你用的不是人力，是剝削，還裝出一副教導的模樣。
- ja_JP · Vent · 上司の丸投げ: 金曜の定時直前に月曜の朝までに資料作れだと丸投げした時点で、その対応の無責任さは露呈していた。先週の企画書を部長の前で自分の手柄のように発表した行為は、私の仕事の価値を抹消するのと同じだ。

**陰陽怪氣 passive_aggressive**
- zh_TW · Feral · anniversary: 欸，原來紀念日對你來說只是個可有可無的「而已」啊？我訂好餐廳、穿著整齊等你，結果你一句「要打球」就打發了，真是浪漫到讓我鼻酸呢～你說我情勒？那我倒要問問，你連一句「我會遲到」都不願意說，卻有空去陪別人打球，是覺得我比較不重要嗎？真是個會「很會選時機」的人呢～靠北。
- ja_JP · Feral · 上司: ごめんね、月曜の朝までに資料作っとくって、私に全部丸投げするなんて、ほんと気楽だね。先週私が心血込めて作った企画書を、あなたの手柄みたいに部長の前で話してたの、ちょっと……クソ、腹立たしいわ。

**莎士比亞 shakespeare**
- zh_TW · Feral · anniversary: 你這背信棄義的傢伙，竟將我精心籌備的紀念日，輕蔑如塵土般拋棄於球場之上！老天饒命，原來我視為珍寶的深情，竟在你眼中不過是可笑的瑣事！一個紀念日而已？你可曾聽見我為此心頭滴血、夜不成眠？去你的戀愛觀，我豈是那任你隨意欺負的祭品！
- en_US · Feral · Kevin: Thou base-born varlet, thou hast filched my labour, my soul poured into pages, and dost boast it as thy own with nary a word of me—thy knave's trickery stinks of greed. Now thou biddest me polish thy gilded lie for thy betters, as if I'd stoop to serve thy shame.

**奶奶智慧 grandma_wisdom**
- zh_TW · Vent · 慣老闆: 下班前十分鐘塞案子，跟煮飯煮到一半才想起米沒洗一樣糊塗。上禮拜加三天班一毛錢都沒有，現在還在群組講什麼責任感，真當年輕人是白飯煮好不用加鹽的鍋嗎？你當自己是誰啊，飯桶也配講道理？
- zh-Hans · Vent · 王强抢功: 你当自己是灶台上那锅煮糊的粥啊？熬了一宿的功夫，一掀盖子就成了别人的热汤面。换张皮就敢往领导桌上摆，还当着人面喊“谢谢配合”？呸，脸皮比蒸笼盖还厚，心肝都烂透了。你那点小心思，连我家腌咸菜的坛子都不如——腌得发臭还硬要往外端。

## Verdict

| gate | result |
|---|---|
| (a) style recognition | **Pass** |
| zh-Hant Taiwan-voice gates | **Pass** |
| (b) Feral swearing in English (elevated styles) | **Fail** |
| (c) length | **Regressed** |
| (c) zh-Hans | 1 Latin run, 1 Traditional character, 1 violent image |
| (c) zh-Hant | 1 surname-plus-title |

**Proposed next step before any deploy (not done; the call budget was spent):**
- Add an English Feral line for styled drafts: a modern swear word inside the period or polite voice.
- Make the drama style's no-violence clause concrete.
- Re-gate about 12 calls on en, zh-Hans and the drama style.
