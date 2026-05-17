import Foundation

/// Cross-process hand-off for native-capture entry points (Pillar C).
///
/// A Control Center / Lock Screen / Action Button "Quick Vent" tap, or
/// the "Vent about this" App Intent, runs `QuickVentIntent` which opens
/// the app. Because the intent may perform in a different process than
/// the foreground UI, the request is parked in the shared App Group
/// `UserDefaults` (the same group the Share Extension already uses) and
/// the foreground UI drains it when it next appears.
///
/// `UserDefaults` is injectable so the routing logic is unit-testable
/// in the Shared test target (codebase convention: testable logic in
/// `Shared/`), without touching the real app-group suite.
@MainActor
@Observable
final class LaunchRouter {
    static let appGroupID = "group.yyh.roastmate.app"
    private static let quickVentKey = "launchrouter.pendingQuickVent"

    static let shared = LaunchRouter(
        defaults: UserDefaults(suiteName: appGroupID) ?? .standard
    )

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Park a Quick Vent request (called from `QuickVentIntent`).
    func flagQuickVent() {
        defaults.set(true, forKey: Self.quickVentKey)
    }

    /// Non-destructive peek — RootView uses this to switch to the
    /// generator tab without clearing the request.
    var hasPendingQuickVent: Bool {
        defaults.bool(forKey: Self.quickVentKey)
    }

    /// Destructive read — the generator drains this exactly once and
    /// then pre-selects the Vent intensity.
    func consumeQuickVent() -> Bool {
        let pending = defaults.bool(forKey: Self.quickVentKey)
        if pending { defaults.removeObject(forKey: Self.quickVentKey) }
        return pending
    }
}
