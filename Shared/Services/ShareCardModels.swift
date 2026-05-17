import SwiftUI

/// Export aspect ratios tuned for the Chinese-language-first social
/// surfaces: 4:5 for 小红书 / IG feed, 9:16 for 抖音 / Reels / Stories.
enum ShareCardFormat: String, CaseIterable, Identifiable {
    case portrait45
    case story916

    var id: String { rawValue }

    var pixelSize: CGSize {
        switch self {
        case .portrait45: return CGSize(width: 1080, height: 1350)
        case .story916:   return CGSize(width: 1080, height: 1920)
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .portrait45: return "sharecard.format.portrait"
        case .story916:   return "sharecard.format.story"
        }
    }
}

/// What a card renders. The vent ("before") side is privacy-load-bearing:
/// `revealVent` defaults **false**, and when false the rendered image
/// never contains the vent text at all — only an obscured placeholder.
/// The composer flips it to true only after an explicit, warned opt-in,
/// and feeds back the locally PII-redacted / user-edited text.
struct ShareCardContent: Equatable {
    var styleName: String?
    /// The polished, sendable line — always shown.
    var sentText: String
    /// Optional "before" vent text. Only legible in the export if
    /// `revealVent` is true (composer-controlled).
    var ventText: String?
    var revealVent: Bool = false

    var hasVentPairing: Bool {
        guard let v = ventText else { return false }
        return !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Resolves the `.ventDraft` a `.sendableReply` was rewritten from, so
/// the share card can offer the Vent→Sent layout.
enum ShareCardPairing {
    static func ventText(for result: GeneratedRoast, in pool: [GeneratedRoast]) -> String? {
        guard result.kind == .sendableReply,
              let srcId = result.sourceVentDraftId else { return nil }
        return pool.first { $0.id == srcId && $0.kind == .ventDraft }?.text
    }
}

extension RoastSession {
    func sourceVentText(for result: GeneratedRoast) -> String? {
        ShareCardPairing.ventText(for: result, in: results ?? [])
    }
}
