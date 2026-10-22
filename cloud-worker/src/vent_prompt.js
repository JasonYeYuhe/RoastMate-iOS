// The private-draft prompt (mode "vent": intensities vent / feral), built per
// output script. Moved out of index.js so the per-script selection can be
// unit-tested without the Worker runtime (test/vent_prompt.test.js).
//
// Why per script (measured 2026-10-22 on the shipped prompt, 29 zh-Hant
// replies from the production Worker):
//   - One shared rule block carried Simplified mainland examples
//     (「对方」, 尼玛 / 他妈的 / 服了, 傻逼 / 卧槽 …) to EVERY locale, and the
//     zh-Hant word lists asked for 老子 / 傻逼 / 特麼 / 服了 / 裝什麼裝 outright.
//     27 of 29 zh-Hant replies used mainland slang; 0 used a Taiwan term.
//   - "Must use N strong words / zero = task failed" quotas made 19 of 29
//     zh-Hant replies open with 他媽的, and en / ja replies printed the word
//     list itself ("Damn you. Uru-see.", "（うるせえ、ふざけんな、ありえねえ）").
// So: each script gets its own examples, Taiwan gets Taiwan register with the
// mainland markers named as things to avoid, and the quotas are replaced by
// guidance (vary the opening, answer this situation, swear where it lands).
// zh-Hans keeps its mainland register. The safety rules are unchanged in
// substance and present for every script.
//
// Second pass (review of the first gate, 2026-10-22, 14 zh-Hant replies):
//   - The Taiwan replies had found a new template: 靠北 in 9/14, a 「…喔？」
//     rhetorical question in 11/14, 「你當我…」 in 6/14 — the shape of the
//     single Taiwan calibration line (「你是把宿舍當你家網咖喔？靠北」) and the
//     first word of both lists. Two fixed replacement lines were copied in
//     turn (爛人 5/14, 臉皮 3/14), so the calibration now shows two lines
//     picked per situation from a pool of six (src/calibration.js), 靠北 is no
//     longer first in either list, and the block names the shapes as ones not
//     to fall back on.
//   - Feral (the "swearing expected" mode) produced 2 of 13 replies with no
//     swear word at all, so Feral asks for at least one — never a count.
//   - English still ran 4–5 sentences in 3 of 6 replies, often a closing
//     "Fuck you." as its own sentence: two sentences is now the target and a
//     swear word goes inside a sentence.

import { isTraditionalChinese } from "./locale.js";
import { privateDraftCalibration } from "./calibration.js";
import { languageDirective, userLanguageReminder } from "./language.js";
import { resolveStyleId, styleVoiceInstruction, styleVoiceBlock, styleUserLine, STYLED_LENGTH, STYLED_MAX } from "./style_voice.js";

/// Which example set a locale gets. "en" covers every locale whose output
/// language is English (languageDirective answers in English for anything
/// that is not zh / ja / ko); "other" (Korean) gets no word examples at all.
export function ventVoice(locale) {
  if (isTraditionalChinese(locale)) return "hant";
  const code = String(locale || "").toLowerCase();
  if (code.startsWith("zh")) return "hans";
  if (code.startsWith("ja")) return "ja";
  if (code.startsWith("ko")) return "other";
  return "en";
}

const EN_REFS = {
  maxLength: "120 words per variant",
  roles: "\"the manager\", \"the roommate\"",
  refs: "them / your coworker / that company",
  handles: "Instagram, Snapchat or Discord handles",
  directAddress: "\"who the hell do you think you are...\"",
  softOpeners: "\"Oh my…\" / \"Wow, just wow…\"",
  specific: "\"You ghost me the second I ask for my money back\" beats \"you're the worst\"",
  reflective: "\"maybe focus on yourself...\" / \"you deserve better...\""
};

/// Per-script pieces. `vocab` is shown as examples only — never a count.
export const VOICES = {
  en: {
    ...EN_REFS,
    // Measured (2026-10-22): under the shared 120-word ceiling, en replies ran
    // 64–113 words and up to 11 sentences against "1–3 sentences"; with a
    // 60-word rule they still reached 77 words / 5 sentences (gate run 1).
    // English gets its own, tighter ceiling.
    maxLength: "50 words",
    vocab: { vent: "damn, hell, bullshit", feral: "fuck, shit, asshole, prick" },
    block: (intensity, v, styled = false) => [
      "ENGLISH VOICE:",
      "- Plain text only: no asterisks, no bold or italics, no markdown, no headings, no lists. One short paragraph.",
      styled
        ? `- Length: ${STYLED_LENGTH.en}, unless the user's situation asks for a different length — then follow that. Every sentence counts, a short one or a question included.`
        : "- Length: two sentences is the target, three the most, and under 50 words, unless the user's situation asks for a different length — then follow that. Every sentence counts, a short one or a question included.",
      "- English words only. Never mix in words from another language.",
      intensity === "feral"
        ? `- At least one real swear word (${v.vocab.feral}), inside a sentence where it hits hardest — not stacked into every sentence, and never a swear word as a sentence of its own. Never list words.`
        : `- Mild swearing (${v.vocab.vent}) is fine where it lands, inside a sentence; it is not required. Never list words.`,
      "- Do not open with a swear word or an exclamation; open with what they did or said."
    ].join("\n")
  },

  hans: {
    maxLength: "120 words per variant",
    roles: "「那个领导」/「室友」",
    refs: "「对方」/「你的同事」/「那家公司」",
    handles: "WeChat/vx/QQ",
    directAddress: "「你到底凭什么…」",
    softOpeners: "「哎呀…」/「真是的…」",
    specific: "「借钱时叫我宝，一催还钱就已读不回」比「你太过分了」有力",
    reflective: "「如果你把这份心思放在自己身上…」/「你值得更好的…」",
    vocab: {
      vent: "他妈的、老子、特么、服了、装什么装、烦死了",
      feral: "他妈的、老子、傻逼、操、卧槽、滚、神经病"
    },
    block: (intensity, v, styled = false) => [
      "简体中文口气:",
      styled
        ? "- 口吻照用户选的风格(见下面的 STYLE VOICE),但要说人话、带真火气。"
        : "- 像真人气头上打字:直接、有脾气、说大白话。",
      intensity === "feral"
        ? `- 暴走模式:脏话是意料之中的,但用在最狠的地方,不要每句都堆。参考(不是指标,更不要把词列出来):${v.vocab.feral}。`
        : `- 强烈词可以用,用在刀刃上,不是指标——不要堆砌,更不要把词列出来。参考:${v.vocab.vent}。`,
      "- 开头不要每次都是「他妈的」或别的脏话;直接从对方干的事、说过的原话,或一句反问开始。",
      "- 对象是用户自己的爸妈或家人时,别用「你妈」这类骂到对方家人的话(那是在骂用户自己的家人),只骂那个行为。",
      styled ? `- 不许用「哎呀」「真是的」「唉」开头。${STYLED_LENGTH.hans}。` : "- 不许用「哎呀」「真是的」「唉」开头。全文 150 字以内。"
    ].join("\n")
  },

  hant: {
    maxLength: "120 words per variant",
    roles: "「那個主管」/「室友」",
    refs: "「對方」/「你同事」/「那間公司」",
    handles: "LINE ID、IG 帳號",
    directAddress: "「你到底憑什麼…」",
    softOpeners: "「哎呀…」/「真是的…」",
    specific: "「借錢時叫我寶貝，一催還錢就已讀不回」比「你很過分」有力",
    reflective: "「如果你把這份心思放在自己身上…」/「你值得更好的…」",
    // 靠北 was first in both lists and turned up in 9 of 14 replies; it stays
    // (it is the most Taiwanese of them) but no longer leads.
    vocab: {
      vent: "很扯、傻眼、白目、機車、很盤、是怎樣、夠了喔、火大、三小、靠北",
      feral: "幹、北七、爛人、王八蛋、去你的、白目、機車、三小、靠北、滾"
    },
    block: (intensity, v, styled = false) => [
      "繁體中文(台灣)口氣:",
      styled
        ? "- 口吻照使用者選的風格(見下面的 STYLE VOICE)來寫,用詞是台灣用語、台灣說法。語尾助詞(啦、欸、齁、耶)偶爾自然帶到就好,不用每句都加。"
        : "- 寫成台灣人氣到在 LINE 上打字的口氣:台灣用語、台灣說法。語尾助詞(啦、欸、齁、耶)偶爾自然帶到就好,不用每句都加。",
      intensity === "feral"
        ? `- 暴走模式:一定要有真的髒話,一兩個就夠,放在最狠的地方,不要每句都塞。台灣常用的罵法(配合這個情境挑;不是清單,更不要把詞列出來):${v.vocab.feral}。`
        : `- 台灣常用的罵法(配合這個情境挑一個,或一個都不用;不是指標,不要硬塞,更不要把詞列出來):${v.vocab.vent}。`,
      "- 不要套固定句型:不要預設用「靠北」,也不要用「你當我…喔？」「你是把…當…喔？」這種反問句。大部分句子用直述句,直接講對方做了什麼;問句最多一個,而且不要用「你當我…」開頭、不要用「…喔？」結尾。",
      "- 不要用大陸用語:老子、傻逼、特麼、服了(真服了)、裝什麼裝、臥槽、尼瑪、你妹、牛逼、絕了。也不要用大陸詞彙:視頻(→影片)、信息(→訊息)、質量(→品質)、網吧(→網咖)、微信(→LINE)、朋友圈(→限動、貼文)、微博(→IG、FB)。",
      "- 自稱用「我」,不要用「老子」。",
      "- 開頭不要每次都是「他媽的」或「幹」;直接從對方做的事、說過的話,或一句反問開始。",
      "- 只講使用者寫到的事,不要自己編細節。",
      "- 對象是使用者自己的爸媽或家人時,不要用「你媽」這類罵到對方家人的話(那等於罵到使用者自己的家人),只罵那個行為。",
      styled
        ? `- 不許用「哎呀」「真是的」「唉」開頭。避免簡體字(誰不能寫成谁,讓不能寫成让)。${STYLED_LENGTH.hant}。`
        : "- 不許用「哎呀」「真是的」「唉」開頭。避免簡體字(誰不能寫成谁,讓不能寫成让)。兩三句就好,全文 120 字以內。"
    ].join("\n")
  },

  ja: {
    maxLength: "120 words per variant",
    roles: "「上司」/「ルームメイト」",
    refs: "「相手」/「同僚」/「あの会社」",
    handles: "LINE ID、X のアカウント",
    directAddress: "「何様のつもりだよ…」",
    softOpeners: "「あらまあ…」/「やれやれ…」",
    specific: "「金を借りる時だけ優しくて、返せと言ったら既読無視」は「最低」より刺さる",
    reflective: "「その情熱を自分に向ければ…」/「あなたはもっと大切にされるべき…」",
    vocab: { vent: "", feral: "クソ、ふざけんな" },
    block: (intensity, v, styled = false) => [
      "日本語の口調:",
      intensity === "feral"
        ? (styled
          ? `- 口調はユーザーが選んだスタイル(下の STYLE VOICE)に合わせ、本気でキレていることが伝わるように書く。本気の罵倒(例えば${v.vocab.feral})を少なくとも一つ、一番効くところで使う。数を稼ぐために並べない。`
          : `- 本気でキレている人の話し言葉(タメ口)で書く。本気の罵倒(例えば${v.vocab.feral})を少なくとも一つ、一番効くところで使う。数を稼ぐために並べない。`)
        : (styled
          ? "- 口調はユーザーが選んだスタイル(下の STYLE VOICE)に合わせ、本気の苛立ちをにじませる。強めの言葉は効くところで自然に使ってよいが、ノルマではない。"
          : "- 本気でイラついている人の話し言葉(タメ口)で書く。強めの言葉は効くところで自然に使ってよいが、ノルマではない。"),
      "- 単語を並べたり、最後に括弧で付け足したりしない。",
      "- 一人称はユーザーの文に出てくる一人称(私・あたし・僕・俺など)に合わせる。書かれていなければ「私」を使うか、一人称を省く。「俺」「お前」口調をデフォルトにしない。",
      "- 書き出しを毎回罵り言葉にしない。相手がしたこと・言ったことから始める。",
      "- ユーザーが書いていないこと(人・物・出来事)を付け足さない。",
      styled ? `- 「あらまあ」「やれやれ」で始めるな。${STYLED_LENGTH.ja}。改行せず一段落で書く。` : "- 「あらまあ」「やれやれ」で始めるな。2〜3文、120字以内。改行せず一段落で書く。"
    ].join("\n")
  },

  other: {
    ...EN_REFS,
    vocab: { vent: "", feral: "" },
    block: () => [
      "VOICE:",
      "- Natural spoken language in the output language. Strong language is allowed where it lands; it is not required. Never list words.",
      "- Do not open with a swear word or an exclamation; open with what they did or said."
    ].join("\n")
  }
};

function universalRules(v) {
  return [
    "SAFETY RULES (always apply, regardless of intensity / mode):",
    `- Never target a specific real person by full name. If a name appears in the user's situation, replace it with a generic role (${v.roles}).`,
    `- NEVER echo identifying details back, even if the user typed them: no real names (a first name or a full name counts — do not repeat it anywhere, not even as the first word), no company or school names, no addresses, no phone numbers, no email addresses, and no contact handles (${v.handles}). Replace them with a generic role or reference: ${v.refs}. The output may be rendered onto a shareable image, so treat every specific identifier as something that must not survive into it.`,
    "- Never produce slurs, racist, sexist, ableist, homophobic, transphobic, or hateful content.",
    "- Never produce threats of physical violence, doxxing, sexual content, or self-harm content.",
    "- Never attack protected attributes (race, religion, gender, sexuality, disability, appearance, body, family).",
    "- If the user's situation suggests self-harm, violence, or stalking, decline and respond with empathy and a suggestion to seek support.",
    `- Stay under ${v.maxLength}.`,
    "- For private drafts, raw anger is allowed, but keep the attack on the behavior or choice — never on identity."
  ].join("\n");
}

function ventRules(v, styled = false) {
  return [
    "VENT DRAFT RULES (this output is private and will be labelled \"for yourself only\"):",
    "- The user is FURIOUS. They are not asking for advice and not trying to be witty. Write what is screaming in their head right now.",
    styled
      ? "- Write a PRIVATE OUTBURST in the voice of the style the user picked (STYLE VOICE, below): the style sets how it sounds, the anger is still real. Never a therapeutic reflection."
      : "- Write a PRIVATE OUTBURST in the user's voice, not a clever observation and not a therapeutic reflection. Anger first, structure last.",
    `- Imagined direct address is ALLOWED when it gives the anger more force. People vent by thinking ${v.directAddress} in their head. Do not flatten that into detached narration.`,
    `- Strong, raw language and mild profanity are welcome where they land — they are not a quota, so do not stack them. Do not water the anger down into sarcastic exclamations (${v.softOpeners} are FORBIDDEN openings — those are polite-sarcasm, not vent).`,
    `- Answer THIS situation: name what the other person actually did or said, using the details the user gave. ${v.specific}. Do not invent facts the user did not mention.`,
    "- Vary the opening: start with the offense itself — what they did, what they said, or a pointed question about it — not with a swear word or a stock exclamation.",
    styled
      ? "- Shape: whatever the style calls for, in 1–3 sentences within the length limit, staying on the grievance. No life lesson for the user."
      : "- Default shape: 1–3 blunt sentences that hit the grievance immediately. No proverb, compliment, or life lesson.",
    `- FORBIDDEN: advice, consolation, moral lessons, self-improvement reframes, therapist voice, and reflective lines such as ${v.reflective}.`,
    "- Do not use slurs, threats of violence, sexual content, doxxing, or attacks on protected attributes — the universal safety rules above still apply absolutely."
  ].join("\n");
}

function feralRules(v, styled = false) {
  return [
    "FERAL DRAFT RULES (this output is private and will be labelled \"for yourself only\"):",
    styled
      ? "- The user is past polite. They want maximum cathartic impact. The style may be cold, sweet, theatrical or old-fashioned, but the fury has to come through it — never sarcasm instead of anger."
      : "- The user is past polite. They want maximum cathartic impact, RAW. No sarcasm-as-substitute-for-anger.",
    "- Swearing is expected here: at least one real swear word (one or two is enough), placed where it hits hardest — not a list to tick off, and never the words on their own.",
    styled
      ? `- Write a PRIVATE OUTBURST in the voice of the style the user picked (STYLE VOICE, below). Imagined direct address is ALLOWED and often preferred when it makes the line hit harder. FORBIDDEN openings: ${v.softOpeners}.`
      : `- Write a PRIVATE OUTBURST in the user's own voice. Imagined direct address is ALLOWED and often preferred when it makes the line hit harder. FORBIDDEN openings: ${v.softOpeners}.`,
    `- Answer THIS situation: be specific about the behavior and the role (${v.roles}), using the details the user gave. Do not invent facts the user did not mention.`,
    "- Vary the opening: start with the offense itself, not with a swear word.",
    styled
      ? "- Shape: whatever the style calls for, in 1–3 sentences within the length limit. No advice, no consolation, no moral lesson, no reflective self-help framing."
      : "- Default shape: 1–3 blunt sentences. Start with the offense. No advice, no consolation, no moral lesson, no reflective self-help framing.",
    "- Hard limits (UNIVERSAL SAFETY RULES still apply): no slurs based on race/religion/gender/sexuality/disability/body/family; no threats of physical violence; no sexual content; no doxxing.",
    `- Stay under ${v.maxLength.replace(" per variant", "")}.`
  ].join("\n");
}

/// The voice instruction for the request's Pro style in this locale's script,
/// or "" (no style, a free style, an unknown style, or a style with no form in
/// that language).
/// `styleId` (apps from 1.7.1) wins over the localized `styleName`.
export function ventStyleInstruction(locale, styleName, styleId) {
  return styleVoiceInstruction(resolveStyleId(styleId, styleName), ventVoice(locale));
}

/// The calibration block without its GOOD lines (and the "GOOD examples show
/// the tone only" note), for a styled draft: the GOOD lines are written in the
/// plain angry register, and the model copies them. Measured 2026-10-22 (6
/// zh_TW Feral drafts, one per style, with the style block at the top and the
/// GOOD lines kept): all 6 came out in the same plain LINE register, 爛人 in
/// 6 of 6 — none recognisably cold, melodramatic or Shakespearean. The BAD line
/// (too reflective, too polite) still applies to every style.
function styledCalibration(locale, intensity, situation) {
  return privateDraftCalibration(locale, intensity, situation)
    .split("\n").filter((line) => !line.startsWith("- GOOD")).join("\n");
}

/// `situation` only picks which Taiwan calibration lines this request shows
/// (src/calibration.js); nothing from it is copied into the system prompt.
///
/// A Pro style (src/style_voice.js) sets the draft's voice: the lines that
/// prescribe the default plain-angry register (the private-outburst line, the
/// default shape, the script block's register line, Feral's "no sarcasm") get
/// their styled wording, the length lines state the styled limit (up to 1.3×
/// the usual one), the calibration loses its plain-register GOOD lines, and a
/// STYLE VOICE block goes last before the language directive, where the model
/// weighs it most (the first version put it at the top, where the old line
/// was, and the pilot above showed no style). The safety rules, the
/// intensity's anger and swearing rules and the language directive are the
/// same lines as in an unstyled prompt.
///
/// Without a style voice — no style, a free style (the app default high_eq
/// among them), a style this Worker does not know, or one with no form in
/// this language — the prompt is byte-identical to the one before styles
/// shaped private drafts (test/style_voice.test.js pins it against a fixture
/// recorded from HEAD 4ed652f).
export function buildVentSystemPrompt(intensity, locale, styleName, situation = "", styleId = "") {
  const voice = ventVoice(locale);
  const v = VOICES[voice];
  const instruction = ventStyleInstruction(locale, styleName, styleId);
  if (instruction) {
    // The styled length replaces the usual one in every line that states it.
    const sv = { ...v, maxLength: STYLED_MAX[voice] };
    return [
      "You are RoastMate, an AI that helps users express frustration through private vent drafts.",
      universalRules(sv),
      intensity === "feral" ? feralRules(sv, true) : ventRules(sv, true),
      styledCalibration(locale, intensity, situation),
      v.block(intensity, v, true),
      styleVoiceBlock(instruction, intensity, voice),
      languageDirective(locale)
    ].join("\n\n");
  }
  const styleLine = styleName
    ? `Style hint: ${styleName} — but IGNORE this style's politeness/professional/de-escalating framing. Intensity overrides Style for private drafts.`
    : "Style hint: none. Write in the user's raw voice, not a styled register.";
  return [
    "You are RoastMate, an AI that helps users express frustration through private vent drafts.",
    styleLine,
    universalRules(v),
    intensity === "feral" ? feralRules(v) : ventRules(v),
    privateDraftCalibration(locale, intensity, situation),
    v.block(intensity, v),
    languageDirective(locale)
  ].join("\n\n");
}

// First-person pronouns a Japanese user may write about themself, in the
// order they are checked when two appear at the same position. Hiragana おれ
// is not counted inside お礼 (おれい), 倒れ / 萎れ (たおれ, しおれ) or 折れる
// (おれる, おれて, おれない) — each would pin a male voice on someone who never
// used one. ウチ is not listed: 「ウチの会社」「ウチの上司」 ("our company") is far
// more common in a vent than ウチ as a pronoun; without a match the reply
// falls back to the neutral 私, and the system prompt still asks the model to
// follow whatever pronoun the user wrote.
const JA_FIRST_PERSON = [
  ["わたし", /わたし/], ["あたし", /あたし/], ["ぼく", /ぼく/], ["おれ", /(?<![たし])おれ(?![いるてな])/],
  ["オレ", /オレ/], ["私", /私/], ["僕", /僕/], ["俺", /俺/]
];

/// The first-person pronoun the user used in a Japanese situation (the
/// earliest one), or null. Measured: 5 of 6 ja replies used a male 俺 for
/// situations written with 私 (a girlfriend whose 彼氏 forgot her birthday).
export function jaFirstPerson(situation) {
  const s = String(situation || "");
  let best = null;
  let at = Infinity;
  for (const [word, re] of JA_FIRST_PERSON) {
    const m = s.match(re);
    if (m && m.index < at) { best = word; at = m.index; }
  }
  return best;
}

function voiceUserLine(locale, situation) {
  switch (ventVoice(locale)) {
    case "en":
      return "Plain text, two sentences (three at most), under 50 words, no asterisks.";
    case "hant":
      return "用台灣人的口氣和台灣用語寫。";
    case "ja": {
      const p = jaFirstPerson(situation);
      return p
        ? `一人称はユーザーと同じ「${p}」にすること。`
        : "一人称が必要なら「私」を使う(「俺」にしない)。";
    }
    default:
      return "";
  }
}

/// voiceUserLine for a styled draft: the style now sets the tone (Taiwan gets
/// Taiwan wording rather than "a Taiwanese tone") and the length (English: the
/// styled line carries the styled limit, so the 50-word line goes).
function styledVoiceUserLine(locale, situation) {
  switch (ventVoice(locale)) {
    case "en": return "Plain text, no asterisks.";
    case "hant": return "用台灣用語、台灣說法寫。";
    default: return voiceUserLine(locale, situation);
  }
}

// When the situation involves the user's own parent, a "your mother" curse
// lands on the user's own family. Measured: two zh-Hant feral replies about
// 「我媽每次過年…」 opened 「你媽他媽的…」 / 「你媽真的操你媽的…」, and the
// general family rule in the system prompt did not stop it.
//
// The line says the situation MENTIONS the parent, never that the parent is
// the target: the regex cannot tell 「我媽每次…」 from 「鄰居一直講我媽壞話」
// or "My dad's boss fired him", and an earlier wording ("這次罵的是使用者自己
// 的家人" / "The person is the user's own parent") pointed the anger at the
// parent in exactly those cases. The ban itself is harmless either way.
const OWN_PARENT_ZH = /我的?(?:媽|妈|爸|父母|家人)|老(?:媽|妈|爸)/;
const OWN_PARENT_EN = /\bmy (?:mom|mum|mother|dad|father|parents)\b/i;

/// One extra line when the situation mentions the user's own parent, else "".
export function ownFamilyLine(locale, situation) {
  const s = String(situation || "");
  switch (ventVoice(locale)) {
    case "hant":
      return OWN_PARENT_ZH.test(s) ? "這個情境提到使用者自己的家人:不要用「你媽的」「他媽的」這類帶「媽」字的髒話(會罵到使用者自己的家人),只罵對方做的事。" : "";
    case "hans":
      return OWN_PARENT_ZH.test(s) ? "这个情境提到用户自己的家人:不要用「你妈的」「他妈的」这类带「妈」字的脏话(会骂到用户自己的家人),只骂对方做的事。" : "";
    case "en":
      return OWN_PARENT_EN.test(s) ? "The situation mentions the user's own parent: no \"your mom\"-style insults (they would land on the user's own family); go after what was done." : "";
    default:
      return "";
  }
}

/// `extra` is one more instruction line (the quality retry's nudge); empty
/// on the first call. `style` ({ styleName, styleId } as the request sent
/// them, plus its intensity) adds the Pro style's voice instruction once more,
/// in the reply's language, with the styled length, the no-invented-facts rule
/// and, in Feral, the swear word (and, for Taiwan, asks for Taiwan wording
/// rather than "a Taiwanese tone", which the style now sets); without a style
/// voice the user prompt is unchanged.
export function buildVentUserPrompt(situation, locale, extra = "", style = {}) {
  const instruction = ventStyleInstruction(locale, style && style.styleName, style && style.styleId);
  const instructions = [
    "Write 1 private vent draft about THIS situation — raw, immediate, and emotionally specific, using what the user actually described. It may use imagined direct address if that makes the anger sharper. Do not give advice, reflection, or moral lessons. Output the draft directly — no numbering, no preface, no commentary.",
    instruction ? styleUserLine(instruction, ventVoice(locale), style && style.intensity) : "",
    instruction ? styledVoiceUserLine(locale, situation) : voiceUserLine(locale, situation),
    ownFamilyLine(locale, situation),
    extra,
    userLanguageReminder(locale)
  ].filter(Boolean);
  return [`Situation: ${situation}`, "", ...instructions].join("\n");
}
