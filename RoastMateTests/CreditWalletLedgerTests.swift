import XCTest
import SwiftData
@testable import RoastMate

/// β3 (Phase 3 W2): tests for the append-only credit ledger.
///
/// In-memory ModelContainer per test so CloudKit auto-mirror is not
/// engaged — these are pure ledger-semantics tests. The cross-device
/// sync behavior is exercised at integration time (manual smoke on
/// two devices on the same iCloud account).
final class CreditWalletLedgerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var settings: UserSettings!

    override func setUp() {
        super.setUp()
        // In-memory container; never persists to disk.
        let schema = Schema([
            UserSettings.self,
            CreditLedgerEntry.self
        ])
        let config = ModelConfiguration("ledger-test", schema: schema, isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: schema, configurations: [config])
        let ctx = ModelContext(container)
        let s = UserSettings()
        ctx.insert(s)
        context = ctx
        settings = s
    }

    override func tearDown() {
        settings = nil
        context = nil
        container = nil
        super.tearDown()
    }

    // MARK: - Empty + initial state

    @MainActor func test_emptyLedger_hasZeroDelta() {
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 0)
    }

    @MainActor func test_hasGrant_isFalseForUnknownTxID() {
        XCTAssertFalse(CreditWallet.hasGrant(txID: "never-seen", context: context))
    }

    @MainActor func test_hasGrant_isFalseForEmptyString() {
        XCTAssertFalse(CreditWallet.hasGrant(txID: "", context: context))
    }

    // MARK: - Grants

    @MainActor func test_recordGrant_addsToDelta() {
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 10)
        XCTAssertTrue(CreditWallet.hasGrant(txID: "tx-1", context: context))
    }

    @MainActor func test_recordGrant_isIdempotentByTxID() {
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 10,
                       "Same txID twice must not double-grant — the ledger is the idempotency key.")
    }

    @MainActor func test_distinctTxIDs_areCumulative() {
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-2", credits: 5)
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 15)
    }

    @MainActor func test_recordGrant_rejectsZeroOrNegative() {
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-zero", credits: 0)
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-neg", credits: -5)
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 0)
    }

    // MARK: - Spends

    @MainActor func test_recordSpend_subtractsFromDelta() {
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        CreditWallet.recordSpend(settings: settings, context: context)
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 9)
    }

    @MainActor func test_multipleSpends_areCumulative() {
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        for _ in 0..<3 { CreditWallet.recordSpend(settings: settings, context: context) }
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 7)
    }

    @MainActor func test_eachSpend_hasIndependentUUID() {
        // Cross-device safety guarantee: every spend is its own
        // record, so set-union merge in CloudKit never erases another
        // device's spend. We assert "different ids" by exercising the
        // pure record-creation path.
        for _ in 0..<5 { CreditWallet.recordSpend(settings: settings, context: context) }
        let entries = try! context.fetch(FetchDescriptor<CreditLedgerEntry>())
        let spendIDs = Set(entries.filter { $0.kind == .spend }.map(\.id))
        XCTAssertEqual(spendIDs.count, 5, "Each spend must have a unique UUID — that's the cross-device merge primitive.")
    }

    // MARK: - Computed balance (caches into UserSettings.creditBalanceRaw)

    @MainActor func test_recomputeBalance_caches_legacyBaseline_onFirstCall() {
        settings.creditBalance = 7   // pre-upgrade state
        XCTAssertNil(settings.legacyBalanceBaselineRaw)
        CreditWallet.recomputeBalance(context: context, settings: settings)
        XCTAssertEqual(settings.legacyBalanceBaselineRaw, 7,
                       "First recompute must freeze the pre-upgrade balance as the baseline.")
        XCTAssertEqual(settings.creditBalance, 7,
                       "With empty ledger, computed balance equals the baseline.")
    }

    @MainActor func test_recomputeBalance_doesNotOverwriteBaseline() {
        settings.creditBalance = 7
        CreditWallet.recomputeBalance(context: context, settings: settings)
        // simulate a later state where creditBalance has been written
        // by some other path; baseline must remain the original
        settings.creditBalance = 99
        CreditWallet.recomputeBalance(context: context, settings: settings)
        XCTAssertEqual(settings.legacyBalanceBaselineRaw, 7,
                       "Baseline is one-time-only; subsequent recomputes never re-snapshot.")
    }

    @MainActor func test_balance_isBaselinePlusGrants_minusSpends() {
        settings.creditBalance = 5   // baseline
        CreditWallet.recomputeBalance(context: context, settings: settings)
        CreditWallet.recordGrant(settings: settings, context: context, txID: "tx-1", credits: 10)
        CreditWallet.recordSpend(settings: settings, context: context)
        CreditWallet.recordSpend(settings: settings, context: context)
        // baseline 5 + grants 10 - spends 2 = 13
        XCTAssertEqual(settings.creditBalance, 13)
    }

    @MainActor func test_balance_clampsToZero_underOversold() {
        settings.creditBalance = 1   // baseline
        CreditWallet.recomputeBalance(context: context, settings: settings)
        // Two devices each spend offline → ledger has 2 spends but
        // only 1 baseline credit. Without clamp, balance would be -1.
        CreditWallet.recordSpend(settings: settings, context: context)
        CreditWallet.recordSpend(settings: settings, context: context)
        XCTAssertEqual(settings.creditBalance, 0,
                       "Cross-device offline-spend oversell clamps to 0 — the user effectively gets a free generation, but no negative balance lock-in.")
    }

    // MARK: - β3 baseline self-healing (Codex W2 review 2026-05-26)

    @MainActor func test_legacyBaseline_isPerDeviceID_dedupOnRepeatedRecomputes() {
        settings.creditBalance = 5
        CreditWallet.recomputeBalance(context: context, settings: settings)
        CreditWallet.recomputeBalance(context: context, settings: settings)
        CreditWallet.recomputeBalance(context: context, settings: settings)
        let entries = try! context.fetch(FetchDescriptor<CreditLedgerEntry>())
        let baselineEntries = entries.filter { $0.kind == .legacyBaseline }
        XCTAssertEqual(baselineEntries.count, 1,
                       "Per-device baseline entry must be inserted only once — no feedback loop on subsequent recomputes.")
    }

    @MainActor func test_legacyBaseline_takesMaxAcrossMultipleDevices() {
        // Simulate two other devices on the same Apple ID having
        // CloudKit-synced their own baseline entries down to this device.
        context.insert(CreditLedgerEntry(kind: .legacyBaseline, amount: 3, deviceID: "device-A"))
        context.insert(CreditLedgerEntry(kind: .legacyBaseline, amount: 9, deviceID: "device-B"))
        // This device snapshots its own pre-upgrade balance (5).
        settings.creditBalance = 5
        CreditWallet.recomputeBalance(context: context, settings: settings)
        XCTAssertEqual(settings.creditBalance, 9,
                       "Baseline takes the MAX snapshot across all devices — most generous wins, no last-write-wins data loss.")
    }

    @MainActor func test_legacyBaseline_doesNotContributeToLedgerDelta() {
        context.insert(CreditLedgerEntry(kind: .legacyBaseline, amount: 5, deviceID: "device-A"))
        context.insert(CreditLedgerEntry(kind: .legacyBaseline, amount: 7, deviceID: "device-B"))
        XCTAssertEqual(CreditWallet.ledgerDelta(context: context), 0,
                       ".legacyBaseline entries are starting-point markers; signedAmount must return 0 for them.")
    }

    @MainActor func test_legacyBaseline_signedAmountIsZero() {
        let entry = CreditLedgerEntry(kind: .legacyBaseline, amount: 42)
        XCTAssertEqual(entry.signedAmount, 0,
                       "Sanity: legacyBaseline.signedAmount must be 0 even for non-zero amounts.")
    }

    @MainActor func test_legacyBaseline_doesNotSeed_whenFreshInstall() {
        // creditBalanceRaw is the default 0 (no `creditBalance = N`
        // setter called). Recompute snapshots 0, MAX over the single
        // entry = 0. Balance stays 0.
        CreditWallet.recomputeBalance(context: context, settings: settings)
        XCTAssertEqual(settings.creditBalance, 0)
        let baselines = try! context.fetch(FetchDescriptor<CreditLedgerEntry>())
            .filter { $0.kind == .legacyBaseline }
        XCTAssertEqual(baselineCount(baselines), 1,
                       "Fresh install still inserts ONE baseline (amount 0) so future grants compose against a defined starting point.")
    }

    @MainActor private func baselineCount(_ entries: [CreditLedgerEntry]) -> Int {
        entries.count
    }

    // MARK: - deviceID

    @MainActor func test_deviceID_isStableAcrossCalls() {
        let defaults = UserDefaults(suiteName: "wallet-test-\(UUID().uuidString)")!
        let first = CreditWallet.deviceID(defaults: defaults)
        let second = CreditWallet.deviceID(defaults: defaults)
        XCTAssertEqual(first, second,
                       "deviceID is cached on first use and must remain stable for the lifetime of the install.")
    }

    @MainActor func test_deviceID_isDistinctAcrossInstalls() {
        let installA = UserDefaults(suiteName: "wallet-test-a-\(UUID().uuidString)")!
        let installB = UserDefaults(suiteName: "wallet-test-b-\(UUID().uuidString)")!
        XCTAssertNotEqual(CreditWallet.deviceID(defaults: installA),
                          CreditWallet.deviceID(defaults: installB),
                          "Each install gets its own deviceID; never shared.")
    }
}
