import WidgetKit
import SwiftUI
import AppIntents

/// RoastMateControls — a WidgetKit extension whose only job is the
/// "Quick Vent" control. It surfaces in Control Center, on the Lock
/// Screen, and as an Action Button assignment, giving a one-press path
/// to the vent box in the moment of rage (no unlock friction).
///
/// The control deliberately does no generation itself: tapping it runs
/// `QuickVentIntent` (Shared) which opens the app and parks the request
/// via `LaunchRouter`. All entitlement gating, the credit wallet and
/// the crisis safety net stay in the app where they already live.
@main
struct RoastMateControlsBundle: WidgetBundle {
    var body: some Widget {
        QuickVentControl()
    }
}

struct QuickVentControl: ControlWidget {
    static let kind = "yyh.roastmate.app.controls.quickvent"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickVentIntent()) {
                Label("control.quick_vent.title", systemImage: "flame.fill")
            }
        }
        .displayName("control.quick_vent.title")
        .description("control.quick_vent.description")
    }
}
