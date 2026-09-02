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

/// What a card renders: the sendable line, and nothing else.
///
/// This type deliberately has **no** field for the private vent draft. The
/// v1.3.1 purge removed `ventText` / `revealVent` (and the `ShareCardPairing`
/// helper that resolved a reply back to its source draft) so that no code path
/// — present or future — can put the user's private text onto a shareable,
/// RoastMate-branded image. `sentText` is `SafetyFilter`-validated upstream at
/// generation time and is never user-editable before render.
struct ShareCardContent: Equatable {
    var styleName: String?
    /// The polished, sendable line — the only text the card renders.
    var sentText: String
    /// Growth layer (B.4/B.5): the QR + "search RoastMate" badge. Gated by the
    /// `share_card_enabled` RemoteConfig flag, DARK by default. When false the
    /// card still renders — it just carries the plain wordmark, exactly as it
    /// does today — so flipping this on adds an acquisition surface rather than
    /// restoring a removed one.
    var showsGrowthBadge: Bool = false
}
