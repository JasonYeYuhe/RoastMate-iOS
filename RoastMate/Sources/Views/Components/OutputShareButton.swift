import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Share button used at every output-content share site (RoastCard,
/// GeneratedRoastCard, ShareCardComposer image share). Differs from raw
/// `ShareLink` in that it fires the P5 Tier-1 `recordOutputShareTap()`
/// counter on **confirmed user completion** (a destination was picked AND
/// the share committed) rather than on every tap of the share button —
/// the latter overcounts because the system Share Sheet is often
/// cancelled.
///
/// Confirmed-send semantics are available only on iOS / visionOS via
/// `UIActivityViewController.completionWithItemsHandler`. SwiftUI's
/// cross-platform `ShareLink` does NOT expose a completion callback as
/// of macOS 26.x, so the macOS path falls back to tap-intent semantics.
/// `docs/A_PRIME_TELEMETRY.md` documents the platform divergence.
///
/// Both platforms also bump the legacy v1 `share_taps` counter via
/// `recordOutputShareTap()`, which preserves the back-compat audit fix
/// (Codex Phase 4 §0.5 #5).
struct OutputShareButton<Item: Transferable, Content: View>: View {
    let item: Item
    /// Optional callback invoked once the share is confirmed (iOS) or
    /// tapped (macOS, since no completion handler exists). Useful for
    /// downstream side effects that depend on the user actually
    /// reaching the share moment — e.g. RatingPromptService should
    /// not fire on tap-only.
    let onConfirmedShare: (() -> Void)?
    @ViewBuilder var label: () -> Content

    init(
        item: Item,
        onConfirmedShare: (() -> Void)? = nil,
        @ViewBuilder label: @escaping () -> Content
    ) {
        self.item = item
        self.onConfirmedShare = onConfirmedShare
        self.label = label
    }

    var body: some View {
        #if os(iOS) || os(visionOS)
        ConfirmedShareButton(item: item, onConfirmedShare: onConfirmedShare, label: label)
        #else
        // macOS: ShareLink does not expose a completion handler. Fire
        // `recordOutputShareTap()` on tap intent (overcounts by ~the
        // cancellation rate). Analysts must treat the counter as
        // intent-only on macOS, confirmed on iOS.
        ShareLink(item: item) { label() }
            .simultaneousGesture(TapGesture().onEnded {
                EventLedger.shared.recordOutputShareTap()  // intent-only on macOS
                onConfirmedShare?()
            })
        #endif
    }
}

#if os(iOS) || os(visionOS)
private struct ConfirmedShareButton<Item: Transferable, Content: View>: View {
    let item: Item
    let onConfirmedShare: (() -> Void)?
    @ViewBuilder var label: () -> Content
    @State private var present = false

    var body: some View {
        Button {
            present = true
        } label: {
            label()
        }
        .background(
            ActivitySheetHost(present: $present, item: item, onConfirmedShare: onConfirmedShare)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        )
    }
}

/// Empty hosting view that presents a UIActivityViewController on demand.
/// Fires `recordOutputShareTap()` (and the optional caller callback) only
/// when the system reports `completed == true && activityError == nil`.
private struct ActivitySheetHost<Item: Transferable>: UIViewControllerRepresentable {
    @Binding var present: Bool
    let item: Item
    let onConfirmedShare: (() -> Void)?

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        guard present, host.presentedViewController == nil else { return }

        // Bridge Transferable -> NSItemProvider so UIActivityViewController
        // can handle both String and URL uniformly.
        let activityItems: [Any]
        if let s = item as? String {
            activityItems = [s]
        } else if let u = item as? URL {
            activityItems = [u]
        } else {
            // Last-resort: hand it raw and let UIKit figure it out.
            activityItems = [item as Any]
        }

        let vc = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        vc.completionWithItemsHandler = { _, completed, _, activityError in
            DispatchQueue.main.async {
                self.present = false
                if completed && activityError == nil {
                    EventLedger.shared.recordOutputShareTap()  // confirmed send
                    self.onConfirmedShare?()
                }
            }
        }

        // iPad popover anchor — without this iPad crashes on present.
        if let pop = vc.popoverPresentationController {
            pop.sourceView = host.view
            pop.sourceRect = CGRect(
                x: host.view.bounds.midX,
                y: host.view.bounds.midY,
                width: 0,
                height: 0
            )
            pop.permittedArrowDirections = []
        }

        host.present(vc, animated: true)
    }
}
#endif
