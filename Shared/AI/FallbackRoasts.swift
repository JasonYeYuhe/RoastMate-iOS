import Foundation

/// Curated stock responses for when Foundation Models is unavailable
/// (older hardware, unsupported locale, app review without network).
/// Keeps the app functional end-to-end for App Store reviewers.
enum FallbackRoasts {
    static func curated(for style: StylePreset, locale: Locale, count: Int) -> [String] {
        let language = locale.language.languageCode?.identifier ?? "en"
        let pool = pool(language: language)
        if pool.isEmpty {
            return defaultPool
        }
        return Array(pool.shuffled().prefix(max(1, count)))
    }

    private static func pool(language: String) -> [String] {
        switch language {
        case "zh": return zh
        case "ja": return ja
        default: return en
        }
    }

    private static let en = [
        "I admire your commitment to making my life slightly more interesting. Truly unmatched.",
        "If consistency were a sport, you'd be Olympic-grade at this particular hobby.",
        "Thanks for the daily reminder that patience is, in fact, a finite resource.",
        "I'm not upset, I'm just gathering material for a future memoir.",
        "Bold of you to assume I'd let this slide. But for now — noted."
    ]

    private static let zh = [
        "你这份坚持,真的是不分时间地点。建议你拿来干点别的。",
        "我没生气,只是开始重新评估我们之间能聊的范围。",
        "如果你这份用心放在自己身上,可能现在已经飞黄腾达了。",
        "感谢你每天都提醒我:有些底线是要靠别人来反复测试的。",
        "你这么活着,确实自由。"
    ]

    private static let ja = [
        "ご熱心なお取り組み、いつも勉強させていただいております。",
        "少々認識にズレがあるように感じております。",
        "夜間のご利用について、少しだけご配慮いただけますと大変助かります。",
        "私の理解が追いついていないだけかもしれません。再度ご説明いただけますか。",
        "貴重なお時間を頂戴し、ありがとうございました。"
    ]

    private static let defaultPool = [
        "Sometimes the most powerful response is a long, deeply unimpressed pause."
    ]

    /// Curated Echoes transcript used when the parser rejects the model
    /// output or Foundation Models is unavailable. Always returns the
    /// required 4-role structure: validate → escalate → deescalate →
    /// bridge. Pure-text fallback; safe to ship to App Review on a
    /// device without FM.
    ///
    /// zh-Hans v1 ships canned text in mandarin; other locales fall
    /// through to a slightly-softer zh-Hans variant (until v0.2's
    /// per-locale catalogs land).
    static func curatedEchoTranscript(
        tone: EchoTone,
        voiceCount: EchoVoiceCount,
        personas: [EchoSpec]
    ) -> [EchoMessage] {
        let bridgeIntensity: Intensity = (tone == .feral) ? .savage : .sharp
        let bridgeText = (tone == .feral)
            ? "把这事用 Savage 给他怼回去 →"
            : "用 Sharp 回他一句吧 →"

        if voiceCount == .one {
            return [
                EchoMessage(echoIndex: 0, role: .validate,   text: "你气成这样完全合理。"),
                EchoMessage(echoIndex: 0, role: .escalate,   text: "这种事儿换我得气一天。"),
                EchoMessage(echoIndex: 0, role: .deescalate, text: "但你别因为这事毁今晚。"),
                EchoMessage(echoIndex: 0, role: .bridge,     text: bridgeText, bridgeIntensity: bridgeIntensity)
            ]
        } else {
            return [
                EchoMessage(echoIndex: 0, role: .validate,   text: "你气成这样完全合理。"),
                EchoMessage(echoIndex: 1, role: .escalate,   text: "这种事儿换我得气一天。"),
                EchoMessage(echoIndex: 0, role: .escalate,   text: "而且他这不是第一次了吧。"),
                EchoMessage(echoIndex: 1, role: .deescalate, text: "但你别因为这事毁今晚。"),
                EchoMessage(echoIndex: 0, role: .bridge,     text: bridgeText, bridgeIntensity: bridgeIntensity)
            ]
        }
    }
}
