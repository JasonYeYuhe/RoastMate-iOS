// The user's chosen PRO style as the VOICE of a private Vent / Feral draft.
//
// Until 2026-10-22 the private-draft prompt told the model to ignore the style
// ("Intensity overrides Style for private drafts"), so on phones without
// Apple's on-device model — where Feral is the only real Pro generator — the
// Pro styles changed nothing. Owner decisions 2026-10-22:
//   - Pro styles shape Vent / Feral: the style sets the voice; the intensity
//     still sets how angry the draft is and whether swearing is allowed (Vent)
//     or expected (Feral); every safety rule is unchanged.
//   - Only styles whose tier is "pro" in Shared/Resources/StylePresets.json
//     (STYLE_TIER, generated into style_names.js). A free style — the app
//     default high_eq included — keeps exactly the unstyled prompt, so the raw
//     default stays for everyone who never touches the picker.
//   - A styled draft may run up to 1.3× the script's usual length
//     (STYLED_LENGTH), and the limit is stated where the model reads it.
//   - Feral keeps a real, modern swear word in every Pro style, however
//     polished; no invented numbers, objects, events or people; the forbidden
//     openings win over any style; a polite voice never uses surname + title.
//
// Only mode "vent" uses this. The sendable roast prompt and the roommate
// transcript are built elsewhere (index.js) and never see these lines.
//
// Each instruction is written in the reply's own script, because the model
// copies the script of whatever sits in its prompt (the Simplified examples
// that bled into zh-Hant replies, measured 2026-09 and 2026-10). The user's
// display name is never put into the prompt for a known style: an app in
// Simplified on a Taiwan phone sends 「台剧腔」, which would be an unpaired
// Simplified term inside a Traditional prompt.
//
// A style that has no natural form in a language has no entry for it, and
// that request falls back to the old line (no style voice): 京片兒 is a
// Beijing dialect — in Taiwan register it would mean writing mainland slang
// the zh-Hant rules forbid, and in English or Japanese it has no equivalent.
// MBA jargon uses Taiwan office terms in zh-Hant and katakana in Japanese (no
// stray English words, which the post-processor would treat as a defect).
//
// Gate 1 (2026-10-22, 30 real calls, 6 contrasting styles incl. 3 now-free
// ones): a blind judge placed 30 of 30 drafts; 0 mainland markers and 0
// Simplified characters in 12 zh-Hant drafts. It found: no swear word in
// English Feral for the polished styles, 16 of 30 drafts within the length
// limit, invented details (「三个通宵」, a dress the user never mentioned), a
// forbidden 「哎呀」 opening, 「陳主管」 for a situation naming 陳志明, and one
// image of smashing a keyboard into a face. The rules above answer those;
// gate 2's results are in the style_gate2 report.

import { STYLE_KEY_TO_ID, STYLE_NAME_TO_ID, STYLE_TIER } from "./style_names.js";

/// One voice instruction per PRO style and output script
/// (src/vent_prompt.js ventVoice: en / hans / hant / ja; "other" — Korean —
/// uses the English text). Form and tone only, at most two lines; nothing
/// about swearing (the intensity owns that). test/style_voice.test.js checks
/// that the keys are exactly the Pro styles of StylePresets.json.
///
/// The close neighbours carry one cue each that the others lack (gate 2
/// judged them blind against each other): cold = shuts the door, no argument;
/// killshot = restates their excuse and breaks it; savage = rapid, blunt
/// charges ending in a verdict. daoist = water imagery, feigned serenity;
/// douban = understated diary, devastating last line; ancient = terse
/// classical parallels. corporate = office-email stock phrases; lawyer = a
/// formal notice; mba = buzzwords.
///
/// After gate 2 (one call left in its budget): lawyer_letter's English line
/// asks for two sentences (the en Feral draft ran 66 words, one over the
/// ceiling; 88 in the pilot), and every lawyer_letter line rules out naming a
/// law (a zh-Hant draft cited 勞動基準法 under 「不引法條」).
///
/// Review of gate 2: douban no longer asks to 「把對方釘死」 ("nail them dead";
/// ja 「静かに刺す」, "stab quietly"; now 戳穿 / 暴く, "expose";
/// a zh-Hant draft ended on 「把人活活餓死」), the STYLE VOICE block rules out
/// images of killing or dying as well, and cold's Chinese lines no longer say
/// 「把門關上」, which a zh-Hant draft wrote literally as its second sentence
/// (「門關了。」).
export const STYLE_VOICES = {
  shakespeare: {
    en: "Shakespearean: thee and thou, Elizabethan insults (knave, varlet, rogue), theatrical high diction aimed at what they did, never looks, birth or family. Never wish death, illness or harm.",
    hans: "莎士比亚舞台剧腔(像经典中译本的台词):「你这……的家伙」,句中带「啊」「老天」,用华丽夸张的骂人修辞对准对方的行为,不骂长相、出身或家人,也不咒人死、生病或受伤。",
    hant: "莎士比亞舞台劇腔(像經典中譯本的台詞):「你這……的傢伙」,句中帶「啊」「老天」,用華麗誇張的罵人修辭對準對方的行為,不罵長相、出身或家人,也不咒人死、生病或受傷。",
    ja: "シェイクスピア劇の翻訳調:「おお」「汝」のような大仰な台詞回しと芝居がかった罵倒で相手の行いをなじる。容姿・生まれ・家族はけなさず、死・病・暴力を願う言葉も使わない。"
  },
  mba_boss: {
    en: "MBA buzzword parody: escalating corporate jargon (circle back, leverage, align, deliverables) used to describe what they did, so the jargon itself mocks them.",
    hans: "MBA 黑话戏仿:用越来越夸张的大厂黑话(对齐、闭环、抓手、赋能、颗粒度)描述对方干的事,让黑话本身变成嘲讽。不要夹英文单词。",
    hant: "MBA 黑話戲仿:用越來越誇張的台灣職場術語(對焦、綜效、優化、落地、盤點、KPI)描述對方做的事,讓術語本身變成嘲諷。除了 KPI 不要夾英文單字。",
    ja: "MBAバズワードのパロディ:カタカナのビジネス用語(アジェンダ、コミット、シナジー、エビデンス、ステークホルダー)を重ねて相手のしたことを語り、用語そのものを皮肉にする。英字は使わない。"
  },
  ancient_chinese: {
    en: "Mock-classical: terse, archaic, parallel lines like a translated ancient Chinese text, raising the petty offense to mock-epic.",
    hans: "文言文:用简短对仗的文言句子,化用成语,把对方这点破事抬成史书级的讽刺。",
    hant: "文言文:用簡短對仗的文言句子,化用成語,把對方這點爛事抬成史書等級的諷刺。",
    ja: "漢文訓読調:「〜なり」「〜せんや」のような硬い古文調と対句で、相手の小さな悪行を大げさな史書のように断じる。"
  },
  lawyer_letter: {
    en: "Mock demand letter in two clipped sentences of formal legalese (we write to advise, pursuant to, please be advised) setting out what they did. No real legal threats; name no law or statute.",
    hans: "律师函腔:用正式、冷硬的公文措辞(兹通知如下、特此函告)把对方的行为一一列出。不提任何法律或法条名称,不做真的法律威胁。",
    hant: "律師函腔:用正式、冷硬的公文措辭(茲通知如下、特此函告)把對方的行為一一列出。不提任何法律或法條名稱,不做真的法律威脅。",
    ja: "通知書風:「謹啓」「下記の通り通知いたします」のような硬い文書調で、相手の行為を一段落のまま淡々と突きつける。実際の法的脅しはせず、法律名や条文も出さない。"
  },
  daoist_calm: {
    en: "Mock-serene Daoist: water-and-river imagery and unbothered calm, through which the contempt for what they did is plain. Serene on top, seething underneath.",
    hans: "装出来的道家心境:水、河、无为之类的意象,一副不争的淡定,底下对对方行为的鄙视藏都藏不住。面上云淡风轻,心里咬牙切齿。",
    hant: "裝出來的道家心境:水、河、無為之類的意象,一副不爭的淡定,底下對對方行為的不屑藏都藏不住。表面雲淡風輕,心裡咬牙切齒。",
    ja: "道家の境地を装う:水や川の比喩、争わない静けさを装いながら、相手のしたことへの軽蔑が透けて見える。表は涼しく、内心は煮えくり返っている。"
  },
  tokyo_office_lady: {
    en: "A worn-out Tokyo office worker venting to a colleague over drinks after work: weary, wry, conspiratorial, the complaint you would mutter at the bar and never say to their face.",
    hans: "下班后在居酒屋跟同事吐槽的东京上班族:累、丧、带点自嘲的碎碎念,是只敢在酒桌上说的那种抱怨。",
    hant: "下班後在居酒屋跟同事抱怨的東京上班族:累、厭世、帶點自嘲的碎念,是只敢在酒桌上講的那種抱怨。",
    ja: "仕事帰りの居酒屋で同僚に愚痴る東京のOL:疲れ切って、少し自虐的で、本人の前では絶対言えない本音をこぼす口調。"
  },
  douban_essay: {
    en: "A quiet literary journal entry: understated, self-deprecating, observational, with a last line that is devastating about what they did.",
    hans: "豆瓣式短文:像周六下午写的日记,文艺、克制、略带自嘲,最后一句冷冷地戳穿对方。",
    hant: "文青日記體:像週六下午寫的日記,文藝、克制、帶點自嘲,最後一句冷冷地戳穿對方。",
    ja: "土曜の午後の日記エッセイ風:淡々として文学的、少し自虐的に綴り、最後の一文で相手のしたことを静かに暴く。"
  },
  reddit_eli5: {
    en: "Deadpan Reddit explainer: treat what they did as a baffling phenomenon and explain it flatly, as if to a five-year-old, so the explanation itself mocks them.",
    hans: "一本正经的论坛科普腔:把对方的行为当成一种怪现象,像讲给五岁小孩听那样平铺直叙地解释,解释本身就是嘲讽。不要夹英文。",
    hant: "一本正經的論壇科普腔:把對方的行為當成一種怪現象,像講給五歲小孩聽一樣平鋪直敘地解釋,解釋本身就是嘲諷。不要夾英文。",
    ja: "掲示板の大真面目な解説風:相手の行動を不可解な現象として、5歳児に説明するように淡々と解説し、その説明自体を皮肉にする。"
  },
  stand_up_comedy: {
    en: "Stand-up bit: setup, escalation and a punchline about what they did, squeezed into the length limit. Punchlines, not explanations.",
    hans: "脱口秀段子:铺垫、升级、抖包袱,把对方干的事讲成一个梗,压在字数限制里。要笑点,不要解释。",
    hant: "脫口秀段子:鋪梗、升級、丟笑點,把對方做的事講成一個哏,壓在字數限制內。要笑點,不要解釋。",
    ja: "スタンダップ風:フリ→展開→オチで相手のしたことをネタにする。字数制限の中に収め、説明ではなくオチで笑わせる。"
  },
  taiwanese_drama: {
    en: "Melodramatic TV-drama monologue: heightened, theatrical, tearful, one sweeping simile about the betrayal, kept short. No talk of dying, and no image of hitting, smashing or hurting anyone.",
    hans: "台湾偶像剧独白腔:情绪满溢、有点浮夸、带哭腔,用啦、喔、欸这类语气词和一个夸张的比喻控诉对方,短短几句。不说想死,也不写打人、砸东西或任何伤人的画面。",
    hant: "台劇獨白腔(台灣偶像劇主角那種):情緒滿到溢出來、帶哭腔,用啦、欸這類語氣詞和一個誇張的比喻控訴對方,短短幾句。不說想死,也不寫打人、砸東西或任何傷人的畫面。",
    ja: "台湾ドラマの主人公の独白のように:感情があふれ、涙まじりに、一つの大げさな比喩で相手の裏切りを短く嘆く。死の話も、殴る・物を投げつけるなど人を傷つける描写もしない。"
  },
  cold_violence: {
    en: "Cold reply: exactly two short, flat sentences: name what they did, then shut the door on them. No argument, no questions, no exclamation marks; the anger is in how little you give them.",
    hans: "冷处理:只写两句短句,平淡、冰冷:先说对方干了什么,再一句话收尾、从此不再理对方。不争辩、不反问、不用感叹号;火气在于你根本懒得多给对方一个字。",
    hant: "冷處理:只寫兩句短句,平淡、冰冷:先講對方做了什麼,再一句話收尾、從此不再理對方。不爭辯、不反問、不用驚嘆號;火氣在於你根本懶得多給對方一個字。",
    ja: "冷たい返し:短く平坦な二文だけ。相手のしたことを言い、次の一文で突き放して終わる。反論も問いかけも感嘆符もなし。怒りは言葉の少なさで伝える。"
  },
  bjing_taunt: {
    hans: "京片儿调侃:北京胡同大爷式的贫嘴,您、得嘞、儿化音,面上客气热络,话里句句损对方干的事。"
  },
  savage_no_filter: {
    en: "Savage: blunt, rapid-fire charges, no mercy and no wit for its own sake: hit exactly what they did in hard, short clauses and end on a flat verdict about them.",
    hans: "硬核回怼:不留情面、不耍嘴皮,用又短又硬的句子连珠炮式数落对方到底干了什么,最后给对方下一句定论。",
    hant: "硬核回擊:不留情面、不耍嘴皮,用又短又硬的句子連珠炮式數落對方到底做了什麼,最後給對方下一句定論。",
    ja: "容赦なし:手加減も小細工もなく、短く硬い言葉で相手のしたことを畳みかけ、最後に相手への断定で締める。"
  },
  dark_humor: {
    en: "Dark humor: bleak, dry, oddly cheerful observations about what they did and the absurdity of it all. Dark about life, never about death, self-harm or violence.",
    hans: "黑色幽默:用冷峻、干巴巴又莫名轻快的口气,把对方干的事说成人间荒诞的一部分。黑的是生活,绝不碰死亡、自伤或暴力。",
    hant: "黑色幽默:用冷峻、乾巴巴又莫名輕快的口氣,把對方做的事講成人間荒謬的一部分。黑的是生活,絕不碰死亡、自傷或暴力。",
    ja: "ブラックユーモア:乾いた、妙に明るい口調で相手のしたことを人生の不条理の一部として語る。暗いのは人生観で、死・自傷・暴力には触れない。"
  },
  argument_killshot: {
    en: "Argument killshot: restate their excuse or claim, then name the one flaw that collapses it (you said X, yet Y), in one or two exact sentences. No exclamation marks.",
    hans: "辩论收尾杀:先复述对方的借口或说法,再点破让它整个站不住的那个漏洞(你说……,可是……),一两句,冷静精确,不用感叹号。",
    hant: "辯論收尾殺:先重述對方的藉口或說法,再點破讓它整個站不住的那個漏洞(你說……,可是……),一兩句,冷靜精確,不用驚嘆號。",
    ja: "ディベート終止符:相手の言い訳や主張をなぞり、それを崩す致命的な一点を指摘する(〜と言うが、〜)。冷静で正確な一、二文で、感嘆符は使わない。"
  },
  corporate_passive_violence: {
    en: "Corporate passive violence: frosty office-email phrasing (per my last email, as previously noted, to ensure visibility), a thin crust of courtesy over glacial contempt.",
    hans: "职场冷暴力:冷冰冰的职场邮件措辞(如上封邮件所述、再同步一下、烦请知悉),一层薄薄的客套底下是冷到结冰的鄙视。",
    hant: "職場冷暴力:冷冰冰的職場信件措辭(如前信所述、再次提醒、敬請知悉),一層薄薄的客套底下是冷到結冰的不屑。",
    ja: "ビジネス冷たい暴力:「前回のメールでもお伝えしました通り」のような冷え切ったビジネスメール調。薄い礼儀の下に、凍りつくような軽蔑。"
  }
};

/// For case-, width- and space-insensitive name matching: 「高 EQ」, "高EQ"
/// and a full-width "ＥＱ" are the same name.
export function normalizeStyleName(name) {
  return String(name || "").normalize("NFKC").replace(/\s+/g, "").toLowerCase();
}

const NAME_INDEX = new Map(
  Object.entries(STYLE_NAME_TO_ID).map(([name, id]) => [normalizeStyleName(name), id])
);

/// The style a request means, as a preset id, or null. `styleId` wins when it
/// is a known preset id or displayKey stem ("cold_violence" or "cold");
/// otherwise the localized `styleName` is looked up (apps before 1.7.1 send
/// only that). Anything else — no style, a new style this Worker does not
/// know yet, a made-up value — is null, and the prompt stays as it was.
/// Free and Pro styles both resolve; isProStyle decides whether it shapes.
export function resolveStyleId(styleId, styleName) {
  const id = String(styleId || "").trim().toLowerCase();
  if (id) {
    if (Object.hasOwn(STYLE_TIER, id)) return id;
    if (Object.hasOwn(STYLE_KEY_TO_ID, id)) return STYLE_KEY_TO_ID[id];
  }
  const name = normalizeStyleName(styleName);
  return name && NAME_INDEX.has(name) ? NAME_INDEX.get(name) : null;
}

/// True only for a preset whose tier in StylePresets.json is "pro".
export function isProStyle(id) {
  return Boolean(id) && Object.hasOwn(STYLE_TIER, id) && STYLE_TIER[id] === "pro";
}

/// The voice instruction for this style in this output script, or "" when the
/// style is unknown, free, or has no form in that language.
export function styleVoiceInstruction(id, voice) {
  if (!isProStyle(id) || !Object.hasOwn(STYLE_VOICES, id)) return "";
  const v = STYLE_VOICES[id];
  return (voice === "other" ? v.en : v[voice]) || "";
}

/// The usual limit per script (src/vent_prompt.js VOICES) and the styled
/// ceiling, at most 1.3× of it (owner decision 2026-10-22). Gate 1 had 16 of
/// 30 styled drafts within the usual limits; theatrical styles ran long.
///
/// The styled wording keeps the usual sentence count and the usual figure as
/// the aim, and states the ceiling as the hard limit. Measured 2026-10-22
/// (gate 2 pilot, 4 calls): stated as just "three sentences at most, under
/// 65 words", the limit became the target — two en Feral drafts ran 84 and 88
/// words, against ≤ 60 for every en draft of gate 1 under "under 50"; a zh-Hans
/// draft ran 211 characters against 195. Every line of a styled prompt that
/// states a length says this (the script block, the safety block's and
/// Feral's "Stay under" carry the ceiling). test/style_voice.test.js checks
/// the ratio.
export const USUAL_LIMIT = { en: 50, hans: 150, hant: 120, ja: 120, other: 120 };
export const STYLED_LIMIT = { en: 65, hans: 195, hant: 155, ja: 155, other: 155 };
export const STYLED_LENGTH = {
  en: "two sentences is the target, three the most; aim for under 50 words and never go over 65",
  hans: "两三句;尽量 150 字以内,最多不能超过 195 字",
  hant: "兩三句;盡量 120 字以內,最多不能超過 155 字",
  ja: "2〜3文;なるべく120字以内、多くても155字まで",
  other: "two or three sentences; aim for under 120 words and never go over 155"
};
/// The "Stay under …" form of the styled limit.
export const STYLED_MAX = { en: "65 words", hans: "195 字", hant: "155 字", ja: "155字", other: "155 words" };

/// A few real, modern swear words per script, for the Feral line of the
/// STYLE VOICE block (a subset of the script block's own list). Gate 1: en
/// Feral drafts in a polished voice (high-EQ, Shakespeare, corporate) kept
/// only archaic or polite insults.
const FERAL_EXAMPLES = { en: "fuck, shit, asshole", hans: "他妈的、操、傻逼", hant: "幹、王八蛋、去你的", ja: "クソ、ふざけんな", other: "" };

/// The forbidden openings (the script block's own list), restated next to the
/// style so a sweet or theatrical voice cannot override them. Gate 1: a
/// sugary zh-Hans draft opened 「哎呀」.
const FORBIDDEN_OPENINGS = {
  en: "\"Oh\", \"Oh my\", \"Wow\"",
  hans: "「哎呀」「真是的」「唉」",
  hant: "「哎呀」「真是的」「唉」",
  ja: "「あらまあ」「やれやれ」",
  other: "\"Oh\", \"Wow\""
};

/// The STYLE VOICE block of the system prompt (English frame, the instruction
/// in the reply's script). It goes after every other rule, just before the
/// language directive. The intensity line keeps Vent / Feral in charge of how
/// angry the draft is and of swearing.
///
/// "Role only": a polite voice reached for surname + title — one draft opened
/// 「陳主管欸」 for a situation naming 陳志明 (the Worker's name check now
/// catches that form too, src/postprocess.js).
export function styleVoiceBlock(instruction, intensity, voice) {
  const key = Object.hasOwn(STYLED_LENGTH, voice) ? voice : "other";
  const examples = FERAL_EXAMPLES[key] ? ` (for example ${FERAL_EXAMPLES[key]})` : "";
  return [
    "STYLE VOICE (the user picked a style for this private draft — write it in this voice):",
    `- Voice: ${instruction}`,
    "- The style decides how the draft sounds: its register, rhythm and sentence shape. Someone who knows the style should recognise it at once.",
    intensity === "feral"
      ? `- Intensity is Feral: keep its raw fury, and the draft MUST contain at least one real, modern swear word in the reply's language${examples}, however polished the voice — formal letters, office email, classical, poetic or serene styles included: put it inside the polished sentence, where the clash hits hardest. Archaic, polite or made-up insults do not count as that swear word.`
      : "- Intensity is Vent: keep it raw, private and cathartic, in this voice. Strong language where it lands; swearing is optional.",
    `- Length: ${STYLED_LENGTH[key]}. That ceiling is hard: cut the style's flourishes (an extra metaphor, a repeat, a second punchline) before going over it.`,
    "- Facts: only what the user's situation says. Add no numbers, durations, counts, objects, clothes, places, events or people that are not in it (no \"three all-nighters\" when the user only said they stayed up, no outfit they never mentioned). A metaphor may exaggerate; the facts may not.",
    `- Opening: never ${FORBIDDEN_OPENINGS[key]} or any other stock exclamation, however sweet, sugary or theatrical the style; open with what they did or said.`,
    "- Unchanged: the format limits above, and every safety rule. However theatrical the voice: no image of hitting, smashing, hurting or killing anyone, or of anyone dying, and no insult about looks, birth or family. A polite or formal voice addresses the other person by role only, never by surname plus title. Any wisdom, metaphor or reflection the style calls for is aimed at what the other person did, never advice or comfort for the user."
  ].join("\n");
}

/// The style line of the user prompt, in the reply's language: the same
/// instruction again, right before the model writes, with the styled length,
/// the no-invented-facts rule and, in Feral, the swear word.
export function styleUserLine(instruction, voice, intensity) {
  const feral = intensity === "feral";
  switch (voice) {
    case "hant":
      return `風格口吻:${instruction} 怒氣照強度規則${feral ? ",而且不管風格多文雅、多正式,都要有至少一個真的髒話" : ""}。長度:${STYLED_LENGTH.hant}。只寫情境裡有的事,不要自己加數字、天數、東西、衣著、事件或人物。`;
    case "hans":
      return `风格口吻:${instruction} 怒气照强度规则${feral ? ",而且不管风格多文雅、多正式,都要有至少一个真的脏话" : ""}。长度:${STYLED_LENGTH.hans}。只写情境里有的事,不要自己加数字、天数、东西、衣着、事件或人物。`;
    case "ja":
      return `口調:${instruction} 怒りの強さは強度のルールに従う${feral ? "。どんなに丁寧・上品な口調でも、本物の罵り言葉を少なくとも一つ入れる" : ""}。長さは${STYLED_LENGTH.ja}。状況に書かれていない数字・期間・物・服装・出来事・人物を付け足さない。`;
    default: {
      const key = voice === "en" ? "en" : "other";
      return `Voice: ${instruction} The intensity rules still set the anger${feral ? "; Feral needs at least one real, modern swear word, however polished the voice" : ""}. Length: ${STYLED_LENGTH[key]}. Use only the facts in the situation: no added numbers, durations, objects, events or people.`;
    }
  }
}
