import Foundation
import StoreKit
import os.log

/// StoreKit 2 wrapper for the Pro subscription. V1 ships with the
/// in-memory state only; full restore + transaction listener will land
/// when Configuration.storekit is wired up (W7 per the plan).
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

    /// Credits from verified consumable purchases not yet written into
    /// the on-device wallet. `UserSettings` owns persistence, so the
    /// presenting view drains this into the wallet and zeroes it. This
    /// also catches transactions delivered via `Transaction.updates`
    /// (Ask-to-Buy / interrupted purchases). There is no server-side
    /// reconciliation by design — the app has no backend and rage never
    /// leaves the device.
    var pendingCreditGrant: Int = 0
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

    /// Consumable credit-pack purchase. On a verified transaction the
    /// credit amount is staged in `pendingCreditGrant`; the presenting
    /// view writes it into the wallet (which owns persistence) and
    /// finishes nothing here — `transaction.finish()` is called only
    /// after staging so an interrupted write is recoverable via
    /// `Transaction.updates`.
    func purchaseCredits(_ product: Product) async throws {
        guard CreditCatalog.credits(forProductID: product.id) != nil else { return }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                if let credits = CreditCatalog.credits(forProductID: transaction.productID) {
                    pendingCreditGrant += credits
                }
                await transaction.finish()
            case .unverified:
                logger.warning("Credit purchase verification failed.")
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
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
        if case .verified(let transaction) = update {
            // A consumable arriving here (Ask-to-Buy approved, or an
            // interrupted purchase) still needs its credits staged so
            // they are not silently lost.
            if let credits = CreditCatalog.credits(forProductID: transaction.productID) {
                pendingCreditGrant += credits
            }
            await transaction.finish()
            await refreshSubscriptionStatus()
        }
    }
}
