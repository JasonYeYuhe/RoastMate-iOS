// The output-language lines every prompt ends with (vent, roommate, roast).
// Moved verbatim out of index.js so they can be unit-tested without the
// Worker runtime; test/language.test.js pins their exact text, because the
// roommate transcript prompt (parsed by the app's EchoesParser) uses them too.
import { isTraditionalChinese } from "./locale.js";

export function languageDirective(locale) {
  const code = (locale || "").toLowerCase();
  if (isTraditionalChinese(locale)) {
    // Measured 2026-09-03: the sendable eval found simplified-character bleed
    // in 6 of 24 zh-Hant cells, including one response written ENTIRELY in
    // Simplified. The old directive was a single sentence — materially weaker
    // than the zh-Hans one, which already carried the "even if the rest of the
    // prompt is English" reinforcement, and it never actually forbade
    // simplified characters. The examples below are the exact characters that
    // leaked, which gives the model something concrete to check against.
    return "OUTPUT LANGUAGE (REQUIRED): 必須全程使用「繁體中文」回覆。"
         + "即使本提示其他部分是英文，你的回覆也必須完全使用繁體中文。"
         + "嚴禁出現任何簡體字（例如「说、让、经、义、认、这、个、时、会、门、问、发」等），"
         + "每一個字都必須是繁體寫法（說、讓、經、義、認、這、個、時、會、門、問、發）。";
  }
  if (code.startsWith("zh")) {
    return "OUTPUT LANGUAGE (REQUIRED): 必须用「简体中文」回复。即使本提示其它部分是英文,你的回复也必须完全使用简体中文。";
  }
  if (code.startsWith("ja")) {
    return "OUTPUT LANGUAGE (REQUIRED): 必ず日本語で回答してください。";
  }
  if (code.startsWith("ko")) {
    return "OUTPUT LANGUAGE (REQUIRED): 반드시 한국어로 답변하세요.";
  }
  return "OUTPUT LANGUAGE (REQUIRED): Reply entirely in English.";
}

export function userLanguageReminder(locale) {
  const code = (locale || "").toLowerCase();
  if (isTraditionalChinese(locale)) return "請以繁體中文回覆，全文不得出現簡體字。";
  if (code.startsWith("zh")) return "请用简体中文回复。";
  if (code.startsWith("ja")) return "日本語で回答してください。";
  if (code.startsWith("ko")) return "한국어로 답변해 주세요.";
  return "Reply in English.";
}
