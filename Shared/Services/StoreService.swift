import Foundation
import StoreKit
import os.log

/// StoreKit 2 wrapper. Owns the Pro subscription entitlement and the
/// v1.1 consumable credit packs. Consumable settlement is durable-first
/// and exactly-once (persist via the app-installed `creditSettler`,
/// then finish); no server-side reconciliation by design.
@MainActor
@Observable
final class StoreService {
    static let shared = StoreService()

    nonisolated static let monthlyProductId = "yyh.roastmate.app.pro.monthly"
    nonisolated static let yearlyProductId = "yyh.roastmate.app.pro.yearly"

    /// β2: how recent a CloudKit-synced `proLastVerifiedAt` can be and
    /// still grant optimistic Pro on launch. Sized to outlast a typical
    /// monthly billing cycle so a brief sync delay doesn't downgrade
    /// the user mid-billing. StoreKit always re-verifies in the
    /// background, so a stale `true` self-heals to `false` within a
    /// second of launch when entitlement has actually expired.
    nonisolated static let optimisticProGraceDays: TimeInterval = 90 * 24 * 60 * 60

    /// Subscription products only (Pro — the unlimited best-value tier).
    private(set) var products: [Product] = []

    /// Consumable credit packs (the pay-as-you-go, zh-first primary
    /// path), sorted cheapest → most credits.
    private(set) var creditProducts: [Product] = []

    /// Persists a verified consumable's credits and returns true once
    /// the transaction is durably accounted for (just-applied OR
    /// already-applied) — only then is it safe to finish the StoreKit
    /// transaction. `UserSettings` owns persistence + the exactly-once
    /// ledger; the app installs this at launch. No server-side
    /// reconciliation by design — the app has no backend.
    typealias CreditSettler = @MainActor (_ txID: String, _ credits: Int) -> Bool

    /// Installed by the app at bootstrap (it owns the model context).
    var creditSettler: CreditSettler?

    /// β2 (Phase 3 W2): persister hook for Pro state. Installed by the
    /// app at bootstrap to write `proLastVerifiedAt` onto the
    /// CloudKit-synced `UserSettings` whenever StoreKit confirms the
    /// entitlement. StoreKit stays canonical — this is purely a
    /// trust-signal mirror used to seed optimistic Pro on a fresh
    /// device.
    typealias ProPersister = @MainActor (_ isPro: Bool) -> Void
    var proPersister: ProPersister?

    private(set) var isPro: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "Store")

    private init() {
        // Singleton; updates task runs for app lifetime.
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handleTransactionUpdate(update)
            }
        }
        Task { await refreshSubscriptionStatus() }
    }

    func loadProducts() async {
        do {
            let all = try await Product.products(
                for: [Self.monthlyProductId, Self.yearlyProductId] + CreditCatalog.allProductIDs
            )
            products = all
                .filter { $0.id == Self.monthlyProductId || $0.id == Self.yearlyProductId }
            creditProducts = all
                .filter { CreditCatalog.credits(forProductID: $0.id) != nil }
                .sorted { (CreditCatalog.credits(forProductID: $0.id) ?? 0)
                        < (CreditCatalog.credits(forProductID: $1.id) ?? 0) }
        } catch {
            logger.error("Product load failed: \(error.localizedDescription)")
        }
    }

    /// Subscription purchase (Pro). Entitlement handling is unchanged; 1.7.1
    /// returns what happened so the paywall can say so instead of going
    /// silent on Ask to Buy (`.pending`) or a failed verification.
    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        EventLedger.shared.recordPurchaseAttempt()  // A′
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                EventLedger.shared.recordPurchaseCompleted()  // A′
                await transaction.finish()
                await refreshSubscriptionStatus()
                return .purchased
            case .unverified:
                logger.warning("Purchase verification failed.")
                return .unverified
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// Consumable credit-pack purchase. Durable-first: the purchase
    /// leaves the transaction UNFINISHED, then `settleConsumables()`
    /// persists the credits via the settler and only finishes the
    /// transaction once that write succeeded. If the process dies before
    /// the write, StoreKit keeps the transaction in `Transaction
    /// .unfinished` and it is recovered on the next settle.
    @discardableResult
    func purchaseCredits(_ product: Product) async throws -> PurchaseOutcome {
        guard CreditCatalog.credits(forProductID: product.id) != nil else { return .cancelled }
        EventLedger.shared.recordPurchaseAttempt()  // A′
        let result = try await product.purchase()
        switch result {
        case .success(.verified):
            EventLedger.shared.recordPurchaseCompleted()  // A′
            await settleConsumables()
            return .purchased
        case .success(.unverified):
            logger.warning("Credit purchase verification failed.")
            return .unverified
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// Settles every unfinished consumable: persist credits via the
    /// settler (idempotent, keyed by transaction id), and finish the
    /// transaction ONLY after the settler confirms a durable write.
    /// Safe to call repeatedly (launch, paywall appear, post-purchase,
    /// Ask-to-Buy / interrupted delivery).
    func settleConsumables() async {
        guard let settler = creditSettler else { return }
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result,
                  let credits = CreditCatalog.credits(forProductID: transaction.productID)
            else { continue }
            if settler(String(transaction.id), credits) {
                await transaction.finish()
            }
        }
    }

    /// True when a purchase error only means the buyer backed out, which the
    /// paywall must not report as a failure. Everything else (network, not
    /// allowed, product unavailable, verification) is shown to the buyer
    /// instead of being swallowed, as the paywall did until 1.7.1.
    nonisolated static func isUserCancellation(_ error: any Error) -> Bool {
        if error is CancellationError { return true }
        if let storeKitError = error as? StoreKitError, case .userCancelled = storeKitError { return true }
        return false
    }

    /// Re-syncs with the App Store. 1.7.1 returns the outcome (it used to be
    /// `try?` and silent) so the paywall can report a failure, or that there
    /// was nothing to restore. The Settings button still ignores it.
    @discardableResult
    func restorePurchases() async -> RestoreOutcome {
        do {
            try await AppStore.sync()
        } catch let error where Self.isUserCancellation(error) {
            return .cancelled
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            await refreshSubscriptionStatus()
            return isPro ? .restoredPro : .failed(error.localizedDescription)
        }
        await refreshSubscriptionStatus()
        return isPro ? .restoredPro : .nothingToRestore
    }

    func refreshSubscriptionStatus() async {
        #if DEBUG
        // DEBUG builds bypass the StoreKit entitlement check so the developer's
        // own device is always Pro. Release builds still go through StoreKit.
        // β2 NOTE: deliberately do NOT call `proPersister(true)` here — DEBUG
        // Pro is local-only and must never write a CloudKit-synced
        // `proLastVerifiedAt`, which would grant Release devices on the
        // same Apple ID a stale optimistic Pro.
        isPro = true
        return
        #else
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.monthlyProductId
                || transaction.productID == Self.yearlyProductId {
                pro = true
            }
        }
        let wasPro = isPro
        isPro = pro
        // β2: persist on transition AND while still-Pro (refresh the
        // verifiedAt so the CloudKit copy stays warm for any other
        // device's optimistic seed). Clearing on transition-to-false
        // resets the optimistic grace window across all devices.
        if pro || wasPro != pro {
            proPersister?(pro)
        }
        #endif
    }

    /// Track M M.1 (v1.3): the active Pro subscription's Apple-signed JWS
    /// (`VerificationResult.jwsRepresentation`), which the Worker verifies at
    /// /v1/auth to mint a session token. Returns nil when there is no verified
    /// active Pro entitlement — including DEBUG builds, which force `isPro`
    /// without a real StoreKit transaction, so a DEBUG build can never
    /// authenticate to the real Worker (matching the Worker's DEBUG stance).
    func currentProTransactionJWS() async -> String? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.monthlyProductId
                || transaction.productID == Self.yearlyProductId {
                return result.jwsRepresentation
            }
        }
        return nil
    }

    /// β2: optimistically grant Pro at launch from a CloudKit-synced
    /// `UserSettings.proLastVerifiedAt`. Stale grants outside the grace
    /// window are ignored; `refreshSubscriptionStatus()` then runs in
    /// the background and confirms (or revokes) the optimistic state.
    /// Returns true iff the seed actually granted Pro.
    @discardableResult
    func seedOptimisticPro(verifiedAt: Date?, now: Date = Date()) -> Bool {
        guard let verifiedAt else { return false }
        let age = now.timeIntervalSince(verifiedAt)
        guard age >= 0, age <= Self.optimisticProGraceDays else { return false }
        isPro = true
        return true
    }

    private func handleTransactionUpdate(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        if CreditCatalog.credits(forProductID: transaction.productID) != nil {
            // Consumable (Ask-to-Buy approved / interrupted). Do NOT
            // finish here — route through the durable-first settler so
            // credits are persisted before the transaction is finished.
            await settleConsumables()
        } else {
            // Subscription entitlement change.
            await transaction.finish()
            await refreshSubscriptionStatus()
        }
    }
}

/// What a purchase attempt ended as, for the paywall's message. Success is
/// still applied by `StoreService` itself (Pro through `isPro`, credits
/// through the settler); this only decides what the buyer is told.
enum PurchaseOutcome: Sendable, Equatable {
    case purchased
    case cancelled
    /// Waiting for approval (Ask to Buy, or a payment that needs action).
    /// The approved transaction arrives later through `Transaction.updates`
    /// and is applied there.
    case pending
    /// The App Store returned a transaction that failed verification, so it
    /// was not applied.
    case unverified
}

/// What a restore attempt ended as.
enum RestoreOutcome: Sendable, Equatable {
    case restoredPro
    case nothingToRestore
    case cancelled
    case failed(String)
}

/// The alert the paywall shows after a purchase or restore attempt; nil when
/// there is nothing to say. Lives in Shared so the hostless unit tests can
/// check every outcome maps to copy that exists in all four locales — the
/// paywall view itself is app-target code they cannot reach.
struct PurchaseNotice: Sendable, Equatable, Identifiable {
    let titleKey: String
    /// Localizable.strings key for the message, or nil when `detail` is the
    /// message (a StoreKit error's own localized description).
    let messageKey: String?
    let detail: String?

    var id: String { titleKey + (messageKey ?? "") + (detail ?? "") }

    static func forPurchase(_ outcome: PurchaseOutcome) -> PurchaseNotice? {
        switch outcome {
        case .purchased, .cancelled:
            // Pro shows its own confirmation when `isPro` turns on; credits
            // appear in the balance. Cancelling needs no message.
            return nil
        case .pending:
            return PurchaseNotice(titleKey: "paywall.pending.title",
                                  messageKey: "paywall.pending.body", detail: nil)
        case .unverified:
            return PurchaseNotice(titleKey: "paywall.error.title",
                                  messageKey: "paywall.unverified.body", detail: nil)
        }
    }

    /// nil for the buyer backing out (`StoreService.isUserCancellation`).
    static func forPurchaseError(_ error: any Error) -> PurchaseNotice? {
        if StoreService.isUserCancellation(error) { return nil }
        return PurchaseNotice(titleKey: "paywall.error.title",
                              messageKey: nil, detail: error.localizedDescription)
    }

    static func forRestore(_ outcome: RestoreOutcome) -> PurchaseNotice? {
        switch outcome {
        case .restoredPro, .cancelled:
            // Restored Pro shows the same confirmation as a purchase.
            return nil
        case .nothingToRestore:
            return PurchaseNotice(titleKey: "paywall.restore.none.title",
                                  messageKey: "paywall.restore.none.body", detail: nil)
        case .failed(let message):
            return PurchaseNotice(titleKey: "paywall.restore.failed.title",
                                  messageKey: nil, detail: message)
        }
    }
}
