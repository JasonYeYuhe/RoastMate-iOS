// The user's chosen Pro style as the voice of a private Vent / Feral draft
// (src/style_voice.js, decided 2026-10-22), and everything that must NOT
// change with it: free styles (the app default high_eq among them), unknown
// styles, the roommate transcript and the sendable roast prompt stay
// byte-identical to HEAD 4ed652f (production 7846ac95).
import { registerHooks } from "node:module";
import { test, afterEach } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (specifier === "cloudflare:workers") {
      return { url: "data:text/javascript,export class DurableObject {}", shortCircuit: true };
    }
    return nextResolve(specifier, context);
  }
});
const worker = (await import("../src/index.js")).default;
const { STYLE_VOICES, STYLED_LENGTH, STYLED_LIMIT, USUAL_LIMIT, STYLED_MAX, resolveStyleId, isProStyle, normalizeStyleName,
        styleVoiceInstruction, styleVoiceBlock, styleUserLine } = await import("../src/style_voice.js");
const { STYLE_KEY_TO_ID, STYLE_NAME_TO_ID, STYLE_TIER } = await import("../src/style_names.js");
const { buildVentSystemPrompt, buildVentUserPrompt, ventVoice, VOICES: SCRIPT_VOICES } = await import("../src/vent_prompt.js");
const { languageDirective, userLanguageReminder } = await import("../src/language.js");
const { simplifiedChars } = await import("../src/postprocess.js");

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO = join(HERE, "..", "..");
const APP_LOCALES = ["en", "zh-Hans", "zh-Hant", "ja"];
const PRESETS = JSON.parse(readFileSync(join(REPO, "Shared/Resources/StylePresets.json"), "utf8")).styles;
const PRO = PRESETS.filter((p) => p.tier === "pro");
const FREE = PRESETS.filter((p) => p.tier === "free");
const keyOf = (p) => p.displayKey.replace(/^style\./, "").replace(/\.name$/, "");

function appNames(locale) {
  const text = readFileSync(join(REPO, `Shared/${locale}.lproj/Localizable.strings`), "utf8");
  const out = {};
  for (const m of text.matchAll(/^"style\.([a-z0-9_]+)\.name"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;/gm)) {
    out[m[1]] = m[2].replace(/\\(.)/g, "$1");
  }
  return out;
}
const NAMES = Object.fromEntries(APP_LOCALES.map((l) => [l, appNames(l)]));

// One request locale per output script, plus the variants the Worker sees.
const REQUEST_LOCALES = { en: ["en_US", "en_GB"], hans: ["zh-Hans", "zh_CN"], hant: ["zh_TW", "zh_HK", "zh_TW@calendar=roc"], ja: ["ja_JP"], other: ["ko_KR"] };
const VOICES = ["en", "hans", "hant", "ja", "other"];
const INTENSITIES = ["vent", "feral"];
const OLD_LINE = /Intensity overrides Style for private drafts/;
const SAFETY = ["Never produce slurs", "self-harm", "Never attack protected attributes",
                "NEVER echo identifying details", "never on identity", "doxxing"];
const HAN = /[一-鿿]/;
const KANA = /[぀-ヿ]/;
// Characters that exist only in Traditional script (common ones, incl. every
// Traditional form a Simplified instruction here could plausibly slip into).
const TRADITIONAL_ONLY = /[兩還開遊戲當個網別這們說時為會對沒過讓樣發頭氣話點邊問間實覺應關東車長見經進動媽罵機禮稱臉醫寫幫釘鋪誇張條傢術語綜優盤爛詞謂詐該聽觀劇獨淚啟邏輯縮譯學園裝雲風輕厭週藝論壇丟驚嘆號擊種悶憤]/;
const MAINLAND = ["老子", "傻逼", "特麼", "特么", "服了", "裝什麼裝", "臥槽", "卧槽", "尼瑪", "尼玛", "你妹", "牛逼", "絕了"];
const SITUATION = {
  en: "My manager Kevin took credit for the report I spent my whole weekend on.",
  hans: "领导周五晚上十点在群里@我，让我周末把整个方案重做。",
  hant: "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。",
  ja: "彼氏が私の誕生日をまた忘れてた。",
  other: "룸메이트가 또 내 음식을 먹었어."
};

// --- the catalog: every app style has an id, a name entry and a voice ---------

test("style_names.js matches the app's StylePresets.json and Localizable.strings (regenerate it if this fails)", () => {
  const keyToId = Object.fromEntries(PRESETS.map((p) => [keyOf(p), p.id]));
  const tier = Object.fromEntries(PRESETS.map((p) => [p.id, p.tier]));
  assert.deepEqual(STYLE_TIER, tier, `STYLE_TIER drifted; expected:\n${JSON.stringify(tier, null, 1)}`);
  const nameToId = {};
  for (const l of APP_LOCALES) for (const p of PRESETS) {
    const name = NAMES[l][keyOf(p)];
    assert.ok(name, `${l}.lproj has no ${p.displayKey}`);
    nameToId[name] = p.id;
  }
  assert.deepEqual(STYLE_KEY_TO_ID, keyToId, `STYLE_KEY_TO_ID drifted; expected:\n${JSON.stringify(keyToId, null, 1)}`);
  assert.deepEqual(STYLE_NAME_TO_ID, nameToId, `STYLE_NAME_TO_ID drifted; expected:\n${JSON.stringify(nameToId, null, 1)}`);
});

test("every Pro style has a voice entry and no free style has one (owner decision: Pro styles only)", () => {
  assert.equal(PRESETS.length, 24);
  assert.equal(PRO.length, 16);
  assert.ok(FREE.some((p) => p.id === "high_eq"), "the app default is a free style");
  assert.deepEqual(Object.keys(STYLE_VOICES).sort(), PRO.map((p) => p.id).sort());
  for (const p of PRESETS) {
    assert.equal(isProStyle(p.id), p.tier === "pro", p.id);
    for (const voice of VOICES) {
      if (p.tier === "free") assert.equal(styleVoiceInstruction(p.id, voice), "", `${p.id}/${voice}`);
    }
  }
  for (const k of [null, undefined, "", "__proto__", "constructor", "made_up"]) assert.equal(isProStyle(k), false, String(k));
});

test("every localized display name, preset id and key stem resolves to that style", () => {
  for (const p of PRESETS) {
    assert.equal(resolveStyleId(p.id, ""), p.id, p.id);
    assert.equal(resolveStyleId(keyOf(p), ""), p.id, `key stem ${keyOf(p)}`);
    for (const l of APP_LOCALES) {
      const name = NAMES[l][keyOf(p)];
      assert.equal(resolveStyleId("", name), p.id, `${l} ${name}`);
      assert.equal(resolveStyleId(undefined, ` ${name.toUpperCase()} `), p.id, `${l} ${name} (case/space)`);
    }
  }
  assert.equal(resolveStyleId("", "高ＥＱ"), "high_eq", "full-width letters");
  assert.equal(resolveStyleId("", "高EQ"), "high_eq");
});

test("no two styles share a display name, even after normalization", () => {
  const seen = new Map();
  for (const [name, id] of Object.entries(STYLE_NAME_TO_ID)) {
    const k = normalizeStyleName(name);
    if (seen.has(k)) assert.equal(seen.get(k), id, `${name} is both ${seen.get(k)} and ${id}`);
    seen.set(k, id);
  }
});

test("resolveStyleId: styleId wins, unknown values are null, prototype keys are not styles", () => {
  assert.equal(resolveStyleId("cold_violence", "台劇腔"), "cold_violence", "styleId wins over the name");
  assert.equal(resolveStyleId("cold", "High EQ"), "cold_violence");
  assert.equal(resolveStyleId("a_style_from_the_future", "台劇腔"), "taiwanese_drama", "unknown id falls back to the name");
  assert.equal(resolveStyleId("made_up", "Nope"), null);
  assert.equal(resolveStyleId("", ""), null);
  assert.equal(resolveStyleId(undefined, undefined), null);
  assert.equal(resolveStyleId("", "高情商"), null, "a near miss is not a style");
  for (const k of ["__proto__", "constructor", "toString", "hasOwnProperty", "valueOf"]) {
    assert.equal(resolveStyleId(k, ""), null, k);
    assert.equal(resolveStyleId("", k), null, k);
  }
});

// --- the instructions themselves ----------------------------------------------

test("each instruction is short, one line, and in the reply's own script", () => {
  for (const [id, v] of Object.entries(STYLE_VOICES)) {
    for (const [voice, text] of Object.entries(v)) {
      assert.ok(["en", "hans", "hant", "ja"].includes(voice), `${id}: unexpected voice ${voice}`);
      assert.doesNotMatch(text, /\n/, `${id}/${voice}`);
      assert.ok(text.length <= (voice === "en" ? 200 : 110), `${id}/${voice} is ${text.length} chars`);
    }
    if (v.en) {
      assert.doesNotMatch(v.en, HAN, `${id}/en`);
      assert.doesNotMatch(v.en, KANA, `${id}/en`);
    }
    if (v.hans) {
      assert.doesNotMatch(v.hans, TRADITIONAL_ONLY, `${id}/hans has a Traditional character`);
      assert.doesNotMatch(v.hans, KANA, `${id}/hans`);
    }
    if (v.hant) {
      assert.deepEqual(simplifiedChars(v.hant, "zh_TW"), [], `${id}/hant has Simplified characters`);
      for (const w of MAINLAND) assert.ok(!v.hant.includes(w), `${id}/hant carries ${w}`);
      assert.doesNotMatch(v.hant, KANA, `${id}/hant`);
    }
    if (v.ja) assert.match(v.ja, KANA, `${id}/ja`);
  }
});

test("no style voice offers an insult about birth, looks or family, and every styled prompt forbids violent images", () => {
  // Review 2026-10-22: the Shakespeare line offered "thou base-born wretch"
  // and the en draft used it verbatim; a zh-Hans 台剧腔 draft imagined
  // smashing a keyboard into the other person's face.
  const BIRTH_OR_FAMILY_INSULT = /base-?born|bastard|whoreson|mother|野种|杂种|雜種|私生|没家教|沒家教|你妈|你媽|妾の子|親の顔/i;
  // Review of gate 2: douban's 「把對方釘死」 ("nail them dead") preceded a
  // draft ending on 「把人活活餓死」. No instruction may itself use a killing
  // or violence metaphor as a cue.
  const VIOLENT_CUE = /钉死|釘死|杀死|殺死|砍|捅|\bkill(?!shot)|\bstab|\bslay|\bbury\b|刺す|殺す/i;
  for (const [id, v] of Object.entries(STYLE_VOICES)) {
    for (const [voice, text] of Object.entries(v)) {
      assert.doesNotMatch(text, BIRTH_OR_FAMILY_INSULT, `${id}/${voice}`);
      assert.doesNotMatch(text, VIOLENT_CUE, `${id}/${voice} uses a violent cue`);
    }
  }
  for (const voice of ["en", "hans", "hant", "ja"]) {
    assert.match(STYLE_VOICES.taiwanese_drama[voice], /smashing|砸东西|砸東西|殴る/, `taiwanese_drama/${voice} names the images it forbids`);
    assert.match(STYLE_VOICES.shakespeare[voice], /birth|出身|生まれ/, `shakespeare/${voice} rules out insults about birth`);
  }
  for (const voice of VOICES) for (const intensity of INTENSITIES) for (const p of PRESETS) {
    const instruction = styleVoiceInstruction(p.id, voice);
    if (!instruction) continue;
    const block = styleVoiceBlock(instruction, intensity, voice);
    assert.match(block, /no image of hitting, smashing, hurting or killing anyone, or of anyone dying, and no insult about looks, birth or family/, `${p.id} ${voice}`);
    if (intensity === "feral") assert.match(block, /Archaic, polite or made-up insults do not count as that swear word/, `${p.id} ${voice}`);
    else assert.doesNotMatch(block, /swear word/, `${p.id} ${voice}: Vent never asks for one`);
  }
});

test("a style never takes over swearing or the anger level: no instruction talks about swearing", () => {
  // Vent / Feral decide whether swearing is allowed or expected (the STYLE
  // VOICE frame says so); a style that said "no profanity" would silently
  // turn Feral into Vent.
  const SWEAR_TALK = /swear|profan|curse word|髒話|脏话|粗口|罵り言葉|罵倒語|下品/i;
  for (const [id, v] of Object.entries(STYLE_VOICES)) {
    for (const [voice, text] of Object.entries(v)) assert.doesNotMatch(text, SWEAR_TALK, `${id}/${voice}`);
  }
});

test("only the Beijing-dialect style is missing a language (it falls back to no style voice there)", () => {
  for (const [id, v] of Object.entries(STYLE_VOICES)) {
    const missing = ["en", "hans", "hant", "ja"].filter((voice) => !v[voice]);
    if (id === "bjing_taunt") assert.deepEqual(missing, ["en", "hant", "ja"]);
    else assert.deepEqual(missing, [], id);
  }
});

// --- the prompt: both inputs carry the voice; everything else is kept --------

test("every Pro style shapes the vent and feral prompt, by styleId and by every localized name; free styles do not", () => {
  for (const voice of VOICES) for (const locale of REQUEST_LOCALES[voice]) for (const intensity of INTENSITIES) {
    for (const p of PRESETS) {
      const instruction = styleVoiceInstruction(p.id, voice);
      const inputs = [["id", { styleId: p.id }], ["key", { styleId: keyOf(p) }],
                      ...APP_LOCALES.map((l) => [`name:${l}`, { styleName: NAMES[l][keyOf(p)] }])];
      for (const [label, s] of inputs) {
        const sys = buildVentSystemPrompt(intensity, locale, s.styleName || "", SITUATION[voice], s.styleId || "");
        const user = buildVentUserPrompt(SITUATION[voice], locale, "", { ...s, intensity });
        const where = `${p.id} ${label} ${locale}/${intensity}`;
        if (p.tier === "free") assert.equal(instruction, "", where);
        if (!instruction) {
          // A free style, or no form in this language: exactly the prompt an
          // unknown style (or the same display name before styles) gets.
          assert.doesNotMatch(sys, /STYLE VOICE/, where);
          assert.equal(sys, buildVentSystemPrompt(intensity, locale, s.styleName || "", SITUATION[voice]), where);
          assert.equal(user, buildVentUserPrompt(SITUATION[voice], locale), where);
          continue;
        }
        assert.ok(sys.includes(`- Voice: ${instruction}`), `${where}: instruction missing`);
        assert.doesNotMatch(sys, OLD_LINE, where);
        assert.ok(!sys.includes("Style hint:"), where);
        const sections = sys.split("\n\n");
        assert.equal(sections.at(-2), styleVoiceBlock(instruction, intensity, voice), `${where}: STYLE VOICE goes last before the language directive`);
        assert.ok(!sys.split("\n").some((l) => l.startsWith("- GOOD")), `${where}: the plain-register GOOD lines are gone`);
        assert.match(sys, /- BAD: /, `${where}: the too-reflective BAD line stays`);
        assert.ok(user.includes(styleUserLine(instruction, voice, intensity)), `${where}: the user prompt repeats the instruction`);
        if (s.styleName) assert.ok(!sys.includes(s.styleName) || instruction.includes(s.styleName), `${where}: the raw display name is not copied in`);
        for (const rule of SAFETY) assert.ok(sys.includes(rule), `${where} lost "${rule}"`);
        assert.ok(sys.endsWith(languageDirective(locale)), where);
        assert.ok(user.endsWith(userLanguageReminder(locale)), where);
        if (intensity === "feral") {
          assert.match(sys, /at least one real swear word \(one or two is enough\)/, where);
          assert.match(sys, /Intensity is Feral: keep its raw fury, and the draft MUST contain at least one real, modern swear word/, where);
        } else {
          assert.doesNotMatch(sys, /at least one real swear word/, where);
          assert.match(sys, /Intensity is Vent/, where);
        }
      }
    }
  }
});

test("a styled prompt keeps every other line of the unstyled one; only the default-register lines change", () => {
  // The lines a style may replace: the old style line, the plain-register GOOD
  // examples, the lines that prescribe the default voice / shape, and the
  // lines that state the usual length (the styled limit replaces it).
  const REGISTER = [/^Style hint:/, /^- GOOD/, /in the user's voice, not a clever observation/, /^- Default shape:/,
                    /in the user's own voice\. Imagined/, /No sarcasm-as-substitute-for-anger/,
                    /^- 像真人气头上打字/, /^- 寫成台灣人氣到在 LINE/, /タメ口/,
                    /^- Stay under (50 words|120 words)/, /^- Length: two sentences is the target/,
                    /全文 150 字以内。$/, /兩三句就好,全文 120 字以內。$/, /2〜3文、120字以内。/];
  for (const voice of VOICES) for (const intensity of INTENSITIES) for (const p of PRESETS) {
    const locale = REQUEST_LOCALES[voice][0];
    const instruction = styleVoiceInstruction(p.id, voice);
    if (!instruction) continue;
    const where = `${p.id} ${locale}/${intensity}`;
    const plain = buildVentSystemPrompt(intensity, locale, "", SITUATION[voice]).split("\n");
    const styled = buildVentSystemPrompt(intensity, locale, "", SITUATION[voice], p.id).split("\n");
    const block = new Set(styleVoiceBlock(instruction, intensity, voice).split("\n"));
    for (const line of plain.filter((l) => !styled.includes(l))) {
      assert.ok(REGISTER.some((re) => re.test(line)), `${where}: dropped a line that is not a register line: ${line}`);
    }
    for (const line of styled.filter((l) => !plain.includes(l))) {
      assert.ok(block.has(line) || /STYLE VOICE|the style|^- Stay under /i.test(line) || line.includes(STYLED_LENGTH[voice]),
                `${where}: added an unexpected line: ${line}`);
    }
    const plainUser = buildVentUserPrompt(SITUATION[voice], locale).split("\n");
    const styledUser = buildVentUserPrompt(SITUATION[voice], locale, "", { styleId: p.id, intensity }).split("\n");
    const extra = styledUser.filter((l) => !plainUser.includes(l));
    const gone = plainUser.filter((l) => !styledUser.includes(l));
    if (voice === "hant") {
      assert.deepEqual(gone, ["用台灣人的口氣和台灣用語寫。"], where);
      assert.deepEqual(extra, [styleUserLine(instruction, voice, intensity), "用台灣用語、台灣說法寫。"], where);
    } else if (voice === "en") {
      assert.deepEqual(gone, ["Plain text, two sentences (three at most), under 50 words, no asterisks."], where);
      assert.deepEqual(extra, [styleUserLine(instruction, voice, intensity), "Plain text, no asterisks."], where);
    } else {
      assert.deepEqual(gone, [], where);
      assert.deepEqual(extra, [styleUserLine(instruction, voice, intensity)], where);
    }
  }
});

test("styled length: at most 1.3× the script's usual limit, stated in the block and the user prompt, and the only limit in the prompt", () => {
  // Owner decision 2026-10-22: a styled draft may run up to 1.3× the base
  // limit. The usual limits below are the ones the unstyled prompt states.
  const plain = (voice, i = "vent") => buildVentSystemPrompt(i, REQUEST_LOCALES[voice][0], "", SITUATION[voice]);
  assert.match(plain("en"), /two sentences is the target, three the most, and under 50 words/);
  assert.ok(plain("hans").includes("全文 150 字以内"));
  assert.ok(plain("hant").includes("兩三句就好,全文 120 字以內"));
  assert.ok(plain("ja").includes("2〜3文、120字以内"));
  assert.ok(plain("other").includes("Stay under 120 words"));
  assert.deepEqual(USUAL_LIMIT, { en: 50, hans: 150, hant: 120, ja: 120, other: 120 });
  for (const voice of VOICES) {
    assert.ok(STYLED_LIMIT[voice] > USUAL_LIMIT[voice] && STYLED_LIMIT[voice] <= USUAL_LIMIT[voice] * 1.3, voice);
    assert.ok(STYLED_LENGTH[voice].includes(String(STYLED_LIMIT[voice])), voice);
    assert.ok(STYLED_LENGTH[voice].includes(String(USUAL_LIMIT[voice])), `${voice}: the usual figure stays as the aim`);
    assert.ok(STYLED_MAX[voice].startsWith(String(STYLED_LIMIT[voice])), voice);
  }
  // The usual number appears only as the aim, next to the ceiling: never as
  // a limit of its own (gate 2 pilot: a lone higher limit became the target).
  const USUAL_TEXT = { en: /\b50 words\b/, hans: /150 字/, hant: /120 字/, ja: /120字/, other: /\b120 words\b/ };
  for (const voice of VOICES) for (const intensity of INTENSITIES) {
    const locale = REQUEST_LOCALES[voice][0];
    const sys = buildVentSystemPrompt(intensity, locale, "", SITUATION[voice], "shakespeare");
    const user = buildVentUserPrompt(SITUATION[voice], locale, "", { styleId: "shakespeare", intensity });
    assert.ok(sys.includes(`- Length: ${STYLED_LENGTH[voice]}. That ceiling is hard:`), voice);
    assert.ok(sys.includes(`- Stay under ${STYLED_MAX[voice]}.`), voice);
    assert.ok(user.includes(STYLED_LENGTH[voice]), voice);
    for (const line of [...sys.split("\n"), ...user.split("\n")]) {
      if (USUAL_TEXT[voice].test(line)) assert.ok(line.includes(STYLED_LENGTH[voice]), `${voice}/${intensity}: a lone usual limit: ${line}`);
    }
    assert.match(sys, /addresses the other person by role only, never by surname plus title/);
  }
});

test("Feral: every Pro style asks for a real, modern swear word however polished, in the block and in the reply's language", () => {
  const USER_SWEAR = { en: /at least one real, modern swear word, however polished the voice/, other: /at least one real, modern swear word/,
                       hans: /都要有至少一个真的脏话/, hant: /都要有至少一個真的髒話/, ja: /本物の罵り言葉を少なくとも一つ/ };
  for (const voice of VOICES) for (const p of PRO) {
    const instruction = styleVoiceInstruction(p.id, voice);
    if (!instruction) continue;
    const locale = REQUEST_LOCALES[voice][0];
    for (const intensity of INTENSITIES) {
      const sys = buildVentSystemPrompt(intensity, locale, "", SITUATION[voice], p.id);
      const user = buildVentUserPrompt(SITUATION[voice], locale, "", { styleId: p.id, intensity });
      const where = `${p.id} ${voice}/${intensity}`;
      if (intensity === "feral") {
        assert.match(sys, /the draft MUST contain at least one real, modern swear word in the reply's language/, where);
        assert.match(sys, /however polished the voice — formal letters, office email, classical, poetic or serene styles included/, where);
        assert.match(user, USER_SWEAR[voice], where);
      } else {
        assert.doesNotMatch(sys, /MUST contain at least one real, modern swear word/, where);
        assert.doesNotMatch(user, USER_SWEAR[voice], where);
      }
    }
  }
  // The examples the block offers are the script's own Feral words.
  for (const [voice, words] of [["en", ["fuck", "shit", "asshole"]], ["hans", ["他妈的", "操", "傻逼"]], ["hant", ["幹", "王八蛋", "去你的"]], ["ja", ["クソ", "ふざけんな"]]]) {
    const block = styleVoiceBlock("x", "feral", voice);
    for (const w of words) {
      assert.ok(block.includes(w), `${voice}: ${w}`);
      assert.ok(SCRIPT_VOICES[voice].vocab.feral.includes(w), `${voice}: ${w} is not in the script's own Feral list`);
    }
  }
  assert.doesNotMatch(styleVoiceBlock("x", "feral", "other"), /for example/, "Korean gets no examples, as in its script block");
});

test("no invented specifics: the block and the user line forbid added numbers, durations, objects, events or people", () => {
  const USER_FACTS = { en: /no added numbers, durations, objects, events or people/, other: /no added numbers, durations, objects, events or people/,
                       hans: /不要自己加数字、天数、东西、衣着、事件或人物/, hant: /不要自己加數字、天數、東西、衣著、事件或人物/,
                       ja: /数字・期間・物・服装・出来事・人物を付け足さない/ };
  for (const voice of VOICES) for (const intensity of INTENSITIES) {
    const locale = REQUEST_LOCALES[voice][0];
    const sys = buildVentSystemPrompt(intensity, locale, "", SITUATION[voice], "taiwanese_drama");
    assert.match(sys, /- Facts: only what the user's situation says\. Add no numbers, durations, counts, objects, clothes, places, events or people that are not in it/, voice);
    assert.match(buildVentUserPrompt(SITUATION[voice], locale, "", { styleId: "taiwanese_drama", intensity }), USER_FACTS[voice], voice);
  }
});

test("openings: the styled block restates the script's forbidden openings, and they win over any style", () => {
  const OPENERS = { en: ["Oh my", "Wow"], hans: ["哎呀", "真是的", "唉"], hant: ["哎呀", "真是的", "唉"], ja: ["あらまあ", "やれやれ"] };
  for (const [voice, words] of Object.entries(OPENERS)) {
    const locale = REQUEST_LOCALES[voice][0];
    const plain = buildVentSystemPrompt("vent", locale, "", SITUATION[voice]);
    for (const intensity of INTENSITIES) {
      const block = styleVoiceBlock("x", intensity, voice);
      const line = block.split("\n").find((l) => l.startsWith("- Opening: never "));
      assert.ok(line, voice);
      assert.match(line, /however sweet, sugary or theatrical the style/, voice);
      for (const w of words) {
        assert.ok(line.includes(w), `${voice}: ${w}`);
        assert.ok(plain.includes(w), `${voice}: ${w} is not one of the script's own forbidden openings`);
      }
    }
  }
});

test("zh-Hant styled prompts keep Taiwan register: no Simplified characters, mainland words only in avoid lines", () => {
  for (const intensity of INTENSITIES) for (const p of PRESETS) {
    for (const s of [{ styleId: p.id }, { styleName: NAMES["zh-Hans"][keyOf(p)] }]) {
      const sys = buildVentSystemPrompt(intensity, "zh_TW", s.styleName || "", SITUATION.hant, s.styleId || "");
      if (!/STYLE VOICE/.test(sys)) continue;
      const body = sys.replace(languageDirective("zh_TW"), "").replace("避免簡體字(誰不能寫成谁,讓不能寫成让)", "");
      assert.deepEqual(simplifiedChars(body, "zh_TW"), [], `${p.id} ${JSON.stringify(s)}`);
      for (const line of sys.split("\n")) {
        const hits = MAINLAND.filter((w) => line.includes(w));
        if (hits.length) assert.match(line, /不要用/, `${p.id}: ${hits} outside an avoid line`);
      }
    }
  }
});

test("en styled prompts carry no Chinese or Japanese at all, even when the app UI sent a Chinese name", () => {
  for (const intensity of INTENSITIES) for (const p of PRESETS) {
    const sys = buildVentSystemPrompt(intensity, "en_US", NAMES["zh-Hant"][keyOf(p)], SITUATION.en);
    if (!/STYLE VOICE/.test(sys)) continue;
    assert.doesNotMatch(sys, HAN, p.id);
    assert.doesNotMatch(sys, KANA, p.id);
  }
});

// --- byte-identical to HEAD where nothing should change ------------------------

const sha = (s) => createHash("sha256").update(s).digest("hex");
const realFetch = globalThis.fetch;
afterEach(() => { globalThis.fetch = realFetch; });

function kv() {
  const m = new Map();
  return { async get(k) { return m.has(k) ? m.get(k) : null; }, async put(k, v) { m.set(k, v); } };
}
function makeEnv() {
  return { OPENROUTER_API_KEY: "test-key", DEFAULT_MODEL: "a/primary", FALLBACK_MODELS: "b/fallback", RATE_LIMITS: kv(),
           ROAST_MODE_ENABLED: "true", DAILY_LIMIT_PER_DEVICE: "100000", APP_DAILY_LIMIT_PER_IP: "100000" };
}
function stub(responder) {
  const calls = [];
  globalThis.fetch = async (_url, init) => {
    const body = JSON.parse(init.body);
    calls.push(body);
    const content = responder(calls.length - 1, body);
    return new Response(JSON.stringify({ model: "a/primary", choices: [{ message: { content } }] }), {
      status: 200, headers: { "Content-Type": "application/json" }
    });
  };
  return calls;
}
async function post(body, env = makeEnv(), n = 0) {
  const req = new Request("https://worker.test/v1/vent", {
    method: "POST",
    headers: { "Content-Type": "application/json", "CF-Connecting-IP": "203.0.113.9" },
    body: JSON.stringify({ deviceId: `fixture-device-${n}`, ...body })
  });
  const res = await worker.fetch(req, env, { waitUntil() {} });
  return { status: res.status, json: await res.json() };
}

test("roommate, roast, and vent with no, an unknown or a free style: prompts byte-identical to HEAD (312 requests)", async () => {
  const fixture = JSON.parse(readFileSync(join(HERE, "fixtures/head_prompts.json"), "utf8"));
  assert.match(fixture.generated_from, /HEAD 4ed652f/);
  const kinds = new Set(fixture.cases.map((c) => c.id.split("/")[0]));
  assert.deepEqual([...kinds].sort(), ["roast", "roommate", "vent"]);
  // The fixture's roommate / roast cases include styled requests (台劇腔 by id
  // and by name): neither mode may pick the style voice up.
  assert.ok(fixture.cases.some((c) => c.id.startsWith("roommate/") && c.body.styleId === "taiwanese_drama"));
  assert.ok(fixture.cases.some((c) => c.id.startsWith("roast/") && c.body.styleId === "cold_violence"));
  // Every free style, by id and by its display name, in every script; and
  // 京片兒 (Pro) where it has no form.
  assert.equal(fixture.cases.length, 312);
  for (const p of FREE) {
    assert.ok(fixture.cases.some((c) => c.id.startsWith("vent/") && c.body.styleId === p.id), p.id);
    assert.ok(fixture.cases.some((c) => c.id.startsWith("vent/") && c.body.styleName && STYLE_NAME_TO_ID[c.body.styleName] === p.id), p.id);
  }
  assert.ok(fixture.cases.some((c) => c.body.styleName === "高 EQ" && c.body.locale === "zh_TW"));
  const env = makeEnv();
  for (const [n, c] of fixture.cases.entries()) {
    const calls = stub(() => "好");
    const { status } = await post(c.body, env, n);
    assert.equal(status, 200, c.id);
    assert.equal(sha(calls[0].messages[0].content), c.system_sha256, `${c.id}: system prompt changed`);
    assert.equal(sha(calls[0].messages[1].content), c.user_sha256, `${c.id}: user prompt changed`);
  }
});

// --- end to end through the handler --------------------------------------------

test("handler: a styled vent request sends the voice on the first call and on the quality retry", async () => {
  for (const s of [{ styleId: "cold_violence" }, { styleName: "冷處理" }, { styleName: "冷处理" }, { styleId: "cold" }]) {
    const calls = stub((i) => i === 0 ? "fucking 下班前十分鐘丟案子。" : "下班前十分鐘丟案子。到此為止。");
    const { status, json } = await post({ situation: "慣老闆下班前十分鐘丟案子", intensity: "feral", locale: "zh_TW", ...s });
    assert.equal(status, 200);
    assert.deepEqual(Object.keys(json).sort(), ["model", "provider", "remaining", "text"], "response contract unchanged");
    assert.equal(calls.length, 2, "the Latin run still triggers the one quality retry");
    const instruction = STYLE_VOICES.cold_violence.hant;
    for (const c of calls) {
      assert.ok(c.messages[0].content.includes(`- Voice: ${instruction}`), JSON.stringify(s));
      assert.ok(c.messages[1].content.includes(instruction), "the user prompt repeats it, on the retry too");
    }
    assert.match(calls[1].messages[1].content, /不要夾英文單字/, "the retry nudge is still there");
    assert.equal(calls[0].messages[0].content, calls[1].messages[0].content);
  }
});

test("handler: the same style reaches every reply script in that script's words", async () => {
  const cases = [
    ["en_US", "Taiwanese Drama", STYLE_VOICES.taiwanese_drama.en],
    ["zh-Hans", "台剧腔", STYLE_VOICES.taiwanese_drama.hans],
    ["zh_TW", "台剧腔", STYLE_VOICES.taiwanese_drama.hant],
    ["ja_JP", "台湾ドラマ口調", STYLE_VOICES.taiwanese_drama.ja],
    ["ko_KR", "Taiwanese Drama", STYLE_VOICES.taiwanese_drama.en]
  ];
  for (const [locale, styleName, instruction] of cases) {
    const calls = stub(() => "好");
    await post({ situation: "x", intensity: "vent", locale, styleName });
    assert.ok(calls[0].messages[0].content.includes(instruction), locale);
    if (locale === "zh_TW") assert.ok(!calls[0].messages[0].content.includes("台剧腔"), "the Simplified display name stays out of a zh-Hant prompt");
  }
});

test("handler: a free style, an unknown style, a style with no form in that language, and no style keep the old line", async () => {
  const cases = [
    [{ styleName: "Some Unknown Style" }, "zh_TW", /Style hint: Some Unknown Style — but IGNORE/],
    [{ styleName: "高 EQ" }, "zh_TW", /Style hint: 高 EQ — but IGNORE/],
    [{ styleId: "high_eq", styleName: "High EQ" }, "en_US", /Style hint: High EQ — but IGNORE/],
    [{ styleId: "passive_aggressive" }, "zh-Hans", /Style hint: none\./],
    [{ styleName: "おばあちゃんの知恵" }, "ja_JP", /Style hint: おばあちゃんの知恵 — but IGNORE/],
    [{ styleId: "bjing_taunt", styleName: "京片兒" }, "zh_TW", /Style hint: 京片兒 — but IGNORE/],
    [{ styleId: "bjing_taunt" }, "en_US", /Style hint: none\./],
    [{}, "ja_JP", /Style hint: none\./]
  ];
  for (const [s, locale, re] of cases) {
    const calls = stub(() => "好");
    await post({ situation: "x", intensity: "feral", locale, ...s });
    assert.match(calls[0].messages[0].content, re, JSON.stringify(s));
    assert.doesNotMatch(calls[0].messages[0].content, /STYLE VOICE/);
    assert.doesNotMatch(calls[0].messages[1].content, /STYLE VOICE/);
  }
  const calls = stub(() => "好");
  await post({ situation: "x", intensity: "vent", locale: "zh-Hans", styleId: "bjing_taunt" });
  assert.ok(calls[0].messages[0].content.includes(STYLE_VOICES.bjing_taunt.hans), "京片儿 does speak in zh-Hans");
});

test("handler: surname + title of the situation's person is stripped or retried in every Vent/Feral draft, styled or not", async () => {
  const situation = "慣老闆陳志明又在下班前十分鐘丟一個案子給我，說明天早上就要。";
  // Styled: an opening vocative goes, no retry.
  let calls = stub(() => "陳主管，你又在下班前十分鐘丟案子。");
  let r = await post({ situation, intensity: "feral", locale: "zh_TW", styleId: "cold_violence" });
  assert.equal(calls.length, 1);
  assert.equal(r.json.text, "你又在下班前十分鐘丟案子。");
  // Styled: 「陳主管欸」 is not a clean vocative, so the one quality retry runs
  // with the surname + title nudge, and the draft without it wins.
  calls = stub((i) => i === 0 ? "陳主管欸，下班前十分鐘丟案子。" : "下班前十分鐘丟案子。到此為止。");
  r = await post({ situation, intensity: "feral", locale: "zh_TW", styleId: "cold_violence" }, makeEnv(), 1);
  assert.equal(calls.length, 2);
  assert.match(calls[1].messages[1].content, /也不要用姓氏加職稱的叫法/);
  assert.ok(calls[1].messages[1].content.includes(STYLE_VOICES.cold_violence.hant), "the retry keeps the style line");
  assert.equal(r.json.text, "下班前十分鐘丟案子。到此為止。");
  // Unstyled (a free style, an unknown style, no style): the same rule
  // (owner decision 2026-10-22) — an opening vocative is stripped, no retry.
  for (const [n, s] of [[2, { styleName: "高 EQ" }], [3, { styleId: "high_eq" }], [4, { styleName: "Nope" }], [5, {}]]) {
    calls = stub(() => "陳主管，你又在下班前十分鐘丟案子。");
    r = await post({ situation, intensity: "feral", locale: "zh_TW", ...s }, makeEnv(), n);
    assert.equal(calls.length, 1, JSON.stringify(s));
    assert.equal(r.json.text, "你又在下班前十分鐘丟案子。", JSON.stringify(s));
  }
});

test("ventVoice still routes every request locale used above", () => {
  for (const [voice, locales] of Object.entries(REQUEST_LOCALES)) for (const l of locales) assert.equal(ventVoice(l), voice, l);
});
