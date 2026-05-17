import XCTest
@testable import RoastMate

/// Pillar B: consumables-primary hybrid monetization. Pins the wallet
/// invariants — credits are a quantity knob (never a capability unlock),
/// the trial wallet seeds exactly once (incl. legacy upgrade), the
/// starter window trickle does not drain the wallet, and the legacy
/// quota path is left byte-unchanged (additive guarantee).
final class CreditWalletTests: XCTestCase {

    private let base = Calendar.current.startOfDay(for: Date())
    private func day(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: base)!
    }

    // MARK: - Trial wallet seeding (one-time, incl. legacy upgrade)

    func testSeedGrantsOnceAndIsIdempotent() {
        let s = UserSettings()
        XCTAssertFalse(s.hasSeededTrialWallet)
        XCTAssertEqual(s.creditBalance, 0)

        XCTAssertTrue(s.ensureTrialWalletSeeded(now: base))
        XCTAssertEqual(s.creditBalance, CreditCatalog.seededTrialCredits)
        XCTAssertTrue(s.hasSeededTrialWallet)
        XCTAssertEqual(s.firstLaunchDate, base)

        // Second call must not double-grant.
        XCTAssertFalse(s.ensureTrialWalletSeeded(now: day(1)))
        XCTAssertEqual(s.creditBalance, CreditCatalog.seededTrialCredits)
    }

    func testLegacyStoreUpgradeGetsTheOneTimeWallet() {
        // Pre-v1.1 stores hydrate with nil raw fields.
        let s = UserSettings()
        s.creditBalanceRaw = nil
        s.hasSeededTrialWalletRaw = nil
        XCTAssertEqual(s.creditBalance, 0)
        XCTAssertFalse(s.hasSeededTrialWallet)
        XCTAssertTrue(s.ensureTrialWalletSeeded(now: base))
        XCTAssertEqual(s.creditBalance, CreditCatalog.seededTrialCredits)
    }

    // MARK: - Starter window trickle does not drain the wallet

    func testStarterTrickleSpendsBeforeWallet() {
        let s = UserSettings()
        s.ensureTrialWalletSeeded(now: base)
        let seeded = s.creditBalance

        // Today's free trickle is consumed first; wallet untouched.
        for _ in 0..<CreditCatalog.starterWindowDailyTrickle {
            XCTAssertTrue(s.spendOneCredit(now: base))
        }
        XCTAssertEqual(s.creditBalance, seeded, "Trickle must not touch the wallet")
        XCTAssertEqual(s.starterTrickleRemaining(now: base), 0)

        // Trickle exhausted today → next spend comes from the wallet.
        XCTAssertTrue(s.spendOneCredit(now: base))
        XCTAssertEqual(s.creditBalance, seeded - 1)
    }

    func testStarterTrickleResetsNextDayWithinWindow() {
        let s = UserSettings()
        s.ensureTrialWalletSeeded(now: base)
        for _ in 0..<CreditCatalog.starterWindowDailyTrickle {
            _ = s.spendOneCredit(now: base)
        }
        XCTAssertEqual(s.starterTrickleRemaining(now: base), 0)
        // Next day, still inside the starter window → fresh trickle.
        XCTAssertEqual(s.starterTrickleRemaining(now: day(1)),
                       CreditCatalog.starterWindowDailyTrickle)
        let seeded = s.creditBalance
        XCTAssertTrue(s.spendOneCredit(now: day(1)))
        XCTAssertEqual(s.creditBalance, seeded, "Day-2 trickle must not touch the wallet")
    }

    // MARK: - After the starter window: pure wallet

    func testAfterWindowSpendsFromWalletOnly() {
        let s = UserSettings()
        s.ensureTrialWalletSeeded(now: base)
        let afterWindow = day(CreditCatalog.starterWindowDays + 1)
        XCTAssertFalse(s.isInStarterWindow(now: afterWindow))
        XCTAssertEqual(s.starterTrickleRemaining(now: afterWindow), 0)

        let seeded = s.creditBalance
        for i in 1...seeded {
            XCTAssertTrue(s.spendOneCredit(now: afterWindow))
            XCTAssertEqual(s.creditBalance, seeded - i)
        }
        // Wallet empty + window closed → blocked (paywall intent).
        XCTAssertFalse(s.spendOneCredit(now: afterWindow))
        XCTAssertFalse(s.canSpendNow(now: afterWindow))
    }

    // MARK: - canSpendNow peek (read-only, does not mutate)

    func testCanSpendNowUnseededIsTrueAndNonMutating() {
        let s = UserSettings()
        XCTAssertTrue(s.canSpendNow(now: base), "Pending trial counts as spendable")
        XCTAssertFalse(s.hasSeededTrialWallet, "Peek must not seed")
        XCTAssertEqual(s.creditBalance, 0, "Peek must not mutate the wallet")
    }

    func testGrantCreditsAddsAndIgnoresNonPositive() {
        let s = UserSettings()
        s.ensureTrialWalletSeeded(now: base)
        let seeded = s.creditBalance
        s.grantCredits(70)
        XCTAssertEqual(s.creditBalance, seeded + 70)
        s.grantCredits(0)
        s.grantCredits(-5)
        XCTAssertEqual(s.creditBalance, seeded + 70)
    }

    func testAvailableCreditsIsTrialAware() {
        let s = UserSettings()
        // Un-seeded: pending trial + today's trickle are both spendable.
        XCTAssertEqual(s.availableCreditsNow(now: base),
                       CreditCatalog.seededTrialCredits + CreditCatalog.starterWindowDailyTrickle)
        s.ensureTrialWalletSeeded(now: base)
        // Seeding must not change the surfaced number.
        XCTAssertEqual(s.availableCreditsNow(now: base),
                       CreditCatalog.seededTrialCredits + CreditCatalog.starterWindowDailyTrickle)
    }

    // MARK: - Credit ladder mapping (RMB ¥1→10/¥6→70/¥12→160/¥25→380)

    func testCreditLadderMapping() {
        XCTAssertEqual(CreditCatalog.Pack.p10.credits, 10)
        XCTAssertEqual(CreditCatalog.Pack.p70.credits, 70)
        XCTAssertEqual(CreditCatalog.Pack.p160.credits, 160)
        XCTAssertEqual(CreditCatalog.Pack.p380.credits, 380)
        XCTAssertEqual(CreditCatalog.allProductIDs.count, 4)
        XCTAssertEqual(CreditCatalog.credits(forProductID: "yyh.roastmate.app.credits.70"), 70)
        XCTAssertNil(CreditCatalog.credits(forProductID: StoreService.monthlyProductId),
                     "The subscription is not a credit pack")
        XCTAssertNil(CreditCatalog.credits(forProductID: "bogus"))
        XCTAssertTrue(CreditCatalog.Pack.p380.isBestValue)
        XCTAssertFalse(CreditCatalog.Pack.p10.isBestValue)
    }

    // MARK: - Starter window spans exactly N calendar days (advisor fix)

    func testStarterWindowIsExactlySevenCalendarDays() {
        // Seed mid-afternoon: the window must still close after exactly
        // starterWindowDays *calendar* days (day 0 … day N-1), not leak
        // an extra date because of the non-midnight seed time.
        let seed = Calendar.current.date(byAdding: .hour, value: 15, to: base)!
        let s = UserSettings()
        s.ensureTrialWalletSeeded(now: seed)
        let lastIn = day(CreditCatalog.starterWindowDays - 1)
        let firstOut = day(CreditCatalog.starterWindowDays)
        XCTAssertTrue(s.isInStarterWindow(now: lastIn))
        XCTAssertFalse(s.isInStarterWindow(now: firstOut),
                       "Window must not leak an 8th eligible day for a non-midnight seed")
    }

    func testLegacyUpgraderStillGetsStarterWindow() {
        // Pre-v1.1 store: nil raw fields incl. firstLaunchDate. Seeding
        // must stamp firstLaunchDate=now so the window starts at upgrade,
        // not from a stale install date.
        let s = UserSettings()
        s.creditBalanceRaw = nil
        s.hasSeededTrialWalletRaw = nil
        s.firstLaunchDate = nil
        s.ensureTrialWalletSeeded(now: base)
        XCTAssertEqual(s.firstLaunchDate, base)
        XCTAssertTrue(s.isInStarterWindow(now: base))
        XCTAssertEqual(s.starterTrickleRemaining(now: base),
                       CreditCatalog.starterWindowDailyTrickle)
    }

    // MARK: - Purchased-credit settlement ledger (exactly-once, durable)

    func testApplyCreditGrantIsIdempotentByTxID() {
        let s = UserSettings()
        s.ensureTrialWalletSeeded(now: base)
        let seeded = s.creditBalance

        XCTAssertFalse(s.hasGrantedCreditTx("tx1"))
        XCTAssertTrue(s.applyCreditGrant(txID: "tx1", credits: 70))
        XCTAssertEqual(s.creditBalance, seeded + 70)
        XCTAssertTrue(s.hasGrantedCreditTx("tx1"))

        // Replay of the SAME transaction must not double-grant, but is
        // still "settled" (true) so StoreKit can finish it.
        XCTAssertTrue(s.applyCreditGrant(txID: "tx1", credits: 70))
        XCTAssertEqual(s.creditBalance, seeded + 70, "Replay must not double-grant")

        // A different transaction accumulates.
        XCTAssertTrue(s.applyCreditGrant(txID: "tx2", credits: 10))
        XCTAssertEqual(s.creditBalance, seeded + 80)
        XCTAssertTrue(s.hasGrantedCreditTx("tx2"))
    }

    func testApplyCreditGrantIgnoresEmptyOrNonPositive() {
        let s = UserSettings()
        s.ensureTrialWalletSeeded(now: base)
        let seeded = s.creditBalance
        XCTAssertTrue(s.applyCreditGrant(txID: "", credits: 70))
        XCTAssertTrue(s.applyCreditGrant(txID: "tx", credits: 0))
        XCTAssertEqual(s.creditBalance, seeded)
        XCTAssertFalse(s.hasGrantedCreditTx("tx"))
    }

    // MARK: - Additive guarantee: legacy quota path unchanged

    func testLegacyQuotaPathStillFunctions() {
        let s = UserSettings()
        XCTAssertEqual(s.totalRemainingFree(), 25)
        XCTAssertTrue(s.consumeFreeQuotaIfAvailable())
        XCTAssertEqual(s.totalRemainingFree(), 24)
        XCTAssertEqual(s.lifetimeUsedSafe, 1)
    }
}
