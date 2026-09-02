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
    private static let cjkRules: [(pattern: String, replacement: String)] = [
        // Contact handles: vx / v信 / 微信 / 威信 / QQ / 扣扣 / 企鹅号.
        // `(?<![A-Za-z])` stops "qq" matching inside an ordinary word.
        ("(?<![A-Za-z])(?:vx|v信|微信号?|威信|weixin|wechat|qq号?|扣扣|企鹅号?)\\s*[:：=]?\\s*[A-Za-z0-9_\\-]{4,}",
         "[联系方式]"),
        // Mainland ID card: 18 chars (trailing X allowed) or 15.
        ("(?<![0-9A-Za-z])(?:\\d{17}[\\dXx]|\\d{15})(?![0-9A-Za-z])", "[身份证]"),
        // Phone numbers written in Chinese numerals — a 7+ run of 零〇一二三四五六七八九
        // (with 两 as a common spoken variant). Invisible to any \\d pattern.
        ("[零〇一二三四五六七八九两]{7,}", "[号码]"),
        // Surname + UNAMBIGUOUS title: 李经理 / 王主管 / 陈老师.
        // Deliberately NO trailing word-boundary lookahead: Chinese prose has no
        // spaces, so "张总又画饼了" would never match one. The title itself is
        // the signal, so the pattern is safe without it.
        ("[\\u4e00-\\u9fa5]{1,2}(?:总监|总裁|经理|主管|老师|医生|律师|老板|董事|主任|教授|组长|队长)",
         "[对方]"),
        // Bare 总 (张总 / 李总) needs care: 总 is also a very common adverb.
        // One surname character, and excluded before the adverbial continuations
        // so "我总是这样" / "总共" are left alone.
        ("[\\u4e00-\\u9fa5]总(?![是共结计之要算而算])", "[对方]"),
        // Role-prefixed nickname: PM老王 / HR小李. Anchored to either
        // 老/小/阿 + one character, or exactly two characters, so it cannot run
        // on into the rest of the sentence.
        ("(?:PM|HR|CEO|CTO|COO|VP|TL|PO)\\s*(?:[老小阿][\\u4e00-\\u9fa5]|[\\u4e00-\\u9fa5]{2})",
         "[对方]")
    ]

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
        var out = apply(cjkRules, to: text)
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

    private static func personReplacement(for locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh": return "[对方]"
        case "ja": return "[相手]"
        default:   return "[them]"
        }
    }
}
