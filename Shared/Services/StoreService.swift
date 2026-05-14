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

    static let monthlyProductId = "yyh.roastmate.app.pro.monthly"
    static let yearlyProductId = "yyh.roastmate.app.pro.yearly"

    private(set) var products: [Product] = []
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
            products = try await Product.products(for: [Self.monthlyProductId, Self.yearlyProductId])
        } catch {
            logger.error("Product load failed: \(error.localizedDescription)")
        }
    }

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
            await transaction.finish()
            await refreshSubscriptionStatus()
        }
    }
}
