import SwiftData
import XCTest
@testable import RoastMate

@MainActor
final class ThreadContinuationStoreTests: XCTestCase {
    func testStageThenConsumeReturnsOnceThenNil() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "Roommate ate my food.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["Sample reply."],
            context: context,
            isPro: true
        )
        let thread = ThreadService.promoteToThread(
            session: session,
            title: "Roommate",
            category: .friends,
            context: context
        )

        let store = ThreadContinuationStore.shared
        store.pending = nil  // sanity reset between tests
        store.stage(thread: thread, suggestedStyleId: "high_eq")

        let first = store.consume()
        XCTAssertNotNil(first)
        XCTAssertEqual(first?.threadId, thread.id)
        XCTAssertEqual(first?.suggestedStyleId, "high_eq")
        XCTAssertFalse(first?.priorContext.isEmpty ?? true,
                       "Prior context should be populated once the thread has a session.")

        let second = store.consume()
        XCTAssertNil(second, "Consume must clear the pending state — a stale tap can't re-thread the next generation.")
    }

    func testStageOnEmptyThreadProducesEmptyPriorContext() throws {
        // A freshly-built thread with zero sessions yields an empty summary.
        // PromptBuilder treats empty == nil so this is harmless, but the
        // store must surface the empty value instead of crashing.
        let context = try makeContext()
        let thread = SituationThread(
            title: "Brand new",
            originalSituation: "Just started."
        )
        context.insert(thread)
        try context.save()

        let store = ThreadContinuationStore.shared
        store.pending = nil
        store.stage(thread: thread)
        let pending = store.consume()
        XCTAssertEqual(pending?.priorContext, "")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration("ThreadContinuationStoreTests", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
