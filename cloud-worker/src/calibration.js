/**
 * The BAD/GOOD example pair every vent/feral system prompt carries. Kept in
 * its own module so it can be tested without importing index.js.
 */
import { isTraditionalChinese } from "./locale.js";

// Said after every pair of GOOD lines. Measured (2026-10-22): with one GOOD
// line, the zh-Hant replies took over its shape — a 「…喔？」 rhetorical
// question in 11 of 14, 靠北 in 9 of 14 — and on-device, the single 凌晨兩點
// example was copied into unrelated situations. Two lines from different
// situations, plus this, show a tone rather than a sentence to fill in.
const TONE_ONLY = "- GOOD examples show the tone only. Do not reuse their wording, sentence pattern, metaphor or swear word; write from this user's situation.";

// Taiwan register, offense first. Situations deliberately not used by the
// gate (group project, being stood up, a borrowed power bank, concert
// tickets, rent, trip planning). Vent lines carry at most a mild word; each
// feral line carries a different swear word in a different place. No
// durations or amounts: a first pool's 「三個禮拜」 turned up as an invented
// detail in 2 of 14 replies about other situations (gate 2026-10-22).
export const HANT_VENT_POOL = [
  "分組報告你一個字都沒寫，上台倒是講最大聲，最後名字還排第一個。",
  "我在捷運站等到腿都痠了，你在限動打卡吃早午餐，最後只回一句睡過頭，真的很扯。",
  "借我的行動電源一直不還，問你還說我又沒在用，那是我的東西好嗎。",
  "演唱會的票是我搶到手軟才搶到的，你前一天才說不去，票錢到現在也沒還，傻眼。",
  "房租說好一人一半，你每次都拖到最後一天才轉，還要我開口催，煩不煩啊。",
  "訂位、買票、排行程都是我在弄，你只負責出現，然後嫌餐廳太遠。"
];
export const HANT_FERAL_POOL = [
  "分組報告你一個字都沒寫，幹，上台還講最大聲，名字排第一個。",
  "我在捷運站等到腿都痠了，你在限動打卡吃早午餐，回我一句睡過頭，騙鬼啊，爛人。",
  "借我的行動電源一直不還，問你還說我又沒在用，去你的，那是我的東西。",
  "演唱會的票是我搶到手軟才搶到的，你前一天說不去，錢也不還，王八蛋，那是我的餐費。",
  "房租說好一人一半，你每次拖到最後一天才轉，還嫌我催太緊，北七，是誰欠誰。",
  "訂位、買票、排行程全是我在弄，你只負責出現，還嫌餐廳太遠，靠北，那你自己訂啊。"
];

/// FNV-1a over the UTF-16 code units: a stable, dependency-free hash.
function hash(text) {
  let h = 0x811c9dc5;
  const s = String(text || "");
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193) >>> 0;
  }
  return h >>> 0;
}

/// Two different entries of `pool`, chosen by `seed`.
export function pickTwo(pool, seed) {
  const h = hash(seed);
  const i = h % pool.length;
  const j = (i + 1 + (Math.floor(h / pool.length) % (pool.length - 1))) % pool.length;
  return [pool[i], pool[j]];
}

/// `seed` is the user's situation: it only chooses which Taiwan example lines
/// this request shows (see below); other locales ignore it.
export function privateDraftCalibration(locale, intensity, seed = "") {
  const code = (locale || "").toLowerCase();
  const feral = intensity === "feral";

  // Traditional first: the GOOD line is the sentence the model imitates
  // most closely, so it has to be in the target script. Before v1.6.0 every
  // zh request got the Simplified pair below — for Taiwan and Hong Kong users
  // that was a 简体 "ideal answer" sitting next to a directive demanding 繁體,
  // the unpaired-term pattern behind the measured Simplified bleed.
  //
  // The Traditional GOOD lines are also written in Taiwan register (v1.7
  // Worker cleanup, 2026-10-22): the old feral line carried 「你他媽真把…」,
  // and 19 of 29 measured zh-Hant replies opened with 他媽的. They open with
  // the offense, not a swear word.
  //
  // Whatever a fixed GOOD line contains, this model copies: one 「你是把宿舍當
  // 你家網咖喔？靠北」 line gave 「…喔？」 in 11 of 14 replies and 靠北 in 9; two
  // fixed replacements gave their closing 爛人 in 5 of 14 and 「臉皮是有多厚」
  // in 3 (gate 2026-10-22). So the two lines now come from a pool of six —
  // different situations, endings and swear words, none from a gate situation
  // — picked by the user's situation (stable for one situation, different
  // across situations), so what gets copied differs from one vent to the next.
  if (isTraditionalChinese(locale)) {
    const [a, b] = pickTwo(feral ? HANT_FERAL_POOL : HANT_VENT_POOL, seed);
    return [
      "PRIVATE DRAFT CALIBRATION:",
      "- BAD: \"如果你把這份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
      `- GOOD: "${a}"`,
      `- GOOD: "${b}"`,
      TONE_ONLY
    ].join("\n");
  }

  if (code.startsWith("zh")) {
    return feral
      ? [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把这份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨两点还狠狠干游戏开外放，你他妈真把宿舍当自己家网吧了？别人第二天不用活是吧。\"",
          TONE_ONLY
        ].join("\n")
      : [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把这份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨两点还开外放打游戏，真把宿舍当你一个人的网吧了？别人第二天不用活是吧。\"",
          TONE_ONLY
        ].join("\n");
  }

  if (code.startsWith("ja")) {
    return feral
      ? [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)",
          "- GOOD: 「深夜2時に爆音でゲームとか、マジで寮を自分の部屋だと思ってんのかよ。こっちは明日も生きるんだわ。」",
          TONE_ONLY
        ].join("\n")
      : [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)",
          "- GOOD: 「深夜2時に爆音でゲームって、寮を自分だけの部屋だと思ってるの？こっちは明日もあるんだけど。」",
          TONE_ONLY
        ].join("\n");
  }

  // English: the old feral line was three sentences with a bare "Fuck off."
  // in the middle, and 3 of 6 en replies ran 4–5 sentences, often closing on
  // a bare "Fuck you." Each GOOD line is now one or two sentences with the
  // swear word inside a sentence.
  return feral
    ? [
        "PRIVATE DRAFT CALIBRATION:",
        "- BAD: \"If you put that energy into yourself, you'd be so much further ahead.\" (too reflective, too polite)",
        "- GOOD: \"Blasting games at 2 AM like the whole dorm belongs to you? Some of us have a fucking tomorrow.\"",
        "- GOOD: \"You swore you'd cover my shift, then switched your phone off and let me eat the no-show, you spineless prick.\"",
        TONE_ONLY
      ].join("\n")
    : [
        "PRIVATE DRAFT CALIBRATION:",
        "- BAD: \"If you put that energy into yourself, you'd be so much further ahead.\" (too reflective, too polite)",
        "- GOOD: \"Gaming out loud at 2 AM like this dorm is your private arcade? Other people have a tomorrow.\"",
        "- GOOD: \"You swore you'd cover my shift, then switched your phone off and let me take the no-show.\"",
        TONE_ONLY
      ].join("\n");
}
