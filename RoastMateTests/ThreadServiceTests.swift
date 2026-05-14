import SwiftData
import XCTest
@testable import RoastMate

@MainActor
final class ThreadServiceTests: XCTestCase {
    func testPromoteToThreadAttachesWithoutDuplicating() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "A friend cancelled at the last minute.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["That's frustrating."],
            context: context,
            isPro: true
        )

        let thread = ThreadService.promoteToThread(
            session: session,
            title: "Friend cancelled",
            category: .friends,
            context: context
        )
        let second = ThreadService.promoteToThread(session: session, context: context)

        XCTAssertEqual(thread.id, second.id)
        XCTAssertEqual(session.thread?.id, thread.id)
        XCTAssertEqual(thread.sessions.count, 1)
    }

    func testPriorContextSummaryPrefersFavoriteThenSendableThenFirst() throws {
        let context = try makeContext()
        let first = HistoryService.saveSession(
            situation: "Initial issue.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["First answer."],
            context: context,
            isPro: true
        )
        let thread = ThreadService.promoteToThread(session: first, title: "Issue", context: context)
        let second = HistoryService.saveSession(
            situation: "They replied again.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["Vent draft."],
            context: context,
            isPro: true,
            intensity: .vent,
            thread: thread
        )
        let draft = try XCTUnwrap(second.results.first)
        _ = HistoryService.appendSendableReply(
            toSession: second,
            sourceVentDraft: draft,
            rewrittenText: "Sendable answer.",
            context: context
        )
        first.results.first?.isFavorite = true
        first.results.first?.text = "Favorite answer."
        try context.save()

        let summary = ThreadService.priorContextSummary(thread: thread)
        XCTAssertTrue(summary.contains("Favorite answer."))
        XCTAssertTrue(summary.contains("Sendable answer."))
        XCTAssertFalse(summary.contains("Vent draft."))
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration("ThreadServiceTests", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
