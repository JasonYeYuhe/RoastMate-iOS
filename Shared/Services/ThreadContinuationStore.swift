import Foundation
import SwiftData

/// In-memory bridge between the Threads UI ("Continue this event" button)
/// and the Roast Generator screen. The user taps Continue on a thread; we
/// stash the thread's identifier and the pre-baked prior-context summary
/// here, then the Generator picks it up on its next appear and seeds the
/// situation editor + threads any new session it creates.
///
/// Cleared after one read so a stale tap doesn't keep re-threading future
/// one-off generations.
@MainActor
@Observable
final class ThreadContinuationStore {
    static let shared = ThreadContinuationStore()
    private init() {}

    struct Pending: Sendable {
        let threadId: UUID
        let priorContext: String
        let suggestedStyleId: String?
    }

    var pending: Pending?

    func consume() -> Pending? {
        defer { pending = nil }
        return pending
    }

    /// Helper for the Threads UI — resolves the prior-context summary and
    /// stores the pending continuation in one call.
    func stage(thread: SituationThread, suggestedStyleId: String? = nil) {
        let summary = ThreadService.priorContextSummary(thread: thread)
        pending = Pending(
            threadId: thread.id,
            priorContext: summary,
            suggestedStyleId: suggestedStyleId
        )
    }
}
