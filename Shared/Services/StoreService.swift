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
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
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
        let result = try await product.purchase()
        switch result {
        case .success(.verified):
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
        isPro = pro
        #endif
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
