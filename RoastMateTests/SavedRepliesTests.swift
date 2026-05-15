import SwiftData
import XCTest
@testable import RoastMate

/// Validates the v1.5 "Saved replies" feature surface:
/// - `GeneratedRoast.isFavorite` persists across saves
/// - `@Query` style fetches (filter by isFavorite) return what HistoryView
///   would see
/// - Sendable + normal roasts are saveable; private drafts are NOT (the
///   product framing for vent/feral is ephemeral catharsis, not a
///   keepsake)
@MainActor
final class SavedRepliesTests: XCTestCase {
    func testFavoriteFlagPersistsForSendableReply() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "X",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["draft text"],
            context: context,
            isPro: true,
            intensity: .vent
        )
        let draft = try XCTUnwrap(session.results?.first)
        let reply = HistoryService.appendSendableReply(
            toSession: session,
            sourceVentDraft: draft,
            rewrittenText: "the polished reply",
            context: context
        )

        XCTAssertFalse(reply.isFavorite)
        reply.isFavorite = true
        try context.save()

        // Re-fetch via the same predicate HistoryView's @Query uses.
        let predicate = #Predicate<GeneratedRoast> { r in r.isFavorite }
        let fetched = try context.fetch(FetchDescriptor<GeneratedRoast>(predicate: predicate))
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, reply.id)
    }

    func testSavedRepliesPredicateExcludesPrivateDrafts() throws {
        // We persist three results: one normal roast, one sendable reply,
        // one vent draft. Only the first two should be saveable in the
        // product — but here we test the FETCH layer: even if isFavorite
        // is true on a private draft (it shouldn't be, but defensive),
        // the HistoryView-level filter must drop it from the visible
        // "Saved replies" list.
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "X",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["normal roast text"],
            context: context,
            isPro: true,
            intensity: .sharp
        )
        let normal = try XCTUnwrap(session.results?.first)
        normal.isFavorite = true

        let ventSession = HistoryService.saveSession(
            situation: "Y",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["vent draft text"],
            context: context,
            isPro: true,
            intensity: .vent
        )
        let draft = try XCTUnwrap(ventSession.results?.first)
        draft.isFavorite = true  // simulate the defensive case

        let reply = HistoryService.appendSendableReply(
            toSession: ventSession,
            sourceVentDraft: draft,
            rewrittenText: "sendable reply text",
            context: context
        )
        reply.isFavorite = true
        try context.save()

        // What @Query in HistoryView would return:
        let allFavorited = try context.fetch(
            FetchDescriptor<GeneratedRoast>(
                predicate: #Predicate { $0.isFavorite }
            )
        )
        XCTAssertEqual(allFavorited.count, 3,
                       "@Query layer returns all favorited rows.")

        // What HistoryView's `savedReplies` computed property exposes —
        // the same filter applied in code. Vent drafts must drop.
        let savedReplies = allFavorited.filter { result in
            result.kind == .normalRoast || result.kind == .sendableReply
        }
        XCTAssertEqual(savedReplies.count, 2)
        XCTAssertTrue(savedReplies.contains { $0.id == normal.id })
        XCTAssertTrue(savedReplies.contains { $0.id == reply.id })
        XCTAssertFalse(savedReplies.contains { $0.id == draft.id },
                       "Private drafts must never appear in Saved replies.")
    }

    func testNavigationTargetPrefersThreadOverStandaloneSession() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "Boss reverted my work again.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["polished line"],
            context: context,
            isPro: true,
            intensity: .sharp
        )
        let thread = ThreadService.promoteToThread(session: session, context: context)
        let result = try XCTUnwrap(session.results?.first)
        result.isFavorite = true
        try context.save()

        // SwiftData should resolve the inverse relationship automatically.
        XCTAssertNotNil(result.session, "Result's inverse `session` must point back.")
        XCTAssertEqual(result.session?.id, session.id)
        // Threaded session → navigation target is the thread, not the
        // session — so tapping a saved reply opens the rich Thread view
        // when it lives inside one.
        XCTAssertEqual(result.session?.thread?.id, thread.id)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration("SavedRepliesTests", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
