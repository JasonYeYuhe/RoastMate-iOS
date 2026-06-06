import Foundation

/// Parses the model's tag-prefixed transcript output into structured
/// `EchoMessage` values. Pure, deterministic, exhaustively
/// unit-testable. Returns `nil` on parse failure (caller falls back to a
/// curated transcript via `FallbackRoasts`).
///
/// Two contracts, selected by `scene`:
///   - `.classic`       : 4–6 messages, voices A/B. LENIENT — a stray
///                        wrapper line (```text / ---) is skipped. This is
///                        the SHIPPED behaviour and is left untouched.
///   - `.roommateGroup` : 8–10 messages, voices A/B/C with each voice
///                        speaking ≥2×, exactly one BRIDGE (last). STRICT —
///                        any malformed tagged line rejects the whole
///                        transcript. The stricter contract never relaxes
///                        the classic rules.
///
/// Expected line format (both scenes):
///   `[VALIDATE/A] 你被惹到这种程度完全合理。`
///   `[ESCALATE/B] 这事换我我能气一个礼拜。`
///   `[DEESCALATE/C] 但你别因为这事毁今晚。`
///   `[BRIDGE/A:savage] 把这事用 Savage 回他一句 →`
enum EchoesParser {
    static func parse(_ raw: String, scene: EchoScene = .classic) -> [EchoMessage]? {
        let lines = raw
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var messages: [EchoMessage] = []

        for line in lines {
            if let parsed = parseLine(line, scene: scene) {
                messages.append(parsed)
                continue
            }
            // Unparseable line:
            //  - classic: skip it. The model sometimes emits a stray
            //    ```text wrapper or a `---`; leniency is the shipped
            //    behaviour and several classic tests depend on it.
            //  - roommate: a line that LOOKS like a tagged message (`[…]`)
            //    but fails the contract HARD-rejects the whole transcript
            //    (→ curated roommate fallback). Non-tag wrapper lines are
            //    still skipped.
            if scene == .roommateGroup && line.first == "[" {
                return nil
            }
        }

        return validate(messages, scene: scene)
    }

    /// Structural validation, by scene. Shared rails (last is bridge, at
    /// least one validate + one deescalate) apply to both.
    private static func validate(_ messages: [EchoMessage], scene: EchoScene) -> [EchoMessage]? {
        guard messages.last?.role == .bridge else { return nil }
        guard messages.contains(where: { $0.role == .validate }),
              messages.contains(where: { $0.role == .deescalate }) else { return nil }

        switch scene {
        case .classic:
            guard (4...6).contains(messages.count) else { return nil }
        case .roommateGroup:
            guard (8...10).contains(messages.count) else { return nil }
            // Exactly one bridge — the single payoff (already known last).
            guard messages.filter({ $0.role == .bridge }).count == 1 else { return nil }
            // Each of the three synthetic roommates (A/B/C → 0/1/2) must
            // actually speak ≥2× — otherwise it isn't a group.
            for idx in 0...2 {
                guard messages.filter({ $0.echoIndex == idx }).count >= 2 else { return nil }
            }
        }
        return messages
    }

    /// Parse a single line. Returns nil if the format does not match the
    /// scene's contract.
    private static func parseLine(_ line: String, scene: EchoScene) -> EchoMessage? {
        // Format: `[ROLE/IDX(:intensity)] body`
        guard line.first == "[" else { return nil }
        guard let bracketEnd = line.firstIndex(of: "]") else { return nil }
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
        guard let echoIndex = echoIndexFor(idxStr, scene: scene) else { return nil }

        let bridgeIntensity: Intensity?
        if role == .bridge, let raw = intensityHint?.lowercased() {
            bridgeIntensity = Intensity(rawValue: raw) ?? .savage
        } else {
            bridgeIntensity = nil
        }

        // Hard length cap. Past the cap means the model ignored the
        // contract — drop (clamping would let bad output leak). Roommate
        // messages are meant to be punchier, so the cap is tighter.
        let maxLen = (scene == .roommateGroup) ? 80 : 100
        guard body.count <= maxLen else { return nil }

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

    /// Voice index. Classic ships A/B only; the roommate group adds C. An
    /// out-of-range index (e.g. `D`) returns nil — in roommate scene that
    /// hard-rejects the transcript; in classic it drops the single line.
    private static func echoIndexFor(_ raw: String, scene: EchoScene) -> Int? {
        switch raw {
        case "A": return 0
        case "B": return 1
        case "C": return scene == .roommateGroup ? 2 : nil
        default:  return nil
        }
    }
}
