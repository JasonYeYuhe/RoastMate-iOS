import { test } from "node:test";
import assert from "node:assert/strict";
import { languageDirective, userLanguageReminder } from "../src/language.js";

// These two helpers moved verbatim out of index.js (v1.7 Worker cleanup). The
// roommate transcript prompt — whose [ROLE/IDX] lines the app's EchoesParser
// reads — and the roast prompt end with them, so their exact text is pinned
// here. The strings are what HEAD 029ca48's index.js produced.

const HANT_DIRECTIVE = "OUTPUT LANGUAGE (REQUIRED): 必須全程使用「繁體中文」回覆。即使本提示其他部分是英文，你的回覆也必須完全使用繁體中文。嚴禁出現任何簡體字（例如「说、让、经、义、认、这、个、时、会、门、问、发」等），每一個字都必須是繁體寫法（說、讓、經、義、認、這、個、時、會、門、問、發）。";
const HANS_DIRECTIVE = "OUTPUT LANGUAGE (REQUIRED): 必须用「简体中文」回复。即使本提示其它部分是英文,你的回复也必须完全使用简体中文。";

test("languageDirective is byte-for-byte what index.js produced before the move", () => {
  const expected = {
    "zh-Hans": HANS_DIRECTIVE,
    zh_CN: HANS_DIRECTIVE,
    zh_TW: HANT_DIRECTIVE,
    "zh-Hant": HANT_DIRECTIVE,
    zh_HK: HANT_DIRECTIVE,
    ja_JP: "OUTPUT LANGUAGE (REQUIRED): 必ず日本語で回答してください。",
    ko_KR: "OUTPUT LANGUAGE (REQUIRED): 반드시 한국어로 답변하세요.",
    en_US: "OUTPUT LANGUAGE (REQUIRED): Reply entirely in English.",
    fr_FR: "OUTPUT LANGUAGE (REQUIRED): Reply entirely in English.",
    "": "OUTPUT LANGUAGE (REQUIRED): Reply entirely in English."
  };
  for (const [locale, line] of Object.entries(expected)) {
    assert.equal(languageDirective(locale), line, locale);
  }
});

test("userLanguageReminder is byte-for-byte what index.js produced before the move", () => {
  const expected = {
    "zh-Hans": "请用简体中文回复。",
    zh_CN: "请用简体中文回复。",
    zh_TW: "請以繁體中文回覆，全文不得出現簡體字。",
    "zh-Hant": "請以繁體中文回覆，全文不得出現簡體字。",
    zh_HK: "請以繁體中文回覆，全文不得出現簡體字。",
    ja_JP: "日本語で回答してください。",
    ko_KR: "한국어로 답변해 주세요.",
    en_US: "Reply in English.",
    fr_FR: "Reply in English.",
    "": "Reply in English."
  };
  for (const [locale, line] of Object.entries(expected)) {
    assert.equal(userLanguageReminder(locale), line, locale);
  }
});
