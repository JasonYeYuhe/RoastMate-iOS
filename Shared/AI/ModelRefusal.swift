import Foundation

/// Recognises a model refusal that came back as ordinary text.
///
/// Why this exists: "make it sendable" runs under
/// `Guardrails.permissiveContentTransformations` (see `FMGuardrails`). Apple
/// documents that in this mode a refusal is not thrown — "it generates a String
/// refusal message" instead
/// (https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel/guardrails/permissivecontenttransformations).
/// Without this check that refusal would be saved and shown, with a Share
/// button, as the user's rewritten message.
///
/// **Conservative on purpose.** A false positive throws away a good rewrite;
/// a false negative shows the user an obvious refusal they will not send. So
/// this matches only:
/// 1. Apple's own refusal sentences, at the START of the text. Measured on
///    macOS 27.0.1 (2026-10-22, permissive guardrails, 4 languages):
///    "Unable to work with that request." (+ an optional reason sentence),
///    「無法處理該請求。」, 「无法处理该请求。」, 「そのリクエストには対応できません。」
/// 2. The model talking about itself ("As an AI, …", 「作為AI，…」, 「AIとして」), anywhere.
/// 3. A classic short refusal ("I'm sorry, but I can't help with that.",
///    「抱歉，我無法協助這個請求。」, 「申し訳ありませんが、お手伝いできません。」)
///    when it is the whole text. "I'm sorry, but I can't keep covering
///    your shifts." is a real reply and must survive.
/// 4. The same classic refusal as the complete FIRST sentence, followed by an
///    assistant's offer ("I'm sorry, but I can't help with that. If you'd
///    like, I can help you write a more respectful message." / 「…有其他需要
///    嗎？」 / 「他にお手伝いできることがあれば…」). Rule 3 alone missed this
///    shape (reviewer, 2026-10-22). The offer has to be assistant talk about
///    helping, rephrasing or "anything else": "Sorry, I can't help with that.
///    You'll need to ask Sam." and "…If you'd like, I can cover Friday
///    instead." are real messages and stay.
enum ModelRefusal {

    static func looksLikeRefusal(_ text: String) -> Bool {
        let t = normalized(text)
        guard !t.isEmpty else { return false }
        if appleTemplates.contains(where: { matches($0, t, anchored: true) }) { return true }
        if selfReferences.contains(where: { matches($0, t, anchored: false) }) { return true }
        for core in classicRefusals {
            if matches(core + "[.!。！]?", t, anchored: true, wholeText: true) { return true }
            if let remainder = textAfterLeadingSentence(core, in: t),
               assistantOffers.contains(where: { matches($0, remainder, anchored: false) }) {
                return true
            }
        }
        return false
    }

    // MARK: - Patterns (all matched against `normalized` text)

    /// Apple's refusal sentence opens the text.
    private static let appleTemplates: [String] = [
        #"(i'm |i am )?unable to work with (that|this|the) request"#,
        #"(無法|无法)(處理|处理)(該|该|這個|这个|此)(請求|请求)"#,
        #"(その|この)?リクエスト(には|に)(対応|お応え|お答え)(でき|いたしかね)ません"#,
    ]

    /// An AI describing ITSELF ("as an AI…", 「作為AI…」, 「AIとして…」).
    /// Self-referential forms only, with word boundaries: a bare "AI
    /// assistant" / 「AI助手」 is a plausible line in a real message ("I'm not
    /// your AI assistant"), and an unbounded "as an ai" also matched "as an
    /// aide" / "as an airline…". (Reviewer fix, 2026-10-22.)
    private static let selfReferences: [String] = [
        #"\bas an ai( (language )?model| assistant)?(,|，|\.|\s+i\b)"#,
        #"\bas a (large )?language model\b"#,
        #"\bi(?:'m| am) (just |only )?(an ai( (language )?model| assistant)?|a (large )?language model)(,|，|\.|!|$|\s+(and|so|but|that|who|which)\b)"#,
        #"(作為|作为|身為|身为)(一個|一个|一名)?(ai|人工智慧|人工智能|語言模型|语言模型)(助理|助手|模型)?(，|,|、|我)"#,
        #"(ai|aiアシスタント|言語モデル)として"#,
    ]

    /// Classic short refusals, WITHOUT their closing punctuation. They count
    /// when they are the entire text (rule 3), or the complete first sentence
    /// followed by an `assistantOffers` match (rule 4).
    private static let classicRefusals: [String] = [
        #"((i'm sorry|sorry|i apologize),? ?(but )?)?(i can't|i cannot|i'm unable to|i am unable to|i'm not able to|i won't be able to) (assist|help)( you)? with (that|this)( request)?"#,
        #"((i'm sorry|sorry|i apologize),? ?(but )?)?(i can't|i cannot|i'm unable to|i am unable to) (comply( with (that|this|the|your) request)?|fulfill (that|this|the|your) request)"#,
        #"((很)?抱歉|對不起|对不起)?[，,]?(我)?(無法|无法|不能)(協助|协助|幫助|帮助|處理|处理|提供)(你|您)?(的)?(這個|这个|該|该|此|這項|这项)?(請求|请求|內容|内容)"#,
        #"(申し訳(ありません|ございません)(が|。)[、,]?)?(その|この)?(ご依頼|リクエスト|ご要望|要望)?(には|に)?(お応え|お答え|対応|お手伝い)(でき|いたしかね)ません"#,
    ]

    /// An assistant offering something else after refusing. Deliberately
    /// narrow: "if you'd like", "let me know" and "feel free to reach out"
    /// are everyday message phrases, so they only count with an assistant
    /// verb (help you write / rephrase / anything else I can help with).
    private static let assistantOffers: [String] = [
        #"\b(anything|something) else (i can|i could|you'd like|you would like)"#,
        #"\bhelp( you)? (to )?(write|draft|craft|compose|express|phrase|rephrase|reword|come up with)\b"#,
        #"\b(rephrase|reword) (it|this|that|your (message|request))\b"#,
        #"\bfeel free to (ask|rephrase)\b"#,
        #"(有|還有|还有)(其他|別的|别的)(問題|问题|需要|需求|請求|请求)"#,
        #"(其他|別的|别的)(我可以|我能)"#,
        #"(可以|能|很樂意|很乐意|樂意|乐意)(幫|帮|協助|协助)(你|您)(改寫|改写|重寫|重写|撰寫|撰写|寫|写|表達|表达|措辭|措辞|潤飾|润饰|換個|换个)"#,
        #"(換|换)(個|个)(方式|說法|说法|角度)"#,
        #"他に(お手伝い|何か|ご質問|できること)"#,
        #"(別の|ほかの|他の)(言い方|表現|ご依頼|方法で)"#,
        #"(丁寧|穏やか|建設的|前向き)な(表現|言い方|メッセージ|文面)"#,
    ]

    // MARK: - Helpers

    /// Lower-cased, curly quotes straightened, surrounding whitespace and
    /// quotation marks removed (models often wrap a reply in 「」 or "").
    private static func normalized(_ text: String) -> String {
        var t = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
        let wrappers = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "\"'\u{201C}\u{201D}「」『』"))
        t = t.trimmingCharacters(in: wrappers)
        return t
    }

    /// When `core` plus a sentence-ending mark opens the text, the rest of
    /// the text after it; otherwise nil. A refusal that runs on ("I can't help
    /// with that today") is not a complete first sentence and returns nil.
    private static func textAfterLeadingSentence(_ core: String, in text: String) -> String? {
        guard let range = text.range(of: "^" + core + "[.!。！]", options: .regularExpression) else {
            return nil
        }
        let rest = text[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return rest.isEmpty ? nil : rest
    }

    private static func matches(_ pattern: String, _ text: String, anchored: Bool, wholeText: Bool = false) -> Bool {
        let full = (anchored ? "^" : "") + pattern + (wholeText ? "$" : "")
        return text.range(of: full, options: .regularExpression) != nil
    }
}
