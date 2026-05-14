import XCTest
@testable import RoastMate

final class UserSettingsQuotaTests: XCTestCase {
    // MARK: - Daily-only behavior (lifetime exhausted)

    func testDailyOnly_exhaustAndBlock() {
        let settings = UserSettings()
        // Burn through the entire lifetime bucket first.
        settings.lifetimeUsedSafe = UserSettings.freeLifetimeAllotment
        XCTAssertEqual(settings.remainingDailyOnly(), 5)
        for _ in 0..<5 {
            XCTAssertTrue(settings.consumeFreeQuotaIfAvailable())
        }
        XCTAssertEqual(settings.remainingDailyOnly(), 0)
        XCTAssertFalse(settings.consumeFreeQuotaIfAvailable())
    }

    func testDailyOnly_resetsNextDay() {
        let settings = UserSettings()
        settings.lifetimeUsedSafe = UserSettings.freeLifetimeAllotment
        for _ in 0..<5 {
            _ = settings.consumeFreeQuotaIfAvailable()
        }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(settings.consumeFreeQuotaIfAvailable(now: tomorrow))
        XCTAssertEqual(settings.remainingDailyOnly(now: tomorrow), 4)
    }

    // MARK: - Lifetime onboarding bucket

    func testLifetimeBucketDefaultIs20() {
        let settings = UserSettings()
        XCTAssertEqual(settings.lifetimeRemaining, 20)
        XCTAssertTrue(settings.isInLifetimeWindow)
        // Daily is untouched, and the COMBINED total surfaces both buckets.
        XCTAssertEqual(settings.totalRemainingFree(), 25)
        XCTAssertEqual(settings.totalRemainingFreeNow, 25)
    }

    func testLifetimeConsumedFirst_dailyUntouched() {
        let settings = UserSettings()
        for i in 1...20 {
            XCTAssertTrue(settings.consumeFreeQuotaIfAvailable())
            XCTAssertEqual(settings.lifetimeUsedSafe, i)
            // Daily counter must NOT be touched while lifetime has stock.
            XCTAssertEqual(settings.dailyFreeUsed, 0)
        }
        XCTAssertEqual(settings.lifetimeRemaining, 0)
        XCTAssertFalse(settings.isInLifetimeWindow)
    }

    func testDailyKicksInAfterLifetimeExhausted() {
        let settings = UserSettings()
        for _ in 0..<20 {
            _ = settings.consumeFreeQuotaIfAvailable()
        }
        XCTAssertEqual(settings.lifetimeRemaining, 0)
        // Next 5 come from daily.
        for i in 1...5 {
            XCTAssertTrue(settings.consumeFreeQuotaIfAvailable())
            XCTAssertEqual(settings.dailyFreeUsed, i)
        }
        XCTAssertFalse(settings.consumeFreeQuotaIfAvailable())
    }

    func testDailyResetAfterPartialDailyConsumption_postLifetime() {
        // Burn lifetime, take 2 of today's 5, then roll the clock forward.
        // The next day must offer a fresh 5 — not 3 — and the lifetime
        // bucket must stay drained.
        let settings = UserSettings()
        for _ in 0..<20 {
            _ = settings.consumeFreeQuotaIfAvailable()
        }
        for _ in 0..<2 {
            XCTAssertTrue(settings.consumeFreeQuotaIfAvailable())
        }
        XCTAssertEqual(settings.dailyFreeUsed, 2)
        XCTAssertEqual(settings.remainingDailyOnly(), 3)
        XCTAssertEqual(settings.totalRemainingFree(), 3)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertEqual(settings.remainingDailyOnly(now: tomorrow), 5,
                       "Day rollover must restore daily to 5 regardless of yesterday's residue.")
        XCTAssertEqual(settings.totalRemainingFree(now: tomorrow), 5)

        // Consume one tomorrow — counter must reset to 1, not 3.
        XCTAssertTrue(settings.consumeFreeQuotaIfAvailable(now: tomorrow))
        XCTAssertEqual(settings.dailyFreeUsed, 1,
                       "Daily counter must reset on day rollover, not carry over.")
        XCTAssertEqual(settings.lifetimeRemaining, 0,
                       "Lifetime stays exhausted across day rollovers.")
    }

    func testDailyResetDoesNotRefillLifetime() {
        let settings = UserSettings()
        // Burn lifetime entirely.
        for _ in 0..<20 {
            _ = settings.consumeFreeQuotaIfAvailable()
        }
        XCTAssertEqual(settings.lifetimeRemaining, 0)

        // Next day — daily refills but lifetime does NOT.
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertEqual(settings.totalRemainingFree(now: tomorrow), 5)
        XCTAssertTrue(settings.consumeFreeQuotaIfAvailable(now: tomorrow))
        XCTAssertEqual(settings.lifetimeRemaining, 0, "Lifetime must never refill")
    }

    func testTotalRemainingTracksBothBuckets() {
        let settings = UserSettings()
        XCTAssertEqual(settings.totalRemainingFree(), 25)
        _ = settings.consumeFreeQuotaIfAvailable()
        XCTAssertEqual(settings.totalRemainingFree(), 24)
        // Drain lifetime.
        for _ in 0..<19 {
            _ = settings.consumeFreeQuotaIfAvailable()
        }
        XCTAssertEqual(settings.totalRemainingFree(), 5)
        // Drain three from daily.
        for _ in 0..<3 {
            _ = settings.consumeFreeQuotaIfAvailable()
        }
        XCTAssertEqual(settings.totalRemainingFree(), 2)
    }

    // MARK: - Legacy store migration

    func testLegacyStoreWithoutLifetimeFieldReadsAsZeroAndStillGrantsLifetime() {
        // Pre-v1.x stores have `lifetimeFreeUsed == nil`. The init() flips it
        // to 0 for fresh installs, but for already-installed users SwiftData
        // hydrates them with nil. Simulate that by writing nil explicitly.
        let settings = UserSettings()
        settings.lifetimeFreeUsed = nil
        XCTAssertEqual(settings.lifetimeUsedSafe, 0,
                       "Legacy stores must read 0, not nil-propagate.")
        XCTAssertEqual(settings.lifetimeRemaining, 20,
                       "Existing users get the 20-generation onboarding bonus once on upgrade.")
        XCTAssertTrue(settings.consumeFreeQuotaIfAvailable())
        XCTAssertEqual(settings.lifetimeUsedSafe, 1)
    }
}
