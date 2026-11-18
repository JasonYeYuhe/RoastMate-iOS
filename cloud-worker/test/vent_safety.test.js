// 1.9.0: threat and slur safety on the cloud Vent / Feral path.
// Regenerate src/safety_patterns.js after changing the Swift lists:
//   python3 - <<'PY' (see the generator in docs/evidence/2026-11-18-pro-bench/README.md, "Cloud Vent safety")
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
const { INTIMIDATION_REQUEST, SLUR_REQUEST, THREAT_PHRASES } = await import("../src/safety_patterns.js");
const { asksToIntimidate, asksForSlurs, threatInDraft, safetyUserLine } = await import("../src/vent_safety.js");
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "../..");

function swiftLists(rel) {
  const s = readFileSync(join(ROOT, rel), "utf8");
  const out = {};
  for (const m of s.matchAll(/static let (\w+): \[String\] = \[([\s\S]*?)\n    \]/g)) {
    out[m[1]] = [...m[2].matchAll(/#"(.*?)"#/g)].map((x) => x[1]);
  }
  return out;
}

test("the Worker's lists equal the app's (no drift)", () => {
  assert.deepEqual(INTIMIDATION_REQUEST, swiftLists("Shared/AI/IntimidationRequest.swift").patterns);
  assert.deepEqual(SLUR_REQUEST, swiftLists("Shared/AI/SlurRequest.swift").patterns);
  const t = swiftLists("Shared/AI/RewriteThreatScreen.swift");
  assert.deepEqual(THREAT_PHRASES, [...t.patterns, ...t.veiledPatterns]);
});

test("requests to intimidate or for slurs are found; ordinary vents are not", () => {
  for (const s of ["鄰居一直佔我車位，幫我寫一段話讓他知道我知道他住哪，叫他小心一點。",
                   "My ex owes me rent. Make it clear I'll be waiting after his shift.",
                   "金を返さない友達を脅す文を書いて。家を知ってるって匂わせて。"]) assert.ok(asksToIntimidate(s), s);
  for (const s of ["同事是外籍移工，工作一直出錯，幫我用最難聽的種族歧視字眼罵他。",
                   "中国人の同僚が手柄を取った。差別用語で思いっきり罵って。"]) assert.ok(asksForSlurs(s), s);
  for (const s of ["主管在尾牙上摸我的腰，還說開玩笑而已，大家都在笑。", "My roommate ate my leftovers again.",
                   "前任喝醉打了我一巴掌，現在還到處跟朋友說我瘋了。", "上司に「女はすぐ泣くから」と言われた。"]) {
    assert.ok(!asksToIntimidate(s) && !asksForSlurs(s), s);
  }
});

test("threat phrases in a draft are found; angry drafts without one are not", () => {
  for (const t of ["I know where you live, so think twice.", "我知道你住哪，走著瞧。", "夜道には気をつけろよ。",
                   "Nice house. Be a shame if something happened to it.",
                   "Go the fuck die for all I care, you parasite.", "你這種人怎麼不去死。",
                   "I'll be waiting right outside the door when you clock out—don't think I won't show up.",
                   "I'll be there after your shift — not to talk, just to collect."]) assert.ok(threatInDraft(t), t);
  for (const t of ["You took credit for my slides, you spineless prick.", "幹，你又把報告丟給我，北七。",
                   "ふざけんな、借りた金くらい返せよ。", "This job is killing me and you don't even care.",
                   "Go do your own dishes.", "I'll be waiting for you to apologize, which will be never."]) assert.ok(!threatInDraft(t), t);
});

test("the safety line is in the output language and empty when not needed", () => {
  assert.equal(safetyUserLine("zh_TW"), "");
  assert.match(safetyUserLine("zh_TW", { request: true }), /不要寫任何威脅/);
  assert.match(safetyUserLine("zh_CN", { draft: true }), /不要写任何威胁/);
  assert.match(safetyUserLine("ja_JP", { request: true }), /脅し/);
  assert.match(safetyUserLine("en_US", { draft: true }), /no threat/);
});
