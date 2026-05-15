import SwiftData
import XCTest
@testable import RoastMate

/// Validates the historical-rewrite path used by HistorySessionDetailView
/// and ThreadDetailView. The core invariant: a rewrite triggered from
/// History must append the new sendable reply to the SAME session the
/// vent draft lives in — never create a new session.
///
/// These tests run on a simulator where Foundation Models is not
/// available; `RoastEngine.rewriteAsSendable` therefore returns a
/// curated fallback string. That's intentional — the test is about
/// persistence shape, not LLM output quality.
@MainActor
final class RewriteCoordinatorTests: XCTestCase {
    func testRewriteAppendsToExistingSessionInsteadOfCreatingNew() async throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "Boss reassigned my project at 5pm Friday.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["This is absolutely ridiculous timing."],
            context: context,
            isPro: true,
            intensity: .vent
        )
        let draft = try XCTUnwrap(session.results?.first)
        XCTAssertEqual(draft.kind, .ventDraft)

        let beforeSessionCount = try context.fetch(FetchDescriptor<RoastSession>()).count
        XCTAssertEqual(beforeSessionCount, 1)

        let reply = try await RewriteCoordinator.rewriteAsSendable(
            draft: draft,
            session: session,
            context: context,
            locale: Locale(identifier: "en_US")
        )

        // The coordinator must return the newly-persisted sendable reply,
        // not nil — there was no prior pairing on this session.
        let appended = try XCTUnwrap(reply, "Rewrite should return the appended sendable reply.")
        XCTAssertEqual(appended.kind, .sendableReply)
        XCTAssertEqual(appended.sourceVentDraftId, draft.id,
                       "Sendable reply must link back to its source vent draft.")

        // Critical invariant: still ONE session in the store, just with
        // an extra result row attached.
        let afterSessionCount = try context.fetch(FetchDescriptor<RoastSession>()).count
        XCTAssertEqual(afterSessionCount, 1,
                       "Historical rewrite must not spawn a new RoastSession.")
        XCTAssertEqual(session.results?.count, 2,
                       "Same session now has draft + sendable.")
    }

    func testRewriteWorksForFeralDraftToo() async throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "Coworker reverted my code and lied about it.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["You absolute snake — keep my code off your dirty paws."],
            context: context,
            isPro: true,
            intensity: .feral
        )
        let draft = try XCTUnwrap(session.results?.first)
        XCTAssertEqual(draft.kind, .ventDraft,
                       "Feral still uses ventDraft kind (sourceIntensity differentiates).")
        XCTAssertEqual(draft.sourceIntensity, .feral)

        let reply = try await RewriteCoordinator.rewriteAsSendable(
            draft: draft,
            session: session,
            context: context,
            locale: Locale(identifier: "en_US")
        )
        let appended = try XCTUnwrap(reply)
        XCTAssertEqual(appended.kind, .sendableReply)
        XCTAssertEqual(appended.sourceVentDraftId, draft.id)
        XCTAssertEqual(session.results?.count, 2)
    }

    func testRewriteIsIdempotentWhenPairAlreadyExists() async throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "X",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["vent text"],
            context: context,
            isPro: true,
            intensity: .vent
        )
        let draft = try XCTUnwrap(session.results?.first)
        _ = HistoryService.appendSendableReply(
            toSession: session,
            sourceVentDraft: draft,
            rewrittenText: "already sendable",
            context: context
        )
        XCTAssertEqual(session.results?.count, 2)

        // Calling the coordinator again must be a no-op — returns nil and
        // does not duplicate the pairing. This is the guarantee that
        // protects against double-taps on the "Make it sendable" button.
        let secondAttempt = try await RewriteCoordinator.rewriteAsSendable(
            draft: draft,
            session: session,
            context: context,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertNil(secondAttempt,
                     "Coordinator must short-circuit when the draft is already paired.")
        XCTAssertEqual(session.results?.count, 2,
                       "No additional sendable reply should have been appended.")
    }

    func testRewriteSkipsNonVentDraftKinds() async throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "X",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["regular sharp roast"],
            context: context,
            isPro: true,
            intensity: .sharp
        )
        let result = try XCTUnwrap(session.results?.first)
        XCTAssertEqual(result.kind, .normalRoast)

        let outcome = try await RewriteCoordinator.rewriteAsSendable(
            draft: result,
            session: session,
            context: context,
            locale: Locale(identifier: "en_US")
        )
        XCTAssertNil(outcome,
                     "Coordinator must not rewrite non-private-draft kinds.")
        XCTAssertEqual(session.results?.count, 1)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration("RewriteCoordinatorTests", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
