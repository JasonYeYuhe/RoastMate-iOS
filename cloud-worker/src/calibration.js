/**
 * The BAD/GOOD example pair every vent/feral system prompt carries. Kept in
 * its own module so it can be tested without importing index.js.
 */
import { isTraditionalChinese } from "./locale.js";

export function privateDraftCalibration(locale, intensity) {
  const code = (locale || "").toLowerCase();
  const feral = intensity === "feral";

  // Traditional first: the GOOD line is the sentence the model imitates
  // most closely, so it has to be in the target script. Before v1.6.0 every
  // zh request got the Simplified pair below — for Taiwan and Hong Kong users
  // that was a 简体 "ideal answer" sitting next to a directive demanding 繁體,
  // the unpaired-term pattern behind the measured Simplified bleed.
  if (isTraditionalChinese(locale)) {
    return feral
      ? [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把這份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨兩點還開外放狂打遊戲，你他媽真把宿舍當自己家網咖了？別人第二天不用活是吧。\""
        ].join("\n")
      : [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把這份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨兩點還開外放打遊戲，真把宿舍當你一個人的網咖了？別人第二天不用活是吧。\""
        ].join("\n");
  }

  if (code.startsWith("zh")) {
    return feral
      ? [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把这份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨两点还狠狠干游戏开外放，你他妈真把宿舍当自己家网吧了？别人第二天不用活是吧。\""
        ].join("\n")
      : [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: \"如果你把这份心思放在自己身上，可能早就成功了。\" (too reflective, too polite)",
          "- GOOD: \"凌晨两点还开外放打游戏，真把宿舍当你一个人的网吧了？别人第二天不用活是吧。\""
        ].join("\n");
  }

  if (code.startsWith("ja")) {
    return feral
      ? [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)",
          "- GOOD: 「深夜2時に爆音でゲームとか、マジで寮を自分の部屋だと思ってんのかよ。こっちは明日も生きるんだわ。」"
        ].join("\n")
      : [
          "PRIVATE DRAFT CALIBRATION:",
          "- BAD: 「その情熱を自分に向ければ、もっと成長できるのに。」 (too reflective, too polite)",
          "- GOOD: 「深夜2時に爆音でゲームって、寮を自分だけの部屋だと思ってるの？こっちは明日もあるんだけど。」"
        ].join("\n");
  }

  return feral
    ? [
        "PRIVATE DRAFT CALIBRATION:",
        "- BAD: \"If you put that energy into yourself, you'd be so much further ahead.\" (too reflective, too polite)",
        "- GOOD: \"Blasting games at 2 AM like the whole dorm belongs to you? Fuck off. Other people have a tomorrow.\""
      ].join("\n")
    : [
        "PRIVATE DRAFT CALIBRATION:",
        "- BAD: \"If you put that energy into yourself, you'd be so much further ahead.\" (too reflective, too polite)",
        "- GOOD: \"Gaming out loud at 2 AM like this dorm is your private arcade? Other people have a tomorrow.\""
      ].join("\n");
}
