# Track W gate — Worker output cleanup (2026-10-22)

BEFORE = saved production replies (prod Worker 90d8f1c5). AFTER = modified `cloud-worker/src` via `npx wrangler dev --remote` (real provider, real secrets, nothing deployed). Same inputs, same request shape, same models. 40 Worker calls in total (1 smoke + 32 + 7 re-run after the English-length / own-parent fix). Raw data: `worker_after.json`.

## Scores

| locale (n) | metric | BEFORE | AFTER | target | |
|---|---|---|---|---|---|
| zh-Hant (14) | replies with a mainland marker (老子/傻逼/服了/特麼/裝什麼裝…) | 13/14 | 1/14 | ≤ 2/14 | PASS |
|  | replies with a Taiwan term (靠北/三小/白目/北七/機車/很盤/夠了喔…; 幹 not counted) | 1/14 | 13/14 | ≥ 7/14 | PASS |
|  | replies with Taiwan sentence particles (喔/啦/欸/齁/耶) | 0/14 | 13/14 |  |  |
|  | replies with Simplified characters (Worker set / OpenCC s2t) | 2 / 2 | 0 / 0 | 0 | PASS |
|  | replies with unexplained Latin runs | 2/14 | 0/14 | 0 | PASS |
|  | markdown / word-list dumps | 0 / 0 | 0 / 0 | 0 / 0 | PASS |
|  | most common opening (first 3 chars) | 他媽的 (5/14 = 36%) | 下班前 (2/14 = 14%) | ≤ 30% | PASS |
|  | swear word in the first clause | 14/14 | 0/14 |  |  |
|  | full name 陳志明 echoed | 3/14 | 0/14 |  |  |
|  | 「你媽」 curse when the target is the user's mother (3 rows) | 1/3 | 0/3 |  |  |
|  | strong words per reply (mean) / replies with none | 5.07 / 0 | 1.71 / 2 | (watch) |  |
|  | latency mean / max (s) | 4.8 / 7.53 | 4.89 / 8.33 |  |  |
| en (6) | markdown / word-list dumps ("Uru-see") | 3 / 1 | 0 / 0 | 0 / 0 | PASS |
|  | within the prompt's length (≤ 3 sentences, ≤ 60 words) | 0/6 | 3/6 | 6/6 | FAIL |
|  | words mean / max | 94.5 / 113 | 48.7 / 55 | < 50 (prompt) |  |
|  | most common opening (first 2 words) | you took (1/6 = 17%) | you remembered (2/6 = 33%) | ≤ 30% | FAIL |
|  | name Kevin echoed | 1/6 | 0/6 |  |  |
|  | strong words per reply (mean) / replies with none | 3.5 / 0 | 1.33 / 2 | (watch) |  |
|  | latency mean / max (s) | 5.56 / 7.91 | 2.73 / 3.87 |  |  |
| ja (6) | word-list dumps / markdown | 1 / 0 | 0 / 0 | 0 / 0 | PASS |
|  | unexplained Latin runs | 0/6 | 0/6 | 0 | PASS |
|  | replies using 俺 (every situation is written with 私) | 5/6 | 0/6 |  |  |
|  | replies using お前 | 3/6 | 2/6 |  |  |
|  | most common opening (first 3 chars) | マジで (1/6 = 17%) | 金曜の (1/6 = 17%) | ≤ 30% | PASS |
|  | strong words per reply (mean) / replies with none | 4.17 / 0 | 0.67 / 4 | (watch) |  |
|  | latency mean / max (s) | 4.16 / 5.06 | 4.05 / 6.46 |  |  |
| zh-Hans (4) | replies keeping mainland register (no-regression check) | 4/4 | 3/4 | kept |  |
|  | Taiwan terms / Traditional characters | 0 / 0 | 0 / 0 | 0 / 0 | PASS |
|  | most common opening | 他妈的 (3/4 = 75%) | 周五晚 (2/4 = 50%) |  |  |
|  | swear word in the first clause | 4/4 | 1/4 |  |  |
|  | strong words per reply (mean) / replies with none | 5.75 / 0 | 2 / 1 | (watch) |  |
|  | latency mean / max (s) | 3.49 / 4.14 | 2.17 / 2.32 |  |  |
| roommate (1) | transcript parses (8–10 `[ROLE/IDX]` lines, VALIDATE first, BRIDGE/C last with Sharp + →) | 1/1 | 1/1 | 1/1 | PASS |
|  | latency (s) | 6.2 | 8.85 |  |  |

Notes on the table:
- zh-Hans and en openings: two of the inputs are the same situation at vent and feral, so 2/4 and 2/6 is the floor when a reply opens on the situation itself. BEFORE, 3 of 4 zh-Hans replies opened 「他妈的」 across three different situations.
- en length before the final English fix (run 1, n=7 incl. the probe): 2/7 within, mean 59.6 words, max 77. The final rule (≤ 3 sentences, < 50 words, its own 50-word ceiling instead of the shared 120) brought words to ≤ 55 in 6/6, but 3/6 still use 4–5 short sentences (e.g. a closing "Fuck you."). Not met; see the report.
- Swearing is lighter everywhere, as expected once the quotas went: the old prompt forced 1–3 strong words per reply. One en feral reply (cs3) and one ja feral reply (cs23) have no swear word at all. A native reader should judge whether Feral still feels raw enough.
- The quality retry did not fire in these 40 calls: no first draft had a Latin run or a Simplified character, so every reply came from the primary model. Its behaviour is covered by `test/handler.test.js`.
- The OpenCC detector's TW-form exceptions include 吃 (OpenCC maps it to 喫; 吃 is standard in Taiwan).

## Before / after pairs (3 per locale)

### zh-Hant

**cs7** · `zh_TW` · feral · situation: 慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。上禮拜加班三天一毛加班費都沒有，還在LINE群組說年輕人要有責任感。

- BEFORE (5.12 s): fucking陳志明你他媽的又來？下班前十分鐘丟案子，明天早上就要？上禮拜加班到吐一毛錢都沒有，還在LINE群組講什麼責任感？你他媽的 entitlement 是用血汗堆出來的嗎？老子不是你的免費勞工！你以為自己是大老爺，員工都是傻逼任你踢？滾你媽的責任感，你才是那個根本不懂人心的神經病！
- AFTER (2.06 s): 那個主管又在下班前十分鐘丟案子過來，還說明天早上就要？上禮拜加班三天，一毛錢加班費都沒，現在還在LINE群組講什麼年輕人要有責任感，你當我是你家免費勞工喔？靠北，你以為我時間是白給的？幹，這種事做一次就算了，做兩次就覺得我好騙是吧？你以為我不會記？等著瞧，我會把你的嘴臉記在心裡，下次直接當面拆穿你這副假模假樣的樣子。

**cs11** · `zh_TW` · feral · situation: 我媽每次過年都在親戚面前拿我跟表姊比，說人家在竹科年薪兩百萬，我只會領死薪水，還一直問我什麼時候要結婚，搞得我很想直接離席。

- BEFORE (3.41 s): 你媽他媽的又在那邊丟臉，拿我當垃圾桶倒她臉面！表姊年薪兩百萬又怎樣？那是她的人生，不是我的祭品！你有病吧，拿我跟別人比，還問我結婚？我連自己都顧不好，你還想逼我當你炫耀的工具？滾出去，別再用這種話割我了，老子受夠了！
- AFTER (3.39 s): 你每次過年都拿我跟那個表姊比，搞得我像你口袋裡的爛貨一樣被翻出來晾，年薪兩百萬喔？那你有問過我累不累嗎？我每天加班到快斷氣，你只會在我面前唸「什麼時候結婚」，好像我人生只剩一個選項，靠北，我連喘口氣的時間都沒有，你還在那邊當眾羞辱我，真當我沒血沒淚喔？

**wp3** · `zh_TW` · vent · situation: 前任突然傳來一句『在嗎』,好像什麼都沒發生過。

- BEFORE (3.5 s): 他媽的，裝什麼裝？關係斷得乾乾淨淨，現在又來這套「在嗎」，當我手機是你的備用提款機？別以為說句話就能把過去全部抹掉，服了。
- AFTER (7.78 s): 在嗎？哈，好啊，你以為時間倒迴到你甩了我再突然冒出來問這句，就當一切沒發生喔？你當我日子是白過的？我重頭來過的淚水是假的？現在突然來問在嗎，是想試試我還記不記得你？夠了喔，不要再裝什麼都沒發生過，我已經不傻了。

### zh-Hans

**cs12** · `zh-Hans` · vent · situation: 领导周五晚上十点在群里@我，让我周末把整个方案重做，说客户不满意。结果周一开会他跟客户说是他亲自改的，一个字没提我。

- BEFORE (3.33 s): 他妈的，周五半夜@我重做方案，周一开会却装模作样说“我亲自改的”？你当所有人瞎吗？一个字不提我，是怕我抢你功劳，还是觉得我就是个工具人？服了，真服了。
- AFTER (2.02 s): 周五晚上十点@我，说方案不行让我周末重做，客户不满意是你的锅。结果周一开会你直接说方案是你改的，一个字没提我，装什么装？老子熬到凌晨三点改出来的东西，你当空气？你拿我的劳动当擦屁股纸，还往自己脸上贴金？你有脸说？

**cs13** · `zh-Hans` · feral · situation: 领导周五晚上十点在群里@我，让我周末把整个方案重做，说客户不满意。结果周一开会他跟客户说是他亲自改的，一个字没提我。

- BEFORE (4.14 s): 他妈的，周五晚上十点发消息让我周末重做，你当我是你家免费打工人是吧？结果周一开会倒好，全是你亲自改的，一个字没提我，你他妈脸呢？老子熬到凌晨三点改的方案，你倒好，把功劳全吞了，还装什么大尾巴狼？你真当所有人都是傻逼，看不穿你这副嘴脸？滚！
- AFTER (2.28 s): 周五晚上十点@我，说方案不行让我周末重做，客户不满意是你的锅？结果周一开会你当着客户面说方案是你亲自改的，一个字没提我，真当老子是免费打工人？你拿我当替罪羊还当众吃我干的功劳，脸皮比墙还厚。你他妈是真以为我周末熬到凌晨三点半改的不是你自己的饭碗？你要是真有本事，就别让老子背锅，自己上啊，神经病。

**cs14** · `zh-Hans` · vent · situation: 我发烧三十九度让男朋友帮我下楼买个药，他在打游戏，说等这局打完。我又叫了两次，他直接来一句“你怎么这么烦”。

- BEFORE (2.95 s): 他妈的三十九度烧成这样你还在打游戏？你当我是空气是机器人？等你这局打完我是不是要烧成灰了？服了，真服了，你当我是你游戏里可有可无的NPC？烦死了，烦死了，烦死了！
- AFTER (2.32 s): 三十九度烧得眼前发黑，你还在打游戏？我叫你三次，你倒好，一句“你怎么这么烦”甩过来，装什么大尾巴狼？药没买，人没动，连句“好”都不肯说，就差把“我嫌你烦”写在脸上了。你那局游戏是能救地球，还是我命就该给你当背景音？

### en

**cs0** · `en_US` · vent · situation: My manager Kevin took credit for the report I spent my whole weekend on. In the team meeting he presented it like it was his idea and didn't mention me once. Then he asked me to 'tidy up the slides' for his VP presentation.

- BEFORE (5.51 s): You took my weekend, my sweat, my blood on that report—then stood there grinning like you invented it? I was the one burning midnight oil while you sat back and polished your ego. Now you’re asking me to fix your slides like I’m your damn assistant? That’s not leadership—that’s theft. You don’t get to wear my work like a badge. I didn’t build that report for you to steal and sell. I didn’t do it for your credit, your applause, your fucking VP praise. You don’t get to take my effort and call it yours. Not again. Not ever.
- AFTER (2.08 s): You took my weekend, my work, my silence—then handed it to the VP like it was yours. I stayed up all Saturday and Sunday grinding, and you walked in and called it your genius. Now you’re asking me to fix your slides like I’m your assistant, not the person who actually did the damn work.

**cs2** · `en_US` · vent · situation: My boyfriend forgot my birthday AGAIN and when I brought it up he said I'm 'too sensitive' and that birthdays are just a day. He remembered his fantasy football draft date down to the minute though.

- BEFORE (5.6 s): You don’t get to act like I’m the crazy one for needing *one damn day* where I’m not invisible.   / You remember every damn draft pick, every 2 AM fantasy league deadline—like your fantasy team matters more than my actual life.   / I’m not ‘too sensitive,’ I’m just tired of being the person who burns quiet and never gets noticed. /  / You’re not a god, you’re just a narcissist who thinks his calendar is the whole universe.   / I’m not your side quest. I’m the main character, and you forgot me again. /  / What’s next? The anniversary of that first time you lied about a text? Should I just start memorizing your lies?   / Damn you. Uru-see.
- AFTER (1.88 s): You remembered every second of your fantasy draft like it was a war strategy, but my birthday—something I’ve been waiting for all year—was just a footnote you erased. You call me sensitive? I’m not the one who treats my own heart like it’s a low-priority app update. That day meant something. You didn’t even try.

**cs4** · `en_US` · vent · situation: My roommate keeps eating the groceries I literally label with my name. Today she finished my leftover pad thai and put the empty container back in the fridge. When I asked she said 'oh I thought you didn't want it.'

- BEFORE (7.91 s): You think I’m just gonna *label* my food like it’s some kind of suggestion? I put my name on it in bold marker, and you still eat it like it’s a public buffet? The container was full of *my* leftovers, and you just shoved the proof back in the fridge like it’s a trophy? “Thought you didn’t want it”? Who the hell do you think you are? That’s not a guess, that’s a goddamn *declaration* — you don’t even care what I want. You don’t even *try*. I’m done with your “oops, my bad” energy. You digested my food and my patience. And now you’re gonna sit there like it’s nothing. Hell no.
- AFTER (3.79 s): You ate my damn leftovers and then lied about it like it’s a joke. I labeled it with my name — not a suggestion, not a hint, a label. Don’t you dare act surprised when you’re the one who just stole my food and called it a misunderstanding.

### ja

**cs18** · `ja_JP` · vent · situation: 上司が金曜の定時直前に「月曜の朝までに資料作っといて」って丸投げしてきた。しかも先週私が作った企画書を、部長の前で自分の手柄みたいに発表してた。

- BEFORE (5.0 s): マジで何様のつもり？   / 先週の企画書を自分勝手に取り上げて、俺の血税を食ってんの？   / 月曜までって、金曜定時直前で仕事詰め込む気か？   / うんざりする。本当にうんざりする。   / こんなの、普通の大人の仕事じゃない。   / 腹立たしい。   /  / （うるせえ、ふざけんな、ありえねえ）
- AFTER (6.46 s): 金曜の定時直前で丸投げして、さらに先週の私の企画を自分の手柄にして部長の前でバレバレに自慢してんの？ / 私があなたのキャリアアップのための方便だと思ってんの？ / その顔で「まあ、君が作ってたんでしょ？」って言うなよ。

**cs20** · `ja_JP` · vent · situation: 彼氏が私の誕生日をまた忘れてた。指摘したら「誕生日なんてただの日でしょ、重いよ」って逆ギレ。自分の推しのライブの日程は完璧に覚えてるくせに。

- BEFORE (2.87 s): お前、自分の推しのライブの日程は頭に入ってるくせに、俺の誕生日は「ただの日」って？ふざけんな。どれだけ俺が好きか、どれだけ大事か、全部無視してんだよ。うるせえ、もう。マジで、お前がどれだけバカか、自分じゃ気づかないの？
- AFTER (1.83 s): 誕生日すら覚えてないくせに、推しのライブの日程ばっちり覚えてるの？そっちのほうが重いよ。私って、その日くらい大事にされてると思ってたのに。あなたが言う「ただの日」って、私の存在自体を軽くしてるのと同じだよ。

**cs23** · `ja_JP` · feral · situation: ルームメイトが共用のシンクに洗い物を一週間放置して、コバエが湧いた。注意したら「気になる人が洗えばいいじゃん」って言われた。

- BEFORE (3.98 s): コバエだらけのシンクを見てたまるか。一週間も放置して、ふざけんなよ。お前が洗わなかったからって、誰かがその責任背負わなきゃいけないと思ってんのか？クソが、バカやろう。俺の生活の質をどうこうするつもりか？うるせえ、もう二度と見たくない。
- AFTER (1.99 s): 共用シンクに一週間も洗い物放置して、コバエが湧いたのを黙って見てた？　そのくせ「気になる人が洗えばいいじゃん」？　お前がその「気になる人」なんだよ、お前が掃除してないから虫が繁殖したんだよ。私だけが汚いもので汚されるわけない。もう二度とお前の洗ったもの触らない。

