import XCTest
@testable import RoastMate

// β1+β2 (Phase 3 W2) — StoreService.seedOptimisticPro pure-logic tests.
//
// Why not test the singleton's `isPro` directly: DEBUG builds hard-code
// `isPro = true` and tests run in DEBUG, so observing the side-effect is
// ambiguous. Instead we exercise the function's return value, which
// reports whether the seed actually granted Pro — that signal is the
// load-bearing invariant for cross-device optimistic Pro.

final class StoreServiceProTests: XCTestCase {
    @MainActor func test_seed_returnsTrue_forRecentVerifiedAt() {
        let now = Date()
        let recent = now.addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        XCTAssertTrue(StoreService.shared.seedOptimisticPro(verifiedAt: recent, now: now),
                      "A `proLastVerifiedAt` < 90 days old must grant optimistic Pro.")
    }

    @MainActor func test_seed_returnsTrue_atExactlyTheGraceBoundary() {
        let now = Date()
        // 90 days minus 1 second — still inside the closed grace window.
        let edge = now.addingTimeInterval(-(StoreService.optimisticProGraceDays - 1))
        XCTAssertTrue(StoreService.shared.seedOptimisticPro(verifiedAt: edge, now: now))
    }

    @MainActor func test_seed_returnsFalse_pastGraceWindow() {
        let now = Date()
        let stale = now.addingTimeInterval(-(StoreService.optimisticProGraceDays + 60))
        XCTAssertFalse(StoreService.shared.seedOptimisticPro(verifiedAt: stale, now: now),
                       "A `proLastVerifiedAt` older than 90 days is too stale for optimistic grant — StoreKit must re-verify locally.")
    }

    @MainActor func test_seed_returnsFalse_forNilDate() {
        XCTAssertFalse(StoreService.shared.seedOptimisticPro(verifiedAt: nil),
                       "No persisted CloudKit Pro signal → no optimistic grant.")
    }

    @MainActor func test_seed_returnsFalse_forFutureDate() {
        let now = Date()
        let future = now.addingTimeInterval(60 * 60)
        XCTAssertFalse(StoreService.shared.seedOptimisticPro(verifiedAt: future, now: now),
                       "A `proLastVerifiedAt` from the future is corruption signal — refuse the seed.")
    }
}
