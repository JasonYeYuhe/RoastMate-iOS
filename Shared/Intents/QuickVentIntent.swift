import AppIntents

/// "Quick Vent" — the one-press path from Control Center / Lock Screen /
/// the Action Button (via the RoastMateControls extension) and from Siri
/// / Shortcuts. Lives in `Shared/` so both the app and the controls
/// extension compile the exact same intent.
///
/// Unlike `GenerateRoastIntent` (which generates head-lessly on-device),
/// Quick Vent intentionally OPENS THE APP. Vent is a Pro-only,
/// safety-filtered private draft — opening the app keeps entitlement
/// gating, the credit wallet and the crisis safety net exactly where
/// they already live instead of duplicating them in an extension.
struct QuickVentIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.quick_vent.title"
    static let description = IntentDescription("intent.quick_vent.description")

    /// Opens the app; `perform()` then runs in the app process and
    /// parks the request for the generator to drain.
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        LaunchRouter.shared.flagQuickVent()
        return .result()
    }
}
