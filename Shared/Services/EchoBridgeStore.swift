import Foundation

/// Holds the most recent pending Echoes → RoastGenerator deep-link
/// payload (the Bridge-to-Action mechanic). RoastGeneratorView consumes
/// this in `.onAppear` after the user taps the bridge CTA on an
/// Echoes transcript's final `.bridge` message. Cleared after
/// consumption — single-shot.
///
/// Mirrors the same pattern as `HandoffStore` and
/// `ThreadContinuationStore` so the RoastGeneratorView has one
/// uniform "is there a pending pre-fill payload?" check on appearance.
@MainActor
@Observable
final class EchoBridgeStore {
    static let shared = EchoBridgeStore()
    private init() {}

    struct Payload: Sendable {
        let situation: String
        let suggestedIntensity: Intensity
    }

    var pending: Payload?

    /// Destructive read: returns the pending payload (if any) AND
    /// clears the slot so the next foreground doesn't double-consume.
    func consume() -> Payload? {
        defer { pending = nil }
        return pending
    }
}
