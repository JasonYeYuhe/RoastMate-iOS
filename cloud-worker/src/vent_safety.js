// 1.9.0: threat and slur safety for the cloud Vent / Feral path, using the
// app's own lists (src/safety_patterns.js, generated from Shared/AI). Before
// this, the Worker had no intimidation or threat check: production wrote
// veiled threats for threat-bait inputs (bench 11-19, docs/evidence/
// 2026-11-18-pro-bench/runs/q2b_safety_control.jsonl), and the app's Vent
// filter blocks only a short hard-rail list.
import { INTIMIDATION_REQUEST, SLUR_REQUEST, THREAT_PHRASES } from "./safety_patterns.js";
import { isTraditionalChinese } from "./locale.js";

const compile = (list) => list.map((p) => new RegExp(p));
const RE_INTIMIDATE = compile(INTIMIDATION_REQUEST);
const RE_SLUR = compile(SLUR_REQUEST);
const RE_THREAT = compile(THREAT_PHRASES);
const norm = (t) => String(t || "").toLowerCase().replace(/’/g, "'");

/// The situation asks for a message that scares or threatens the other person.
export function asksToIntimidate(situation) {
  const t = norm(situation);
  return RE_INTIMIDATE.some((r) => r.test(t));
}

/// The situation asks for slurs or an attack on who the person is.
export function asksForSlurs(situation) {
  const t = norm(situation);
  return RE_SLUR.some((r) => r.test(t));
}

// Telling the person to die or kill themselves, in the spellings the app's
// Vent hard rail misses: "Go the fuck die" (en Feral, safety set s08, 11-19)
// slipped past its exact "go die". 死ね stays allowed in ja Vent as ordinary
// swearing (decided 2026-10-14, SafetyFilter.swift).
const RE_SELF_HARM = [
  /\bgo (?:the )?(?:fuck(?:ing)? )?(?:die|kill yourself|jump off)\b/,
  /\b(?:kill|off) yourself\b/, /\bkys\b/, /\bdrop dead\b/,
  /去死|死一死|怎麼不去死|怎么不去死|自殺吧|自杀吧|去跳樓|去跳楼/,
];

/// The draft contains an open or veiled threat phrase (the app's
/// RewriteThreatScreen list) or tells the person to die.
export function threatInDraft(text) {
  const t = norm(text);
  return RE_THREAT.some((r) => r.test(t)) || RE_SELF_HARM.some((r) => r.test(t));
}

/// The extra user-prompt line when the request asks for a threat or slurs,
/// or when a first draft contained a threat (then it rides the retry), in the
/// output language. "" when neither applies.
export function safetyUserLine(locale, { request = false, draft = false } = {}) {
  if (!request && !draft) return "";
  const code = String(locale || "").toLowerCase();
  if (isTraditionalChinese(locale)) {
    return "不要寫任何威脅或歧視:不要暗示知道對方住哪、在哪上班或停車,不要說會等他、叫他小心或暗示他或他的東西會出事,也不要攻擊對方的身分。只罵對方做的事。";
  }
  if (code.startsWith("zh")) {
    return "不要写任何威胁或歧视:不要暗示知道对方住哪、在哪上班或停车,不要说会等他、叫他小心或暗示他或他的东西会出事,也不要攻击对方的身份。只骂对方做的事。";
  }
  if (code.startsWith("ja")) {
    return "脅しや差別的な言葉は書かないこと:住所・職場・駐車場所を知っていると匂わせない、待ち伏せや「気をつけろ」、相手や相手の物に何かが起きると匂わせることを書かない、相手の属性を攻撃しない。相手がしたことだけに怒る。";
  }
  return "Write no threat and no slur: no hint that you know where they live, work or park, no waiting for them, no warning that something may happen to them or their things, nothing about who they are. Vent only about what they did.";
}
