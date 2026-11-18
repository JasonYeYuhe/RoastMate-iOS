import Foundation
import NaturalLanguage

/// 1.9.0 Q1: drops sendable versions that do not answer the situation.
///
/// On macOS 27.2.1 the shipped 1.8.0 engine showed 26.7 % non-answers among
/// its Composed / Sharp / Savage versions ("Sleepwalking?", 「明天八點前。」)
/// and only 58 % shared a single word with what the user typed
/// (`docs/evidence/2026-11-18-pro-bench`, control180). The formulas are the
/// bench's (`score.py`, plan §2), so what the screen drops is exactly what the
/// gate counts:
///
/// - **short:** fewer than 8 Han/kana characters (zh/ja) or 5 words (other);
/// - **question only:** ends in ?/？ with no clause before it that ends in
///   anything but a question mark;
/// - **no verb (English only):** NLTagger finds no verb. It has no lexical
///   classes for Chinese or Japanese, so the rule cannot apply there;
/// - **ungrounded:** shares no noun or verb lemma (English) and no character
///   bigram outside a stop list (Chinese, Japanese) with the situation.
enum AnswerScreen {
    enum Reason: String, Sendable, Equatable {
        case short, questionOnly, noVerb, ungrounded
    }

    static func reasons(_ text: String, situation: String, locale: Locale) -> [Reason] {
        var out: [Reason] = []
        let cjk = isCJK(locale)
        if cjk ? hanKanaCount(text) < 8 : englishWords(text).count < 5 { out.append(.short) }
        if questionOnly(text) { out.append(.questionOnly) }
        if !cjk, !hasVerb(text) { out.append(.noVerb) }
        if !grounded(text, situation: situation, locale: locale) { out.append(.ungrounded) }
        return out
    }

    static func passes(_ text: String, situation: String, locale: Locale) -> Bool {
        reasons(text, situation: situation, locale: locale).isEmpty
    }

    /// One line for the retry prompt, naming what was wrong with the last try.
    static func retryInstruction(for reasons: Set<Reason>) -> String {
        var problems: [String] = []
        if reasons.contains(.short) || reasons.contains(.noVerb) {
            problems.append("some were a word or a fragment instead of a full sentence")
        }
        if reasons.contains(.questionOnly) { problems.append("some were only a question") }
        if reasons.contains(.ungrounded) { problems.append("some did not mention anything that actually happened") }
        let why = problems.isEmpty ? "" : " Last time " + problems.joined(separator: ", and ") + "."
        return "IMPORTANT:\(why) Every line must be at least one complete sentence that states something, and it must name one concrete thing from the situation above — what they did or said, or a time, a place or an object the user mentioned. A question may follow the statement, never replace it."
    }

    // MARK: - The formulas (mirror score.py)

    static func isCJK(_ locale: Locale) -> Bool {
        let code = locale.language.languageCode?.identifier
        return code == "zh" || code == "ja"
    }

    private static func isJapanese(_ locale: Locale) -> Bool {
        locale.language.languageCode?.identifier == "ja"
    }

    static func isHan(_ s: Unicode.Scalar) -> Bool {
        (0x3400...0x4DBF).contains(s.value) || (0x4E00...0x9FFF).contains(s.value) || (0xF900...0xFAFF).contains(s.value)
    }
    static func isKana(_ s: Unicode.Scalar) -> Bool { (0x3040...0x30FF).contains(s.value) }
    private static func isKatakana(_ s: Unicode.Scalar) -> Bool { (0x30A0...0x30FF).contains(s.value) }

    static func hanKanaCount(_ text: String) -> Int {
        text.unicodeScalars.filter { isHan($0) || isKana($0) }.count
    }

    static func englishWords(_ text: String) -> [String] {
        matches(#"[A-Za-z0-9]+(?:['’][A-Za-z]+)?"#, in: text)
    }

    private static let outerQuotes: [(Character, Character)] = [("「", "」"), ("『", "』"), ("\"", "\""), ("“", "”"), ("'", "'")]

    static func stripOuterQuotes(_ text: String) -> String {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for (o, c) in outerQuotes where s.count >= 2 && s.first == o && s.last == c {
            let inner = s.dropFirst().dropLast()
            if !inner.contains(o) && !inner.contains(c) {
                return String(inner).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return s
    }

    static func questionOnly(_ text: String) -> Bool {
        var core = stripOuterQuotes(text)
        while let last = core.last, "」』\"”'）) \n\t".contains(last) { core.removeLast() }
        guard let last = core.last, last == "?" || last == "？" else { return false }
        let delimiters = Set(".!?。！？,，;；:：、…")
        let questionMarks = Set("?？!！")
        var clause = ""
        var delim = ""
        func clauseEnds() -> Bool {
            // A non-empty clause closed by anything but ?/？ (or ?! mixes) is declarative.
            let c = clause.trimmingCharacters(in: .whitespaces)
            defer { clause = ""; delim = "" }
            guard !c.isEmpty else { return false }
            let d = Set(delim)
            if !d.isSubset(of: questionMarks) { return true }
            if d.isSubset(of: Set("!！")) { return true }
            return false
        }
        for ch in core {
            if delimiters.contains(ch) {
                delim.append(ch)
            } else {
                if !delim.isEmpty, clauseEnds() { return false }
                clause.append(ch)
            }
        }
        if !delim.isEmpty, clauseEnds() { return false }
        return true
    }

    // MARK: English (NLTagger)

    private static let englishStop: Set<String> = [
        "be", "have", "do", "get", "make", "go", "say", "will", "would", "can", "could", "should",
        "may", "might", "must", "let", "know", "think", "want", "need", "take", "give", "see",
        "come", "look", "tell", "thing", "time", "way", "lot", "one", "people", "something",
        "anything", "nothing", "everything", "someone", "anyone", "everyone", "day", "keep",
    ]

    /// (lexical class, lowercased lemma) per word.
    static func englishTags(_ text: String) -> [(NLTag?, String)] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var out: [(NLTag?, String)] = []
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                             options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            let lemma = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lemma).0?.rawValue
                ?? String(text[range])
            out.append((tag, lemma.lowercased()))
            return true
        }
        return out
    }

    static func hasVerb(_ text: String) -> Bool {
        englishTags(text).contains { $0.0 == .verb }
    }

    private static func englishContent(_ text: String) -> Set<String> {
        Set(englishTags(text).filter { ($0.0 == .noun || $0.0 == .verb) && !englishStop.contains($0.1) }.map(\.1))
    }

    // MARK: Chinese / Japanese bigrams

    private static let chineseStop: Set<String> = [
        "我們", "你們", "他們", "她們", "這個", "那個", "这个", "那个", "一個", "一个", "什麼", "什么",
        "怎麼", "怎么", "就是", "不是", "還是", "还是", "可以", "沒有", "没有", "因為", "因为", "所以",
        "但是", "已經", "已经", "自己", "時候", "时候", "真的", "這樣", "这样", "那樣", "那样", "一下",
        "一點", "一点", "不會", "不会", "知道", "覺得", "觉得", "現在", "现在", "如果", "我的", "你的",
        "他的", "她的", "的時", "的话", "的話", "是你", "是我", "你是", "我是", "不要", "不能", "應該",
        "应该", "一直", "還在", "还在", "每次", "到底", "其實", "其实", "這種", "这种", "那種", "那种",
    ]
    private static let japaneseStop: Set<String> = ["自分", "今日", "本当", "一番", "全部", "大丈夫", "時間", "毎回", "何度"]

    static func contentBigrams(_ text: String, locale: Locale) -> Set<String> {
        let ja = isJapanese(locale)
        var out = Set<String>()
        var run: [Unicode.Scalar] = []
        func flush() {
            if run.count >= 2 {
                for i in 0..<(run.count - 1) {
                    let a = run[i], b = run[i + 1]
                    let bigram = String(String.UnicodeScalarView([a, b]))
                    if ja {
                        guard isHan(a) || isHan(b) || (isKatakana(a) && isKatakana(b)) else { continue }
                        if japaneseStop.contains(bigram) { continue }
                    } else if chineseStop.contains(bigram) {
                        continue
                    }
                    out.insert(bigram)
                }
            }
            run = []
        }
        for s in text.unicodeScalars {
            if isHan(s) || isKana(s) { run.append(s) } else { flush() }
        }
        flush()
        return out
    }

    private static func latinWords(_ text: String) -> Set<String> {
        Set(matches(#"[A-Za-z]{2,}"#, in: text).map { $0.lowercased() })
    }

    static func grounded(_ text: String, situation: String, locale: Locale) -> Bool {
        if isCJK(locale) {
            if !contentBigrams(text, locale: locale).isDisjoint(with: contentBigrams(situation, locale: locale)) {
                return true
            }
            return !latinWords(text).isDisjoint(with: latinWords(situation))
        }
        return !englishContent(text).isDisjoint(with: englishContent(situation))
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range) }
    }
}

/// The answer screen applied to one generation: what the versions must
/// answer, and how the engine sorts and falls back.
struct AnswerTarget: Sendable {
    let situation: String
    let locale: Locale

    /// Versions sorted by how well they answer.
    struct Pool: Sendable {
        /// Pass every rule.
        var answered: [String] = []
        /// Full statements that only failed `.ungrounded`.
        var statements: [String] = []
        /// Everything else (short, question only, no verb).
        var rest: [String] = []
        var reasons: Set<AnswerScreen.Reason> = []

        mutating func merge(_ other: Pool) {
            answered += other.answered
            statements += other.statements
            rest += other.rest
            reasons.formUnion(other.reasons)
        }

        /// What the user sees: the versions that answer; if none does even
        /// after the retry, full statements; if none, `fallback` (what 1.8.0
        /// showed). Never curated text: the screen must not turn a model
        /// answer into a canned one (the curated rate is a no-regression gate).
        func shown(count: Int, fallback: [String]) -> [String] {
            for tier in [answered, statements, fallback] {
                let kept = PromptBuilder.droppingNearDuplicates(tier)
                if !kept.isEmpty { return Array(kept.prefix(count)) }
            }
            return []
        }
    }

    func sort(_ variants: [String]) -> Pool {
        var pool = Pool()
        for v in variants {
            let r = AnswerScreen.reasons(v, situation: situation, locale: locale)
            pool.reasons.formUnion(r)
            if r.isEmpty { pool.answered.append(v) }
            else if r == [.ungrounded] { pool.statements.append(v) }
            else { pool.rest.append(v) }
        }
        return pool
    }

    /// The original user prompt plus the reason line, language reminder last.
    func retryPrompt(_ user: String, reasons: Set<AnswerScreen.Reason>) -> String {
        [user, AnswerScreen.retryInstruction(for: reasons), PromptBuilder.userLanguageReminder(for: locale)]
            .joined(separator: "\n")
    }
}
