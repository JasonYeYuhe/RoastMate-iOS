import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WatchKit)
import WatchKit
#endif

/// Cross-platform haptic helper. iOS gets a light impact; watchOS gets
/// a success tap; macOS is a no-op (haptic engines on Mac are gated
/// behind specific hardware and not relevant for this app).
@MainActor
enum Haptics {
    enum Kind {
        case generated
        case error
        case selection
    }

    static func play(_ kind: Kind) {
        #if os(iOS)
        switch kind {
        case .generated:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #elseif os(watchOS)
        switch kind {
        case .generated:
            WKInterfaceDevice.current().play(.success)
        case .error:
            WKInterfaceDevice.current().play(.failure)
        case .selection:
            WKInterfaceDevice.current().play(.click)
        }
        #endif
    }
}
