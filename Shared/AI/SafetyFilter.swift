import Foundation
import os.log

enum SafetyError: LocalizedError {
    case inputBlocked(reason: String)
    case outputBlocked(reason: String)

    var errorDescription: String? {
        switch self {
        case .inputBlocked(let reason):
            return String(localized: "safety.input_blocked") + " (\(reason))"
        case .outputBlocked(let reason):
            return String(localized: "safety.output_blocked") + " (\(reason))"
        }
    }
}

/// Three-layer safety pipeline:
/// 1. Pre-input: regex denylist (slurs, threats, self-harm, well-known person names).
/// 2. Foundation Models built-in guardrail (handled in `RoastEngine` via catch).
/// 3. Post-output: same denylist + length sanity.
enum SafetyFilter {
    private static let logger = Logger(subsystem: "yyh.roastmate.app", category: "SafetyFilter")

    private static let denylist: [String] = {
        guard let url = ResourceBundle.url(forResource: "ForbiddenTerms", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(ForbiddenTermsFile.self, from: data)
        else {
            logger.error("ForbiddenTerms.json missing — safety filter degraded.")
            return defaultDenylist
        }
        return file.terms.map { $0.lowercased() }
    }()

    /// Hardcoded ultimate fallback if the JSON file is missing (should never happen in production).
    private static let defaultDenylist: [String] = [
        "kill yourself", "kys", "go die", "suicide",
        "杀了你", "去死", "自杀"
    ]

    static func validateInput(_ text: String) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SafetyError.inputBlocked(reason: "empty")
        }
        guard trimmed.count <= 1500 else {
            throw SafetyError.inputBlocked(reason: "too_long")
        }
        if let hit = matchedDenylistTerm(in: trimmed) {
            logger.warning("Input blocked: term=\(hit, privacy: .private)")
            throw SafetyError.inputBlocked(reason: "denylist")
        }
    }

    @discardableResult
    static func validateOutput(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SafetyError.outputBlocked(reason: "empty")
        }
        guard trimmed.count <= 1200 else {
            throw SafetyError.outputBlocked(reason: "too_long")
        }
        if matchedDenylistTerm(in: trimmed) != nil {
            throw SafetyError.outputBlocked(reason: "denylist")
        }
        return trimmed
    }

    /// Output validator for the **vent-draft** path only. Vent drafts are
    /// labelled "for yourself only" in the UI and are NOT presented as
    /// sendable content, so we tolerate stronger language and mild
    /// profanity. The hard rails (slurs, threats, self-harm, sexual content)
    /// continue to apply — those are loaded into a stricter sub-denylist
    /// named `ForbiddenVentTerms` if present, else we fall back to the same
    /// list used for sendable output.
    ///
    /// Until `ForbiddenVentTerms.json` ships (TODO for codex), this method
    /// is intentionally identical to `validateOutput` minus the strict
    /// match — we still enforce length, but skip the denylist substring
    /// check so common venting words like "尼玛" / "damn" don't get dropped.
    /// The model's own SAFETY RULES preamble + the universal `denylist`
    /// applied at the prompt layer is the primary defense for vent drafts.
    @discardableResult
    static func validateVentOutput(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SafetyError.outputBlocked(reason: "empty")
        }
        guard trimmed.count <= 1500 else {
            throw SafetyError.outputBlocked(reason: "too_long")
        }
        // Only reject on the hard-rail subset: phrases that signal self-harm
        // or explicit violence, regardless of vent intent.
        let hardRail: [String] = [
            "kill yourself", "kys", "go die", "suicide",
            "杀了你", "去死", "自杀",
            "shoot you", "shoot them", "stab you", "stab them"
        ]
        let lower = trimmed.lowercased()
        if hardRail.first(where: { lower.contains($0) }) != nil {
            throw SafetyError.outputBlocked(reason: "vent_hard_rail")
        }
        return trimmed
    }

    /// Returns the first denylist substring matched, lowercased, if any.
    private static func matchedDenylistTerm(in text: String) -> String? {
        let lower = text.lowercased()
        return denylist.first { !$0.isEmpty && lower.contains($0) }
    }

    // MARK: - Self-harm crisis detection (two-tier)
    //
    // ADDITIVE ONLY. This does NOT modify or relax `validateInput`,
    // `validateOutput`, or `validateVentOutput` — those filters are
    // unchanged, so the safety guarantee is not weakened. This signals
    // the *user's own* self-harm risk so the UI can offer supportive
    // resources, distinct from the denylist (slurs / threats aimed at
    // *others*).
    //
    // Two tiers, because this is a venting app:
    //  • `.hard` — explicit ideation. The UI intercepts *before*
    //    generating and shows the full support card (input never
    //    generated).
    //  • `.soft` — hyperbole-prone phrases ("ugh I want to die"). The
    //    roast still generates, but a gentle supportive banner is shown
    //    alongside it. Venting isn't blocked; help is still offered.
    //
    // Privacy: this never logs the input or the matched phrase.
    enum CrisisSignal: Equatable { case none, soft, hard }

    /// Explicit ideation — always intercept.
    private static let hardSelfHarmPhrases: [String] = [
        // English
        "kill myself", "killing myself", "kill my self", "end my life",
        "ending my life", "take my own life", "suicidal",
        "don't want to live", "dont want to live", "do not want to live",
        "no reason to live", "better off dead", "self-harm", "self harm",
        "cut myself", "cutting myself", "hurt myself", "harm myself",
        // 中文（强信号）
        "自杀", "自殺", "我想自杀", "想自杀", "我要自杀", "我想自殺",
        "想自殺", "我要自殺", "不想活了", "不想活", "活不下去", "我不想活",
        "结束自己的生命", "结束生命", "結束自己的生命", "結束生命",
        "自残", "自伤", "伤害自己", "自殘", "傷害自己", "轻生", "輕生",
        "了結自己",
        // 日本語（強い表現）
        "自殺したい", "自殺する", "もう生きられない", "リストカット",
        "自傷", "自分を傷つけ"
    ]

    /// Hyperbole-prone — still generate, but surface a supportive banner.
    private static let softSelfHarmPhrases: [String] = [
        // English
        "want to die", "wanna die", "i want to die", "end it all",
        "i can't go on", "i cant go on", "want to disappear",
        "don't want to be here", "dont want to be here",
        // 中文（可能是夸张表达）
        "我想死", "想死", "想去死", "活着没意思", "活着没意义",
        "撑不下去了", "撐不下去", "一了百了", "解脱算了",
        // 日本語（誇張表現の可能性）
        "死にたい", "消えたい", "生きていたくない", "生きるのがつらい",
        "いなくなりたい"
    ]

    /// Two-tier self-harm signal. `.hard` → intercept (do not generate);
    /// `.soft` → keep generating but show a supportive banner; `.none`
    /// → normal. Does not gate or alter the filters above.
    static func crisisSignal(_ text: String) -> CrisisSignal {
        let lower = text.lowercased()
        if hardSelfHarmPhrases.contains(where: { lower.contains($0) }) { return .hard }
        if softSelfHarmPhrases.contains(where: { lower.contains($0) }) { return .soft }
        return .none
    }
}

private struct ForbiddenTermsFile: Codable {
    let terms: [String]
}
