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
    private static let capturedSituationKey = "launchrouter.capturedSituation"

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

    // MARK: - Captured situation (v1.2 keyboard-extension spike)
    //
    // The keyboard extension cannot generate (memory ceiling) and must
    // not own network/safety (privacy + crisis-handoff + Pro gating live
    // in the app only — same rationale as `QuickVentIntent`). So it just
    // *captures* the text the user is venting about and parks it here;
    // the app drains it on next foreground. NOTE: a keyboard extension
    // reaching this App-Group suite requires the user to grant Full
    // Access — see docs/v1.2_KEYBOARD_SPIKE.md.

    /// Park the captured situation text (called from the keyboard
    /// extension). Whitespace-trimmed; empty/whitespace is ignored so a
    /// stray tap doesn't leave a blank pending request.
    func flagCapturedSituation(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        defaults.set(trimmed, forKey: Self.capturedSituationKey)
    }

    /// Non-destructive peek — RootView uses this to route to the
    /// generator without clearing the request.
    var pendingCapturedSituation: String? {
        let s = defaults.string(forKey: Self.capturedSituationKey)
        return (s?.isEmpty == false) ? s : nil
    }

    /// Destructive read — the generator drains this exactly once and
    /// pre-fills the situation box (the user still chooses intensity and
    /// passes the unchanged SafetyFilter/crisis gate in-app).
    func consumeCapturedSituation() -> String? {
        guard let s = pendingCapturedSituation else { return nil }
        defaults.removeObject(forKey: Self.capturedSituationKey)
        return s
    }
}
