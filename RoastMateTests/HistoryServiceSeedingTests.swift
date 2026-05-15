import SwiftData
import XCTest
@testable import RoastMate

/// Verifies the v1.4 sample-seeding shape:
/// - Vent demo samples land as paired `.ventDraft` + `.sendableReply` rows
///   inside ONE session, not two flat normal-roast rows.
/// - At least one multi-round SituationThread is seeded.
/// - `clearSamples` removes BOTH standalone sample sessions and sample
///   threads (cascading their child sessions).
@MainActor
final class HistoryServiceSeedingTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Ensure each test starts with the "haven't seeded yet" flag.
        UserDefaults.standard.removeObject(forKey: "roastmate_samples_seeded_v1")
        UserDefaults.standard.removeObject(forKey: "roastmate_samples_seeded_v2")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "roastmate_samples_seeded_v1")
        UserDefaults.standard.removeObject(forKey: "roastmate_samples_seeded_v2")
        super.tearDown()
    }

    func testSeedingCreatesAtLeastOneSampleThread() throws {
        let context = try makeContext()
        HistoryService.seedSamplesIfNeeded(context: context)

        let threads = try context.fetch(FetchDescriptor<SituationThread>())
        let sampleThreads = threads.filter { $0.isSampleData }
        XCTAssertGreaterThanOrEqual(sampleThreads.count, 1,
                                     "Sample seeding must create at least one demonstration thread.")

        // The seeded thread should have multiple rounds — that's the whole
        // point of showing Threads in the empty-state.
        let firstSample = try XCTUnwrap(sampleThreads.first)
        XCTAssertGreaterThanOrEqual(firstSample.sessions?.count ?? 0, 2,
                                     "Sample thread must have multiple rounds to demonstrate continuation.")
    }

    func testSeededVentDemoPairsLandAsLinkedDraftAndSendable() throws {
        let context = try makeContext()
        HistoryService.seedSamplesIfNeeded(context: context)

        // Tighten: only count STANDALONE sample sessions (no parent
        // thread). The seeded sample thread also contains a vent pair,
        // and that's tested separately in
        // `testSeedingCreatesAtLeastOneSampleThread`. Counting it here
        // would let the JSON-driven path regress silently.
        let allSessions = try context.fetch(FetchDescriptor<RoastSession>())
        let standalonePairs = allSessions.filter { session in
            guard session.thread == nil else { return false }
            let results = session.results ?? []
            let hasDraft = results.contains { $0.kind == .ventDraft }
            let hasReply = results.contains { $0.kind == .sendableReply }
            return hasDraft && hasReply
        }
        XCTAssertEqual(standalonePairs.count, 2,
                       "Exactly the two SampleRoasts.json vent demo pairs (sample_16_vent + sample_17_vent) should seed as standalone paired sessions.")

        // And the sendableReply should record sourceVentDraftId so the UI
        // can pair them on the same card.
        for session in standalonePairs {
            let results = session.results ?? []
            let draft = try XCTUnwrap(results.first { $0.kind == .ventDraft })
            let reply = try XCTUnwrap(results.first { $0.kind == .sendableReply })
            XCTAssertEqual(reply.sourceVentDraftId, draft.id,
                           "Sendable reply must point back to its source vent draft for UI pairing.")
            XCTAssertEqual(draft.sourceIntensity, .vent,
                           "JSON vent demos seed with sourceIntensity=.vent.")
        }
    }

    func testClearSamplesRemovesThreadsAndStandaloneSessions() throws {
        let context = try makeContext()
        HistoryService.seedSamplesIfNeeded(context: context)

        // Insert one NON-sample user thread + session so we can verify
        // cleanup is scoped to sample data only.
        let userThread = SituationThread(
            title: "User's own thread",
            originalSituation: "Real user data — must survive cleanup.",
            isSampleData: false
        )
        context.insert(userThread)
        let userSession = HistoryService.saveSession(
            situation: "User's own session",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["My own answer"],
            context: context,
            isPro: true
        )

        HistoryService.clearSamples(context: context)

        let remainingThreads = try context.fetch(FetchDescriptor<SituationThread>())
        XCTAssertTrue(remainingThreads.allSatisfy { !$0.isSampleData },
                      "All sample threads should be deleted.")
        XCTAssertTrue(remainingThreads.contains(where: { $0.id == userThread.id }),
                      "User's own thread must survive sample cleanup.")

        let remainingSessions = try context.fetch(FetchDescriptor<RoastSession>())
        XCTAssertTrue(remainingSessions.allSatisfy { !$0.isSampleData },
                      "All sample sessions should be deleted.")
        XCTAssertTrue(remainingSessions.contains(where: { $0.id == userSession.id }),
                      "User's own session must survive sample cleanup.")
    }

    func testSeedingIsIdempotent() throws {
        let context = try makeContext()
        HistoryService.seedSamplesIfNeeded(context: context)
        let firstSessionCount = try context.fetch(FetchDescriptor<RoastSession>()).count
        let firstThreadCount = try context.fetch(FetchDescriptor<SituationThread>()).count

        // Calling again on the same store must not duplicate samples; the
        // UserDefaults marker should short-circuit.
        HistoryService.seedSamplesIfNeeded(context: context)
        let secondSessionCount = try context.fetch(FetchDescriptor<RoastSession>()).count
        let secondThreadCount = try context.fetch(FetchDescriptor<SituationThread>()).count

        XCTAssertEqual(firstSessionCount, secondSessionCount)
        XCTAssertEqual(firstThreadCount, secondThreadCount)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration("HistoryServiceSeedingTests", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
