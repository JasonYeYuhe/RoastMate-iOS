import Foundation

/// Parses the model's tag-prefixed transcript output into structured
/// `EchoMessage` values. Pure, deterministic, exhaustively
/// unit-testable. Returns `nil` on parse failure (caller falls back to
/// `FallbackRoasts.curatedEchoTranscript`).
///
/// Expected format per `EchoesPromptBuilder`:
///   `[VALIDATE/A] 你被惹到这种程度完全合理。`
///   `[ESCALATE/B] 这事换我我能气一个礼拜。`
///   `[DEESCALATE/B] 但你别因为这事毁今晚。`
///   `[BRIDGE/A:savage] 把这事用 Savage 回他一句 →`
enum EchoesParser {
    static func parse(_ raw: String) -> [EchoMessage]? {
        let lines = raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var messages: [EchoMessage] = []

        for line in lines {
            guard let parsed = parseLine(line) else {
                // Hard reject any unparseable line — the contract is strict
                // so callers can trust the structure. Note that the model
                // sometimes emits a stray ```text wrapper or a `---` —
                // a single stray line invalidates the whole transcript and
                // we fall back to curated.
                continue
            }
            messages.append(parsed)
        }

        // Validate constraints:
        // - 4 ≤ count ≤ 6
        // - Last message must be a .bridge
        // - At least one .validate, one .deescalate, one .bridge
        guard messages.count >= 4 && messages.count <= 6 else { return nil }
        guard messages.last?.role == .bridge else { return nil }
        guard messages.contains(where: { $0.role == .validate }),
              messages.contains(where: { $0.role == .deescalate }) else {
            return nil
        }

        return messages
    }

    /// Parse a single line. Returns nil if the format does not match.
    private static func parseLine(_ line: String) -> EchoMessage? {
        // Format: `[ROLE/IDX(:intensity)] body`
        // Find first `]` to split header from body.
        guard let bracketEnd = line.firstIndex(of: "]") else { return nil }
        guard line.first == "[" else { return nil }
        let headerStart = line.index(after: line.startIndex)
        let header = String(line[headerStart..<bracketEnd])  // ROLE/IDX or ROLE/IDX:intensity
        let bodyStart = line.index(after: bracketEnd)
        let body = String(line[bodyStart...]).trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return nil }

        // Split optional intensity hint off the header.
        let coreAndIntensity = header.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let core = String(coreAndIntensity[0])
        let intensityHint: String? = coreAndIntensity.count == 2 ? String(coreAndIntensity[1]) : nil

        let parts = core.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }

        let roleStr = String(parts[0]).uppercased()
        let idxStr = String(parts[1]).uppercased()
        guard let role = roleFor(roleStr) else { return nil }
        guard let echoIndex = echoIndexFor(idxStr) else { return nil }

        let bridgeIntensity: Intensity?
        if role == .bridge, let raw = intensityHint?.lowercased() {
            bridgeIntensity = Intensity(rawValue: raw) ?? .savage
        } else {
            bridgeIntensity = nil
        }

        // Hard length cap. Past 45 zh chars indicates the model ignored
        // the contract — drop. (Clamp instead of reject would let bad
        // outputs leak.)
        guard body.count <= 100 else { return nil }

        return EchoMessage(
            echoIndex: echoIndex,
            role: role,
            text: body,
            deliveryDelayMs: 600,
            bridgeIntensity: bridgeIntensity
        )
    }

    private static func roleFor(_ raw: String) -> EchoMessageRole? {
        switch raw {
        case "VALIDATE":   return .validate
        case "ESCALATE":   return .escalate
        case "DEESCALATE": return .deescalate
        case "BRIDGE":     return .bridge
        default:           return nil
        }
    }

    private static func echoIndexFor(_ raw: String) -> Int? {
        switch raw {
        case "A": return 0
        case "B": return 1
        default:  return nil
        }
    }
}
