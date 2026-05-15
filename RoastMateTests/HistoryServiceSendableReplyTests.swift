import SwiftData
import XCTest
@testable import RoastMate

@MainActor
final class HistoryServiceSendableReplyTests: XCTestCase {
    func testAppendSendableReplyLinksBackToVentDraft() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "My manager blamed me for their miss.",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["I am so done with this nonsense."],
            context: context,
            isPro: true,
            intensity: .vent
        )

        let draft = try XCTUnwrap(session.results?.first)
        let reply = HistoryService.appendSendableReply(
            toSession: session,
            sourceVentDraft: draft,
            rewrittenText: "I need us to be clear about ownership here.",
            context: context
        )

        XCTAssertEqual(draft.kind, .ventDraft)
        XCTAssertEqual(reply.kind, .sendableReply)
        XCTAssertEqual(reply.sourceVentDraftId, draft.id)
        XCTAssertEqual(session.results?.count, 2)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration("HistoryServiceTests", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
