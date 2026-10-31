import Foundation

/// A6 (1.8.0): what opened the paywall, so the screen that opened it can
/// finish the user's action once Pro arrives. Until 1.8.0 a purchase closed
/// the paywall and left the user where they were: the locked chip they had
/// tapped still unselected, their typed situation still not generated. The
/// one cancellation we have (day 0) happened in that first minute.
///
/// Lives in Shared so `RoastMateTests` can cover it (the hostless test bundle
/// cannot see app-target types).
struct PaywallIntent: Equatable, Sendable {
    /// A Pro style the user reached for (a locked chip, or a Pro-style sample).
    var styleId: String?
    /// A Pro intensity the user reached for.
    var intensity: Intensity?
    /// The paywall came from a Generate tap with text typed: generate once
    /// after the purchase.
    var runAfterPurchase: Bool = false

    static func style(_ id: String) -> PaywallIntent { PaywallIntent(styleId: id) }
    static func intensity(_ intensity: Intensity) -> PaywallIntent { PaywallIntent(intensity: intensity) }
}

enum PaywallGate {

    /// The paywall intent for a Generate tap by a free user whose selection
    /// needs Pro, or nil when nothing selected needs Pro.
    ///
    /// The style check is new in 1.8.0: a free user who loaded a Pro-style
    /// sample (index 1 of the five shown is `mba_boss`) and tapped Generate
    /// got the orange `quota.exhausted.body` error from the view model's
    /// guard instead of the paywall (Gemini review, plan §9 #6).
    static func lockedSelection(
        isPro: Bool, style: StylePreset?, intensity: Intensity, hasInput: Bool
    ) -> PaywallIntent? {
        guard !isPro else { return nil }
        let styleLocked = style?.tier == .pro
        let intensityLocked = intensity.requiresPro
        guard styleLocked || intensityLocked else { return nil }
        return PaywallIntent(
            styleId: styleLocked ? style?.id : nil,
            intensity: intensityLocked ? intensity : nil,
            runAfterPurchase: hasInput)
    }

    /// The trial line under the yearly plan shows only when StoreKit said the
    /// buyer is eligible BEFORE the row rendered (3.1.2: trial terms only to
    /// eligible users). Unknown (nil) or false → no line.
    static func showsTrialLine(offerIsFreeTrial: Bool, eligible: Bool?) -> Bool {
        offerIsFreeTrial && eligible == true
    }

    /// Plans in a fixed order, yearly first. `Product.products(for:)` returns
    /// them in no guaranteed order, so the two rows could swap between launches.
    static func sortedPlanIDs(_ ids: [String], yearlyID: String) -> [String] {
        ids.sorted { a, b in
            if (a == yearlyID) != (b == yearlyID) { return a == yearlyID }
            return a < b
        }
    }
}
