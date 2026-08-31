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

    /// Subscription purchase (Pro). Unchanged behavior.
    func purchase(_ product: Product) async throws {
        EventLedger.shared.recordPurchaseAttempt()  // A′
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                EventLedger.shared.recordPurchaseCompleted()  // A′
                await transaction.finish()
                await refreshSubscriptionStatus()
            case .unverified:
                logger.warning("Purchase verification failed.")
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    /// Consumable credit-pack purchase. Durable-first: the purchase
    /// leaves the transaction UNFINISHED, then `settleConsumables()`
    /// persists the credits via the settler and only finishes the
    /// transaction once that write succeeded. If the process dies before
    /// the write, StoreKit keeps the transaction in `Transaction
    /// .unfinished` and it is recovered on the next settle.
    func purchaseCredits(_ product: Product) async throws {
        guard CreditCatalog.credits(forProductID: product.id) != nil else { return }
        EventLedger.shared.recordPurchaseAttempt()  // A′
        let result = try await product.purchase()
        switch result {
        case .success(.verified):
            EventLedger.shared.recordPurchaseCompleted()  // A′
            await settleConsumables()
        case .success(.unverified):
            logger.warning("Credit purchase verification failed.")
        case .userCancelled, .pending:
            break
        @unknown default:
            break
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

    func restorePurchases() async {
        try? await AppStore.sync()
        await refreshSubscriptionStatus()
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
