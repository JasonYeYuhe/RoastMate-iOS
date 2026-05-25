import XCTest
@testable import RoastMate

final class RatingPromptServiceTests: XCTestCase {
    // ε1 — RatingPromptService is fired by:
    //   • a successful share-tap, OR
    //   • the 3rd successful generation in the same session.
    // The service must fire AT MOST once per session and must NEVER be
    // called by any non-success path (caller-side discipline; these
    // tests just verify the service's own contract once it's notified).

    private final class HookSpy: @unchecked Sendable {
        private let lock = NSLock()
        private var _calls = 0
        var calls: Int {
            lock.lock(); defer { lock.unlock() }
            return _calls
        }
        func record() {
            lock.lock(); defer { lock.unlock() }
            _calls += 1
        }
    }

    func testShareTapFiresImmediately() {
        let spy = HookSpy()
        let svc = RatingPromptService(requestReviewHook: { spy.record() })
        svc.notifySuccessfulShare()
        XCTAssertEqual(spy.calls, 1, "First successful share-tap should fire the rating prompt.")
        XCTAssertTrue(svc.debugDidPromptThisSession)
    }

    func testThreeGenerationsFireOnceOnTheThird() {
        let spy = HookSpy()
        let svc = RatingPromptService(requestReviewHook: { spy.record() })
        svc.notifySuccessfulGeneration()
        XCTAssertEqual(spy.calls, 0, "First successful generation alone must not fire the prompt.")
        svc.notifySuccessfulGeneration()
        XCTAssertEqual(spy.calls, 0, "Second successful generation alone must not fire the prompt.")
        svc.notifySuccessfulGeneration()
        XCTAssertEqual(spy.calls, 1, "Third successful generation should fire the prompt.")
    }

    func testFurtherGenerationsAfterPromptAreNoOps() {
        let spy = HookSpy()
        let svc = RatingPromptService(requestReviewHook: { spy.record() })
        for _ in 0..<3 { svc.notifySuccessfulGeneration() }
        XCTAssertEqual(spy.calls, 1)
        for _ in 0..<10 { svc.notifySuccessfulGeneration() }
        XCTAssertEqual(spy.calls, 1, "Once prompted this session, additional generations must not re-prompt.")
    }

    func testShareAfterPromptIsNoOp() {
        let spy = HookSpy()
        let svc = RatingPromptService(requestReviewHook: { spy.record() })
        for _ in 0..<3 { svc.notifySuccessfulGeneration() }
        XCTAssertEqual(spy.calls, 1)
        svc.notifySuccessfulShare()
        XCTAssertEqual(spy.calls, 1, "Share after a prompt-already-fired session must not double-prompt.")
    }

    func testGenerationsAfterShareDoNotRePrompt() {
        let spy = HookSpy()
        let svc = RatingPromptService(requestReviewHook: { spy.record() })
        svc.notifySuccessfulShare()
        XCTAssertEqual(spy.calls, 1)
        for _ in 0..<5 { svc.notifySuccessfulGeneration() }
        XCTAssertEqual(spy.calls, 1, "Generations after a successful share-tap prompt must not re-fire.")
    }

    func testResetSessionRearmsTheGate() {
        let spy = HookSpy()
        let svc = RatingPromptService(requestReviewHook: { spy.record() })
        svc.notifySuccessfulShare()
        XCTAssertEqual(spy.calls, 1)
        XCTAssertTrue(svc.debugDidPromptThisSession)

        svc.resetSession()
        XCTAssertFalse(svc.debugDidPromptThisSession)
        XCTAssertEqual(svc.debugGenerationCount, 0)

        // Next session can fire again (Apple's 3-per-365-days will gate
        // the actual UI — that's not our job to enforce).
        svc.notifySuccessfulShare()
        XCTAssertEqual(spy.calls, 2)
    }

    func testGenerationCountSurvivesUntilPromptOrReset() {
        let spy = HookSpy()
        let svc = RatingPromptService(requestReviewHook: { spy.record() })
        svc.notifySuccessfulGeneration()
        svc.notifySuccessfulGeneration()
        XCTAssertEqual(svc.debugGenerationCount, 2)
        XCTAssertFalse(svc.debugDidPromptThisSession)
        // A successful share now fires (still session-virgin), but the
        // generation counter is unaffected by share-triggered prompts.
        svc.notifySuccessfulShare()
        XCTAssertEqual(spy.calls, 1)
        XCTAssertEqual(svc.debugGenerationCount, 2, "Share path must not reset the generation counter.")
    }
}
