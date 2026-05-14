import Foundation

/// Holds the most recent inbound Handoff payload so the foreground UI
/// can pull it the next time the user lands on the Generator. Cleared
/// after consumption.
@MainActor
@Observable
final class HandoffStore {
    static let shared = HandoffStore()
    private init() {}

    var pending: HandoffActivity.ContinuationPayload?

    func consume() -> HandoffActivity.ContinuationPayload? {
        defer { pending = nil }
        return pending
    }
}
