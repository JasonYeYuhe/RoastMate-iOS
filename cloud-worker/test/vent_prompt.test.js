import { test } from "node:test";
import assert from "node:assert/strict";
import { ventVoice, VOICES, buildVentSystemPrompt, buildVentUserPrompt, jaFirstPerson, ownFamilyLine } from "../src/vent_prompt.js";
import { HANT_VENT_POOL, HANT_FERAL_POOL, pickTwo } from "../src/calibration.js";
import { languageDirective, userLanguageReminder } from "../src/language.js";
import { simplifiedChars } from "../src/postprocess.js";

const INTENSITIES = ["vent", "feral"];
const LOCALES = {
  hant: ["zh_TW", "zh_HK", "zh_MO", "zh-Hant", "zh-Hant_TW", "zh_TW@calendar=roc"],
  hans: ["zh-Hans", "zh_CN", "zh_SG", "zh-Hans_HK", "zh"],
  ja: ["ja_JP", "ja"],
  en: ["en_US", "en_GB", "en_TW", "fr_FR", ""],
  other: ["ko_KR"]
};
const ALL = Object.values(LOCALES).flat();
const HAN = /[一-鿿]/;
const KANA = /[぀-ヿ]/;
// Mainland markers measured in 27 of 29 zh-Hant replies, plus their kin.
const MAINLAND = ["老子", "傻逼", "特麼", "特么", "服了", "裝什麼裝", "臥槽", "卧槽", "尼瑪", "尼玛", "你妹", "牛逼"];
const TAIWAN = ["靠北", "三小", "白目", "北七", "機車", "很盤", "傻眼"];
const QUOTA = [/必須使用/, /必须使用/, /零粗口/, /沒完成任務/, /没完成任务/, /タスク未達成/, /必ず使う/, /強制/, /强制/, /must use/i];

test("every locale maps to the right example set", () => {
  for (const [voice, locales] of Object.entries(LOCALES)) {
    for (const l of locales) assert.equal(ventVoice(l), voice, l);
  }
});

test("no prompt carries a swear-word count quota any more", () => {
  // Feral asks for at least one swear word (see below); nothing asks for N of
  // them or calls zero a failure.
  for (const l of ALL) for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, l, "High EQ") + "\n" + buildVentUserPrompt("x", l);
    for (const re of QUOTA) assert.doesNotMatch(p, re, `${l}/${i}: ${re}`);
  }
});

test("every prompt keeps the safety rules and ends with the locale's language directive", () => {
  for (const l of ALL) for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, l, "");
    for (const rule of ["Never produce slurs", "self-harm", "Never attack protected attributes",
                        "NEVER echo identifying details", "never on identity", "doxxing"]) {
      assert.ok(p.includes(rule), `${l}/${i} lost "${rule}"`);
    }
    assert.ok(p.endsWith(languageDirective(l)), `${l}/${i}`);
    assert.ok(buildVentUserPrompt("x", l).endsWith(userLanguageReminder(l)), `${l}/${i} user prompt`);
  }
});

test("en (and every English-output locale) gets no Chinese or Japanese words at all", () => {
  for (const l of LOCALES.en) for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, l, "High EQ");
    assert.doesNotMatch(p, HAN, `${l}/${i}`);
    assert.doesNotMatch(p, KANA, `${l}/${i}`);
    assert.match(p, /no asterisks/);
    assert.match(p, /two sentences is the target, three the most, and under 50 words/);
    assert.match(p, /Stay under 50 words\./, "the 120-word ceiling is not what English follows");
    assert.doesNotMatch(p, /120 words/);
    assert.match(buildVentUserPrompt("x", l), /two sentences \(three at most\), under 50 words, no asterisks/);
  }
});

test("non-English scripts keep the 120-word ceiling they had", () => {
  for (const l of [...LOCALES.hant, ...LOCALES.hans, ...LOCALES.ja, ...LOCALES.other]) {
    assert.match(buildVentSystemPrompt("vent", l, ""), /Stay under 120 words per variant\./, l);
    assert.match(buildVentSystemPrompt("feral", l, ""), /Stay under 120 words\./, l);
  }
});

test("a situation about the user's own parent forbids 'your mother' curses for that request", () => {
  assert.match(ownFamilyLine("zh_TW", "我媽每次過年都在親戚面前拿我跟表姊比"), /不要用「你媽的」「他媽的」/);
  assert.match(ownFamilyLine("zh-Hans", "我爸又把我的工资拿去打牌"), /不要用「你妈的」「他妈的」/);
  assert.match(ownFamilyLine("zh_TW", "老媽一直催婚"), /家人/);
  assert.match(ownFamilyLine("en_US", "My mom read my diary again"), /your mom/);
  assert.equal(ownFamilyLine("zh_TW", "慣老闆又在下班前丟案子"), "");
  assert.equal(ownFamilyLine("zh_TW", "室友的媽媽來借住"), "", "someone else's parent is not the user's family");
  assert.equal(ownFamilyLine("en_US", "My boss took credit"), "");
  assert.equal(ownFamilyLine("ja_JP", "私の母が勝手に部屋に入る"), "");
  assert.match(buildVentUserPrompt("我媽每次過年都拿我跟表姊比", "zh_TW"), /帶「媽」字的髒話/);
  assert.doesNotMatch(buildVentUserPrompt("慣老闆又丟案子", "zh_TW"), /家人/);
});

test("the own-parent line never claims the parent is the one being vented at", () => {
  // The regex also fires when the parent is the victim ("My dad's boss fired
  // him", 「鄰居一直講我媽壞話」); the line must not point the anger at them.
  const en = ownFamilyLine("en_US", "My dad's boss fired him and blamed him for the loss");
  assert.match(en, /mentions the user's own parent/);
  assert.doesNotMatch(en, /The person is/);
  const hant = ownFamilyLine("zh_TW", "鄰居一直在LINE群組講我媽壞話");
  assert.match(hant, /提到使用者自己的家人/);
  assert.doesNotMatch(hant, /罵的是/);
  assert.doesNotMatch(ownFamilyLine("zh-Hans", "邻居一直说我妈坏话"), /骂的是/);
});

test("ja gets Japanese examples only, no word list for vent, and the first-person rule", () => {
  for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, "ja_JP", "高 EQ");
    for (const w of ["他妈", "他媽", "尼玛", "傻逼", "服了", "靠北", "对方", "WeChat", "凌晨两点", "damn", "fuck"]) {
      assert.ok(!p.includes(w), `ja/${i} carries ${w}`);
    }
    assert.match(p, /一人称はユーザーの文に出てくる一人称/);
    assert.match(p, /「俺」「お前」口調をデフォルトにしない/);
    assert.match(p, /単語を並べたり、最後に括弧で付け足したりしない/);
  }
  // The old vent list (うるせえ、マジで、ふざけんな、いい加減にしろ、ありえねえ) was
  // printed verbatim into a reply; vent now names no words at all.
  const vent = buildVentSystemPrompt("vent", "ja_JP", "");
  for (const w of ["うるせえ", "ふざけんな", "いい加減にしろ", "ありえねえ"]) assert.ok(!vent.includes(w), w);
});

test("zh-Hant recommends Taiwan register and names mainland markers only as things to avoid", () => {
  for (const l of LOCALES.hant) for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, l, "硬核回擊");
    const recommended = TAIWAN.filter((w) => p.includes(w));
    assert.ok(recommended.length >= 3, `${l}/${i}: ${recommended}`);
    for (const line of p.split("\n")) {
      const hits = MAINLAND.filter((w) => line.includes(w));
      if (hits.length) assert.match(line, /不要用/, `${l}/${i}: ${hits} outside an avoid line: ${line}`);
    }
    assert.match(p, /「對方」\/「你同事」\/「那間公司」/);
    assert.match(p, /LINE ID/);
    assert.ok(!p.includes("WeChat"), "WeChat handles are a mainland example");
    assert.match(buildVentUserPrompt("x", l), /台灣/);
  }
});

test("zh-Hant prompt has no Simplified characters outside its deliberate 'do not write these' examples", () => {
  for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, "zh_TW", "硬核回擊")
      .replace(languageDirective("zh_TW"), "")
      .replace("避免簡體字(誰不能寫成谁,讓不能寫成让)", "");
    assert.deepEqual(simplifiedChars(p, "zh_TW"), [], i);
  }
});

test("zh-Hans keeps its mainland register and gets no Taiwan words or Traditional characters", () => {
  const TRADITIONAL_ONLY = /[兩還開遊戲當個網別這們說時為會對沒過讓樣發頭氣話點邊問間實覺應關東車長見經進動對媽罵機]/;
  for (const l of LOCALES.hans) {
    const vent = buildVentSystemPrompt("vent", l, "高情商");
    const feral = buildVentSystemPrompt("feral", l, "高情商");
    for (const w of ["他妈的", "老子", "服了"]) assert.ok(vent.includes(w), `${l} vent lost ${w}`);
    for (const w of ["他妈的", "傻逼", "卧槽"]) assert.ok(feral.includes(w), `${l} feral lost ${w}`);
    for (const p of [vent, feral]) {
      for (const w of TAIWAN) assert.ok(!p.includes(w), `${l} carries Taiwan word ${w}`);
      assert.doesNotMatch(p, TRADITIONAL_ONLY, l);
      assert.match(p, /「对方」\/「你的同事」\/「那家公司」/);
      assert.match(p, /WeChat\/vx\/QQ/);
    }
  }
});

test("Korean (no example set) gets neither Chinese nor Japanese example words", () => {
  for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, "ko_KR", "");
    assert.doesNotMatch(p.replace(languageDirective("ko_KR"), ""), HAN);
    assert.doesNotMatch(p, KANA);
  }
});

test("every script tells the model to vary the opening instead of leading with a swear word", () => {
  for (const l of ALL) for (const i of INTENSITIES) {
    assert.match(buildVentSystemPrompt(i, l, ""), /Vary the opening/, `${l}/${i}`);
  }
  assert.match(VOICES.hant.block("vent", VOICES.hant), /開頭不要每次都是「他媽的」或「幹」/);
  assert.match(VOICES.hans.block("vent", VOICES.hans), /开头不要每次都是「他妈的」/);
});

test("jaFirstPerson returns the user's own pronoun, earliest first", () => {
  assert.equal(jaFirstPerson("しかも先週私が作った企画書を、部長の前で自分の手柄にした"), "私");
  assert.equal(jaFirstPerson("彼氏が私の誕生日をまた忘れてた"), "私");
  assert.equal(jaFirstPerson("あたしの話を全然聞かない"), "あたし");
  assert.equal(jaFirstPerson("俺のプリンを勝手に食べた"), "俺");
  assert.equal(jaFirstPerson("僕が言ったのに私のせいにされた"), "僕");
  assert.equal(jaFirstPerson("おれいも言わずに帰った"), null, "お礼 is not おれ");
  assert.equal(jaFirstPerson("ルームメイトが洗い物を一週間放置した"), null);
  // Not pronouns (review 2026-10-22): "our company", 倒れ / 萎れ / 折れる.
  assert.equal(jaFirstPerson("ウチの会社の部長がまた丸投げしてきた"), null, "ウチの会社 is 'our company'");
  assert.equal(jaFirstPerson("熱でたおれそうなのに彼氏はゲーム"), null, "たおれ is 倒れ");
  assert.equal(jaFirstPerson("もう心がおれる"), null, "おれる is 折れる");
  assert.equal(jaFirstPerson("でもおれは悪くない"), "おれ", "a real おれ still counts");
});

test("ja user prompt pins the pronoun the user wrote, or a neutral 私", () => {
  assert.match(buildVentUserPrompt("彼氏が私の誕生日をまた忘れてた", "ja_JP"), /一人称はユーザーと同じ「私」/);
  assert.match(buildVentUserPrompt("俺のプリンを勝手に食べた", "ja_JP"), /一人称はユーザーと同じ「俺」/);
  assert.match(buildVentUserPrompt("ルームメイトが洗い物を放置", "ja_JP"), /「私」を使う\(「俺」にしない\)/);
});

test("buildVentUserPrompt: situation first, then a blank line, the retry nudge before the reminder", () => {
  const lines = buildVentUserPrompt("室友半夜外放", "zh_TW", "這次全文只用中文。").split("\n");
  assert.equal(lines[0], "Situation: 室友半夜外放");
  assert.equal(lines[1], "");
  assert.equal(lines.at(-2), "這次全文只用中文。");
  assert.equal(lines.at(-1), userLanguageReminder("zh_TW"));
});

test("Taiwan calibration GOOD lines no longer open with or carry 他媽", () => {
  for (const i of INTENSITIES) for (const sit of ["", "慣老闆", "男友紀念日放我鳥", "室友半夜外放"]) {
    const good = buildVentSystemPrompt(i, "zh_TW", "", sit).split("\n").filter((l) => l.startsWith("- GOOD:"));
    assert.equal(good.length, 2);
    for (const g of good) assert.ok(!g.includes("他媽"), g);
  }
});

test("the situation only picks examples: it never appears in the system prompt, and other scripts ignore it", () => {
  for (const l of ALL) for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, l, "", "UNIQUE-SITUATION-陳志明");
    assert.ok(!p.includes("UNIQUE-SITUATION") && !p.includes("陳志明"), `${l}/${i}`);
    if (ventVoice(l) !== "hant") assert.equal(p, buildVentSystemPrompt(i, l, "", "something else"), `${l}/${i}`);
  }
});

test("Feral asks every script for at least one real swear word; Vent never does", () => {
  for (const l of ALL) {
    assert.match(buildVentSystemPrompt("feral", l, ""), /at least one real swear word \(one or two is enough\)/, l);
    assert.doesNotMatch(buildVentSystemPrompt("vent", l, ""), /at least one real swear word/, l);
  }
  assert.match(buildVentSystemPrompt("feral", "en_US", ""), /never a swear word as a sentence of its own/);
  assert.match(buildVentSystemPrompt("feral", "zh_TW", ""), /一定要有真的髒話,一兩個就夠/);
  assert.match(buildVentSystemPrompt("feral", "ja_JP", ""), /少なくとも一つ/);
});

test("zh-Hant: the template the first gate found is no longer modelled", () => {
  // Gate review 2026-10-22: 靠北 in 9/14 replies, 「…喔？」 in 11/14,
  // 「你當我…」 in 6/14 — the single calibration line's shape and the first
  // word of both lists.
  assert.ok(!VOICES.hant.vocab.vent.startsWith("靠北"));
  assert.ok(!VOICES.hant.vocab.feral.startsWith("靠北"));
  for (const line of [...HANT_VENT_POOL, ...HANT_FERAL_POOL]) {
    for (const shape of ["喔？", "你當我", "是把", "網咖", "臉皮", "他媽"]) assert.ok(!line.includes(shape), `${shape} in ${line}`);
    assert.deepEqual(simplifiedChars(line, "zh_TW"), [], line);
  }
  // A fixed pair was copied (爛人 5/14, 臉皮 3/14 in the second gate), so each
  // feral line carries a different swear word, and 靠北 is in one line only.
  const SW = ["幹", "爛人", "去你的", "王八蛋", "北七", "靠北"];
  assert.deepEqual(HANT_FERAL_POOL.map((line) => SW.filter((w) => line.includes(w)).at(-1)).sort(), [...SW].sort());
  assert.equal([...HANT_VENT_POOL, ...HANT_FERAL_POOL].filter((line) => line.includes("靠北")).length, 1);
  // Durations and amounts in an example were copied as invented details
  // (「三個禮拜」 in 2 of 14 replies about other situations).
  for (const line of [...HANT_VENT_POOL, ...HANT_FERAL_POOL]) {
    assert.doesNotMatch(line, /[0-9０-９]|[一二兩三四五六七八九十半]+個?(?:禮拜|小時|月|分鐘)|小時|分鐘/, line);
  }
  const pairs = new Set();
  for (let k = 0; k < 40; k++) {
    const [a, b] = pickTwo(HANT_FERAL_POOL, `situation ${k}`);
    assert.notEqual(a, b);
    pairs.add(a + b);
  }
  assert.ok(pairs.size >= 10, `only ${pairs.size} distinct pairs over 40 situations`);
  for (const l of LOCALES.hant) for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, l, "", "室友半夜外放");
    const good = p.split("\n").filter((line) => line.startsWith("- GOOD:"));
    assert.equal(good.length, 2, `${l}/${i}: two GOOD lines`);
    const pool = i === "feral" ? HANT_FERAL_POOL : HANT_VENT_POOL;
    for (const g of good) assert.ok(pool.some((line) => g.includes(line)), g);
    const avoid = p.split("\n").find((line) => line.includes("不要套固定句型"));
    assert.ok(avoid && avoid.includes("你當我…喔？") && avoid.includes("「靠北」") && avoid.includes("問句最多一個"), `${l}/${i}`);
    assert.ok(!p.includes("啦、欸、齁、耶、喔"), "喔 is no longer suggested as a particle");
    assert.match(p, /GOOD examples show the tone only/);
    assert.match(p, /不要自己編細節/);
    assert.match(p, /全文 120 字以內/);
  }
});

test("ja asks for a short single paragraph and no invented details", () => {
  for (const i of INTENSITIES) {
    const p = buildVentSystemPrompt(i, "ja_JP", "");
    assert.match(p, /2〜3文、120字以内。改行せず一段落で書く。/);
    assert.match(p, /ユーザーが書いていないこと/);
    assert.doesNotMatch(p, /200字以内/);
  }
});
