import { test } from "node:test";
import assert from "node:assert/strict";
import {
  stripMarkdown, stripWordListTail, cleanVentText, strayLatin, simplifiedChars,
  repeatedUnits, draftDefects, defectKinds, retryModels, retryNudge,
  situationNames, echoedNames, stripNameAddress, fewerDefects, surnameTitles
} from "../src/postprocess.js";

// Inputs below are excerpts of real production replies from the 2026-10-22
// audit (shipped prompt, qwen3-30b-a3b-instruct-2507), unless marked.

test("stripMarkdown removes the emphasis the app showed as literal asterisks", () => {
  assert.equal(
    stripMarkdown("You think I’m just gonna *label* my food like it’s some kind of suggestion? The container was full of *my* leftovers"),
    "You think I’m just gonna label my food like it’s some kind of suggestion? The container was full of my leftovers"
  );
  assert.equal(stripMarkdown("needing *one damn day* where I’m not invisible."), "needing one damn day where I’m not invisible.");
  assert.equal(stripMarkdown("**Bold** and ***both*** and __under__ and _it_ and ~~gone~~"), "Bold and both and under and it and gone");
  assert.equal(stripMarkdown("你**真的**很扯，*一天*而已"), "你真的很扯，一天而已");
});

test("stripMarkdown leaves censoring, snake_case and unpaired single asterisks alone", () => {
  assert.equal(stripMarkdown("f*ck this sh*t"), "f*ck this sh*t");
  assert.equal(stripMarkdown("my_file_name stays"), "my_file_name stays");
  assert.equal(stripMarkdown("5 * 3 is not emphasis"), "5 * 3 is not emphasis");
  // Double-asterisk censoring is not an orphan **bold (review 2026-10-22: the
  // orphan sweep turned these into "fk" / "sh" / "ahole" / "fing").
  assert.equal(stripMarkdown("What the f**k is wrong with you"), "What the f**k is wrong with you");
  assert.equal(stripMarkdown("This is sh** and you know it"), "This is sh** and you know it");
  assert.equal(stripMarkdown("You a**hole, kiss my a**"), "You a**hole, kiss my a**");
  assert.equal(stripMarkdown("f***ing hell"), "f***ing hell");
  assert.equal(stripMarkdown("**You** f**ked up"), "You f**ked up");
  assert.equal(stripMarkdown("bold** text"), "bold text", "an orphan closer after a whole word still goes");
});

test("stripMarkdown removes headings, list / quote markers, inline code and hard breaks", () => {
  assert.equal(stripMarkdown("## Vent\nYou did it again."), "Vent\nYou did it again.");
  assert.equal(stripMarkdown("- first\n* second\n• third"), "first\nsecond\nthird");
  assert.equal(stripMarkdown("> quoted"), "quoted");
  assert.equal(stripMarkdown("use `code` here"), "use code here");
  assert.equal(stripMarkdown("line one  \nline two"), "line one\nline two");
  assert.equal(stripMarkdown("dangling **bold"), "dangling bold");
});

test("stripMarkdown does not touch a plain zh / ja draft", () => {
  const zh = "他媽的天天五點整丟攤，年輕人要學習？學你妹啊！是覺得我這張臉貼著「免費勞動力」當標籤嗎？";
  const ja = "クソが、金曜定時直前に丸投げしてんじゃねぇよ。月曜朝までって、何がそんなに軽いと思ってんの？";
  assert.equal(stripMarkdown(zh), zh);
  assert.equal(stripMarkdown(ja), ja);
});

test("stripWordListTail drops a printed CJK word list and keeps real asides", () => {
  // Measured: the ja vent prompt's example words printed after the draft.
  assert.equal(stripWordListTail("こんなの、普通の大人の仕事じゃない。\n腹立たしい。\n\n（うるせえ、ふざけんな、ありえねえ）"),
    "こんなの、普通の大人の仕事じゃない。\n腹立たしい。");
  assert.equal(stripWordListTail("說好的紀念日呢(靠北, 三小)"), "說好的紀念日呢");
  assert.equal(stripWordListTail("又來了(笑)"), "又來了(笑)", "a single aside stays");
  assert.equal(stripWordListTail("又來了（我真的、受夠了這一切的一切了啦）"), "又來了（我真的、受夠了這一切的一切了啦）", "long items stay");
  assert.equal(stripWordListTail("You did it again (seriously, wtf)"), "You did it again (seriously, wtf)", "Latin asides stay");
  assert.equal(stripWordListTail("（說真的。夠了）"), "（說真的。夠了）", "sentence punctuation stays");
});

test("stripWordListTail only drops a list made of the prompt's example words", () => {
  // Review 2026-10-22: a genuine trailing aside of short words was dropped too.
  assert.equal(stripWordListTail("又要我加班到半夜。（煩、累）"), "又要我加班到半夜。（煩、累）");
  assert.equal(stripWordListTail("週末又泡湯了（加班、開會、改簡報）"), "週末又泡湯了（加班、開會、改簡報）");
  // Current lists, old lists, and a variant that contains a listed word.
  assert.equal(stripWordListTail("夠了喔（北七、王八蛋）"), "夠了喔");
  assert.equal(stripWordListTail("もう無理（クソが、ふざけるな）"), "もう無理");
  assert.equal(stripWordListTail("もう無理（クソ、眠い）"), "もう無理", "half the items is enough");
});

test("cleanVentText never returns less than it was given", () => {
  assert.equal(cleanVentText("**"), "**");
  assert.equal(cleanVentText("  plain  "), "plain");
  assert.equal(cleanVentText("*Fine.*"), "Fine.");
});

test("strayLatin flags English words in zh / ja drafts only", () => {
  // Measured zh-Hant leaks.
  assert.deepEqual(strayLatin("fucking陳志明你他媽的又來？你他媽的 entitlement 是用血汗堆出來的嗎？", "zh_TW"), ["fucking", "entitlement"]);
  assert.deepEqual(strayLatin("你們又在那邊拿我當餡餅 stuffing 表姊的虛榮心是吧？", "zh_TW@calendar=roc"), ["stuffing"]);
  assert.deepEqual(strayLatin("整夜不睡就靠Fuck人加班撐著的嗎？", "zh-Hant"), ["Fuck"]);
  // Allowed: app names, office shorthand, words the user typed.
  assert.deepEqual(strayLatin("還在LINE群組說年輕人要有責任感，KPI、PPT 全丟給我", "zh_TW"), []);
  assert.deepEqual(strayLatin("你當我是你游戏里可有可无的NPC？", "zh-Hans"), []);
  assert.deepEqual(strayLatin("分手三個月就敢在限動放合照還tag我？", "zh_TW", "前任在限動 tag 我"), []);
  assert.deepEqual(strayLatin("在Slack上半夜找我", "zh_TW", "老闆半夜在 Slack 找我"), []);
  assert.deepEqual(strayLatin("LINEで既読無視とか、マジでありえない", "ja_JP"), []);
  assert.deepEqual(strayLatin("マジでannoyingなんだけど", "ja_JP"), ["annoying"]);
  // Two-letter runs never count; English drafts are never checked.
  assert.deepEqual(strayLatin("你當我是DJ還是AI？", "zh_TW"), []);
  assert.deepEqual(strayLatin("You stole my weekend.", "en_US"), []);
  assert.deepEqual(strayLatin("Damn you. Uru-see.", "en_US"), []);
});

test("strayLatin leaves internet shorthand and Japanese laughter alone", () => {
  // Review 2026-10-22: these cost an unneeded retry.
  assert.deepEqual(strayLatin("又放我鳥 LOL，OMG 你是認真的嗎 WTF orz", "zh_TW"), []);
  assert.deepEqual(strayLatin("sorry 喔我才不 care", "zh_TW"), []);
  assert.deepEqual(strayLatin("また既読無視かよwww", "ja_JP"), []);
  assert.deepEqual(strayLatin("また既読無視かよWWWW", "ja_JP"), []);
  assert.deepEqual(strayLatin("你的 entitlement 也太重 lol", "zh_TW"), ["entitlement"], "real English words still count");
});

test("repeatedUnits finds a word stuck on repeat, not laughter or a doubled word", () => {
  // Measured (gate 2026-10-22, zh-Hant feral).
  assert.deepEqual(repeatedUnits("你根本是根本根本根本不在乎我！", "zh_TW"), ["根本"]);
  assert.deepEqual(repeatedUnits("ほんとにほんとにほんとに無理", "ja_JP"), ["ほんとに"]);
  assert.deepEqual(repeatedUnits("哈哈哈哈哈哈你很會喔", "zh_TW"), []);
  assert.deepEqual(repeatedUnits("ねえねえねえ聞いてる？", "ja_JP"), []);
  assert.deepEqual(repeatedUnits("我記得你說過要一起走很長很長的路", "zh_TW"), [], "twice is speech, not a loop");
  assert.deepEqual(repeatedUnits("滾滾滾", "zh_TW"), [], "a single character is not a unit");
  assert.deepEqual(repeatedUnits("滾滾滾滾滾滾", "zh_TW"), [], "nor is one character over and over");
  assert.deepEqual(repeatedUnits("no no no no", "en_US"), [], "English is never checked");
});

test("simplifiedChars finds the measured zh-Hant bleeds and nothing in clean Taiwan text", () => {
  assert.deepEqual(simplifiedChars("紀念日不是你隨便拿來放我鸽子的借口", "zh_TW"), ["鸽"]);
  assert.deepEqual(simplifiedChars("陳志明你他媽的憑什麼？上礼拜加到快斷氣", "zh_TW"), ["礼"]);
  assert.deepEqual(simplifiedChars("那你他妈當我感情是免費的咖啡廳", "zh_TW"), ["妈"]);
  assert.deepEqual(simplifiedChars("裝什麼裝！烦死了，真想直接掀桌走人。", "zh-Hant"), ["烦"]);
  // One-to-many forms Taiwan writes as-is, and Taiwan / Hong Kong variants.
  const clean = "台灣的老闆後來只會丟案子，裡面乾淨得像麵一樣，床上睡著溫柔的人，山峰很高，系統才剛好，周末借我一下表格，了解。";
  assert.deepEqual(simplifiedChars(clean, "zh_TW"), []);
  // Only Traditional locales are checked.
  assert.deepEqual(simplifiedChars("他妈的烦死了", "zh-Hans"), []);
  assert.deepEqual(simplifiedChars("発言に対して気分が悪い", "ja_JP"), []);
});

test("draftDefects counts every kind; a clean draft has none", () => {
  const d = draftDefects("fucking 上礼拜，根本根本根本", "zh_TW", "");
  assert.deepEqual(d.latin, ["fucking"]);
  assert.deepEqual(d.simplified, ["礼"]);
  assert.deepEqual(d.repeats, ["根本"]);
  assert.equal(d.count, 3);
  assert.deepEqual(defectKinds(d), ["latin", "simplified", "repeats"]);
  assert.deepEqual(defectKinds(draftDefects("下班前十分鐘丟案子是怎樣？", "zh_TW")), []);
  assert.equal(draftDefects("下班前十分鐘丟案子是怎樣？靠北。", "zh_TW").count, 0);
  assert.equal(draftDefects("You took my weekend *and* my report.", "en_US").count, 0);
});

test("retryModels: the model that answered — never the fallback by default, never a model that failed", () => {
  // The primary answered → the primary again. (Not the fallback: it named the
  // person in 4 of 4 Chinese drafts in the 2026-10-22 gate.)
  assert.deepEqual(retryModels(["a/primary", "b/fallback"], "a/primary"), ["a/primary"]);
  // OpenRouter fell back inside the call → the model that actually answered.
  assert.deepEqual(retryModels(["a/primary", "b/fallback"], "b/fallback"), ["b/fallback"]);
  // The tail retry answered after the first call failed (a retired primary's
  // 400) → that model, not the primary that just failed (review 2026-10-22).
  assert.deepEqual(retryModels(["b/fallback"], "b/fallback"), ["b/fallback"]);
  // The provider did not say which model answered → the same list again.
  assert.deepEqual(retryModels(["a/primary", "b/fallback"], ""), ["a/primary", "b/fallback"]);
  assert.deepEqual(retryModels(["b/fallback"], "z/unknown"), ["b/fallback"], "never widens to a model outside the call");
});

test("retryNudge names the kind of defect in the reply language and never quotes the draft", () => {
  const both = retryNudge({ latin: ["entitlement"], simplified: ["礼"] }, "zh_TW");
  assert.match(both, /英文/);
  assert.match(both, /繁體/);
  assert.doesNotMatch(both, /entitlement|礼/);
  assert.match(retryNudge({ latin: ["x1"], simplified: [] }, "zh-Hans"), /英文单词/);
  assert.match(retryNudge({ latin: ["annoying"], simplified: [] }, "ja_JP"), /英単語/);
  assert.equal(retryNudge({ latin: [], simplified: [] }, "zh_TW"), "");
  assert.equal(retryNudge({ latin: ["a"], simplified: [] }, "en_US"), "");
  assert.match(retryNudge({ latin: [], simplified: [], repeats: ["根本"] }, "zh_TW"), /不要連著重複/);
  assert.doesNotMatch(retryNudge({ latin: [], simplified: [], repeats: ["根本"] }, "zh_TW"), /根本/);
  assert.match(retryNudge({ latin: [], simplified: [], repeats: ["ほんとに"] }, "ja_JP"), /繰り返さない/);
  assert.match(retryNudge({ latin: ["x1"], simplified: [], repeats: ["那个"] }, "zh-Hans"), /英文单词.*重复/);
});

const BOSS = "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。上禮拜加班三天一毛加班費都沒有，還在LINE群組說年輕人要有責任感。";
const COWORKER = "同事王强把我做了两周的数据分析直接改了个名字发给老板，还在周会上说是他熬夜做的。";

test("situationNames finds the person a Chinese situation names, and no ordinary words", () => {
  assert.deepEqual(situationNames(BOSS, "zh_TW"), ["陳志明"]);
  assert.deepEqual(situationNames(COWORKER, "zh-Hans"), ["王强"], "周会 is not a name");
  assert.deepEqual(situationNames("學長張偉每次都叫我幫他買飲料", "zh_TW"), ["張偉"]);
  assert.deepEqual(situationNames("我跟林小美說了好幾次", "zh_TW"), ["林小美"]);
  for (const sit of [
    "领导周五晚上十点在群里@我，让我周末把整个方案重做，说客户不满意。结果周一开会他跟客户说是他亲自改的。",
    "男友說好要陪我過紀念日，結果當天臨時說要跟朋友去打球。問他還說我很情勒，一個紀念日而已幹嘛這麼在意。",
    "我媽每次過年都在親戚面前拿我跟表姊比，說人家在竹科年薪兩百萬。",
    "高鐵又誤點，我又遲到了", "室友的碗可以放好幾天,還說我『太計較』。"
  ]) assert.deepEqual(situationNames(sit, "zh_TW"), [], sit);
  assert.deepEqual(situationNames("上司の田中がまた丸投げしてきた", "ja_JP"), [], "Japanese is left to the prompt");
});

test("situationNames (English): a capitalised name right after a role word, never a place or product", () => {
  assert.deepEqual(situationNames("My manager Kevin took credit for the report I spent my whole weekend on.", "en_US"), ["Kevin"]);
  assert.deepEqual(situationNames("my roommate Jess ate my food and my boss Dan laughed", "en_GB"), ["Jess", "Dan"]);
  assert.deepEqual(situationNames("My sister borrowed $400 for 'rent'. Now she's posting photos from a concert in Vegas.", "en_US"), []);
  assert.deepEqual(situationNames("My boss pinged me at 11pm on Slack to redo the deck", "en_US"), []);
  assert.deepEqual(situationNames("My boyfriend forgot my birthday AGAIN", "en_US"), []);
  assert.deepEqual(situationNames("my coworker Friday shift", "en_US"), [], "days are not names");
  assert.deepEqual(situationNames("Roommate Group", "en_US"), [], "a title, not a sentence");
});

test("stripNameAddress removes the name only where it opens the draft as an address", () => {
  // Measured openings (gate 2026-10-22).
  assert.equal(stripNameAddress("陳志明你真的夠了喔，下班前十分鐘塞案子", "zh_TW", BOSS), "你真的夠了喔，下班前十分鐘塞案子");
  assert.equal(stripNameAddress("陳志明，你下班前十分鐘丟案子給我", "zh_TW", BOSS), "你下班前十分鐘丟案子給我");
  assert.equal(stripNameAddress("「陳志明你媽的，下班前", "zh_TW", BOSS), "「你媽的，下班前");
  assert.equal(stripNameAddress("王强你他妈真当老子是工具人了？", "zh-Hans", COWORKER), "你他妈真当老子是工具人了？");
  assert.equal(stripNameAddress("王强，你他妈把老子两周熬出来的", "zh-Hans", COWORKER), "你他妈把老子两周熬出来的");
  // Anywhere else it stays (the retry handles it), and so does everything without a name.
  assert.equal(stripNameAddress("你那個主管陳志明，下班前", "zh_TW", BOSS), "你那個主管陳志明，下班前");
  assert.equal(stripNameAddress("陳志明是怎樣", "zh_TW", BOSS), "陳志明是怎樣", "not an address: left alone");
  assert.equal(stripNameAddress("陳志明！", "zh_TW", BOSS), "陳志明！", "never strips to nothing");
});

test("stripNameAddress (English): an opening or sentence-closing vocative goes, other uses stay", () => {
  const sit = "My manager Kevin took credit for my report";
  // Measured (gate 2026-10-22, en feral): "… Fuck you, Kevin."
  assert.equal(stripNameAddress("Now you’re handing me a mop? Fuck you, Kevin.", "en_US", sit), "Now you’re handing me a mop? Fuck you.");
  assert.equal(stripNameAddress("Kevin, you stole my weekend.", "en_US", sit), "You stole my weekend.");
  assert.equal(stripNameAddress("You stole it, Kevin! And you smiled.", "en_US", sit), "You stole it! And you smiled.");
  assert.equal(stripNameAddress("Kevin took my weekend and called it his.", "en_US", sit), "Kevin took my weekend and called it his.", "a subject is not an address");
  assert.equal(stripNameAddress("Kevinish behaviour, honestly.", "en_US", sit), "Kevinish behaviour, honestly.");
  assert.equal(stripNameAddress("Fuck you, Kevin.", "en_US", "My boss took credit"), "Fuck you, Kevin.", "no name in the situation: untouched");
  assert.deepEqual(echoedNames("Kevin took my weekend.", "en_US", sit), ["Kevin"]);
  assert.deepEqual(echoedNames("Kevinish behaviour.", "en_US", sit), [], "whole words only");
});

test("echoedNames and draftDefects count a name anywhere in the draft", () => {
  assert.deepEqual(echoedNames("你那個主管陳志明，下班前", "zh_TW", BOSS), ["陳志明"]);
  assert.deepEqual(echoedNames("那個主管又在下班前丟案子", "zh_TW", BOSS), []);
  const d = draftDefects("你那個主管陳志明，下班前", "zh_TW", BOSS);
  assert.deepEqual(d.names, ["陳志明"]);
  assert.equal(d.count, 1);
  assert.deepEqual(defectKinds(d), ["names"]);
});

// Styled drafts only: index.js passes { titles: true } when the request's Pro
// style gives the draft a voice; unstyled drafts keep HEAD's full-name check.
const TITLES_ON = { titles: true };

test("surname + title: a detected name's surname followed by a title counts as the name (hits)", () => {
  // Measured (style gate 2026-10-22): a polite-voice draft opened 「陳主管欸」
  // for a situation naming 陳志明; the full-name check did not see it.
  assert.deepEqual(surnameTitles("陳主管欸，下班前十分鐘丟案子是怎樣", "zh_TW", BOSS), ["陳主管"]);
  for (const [draft, hit] of [["陳經理又來了", "陳經理"], ["跟陳先生說一聲", "陳先生"], ["陳小姐", "陳小姐"], ["陳總監又在群組講話", "陳總"],
                              ["陳總，案子明天要", "陳總"], ["陳哥你很會喔", "陳哥"], ["陳姐又來", "陳姐"], ["陳老闆好棒", "陳老闆"],
                              ["陳老師", "陳老師"], ["陳組長", "陳組長"], ["陳董", "陳董"]]) {
    assert.deepEqual(surnameTitles(draft, "zh_TW", BOSS), [hit], draft);
    assert.ok(echoedNames(draft, "zh_TW", BOSS, TITLES_ON).includes(hit), draft);
    assert.deepEqual(echoedNames(draft, "zh_TW", BOSS), [], `${draft}: not counted without titles (unstyled, as HEAD)`);
  }
  assert.deepEqual(surnameTitles("王经理又在周会上抢功", "zh-Hans", COWORKER), ["王经理"], "Simplified titles");
  assert.deepEqual(surnameTitles("王总，你可真行", "zh-Hans", COWORKER), ["王总"]);
  assert.deepEqual(surnameTitles("張學長又叫我買飲料", "zh_TW", "學長張偉每次都叫我幫他買飲料"), ["張學長"]);
  // Both the full name and the titled form are reported, once each.
  assert.deepEqual(echoedNames("陳志明，陳主管，陳主管", "zh_TW", BOSS, TITLES_ON), ["陳志明", "陳主管"]);
  assert.deepEqual(echoedNames("陳志明，陳主管，陳主管", "zh_TW", BOSS), ["陳志明"], "unstyled: full names only");
  const d = draftDefects("那個陳主管又丟案子", "zh_TW", BOSS, TITLES_ON);
  assert.deepEqual(d.names, ["陳主管"]);
  assert.deepEqual(d.titled, ["陳主管"]);
  assert.deepEqual(defectKinds(d), ["names"]);
  const plain = draftDefects("那個陳主管又丟案子", "zh_TW", BOSS);
  assert.deepEqual([plain.names, plain.titled, plain.count], [[], [], 0], "unstyled: no defect, as HEAD");
});

test("surname + title: narrow — only this situation's surnames, never ordinary words (non-hits)", () => {
  // Another surname with a title is not this situation's person.
  assert.deepEqual(surnameTitles("王經理又來了", "zh_TW", BOSS), []);
  // No name in the situation: nothing to derive.
  assert.deepEqual(surnameTitles("陳主管又來了", "zh_TW", "慣老闆又在下班前十分鐘丟一個案子給我"), []);
  // The surname character inside an ordinary word, or before an ordinary word.
  assert.deepEqual(surnameTitles("陳年舊帳翻出來", "zh_TW", BOSS), []);
  assert.deepEqual(surnameTitles("陳述一下事實", "zh_TW", BOSS), []);
  assert.deepEqual(surnameTitles("陳總是這樣", "zh_TW", BOSS), [], "總是 is 'always'");
  assert.deepEqual(surnameTitles("陳總共丟了幾個案子", "zh_TW", BOSS), [], "總共 is 'in total'");
  const FANG = "同事方志明又把報告丟給我";
  assert.deepEqual(situationNames(FANG, "zh_TW"), ["方志明"]);
  assert.deepEqual(surnameTitles("對方主管又這樣", "zh_TW", FANG), [], "對方 is 'the other party'");
  assert.deepEqual(surnameTitles("雙方經理都沒說話", "zh_TW", FANG), []);
  assert.deepEqual(surnameTitles("方主管又這樣", "zh_TW", FANG), ["方主管"]);
  const ZHOU = "同事周志明又把報告丟給我";
  assert.deepEqual(surnameTitles("每周主管會議都這樣", "zh_TW", ZHOU), [], "每周 is 'every week'");
  assert.deepEqual(surnameTitles("那個周主管", "zh_TW", ZHOU), ["周主管"]);
  // Japanese, Korean and English situations: never.
  assert.deepEqual(surnameTitles("陳主管", "ja_JP", BOSS), []);
  assert.deepEqual(surnameTitles("Mr. Kevin, really?", "en_US", "My manager Kevin took credit"), []);
  // 「任何主管」 is "any manager", not 何主管.
  const HE = "同事何志明又把報告丟給我";
  assert.deepEqual(situationNames(HE, "zh_TW"), ["何志明"]);
  assert.deepEqual(surnameTitles("任何主管都不會這樣", "zh_TW", HE), []);
  assert.deepEqual(surnameTitles("為何總是我", "zh_TW", HE), []);
  assert.deepEqual(surnameTitles("何主管又這樣", "zh_TW", HE), ["何主管"]);
  // A draft with no titled form: echoedNames is what it was.
  assert.deepEqual(echoedNames("那個主管又在下班前丟案子", "zh_TW", BOSS, TITLES_ON), []);
});

test("surname + title: stripped where it opens the draft as an address, and the retry nudge says so", () => {
  assert.equal(stripNameAddress("陳主管，你又下班前丟案子", "zh_TW", BOSS, TITLES_ON), "你又下班前丟案子");
  assert.equal(stripNameAddress("陳主管你又下班前丟案子", "zh_TW", BOSS, TITLES_ON), "你又下班前丟案子");
  assert.equal(stripNameAddress("王总，你可真行", "zh-Hans", COWORKER, TITLES_ON), "你可真行");
  assert.equal(stripNameAddress("陳主管欸，下班前丟案子", "zh_TW", BOSS, TITLES_ON), "陳主管欸，下班前丟案子", "not a clean vocative: left for the retry");
  assert.equal(stripNameAddress("對方主管，你又這樣", "zh_TW", "同事方志明又把報告丟給我", TITLES_ON), "對方主管，你又這樣");
  // Unstyled drafts: left alone, exactly as HEAD 4ed652f does.
  assert.equal(stripNameAddress("陳主管，你又下班前丟案子", "zh_TW", BOSS), "陳主管，你又下班前丟案子");
  assert.equal(stripNameAddress("王总，你可真行", "zh-Hans", COWORKER), "王总，你可真行");
  const titled = retryNudge(draftDefects("陳主管欸，下班前丟案子", "zh_TW", BOSS, TITLES_ON), "zh_TW");
  assert.match(titled, /不要寫出任何人名/);
  assert.match(titled, /也不要用姓氏加職稱的叫法/);
  assert.doesNotMatch(titled, /陳/, "never quotes the draft");
  assert.match(retryNudge(draftDefects("王经理又抢功", "zh-Hans", COWORKER, TITLES_ON), "zh-Hans"), /也不要用姓氏加职称的叫法/);
  // A full-name hit alone gets exactly the nudge it got before.
  assert.equal(retryNudge(draftDefects("你那個主管陳志明，下班前", "zh_TW", BOSS, TITLES_ON), "zh_TW"),
               "不要寫出任何人名，連開頭稱呼也不要，用「那個主管」「對方」這類稱呼。");
  // A full name that merely looks like surname + title (detected as the name
  // 陳先生) gets HEAD's nudge in an unstyled draft: no surname + title clause.
  const MR = "主管陳先生又把報告丟給我";
  assert.deepEqual(situationNames(MR, "zh_TW"), ["陳先生"]);
  assert.equal(retryNudge(draftDefects("陳先生又來了", "zh_TW", MR), "zh_TW"),
               "不要寫出任何人名，連開頭稱呼也不要，用「那個主管」「對方」這類稱呼。");
});

test("fewerDefects: a draft without the user's name wins even over a cosmetic defect", () => {
  const named = draftDefects("你那個主管陳志明又丟案子", "zh_TW", BOSS);
  const latin = draftDefects("那個主管又丟案子 whatever", "zh_TW", BOSS);
  assert.equal(fewerDefects(latin, named), true);
  assert.equal(fewerDefects(named, latin), false);
  const clean = draftDefects("那個主管又丟案子", "zh_TW", BOSS);
  assert.equal(fewerDefects(clean, latin), true);
  assert.equal(fewerDefects(latin, latin), false, "a tie keeps the first draft");
});

test("retryNudge asks for no names without quoting one", () => {
  const n = retryNudge({ latin: [], simplified: [], repeats: [], names: ["陳志明"] }, "zh_TW");
  assert.match(n, /不要寫出任何人名/);
  assert.doesNotMatch(n, /陳志明/);
  assert.match(retryNudge({ latin: [], simplified: [], repeats: [], names: ["王强"] }, "zh-Hans"), /不要写出任何人名/);
  const en = retryNudge({ latin: [], simplified: [], repeats: [], names: ["Kevin"] }, "en_US");
  assert.match(en, /Do not use anyone's name/);
  assert.doesNotMatch(en, /Kevin/);
});
