import { test } from "node:test";
import assert from "node:assert/strict";
import { privateDraftCalibration } from "../src/calibration.js";

// The GOOD line is the sentence the model imitates most closely. For Taiwan and
// Hong Kong it must not be the Simplified one — that pairing (a 繁體 directive
// next to a 简体 "ideal answer") is the unpaired-term pattern behind the
// Simplified bleed measured in zh-Hant vent output.
const SIMPLIFIED_ONLY = /[两还开游戏当个网别这们说时为会对没过让样发头气话点边问间实觉应关东车长见经进动]/;
const TRADITIONAL_ONLY = /[兩還開遊戲當個網別這們說時為會對沒過讓樣發頭氣話點邊問間實覺應關東車長見經進動]/;

test("Taiwan / Hong Kong vent and feral calibration is written in Traditional", () => {
  for (const locale of ["zh_TW", "zh_HK", "zh_MO", "zh-Hant", "zh_TW@calendar=roc"]) {
    for (const intensity of ["vent", "feral"]) {
      const text = privateDraftCalibration(locale, intensity);
      assert.doesNotMatch(text, SIMPLIFIED_ONLY, `${locale}/${intensity}`);
      assert.match(text, TRADITIONAL_ONLY, `${locale}/${intensity}`);
    }
  }
});

test("mainland calibration stays Simplified", () => {
  for (const locale of ["zh_CN", "zh-Hans", "zh_SG", "zh-Hans_HK"]) {
    for (const intensity of ["vent", "feral"]) {
      const text = privateDraftCalibration(locale, intensity);
      assert.doesNotMatch(text, TRADITIONAL_ONLY, `${locale}/${intensity}`);
      assert.match(text, SIMPLIFIED_ONLY, `${locale}/${intensity}`);
    }
  }
});

test("every locale's calibration says its GOOD examples are tone, not a template", () => {
  for (const locale of ["zh_TW", "zh-Hans", "ja_JP", "en_US", "ko_KR", ""]) {
    for (const intensity of ["vent", "feral"]) {
      const text = privateDraftCalibration(locale, intensity);
      assert.match(text, /GOOD examples show the tone only/, `${locale}/${intensity}`);
      assert.ok(text.split("\n").some((l) => l.startsWith("- GOOD:")), `${locale}/${intensity}`);
    }
  }
});

test("English GOOD lines are at most two sentences, with no swear word standing alone", () => {
  for (const intensity of ["vent", "feral"]) {
    for (const line of privateDraftCalibration("en_US", intensity).split("\n").filter((l) => l.startsWith("- GOOD:"))) {
      const quote = line.slice(line.indexOf("\"") + 1, line.lastIndexOf("\""));
      const sentences = quote.split(/(?<=[.!?])\s+/).filter(Boolean);
      assert.ok(sentences.length <= 2, `${intensity}: ${quote}`);
      for (const s of sentences) assert.ok(s.split(/\s+/).length > 3, `bare short sentence: ${s}`);
    }
  }
});
