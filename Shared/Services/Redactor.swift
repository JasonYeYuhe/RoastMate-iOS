import Foundation
import NaturalLanguage

/// On-device PII masking. Runs locally; nothing is sent anywhere.
///
/// Two entry points, deliberately different in strength:
///
/// - `redact(_:)` — the original ASCII-oriented pass (email / URL / @handle /
///   digit runs). Kept for callers that only need the cheap sweep.
/// - `redactForPublicShare(_:locale:)` — the strict pass used before anything
///   is rendered onto a shareable image. Adds Chinese contact handles,
///   Chinese-numeral phone runs, ID-card numbers, surname+title forms, and an
///   `NLTagger` personal-name pass.
///
/// ## What this can and cannot do
///
/// Be honest about the limits, because the temptation is to treat this as a
/// guarantee and it is not one. Structured PII — emails, URLs, handles, phone
/// numbers, WeChat/QQ IDs, ID cards — is caught with high confidence because it
/// has shape. Free-form Chinese personal names largely do NOT have shape:
/// "张伟" is two extremely common characters, and a nickname like "大聪明" is
/// indistinguishable from an insult, which in this app it usually is.
/// `NLTagger`'s name recognition is weak on Chinese.
///
/// The Worker's system prompt also forbids the model from echoing names,
/// companies, addresses and contact handles. **Do not rely on that alone.**
/// Measured against the live Worker on 2026-09-03, immediately after that
/// instruction was deployed: contact handles, phone numbers and company names
/// were withheld, but the model still echoed a full name and a surname+title
/// in **2 of 3** generations. Models do not reliably follow negative
/// instructions under emotional load.
///
/// So this pass is a PRIMARY control, not a backstop behind a reliable one.
/// `SafetyFilter.validateOutput` then runs last, before render.
///
/// Over-masking is the safer error, but not free: the shared artifact is a
/// punchline, and a line reading "[某人] 说 [号码]" has no punch and will not be
/// shared. That is measured — see the card's generated-but-not-shared counter.
/// Hence high-precision patterns rather than aggressive guessing.
enum Redactor {
    private static let rules: [(pattern: String, replacement: String)] = [
        // Email
        ("[A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,}", "[email]"),
        // URLs
        ("https?://[^\\s]+", "[link]"),
        // @handles
        ("(^|\\s)@[A-Za-z0-9_]{2,}", "$1@—"),
        // Phone / long digit runs (7+ digits, optional separators)
        ("\\+?\\d[\\d\\s().\\-]{5,}\\d", "[number]")
    ]

    /// Chinese-language and CJK-specific PII that the ASCII rules above miss
    /// entirely. Ordered most-specific first so a WeChat ID is labelled as a
    /// contact rather than swallowed by the generic digit rule.
    /// NOTE ON ORDER: these run BEFORE the ASCII rules. A WeChat/QQ id and a
    /// mainland ID card are both mostly digits, so the generic digit rule would
    /// otherwise swallow them first and mislabel them ("QQ [number]", or an ID
    /// card reduced to "[number]X"). Specific patterns must claim their text
    /// before general ones get a turn.
    /// SCRIPT COVERAGE (fixed 2026-09-06). Every CJK literal below carries BOTH
    /// its Simplified and Traditional form, and the patterns are matched
    /// regardless of the reader's locale.
    ///
    /// Why script-agnostic patterns rather than a per-locale ruleset: the script
    /// of the TEXT and the locale of the READER are independent. A zh-Hans user
    /// can be venting about 陳經理, and a zh-Hant user's model output can come
    /// back Simplified. Gating the patterns on locale would leak in both
    /// directions, so only the replacement TOKEN is locale-dependent — see
    /// `maskToken(_:for:)`.
    ///
    /// This was a real, shipped leak: before this fix 9 of the 13 title literals
    /// were Simplified-only, so 李經理 / 張總 / 陳老師 / 劉醫生 / 孫組長 all
    /// reached the share-card canvas UNMASKED for zh-Hant readers while their
    /// Simplified twins were masked and pinned green by tests. Only the four
    /// script-identical titles (主管/董事/主任/教授) happened to work.
    private static func cjkRules(for locale: Locale) -> [(pattern: String, replacement: String)] {
        let person = maskToken(.person, for: locale)
        return [
            // Contact handles: vx / v信 / 微信 / 威信 / QQ / 扣扣 / 企鹅号.
            // `(?<![A-Za-z])` stops "qq" matching inside an ordinary word.
            ("(?<![A-Za-z])(?:vx|v信|微信[号號]?|威信|weixin|wechat|qq[号號]?|扣扣|企[鹅鵝][号號]?)\\s*[:：=]?\\s*[A-Za-z0-9_\\-]{4,}",
             maskToken(.contact, for: locale)),
            // Mainland ID card: 18 chars (trailing X allowed) or 15.
            ("(?<![0-9A-Za-z])(?:\\d{17}[\\dXx]|\\d{15})(?![0-9A-Za-z])",
             maskToken(.idCard, for: locale)),
            // Phone numbers written in Chinese numerals — a 7+ run of 零〇一二三四五六七八九
            // (with 两/兩 as a common spoken variant). Invisible to any \\d pattern.
            ("[零〇一二三四五六七八九两兩]{7,}", maskToken(.number, for: locale)),
            // Surname + UNAMBIGUOUS title: 李经理 / 王主管 / 陈老师 / 李經理 / 陳老師.
            // Deliberately NO trailing word-boundary lookahead: Chinese prose has no
            // spaces, so "张总又画饼了" would never match one. The title itself is
            // the signal, so the pattern is safe without it.
            ("[\\u4e00-\\u9fa5]{1,2}(?:总监|總監|总裁|總裁|经理|經理|主管|老师|老師|医生|醫生|律师|律師|老板|老闆|董事|主任|教授|组长|組長|队长|隊長)",
             person),
            // Bare 总/總 (张总 / 李總) needs care: 总 is also a very common adverb.
            // One surname character, and excluded before the adverbial continuations
            // so "我总是这样" / "总共" / "總是" are left alone.
            ("[\\u4e00-\\u9fa5][总總](?![是共结結计計之要算而])", person),
            // Role-prefixed nickname: PM老王 / HR小李. Anchored to either
            // 老/小/阿 + one character, or exactly two characters, so it cannot run
            // on into the rest of the sentence.
            ("(?:PM|HR|CEO|CTO|COO|VP|TL|PO)\\s*(?:[老小阿][\\u4e00-\\u9fa5]|[\\u4e00-\\u9fa5]{2})",
             person)
        ]
    }

    /// The kinds of thing a mask can stand in for. Exists so every token has
    /// ONE home — previously the strings were inlined at each rule AND again in
    /// `personReplacement`, which is how the Traditional forms went missing in
    /// one place while looking correct in the other.
    private enum MaskKind { case person, contact, idCard, number }

    /// The mask token, in the READER's script. A Simplified 「[对方]」 stamped
    /// onto a Traditional card is itself a defect the project already treats as
    /// real, so the token follows the locale even though the patterns do not.
    private static func maskToken(_ kind: MaskKind, for locale: Locale) -> String {
        switch (kind, chineseScript(for: locale)) {
        case (.person, .traditional):  return "[對方]"
        case (.person, .simplified):   return "[对方]"
        case (.person, .notChinese):   return personReplacement(for: locale)
        case (.contact, .traditional): return "[聯繫方式]"
        case (.contact, _):            return "[联系方式]"
        case (.idCard, .traditional):  return "[身份證]"
        case (.idCard, _):             return "[身份证]"
        case (.number, .traditional):  return "[號碼]"
        case (.number, _):             return "[号码]"
        }
    }

    private enum ChineseScript { case simplified, traditional, notChinese }

    /// Traditional is signalled either by an explicit `Hant` script subtag or by
    /// a Traditional-using region, so both `zh-Hant` and `zh-TW` resolve
    /// correctly. `maximalIdentifier` fills in the script Apple leaves implicit.
    private static func chineseScript(for locale: Locale) -> ChineseScript {
        guard locale.language.languageCode?.identifier == "zh" else { return .notChinese }
        if locale.language.script?.identifier == "Hant" { return .traditional }
        if let region = locale.region?.identifier, ["TW", "HK", "MO"].contains(region) {
            return .traditional
        }
        return Locale(identifier: locale.identifier).language
            .maximalIdentifier.contains("Hant") ? .traditional : .simplified
    }

    /// The original cheap pass. Unchanged behaviour.
    static func redact(_ text: String) -> String {
        apply(rules, to: text)
    }

    /// Strict pass for anything about to be rendered onto a shareable image.
    ///
    /// Order matters: structured patterns run before the NER pass, so a phone
    /// number or WeChat ID is already masked and cannot be mistaken for a name.
    static func redactForPublicShare(_ text: String, locale: Locale = .current) -> String {
        // CJK first — see the note on `cjkRules`. Then the ASCII sweep, then
        // NER last, so the name pass only ever sees text whose structured PII
        // has already been masked.
        var out = apply(cjkRules(for: locale), to: text)
        out = apply(rules, to: out)
        out = maskPersonalNames(in: out, locale: locale)
        return out
    }

    private static func apply(_ ruleset: [(pattern: String, replacement: String)],
                              to text: String) -> String {
        var out = text
        for rule in ruleset {
            guard let re = try? NSRegularExpression(
                pattern: rule.pattern, options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(out.startIndex..., in: out)
            out = re.stringByReplacingMatches(
                in: out, options: [], range: range, withTemplate: rule.replacement
            )
        }
        return out
    }

    /// Apple's on-device NER (`NLTagger` `.nameType`). Replaces recognised
    /// PERSONAL names with a neutral role so the line still reads.
    ///
    /// Organisations and places are deliberately left alone: they are far more
    /// often part of the joke than identifying ("我们公司", "北京"), and masking
    /// them costs punch for little privacy gain.
    static func maskPersonalNames(in text: String, locale: Locale = .current) -> String {
        guard !text.isEmpty else { return text }
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        // Collect first, mutate after — editing while enumerating would
        // invalidate the ranges behind us.
        var hits: [Range<String.Index>] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word,
                             scheme: .nameType,
                             options: options) { tag, range in
            if tag == .personalName { hits.append(range) }
            return true
        }
        guard !hits.isEmpty else { return text }

        let replacement = personReplacement(for: locale)
        var out = text
        for range in hits.reversed() {
            out.replaceSubrange(range, with: replacement)
        }
        return out
    }

    /// The NER pass's replacement. Kept separate from `maskToken` only because
    /// it also serves non-Chinese locales; the Chinese cases delegate so the
    /// script rule stays in one place.
    private static func personReplacement(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh": return chineseScript(for: locale) == .traditional ? "[對方]" : "[对方]"
        case "ja": return "[相手]"
        default:   return "[them]"
        }
    }
}
