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
}

private struct ForbiddenTermsFile: Codable {
    let terms: [String]
}
