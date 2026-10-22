import Foundation

/// App-owned copy for the subscription rows on the paywall.
///
/// The rows used to show StoreKit's `displayName` / `description`, which come
/// from App Store Connect and still say "Unlimited generations + all styles"
/// (zh-Hant 「無限生成 + 全部風格」, with the mainland-sounding 月度 / 年度).
/// The App Store Connect API refuses to edit a subscription localization while
/// it is ACTIVE (2026-10-22), so the paywall shows this copy instead and only
/// falls back to StoreKit's text for a product it doesn't know.
enum PlanCopy {
    struct Keys: Equatable {
        let name: String
        let detail: String
    }

    static func keys(forProductID id: String) -> Keys? {
        switch id {
        case StoreService.monthlyProductId:
            return Keys(name: "paywall.monthly", detail: "paywall.plan.monthly.detail")
        case StoreService.yearlyProductId:
            return Keys(name: "paywall.yearly", detail: "paywall.plan.yearly.detail")
        default:
            return nil
        }
    }
}
