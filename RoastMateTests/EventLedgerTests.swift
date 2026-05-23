import XCTest
@testable import RoastMate

final class EventLedgerTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var ledger: EventLedger!

    override func setUp() {
        super.setUp()
        // Isolated per-test UserDefaults suite — no contamination across
        // tests or with the real app's App-Group store.
        suiteName = "ledger-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        ledger = EventLedger(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        ledger = nil
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Opt-out is a hard no-op

    func test_defaultIsOptedOut() {
        XCTAssertFalse(ledger.isOptedIn,
                       "Fresh ledger must default to opted out.")
    }

    func test_recordIsNoOp_whenOptedOut() {
        ledger.recordPaywallImpression()
        ledger.recordGeneration(cloud: true)
        ledger.recordPurchaseAttempt()
        ledger.recordShareTap()
        ledger.recordSessionStart()
        let snap = ledger.snapshot()
        // Every known counter must read 0 because nothing should have
        // landed while opted out.
        for c in EventLedger.Counter.allCases {
            XCTAssertEqual(snap[c.rawValue], 0,
                           "counter \(c.rawValue) leaked through opt-out gate.")
        }
    }

    // MARK: - Opt-in records

    func test_optInThenRecord_incrementsCounters() {
        ledger.setOptIn(true)
        XCTAssertTrue(ledger.isOptedIn)

        ledger.recordPaywallImpression()
        ledger.recordPaywallImpression()
        ledger.recordPurchaseAttempt()
        ledger.recordPurchaseCompleted()
        ledger.recordShareTap()
        ledger.recordSessionStart()

        let s = ledger.snapshot()
        XCTAssertEqual(s["paywall_impressions"], 2)
        XCTAssertEqual(s["purchase_attempts"], 1)
        XCTAssertEqual(s["purchases_completed"], 1)
        XCTAssertEqual(s["share_taps"], 1)
        XCTAssertEqual(s["session_starts"], 1)
    }

    func test_recordGeneration_incrementsTotalAndCloudSplit() {
        ledger.setOptIn(true)
        ledger.recordGeneration(cloud: true)
        ledger.recordGeneration(cloud: false)
        ledger.recordGeneration(cloud: false)
        let s = ledger.snapshot()
        XCTAssertEqual(s["generations_total"], 3,
                       "every generation must bump generations_total.")
        XCTAssertEqual(s["generations_cloud"], 1)
        XCTAssertEqual(s["generations_on_device"], 2)
    }

    // MARK: - Reset

    func test_resetCounters_clearsAll() {
        ledger.setOptIn(true)
        for _ in 0..<5 { ledger.recordPaywallImpression() }
        ledger.recordGeneration(cloud: true)
        XCTAssertGreaterThan(ledger.snapshot()["paywall_impressions"] ?? 0, 0)

        ledger.resetCounters()
        let s = ledger.snapshot()
        for c in EventLedger.Counter.allCases {
            XCTAssertEqual(s[c.rawValue], 0,
                           "reset must zero \(c.rawValue).")
        }
        // Opt-in state survives the counter reset.
        XCTAssertTrue(ledger.isOptedIn,
                      "resetCounters() must NOT also flip opt-out.")
    }

    func test_snapshotAlwaysReturnsEveryKnownCounter() {
        // Fresh suite — never written — every counter must be present as 0.
        let s = ledger.snapshot()
        for c in EventLedger.Counter.allCases {
            XCTAssertNotNil(s[c.rawValue],
                            "snapshot missing key \(c.rawValue).")
            XCTAssertEqual(s[c.rawValue], 0)
        }
    }

    func test_optOutAfterCounting_freezesFurtherBumps() {
        ledger.setOptIn(true)
        ledger.recordPaywallImpression()
        ledger.recordPaywallImpression()
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"], 2)

        ledger.setOptIn(false)
        // Snapshot is still readable (we don't wipe on opt-out at the
        // ledger level — SettingsView does that explicitly).
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"], 2)
        // Future bumps don't land.
        ledger.recordPaywallImpression()
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"], 2,
                       "post-opt-out bump must be a no-op.")
    }

    // MARK: - Thread safety

    func test_concurrentBumps_doNotLoseUpdates() {
        ledger.setOptIn(true)
        let iterations = 200
        let workers = 8
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "ledger-test.workers", attributes: .concurrent)
        // Capture the Sendable ledger directly; `self` (XCTestCase) is
        // non-Sendable and would warn under strict concurrency.
        let ledgerRef = ledger!
        for _ in 0..<workers {
            group.enter()
            queue.async {
                for _ in 0..<iterations { ledgerRef.recordPaywallImpression() }
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success,
                       "concurrent bump workers did not finish in time.")
        XCTAssertEqual(ledger.snapshot()["paywall_impressions"],
                       iterations * workers,
                       "lost an update under concurrent bumps.")
    }
}
