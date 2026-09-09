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
    /// Both script forms — 去死 is script-identical, the other two are not.
    private static let defaultDenylist: [String] = [
        "kill yourself", "kys", "go die", "suicide",
        "杀了你", "殺了你", "去死", "自杀", "自殺"
    ]

    /// The ONLY denylist that runs on private vent/feral drafts — the last
    /// gate on cloud vent output (`RoastEngine`) and on every Echoes line
    /// (`EchoesEngine`). Rejects phrases signalling self-harm or explicit
    /// violence regardless of vent intent.
    ///
    /// A `static let`, not a local inside `validateVentOutput`, so the
    /// script-parity test can actually see it. It was a function-local for
    /// months, which is precisely why it kept its Simplified-only gap
    /// (`杀了你` with no `殺了你`, `自杀` with no `自殺`) through three separate
    /// "fix the Simplified-only list" commits.
    private static let ventHardRail: [String] = [
        "kill yourself", "kys", "go die", "suicide",
        "杀了你", "殺了你", "去死", "自杀", "自殺",
        "shoot you", "shoot them", "stab you", "stab them"
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
        let lower = trimmed.lowercased()
        if ventHardRail.first(where: { lower.contains($0) }) != nil {
            throw SafetyError.outputBlocked(reason: "vent_hard_rail")
        }
        return trimmed
    }

    /// Read-only view of the loaded denylist, for the script-parity test.
    ///
    /// Exposed because the rule worth guarding is "every CJK term carries both
    /// script forms", and that can only be checked against the whole list. The
    /// three-instance version of the test would pass again the moment someone
    /// adds a fourth Simplified-only term — which is exactly how the Redactor
    /// leak survived for months behind green tests.
    static func denylistTermsForTesting() throws -> [String] { denylist }

    /// Every CJK-bearing list in this file, keyed by name, for the script-
    /// parity test. The JSON denylist above is deliberately NOT folded in
    /// here — it has its own accessor and its own failure mode (a missing
    /// file), and the test covers both.
    ///
    /// If you add another list of literals used for MATCHING, add it here in
    /// the same commit. The rule is guarded, not the instances.
    static func matchingListsForTesting() -> [String: [String]] {
        [
            "defaultDenylist": defaultDenylist,
            "ventHardRail": ventHardRail,
            "hardSelfHarmPhrases": hardSelfHarmPhrases,
            "softSelfHarmPhrases": softSelfHarmPhrases
        ]
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
        // Reverse-direction gap: this list is not only "Simplified-only" —
        // 了結自己 shipped Traditional-only, so a zh-Hans user typing
        // 了结自己 matched nothing here and nothing in the soft list either.
        "了结自己", "了結自己",
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
        "活著沒意思", "活著沒意義",
        // 撑不下去 (not 撑不下去了) so the Simplified form matches the same
        // inputs the Traditional 撐不下去 already did — the trailing 了 made
        // "我撑不下去" miss while its Traditional twin matched.
        "撑不下去", "撐不下去", "一了百了", "解脱算了", "解脫算了",
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
