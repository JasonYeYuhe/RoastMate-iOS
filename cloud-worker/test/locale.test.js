import { test } from "node:test";
import assert from "node:assert/strict";
import { isTraditionalChinese, baseLocale } from "../src/locale.js";

// What real devices send. "zh_TW" / "zh_HK" were MEASURED on an iOS 18.5
// simulator configured as a Taiwan / Hong Kong phone (2026-09-26): iOS's
// Locale.current.identifier omits the script subtag for those regions.
test("real Taiwan / Hong Kong / Macau identifiers are Traditional", () => {
  for (const id of ["zh_TW", "zh_HK", "zh_MO", "zh-TW", "zh-HK"]) {
    assert.equal(isTraditionalChinese(id), true, id);
  }
});

test("an explicit script subtag wins over the region", () => {
  assert.equal(isTraditionalChinese("zh-Hant"), true);
  assert.equal(isTraditionalChinese("zh-Hant_TW"), true);
  assert.equal(isTraditionalChinese("zh-Hant-CN"), true);
  // Simplified in Hong Kong is a real configuration — respect the script.
  assert.equal(isTraditionalChinese("zh-Hans_HK"), false);
  assert.equal(isTraditionalChinese("zh-Hans-TW"), false);
});

test("Simplified and non-Chinese locales are not Traditional", () => {
  for (const id of ["zh_CN", "zh-Hans", "zh-Hans_CN", "zh_SG", "zh", "ja_JP", "en_US", "en_TW", "", undefined, null]) {
    assert.equal(isTraditionalChinese(id), false, String(id));
  }
});

// iOS appends user overrides as Unicode keywords. A Taiwan phone on the 民國
// calendar sends "zh_TW@calendar=roc"; the region must still decide.
test("Unicode keywords do not hide the region or script", () => {
  for (const id of ["zh_TW@calendar=roc", "zh_HK@fw=mon", "zh_MO@numbers=hanidec", "zh-Hant_TW@rg=twzzzz"]) {
    assert.equal(isTraditionalChinese(id), true, id);
  }
  for (const id of ["zh-Hans_TW@calendar=roc", "zh_CN@calendar=chinese", "en_TW@calendar=roc"]) {
    assert.equal(isTraditionalChinese(id), false, id);
  }
});

test("baseLocale drops Unicode keywords and nothing else", () => {
  assert.equal(baseLocale("zh_TW@calendar=roc"), "zh_TW");
  assert.equal(baseLocale("zh_TW@calendar=roc;fw=mon;measure=metric"), "zh_TW");
  assert.equal(baseLocale("en_US@rg=gbzzzz"), "en_US");
  assert.equal(baseLocale("zh-Hant_TW"), "zh-Hant_TW");
  assert.equal(baseLocale("ja_JP"), "ja_JP");
  assert.equal(baseLocale(""), "");
});
