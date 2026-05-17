import Foundation

/// The consumables-primary half of v1.1 hybrid monetization.
///
/// A "credit" is the spendable currency for ONE generation or ONE
/// sendable-rewrite. Credits are deliberately a *quantity* knob only —
/// they NEVER unlock a capability. Savage / Feral / Vent intensities and
/// the Pro style shelf stay subscription-only no matter how many credits
/// a non-subscriber holds (see `Intensity.requiresPro` /
/// `StylePreset.Tier` — unchanged by Pillar B). Pro is the unlimited,
/// best-value tier for heavy users; credits are the pay-as-you-go path
/// for everyone else, which is the dominant model for the zh-first push.
///
/// Pure value type with no StoreKit dependency so the ladder + the
/// product→credits mapping are unit-testable in the Shared test target
/// (the codebase convention: testable logic lives in `Shared/`).
enum CreditCatalog {

    // MARK: - Trial / starter window (tunable)

    /// One-time seeded wallet granted on first launch (and once to
    /// already-installed users on upgrade). This is the real "trial" —
    /// a free credit gift, NOT a fake StoreKit introductory offer.
    static let seededTrialCredits = 10

    /// Soft-landing window after first launch during which a small daily
    /// trickle of free generations is granted *without* touching the
    /// wallet, so a new user can form the habit before hitting the wall.
    static let starterWindowDays = 7

    /// Free generations per day during the starter window. These do not
    /// deduct credits; they expire daily and do not roll over.
    static let starterWindowDailyTrickle = 2

    // MARK: - Consumable ladder (tunable)

    /// A purchasable credit pack. `id` is the StoreKit product identifier;
    /// `credits` is what the wallet receives on a verified purchase.
    /// Display price is intentionally NOT modeled here — StoreKit /
    /// App Store Connect is the single source of truth for localized
    /// pricing. The reference RMB ladder is ¥1→10 / ¥6→70 / ¥12→160 /
    /// ¥25→380 (set in ASC; the `.storekit` file mirrors it for the
    /// local sandbox only).
    enum Pack: String, CaseIterable, Identifiable, Sendable {
        case p10  = "yyh.roastmate.app.credits.10"
        case p70  = "yyh.roastmate.app.credits.70"
        case p160 = "yyh.roastmate.app.credits.160"
        case p380 = "yyh.roastmate.app.credits.380"

        var id: String { rawValue }

        /// Credits deposited into the local wallet for this pack.
        var credits: Int {
            switch self {
            case .p10:  return 10
            case .p70:  return 70
            case .p160: return 160
            case .p380: return 380
            }
        }

        /// Ascending order for display (cheapest first).
        var sortOrder: Int { credits }

        /// Localization key for the "best value" badge on the top pack.
        var isBestValue: Bool { self == .p380 }
    }

    /// All consumable product identifiers, for `Product.products(for:)`.
    static let allProductIDs: [String] = Pack.allCases.map(\.rawValue)

    /// Credits for a StoreKit product identifier, or nil if the id is not
    /// a known credit pack (e.g. it's the Pro subscription).
    static func credits(forProductID id: String) -> Int? {
        Pack(rawValue: id)?.credits
    }
}
