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

    // MARK: - Schema v2 — ε2 generation feedback (Phase 3 W1)

    func test_feedbackUpAndDown_incrementSeparateCounters() {
        ledger.setOptIn(true)
        ledger.recordFeedbackUp()
        ledger.recordFeedbackUp()
        ledger.recordFeedbackDown()
        let s = ledger.snapshot()
        XCTAssertEqual(s["feedback_thumbsup"], 2)
        XCTAssertEqual(s["feedback_thumbsdown"], 1)
    }

    func test_feedbackTag_eachTagHasItsOwnCounter() {
        ledger.setOptIn(true)
        ledger.recordFeedbackTag(.wrongTone)
        ledger.recordFeedbackTag(.wrongTone)
        ledger.recordFeedbackTag(.tooSoft)
        ledger.recordFeedbackTag(.tooHarsh)
        ledger.recordFeedbackTag(.wrongLanguage)
        ledger.recordFeedbackTag(.wrongStyle)
        ledger.recordFeedbackTag(.didntAddress)
        ledger.recordFeedbackTag(.factuallyWrong)
        ledger.recordFeedbackTag(.other)
        let s = ledger.snapshot()
        XCTAssertEqual(s["feedback_tag_wrong_tone"], 2)
        XCTAssertEqual(s["feedback_tag_too_soft"], 1)
        XCTAssertEqual(s["feedback_tag_too_harsh"], 1)
        XCTAssertEqual(s["feedback_tag_wrong_language"], 1)
        XCTAssertEqual(s["feedback_tag_wrong_style"], 1)
        XCTAssertEqual(s["feedback_tag_didnt_address"], 1)
        XCTAssertEqual(s["feedback_tag_factually_wrong"], 1)
        XCTAssertEqual(s["feedback_tag_other"], 1)
    }

    func test_feedbackCounters_areOptOutGated() {
        // Opted out by default → feedback bumps must be no-ops.
        ledger.recordFeedbackUp()
        ledger.recordFeedbackDown()
        ledger.recordFeedbackTag(.wrongTone)
        let s = ledger.snapshot()
        XCTAssertEqual(s["feedback_thumbsup"], 0)
        XCTAssertEqual(s["feedback_thumbsdown"], 0)
        XCTAssertEqual(s["feedback_tag_wrong_tone"], 0)
    }

    func test_v1Counters_keepTheirRawKeysAfterV2() {
        // Public-contract regression guard: the v1 raw keys must never
        // rename. Lock the exact strings the export schema documents.
        let allRaw = EventLedger.Counter.allCases.map(\.rawValue)
        for expected in [
            "paywall_impressions",
            "generations_total",
            "generations_cloud",
            "generations_on_device",
            "purchase_attempts",
            "purchases_completed",
            "share_taps",
            "session_starts",
        ] {
            XCTAssertTrue(allRaw.contains(expected),
                          "v1 counter \(expected) must still exist as a Counter case.")
        }
    }

    func test_v2Counters_areAppendedAtEndOfEnum() {
        // The additive contract says v2 counters land AFTER v1 counters in
        // Counter.allCases. Verify by checking the first v2 index is past
        // the last v1 index.
        let cases = EventLedger.Counter.allCases.map(\.rawValue)
        let lastV1 = cases.firstIndex(of: "session_starts") ?? -1
        let firstV2 = cases.firstIndex(of: "feedback_thumbsup") ?? -1
        XCTAssertGreaterThan(firstV2, lastV1,
                             "v2 counters must be appended at end of the enum.")
    }
}
