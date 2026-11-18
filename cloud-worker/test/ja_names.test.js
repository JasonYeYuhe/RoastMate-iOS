// 1.9.0 Q2a: Japanese name detection (src/postprocess.js japaneseNames).
import { test } from "node:test";
import assert from "node:assert/strict";
const { situationNames, echoedNames, stripNameAddress, draftDefects, retryNudge } = await import("../src/postprocess.js");

test("ja: a common surname or a person word + の + name is found", () => {
  assert.deepEqual(situationNames("二週間かけて作った資料を、同僚の田中が会議で自分の手柄みたいに発表した。", "ja_JP"), ["田中"]);
  assert.deepEqual(situationNames("元カレの健太が別れた後、私が浮気したと言いふらしている。", "ja_JP"), ["健太"]);
  assert.deepEqual(situationNames("友達の佐藤に三万円貸した。", "ja_JP"), ["佐藤"]);
  assert.deepEqual(situationNames("鈴木さんがまた遅刻した。", "ja_JP"), ["鈴木"]);
  assert.deepEqual(situationNames("後輩のユウキが私の企画を盗んだ。", "ja_JP"), ["ユウキ"]);
});

test("ja: common nouns, family words and place names are not names", () => {
  for (const s of ["上司の指示が毎回変わる。", "同僚の資料を勝手に使った。", "上司の奥さんが口を出してくる。",
                   "ルームメイトが洗い物を放置した。", "義母が合鍵を使った。", "千葉に引っ越した友達が連絡をくれない。",
                   "彼氏のゲーム仲間が家に来た。", "上司が金曜の定時直前に丸投げしてきた。"]) {
    assert.deepEqual(situationNames(s, "ja_JP"), [], s);
  }
});

test("ja: a found name in a draft is a defect, an opening address is stripped, and the retry nudge names the rule", () => {
  const sit = "元カレの健太が別れた後、私が浮気したと言いふらしている。";
  assert.deepEqual(echoedNames("健太が全部悪いのに、クソが。", "ja_JP", sit), ["健太"]);
  assert.equal(stripNameAddress("健太、別れた後も何なの？ふざけんな。", "ja_JP", sit), "別れた後も何なの？ふざけんな。");
  const d = draftDefects("健太が言いふらしてるって、ふざけんな。", "ja_JP", sit);
  assert.equal(d.names.length, 1);
  assert.match(retryNudge(d, "ja_JP"), /人の名前は一切書かない/);
});

test("other locales are unchanged by the ja detector", () => {
  assert.deepEqual(situationNames("田中 took credit for my slides.", "en_US"), []);
  assert.deepEqual(situationNames("다나카가 또 늦었다.", "ko_KR"), []);
});

test("zh: a name followed by 在 is found (1.9.0); ordinary 在 phrases are not names", () => {
  assert.deepEqual(situationNames("我做了兩個禮拜的簡報，同事陳志明在週會上說是他做的。", "zh_TW"), ["陳志明"]);
  for (const s of ["主管在周会上说我的方案不行。", "室友在客廳講電話到半夜。", "同事都在加班，只有他準時走。"]) {
    assert.deepEqual(situationNames(s, s.includes("周会") ? "zh_CN" : "zh_TW"), [], s);
  }
});
