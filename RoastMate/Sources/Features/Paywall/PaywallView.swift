import SwiftUI
import SwiftData
import StoreKit

/// v1.2 hybrid monetization paywall. **Pro is PRIMARY** — it is the
/// only thing that unlocks the marquee modes (Vent / Feral / Savage) +
/// unlimited + every style, so it is the hero and shown first. Credit
/// packs are honest pay-as-you-go *overflow* (no subscription, quantity
/// only) shown second. This corrects the v1.1 "consumables-primary"
/// framing, which foregrounded packs while the things users actually
/// want stayed Pro-gated (the "monetization theater" both the Gemini
/// 3.1 Pro and Codex reviews flagged). No pricing / SKU / entitlement
/// change — packs still never unlock a Pro capability.
///
/// This screen is intent-triggered (it fires at the peak moment the
/// user reaches for a generation with an empty wallet, or taps a
/// Pro-only capability) — never gated onto onboarding.
struct PaywallView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var context
    @Query private var settingsQuery: [UserSettings]
    @State private var store = StoreService.shared

    private var settings: UserSettings {
        settingsQuery.first ?? HistoryService.userSettings(context: context)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if settings.availableCreditsNow() == 0 {
                    outOfCreditsBanner
                }
                proSection
                Divider()
                creditPacksSection

                Button("paywall.restore") {
                    Task { await store.restorePurchases() }
                }
                .font(.footnote)
                .frame(maxWidth: .infinity)

                Button("paywall.continue_free") {
                    isPresented = false
                }
                .frame(maxWidth: .infinity)

                legalFooter
            }
            .padding(24)
        }
        .frame(minWidth: 360, minHeight: 480)
        .task {
            installSettlerIfNeeded()
            await store.loadProducts()
            await store.settleConsumables()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "flame.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            VStack(alignment: .leading) {
                Text("paywall.title").font(.title2.bold())
                Text("paywall.body")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var outOfCreditsBanner: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("paywall.out_of_credits.title")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text("paywall.out_of_credits.body")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.10))
        )
    }

    // MARK: - Credit packs (overflow — honest pay-as-you-go, never unlocks Pro)

    private var creditPacksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("paywall.credits.title").font(.headline)
                Text("paywall.credits.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if settings.availableCreditsNow() > 0 {
                    Text(String(format: String(localized: "paywall.credits.balance"),
                                settings.availableCreditsNow()))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
            if store.creditProducts.isEmpty {
                loadingRow
            } else {
                ForEach(store.creditProducts, id: \.id) { product in
                    creditPackRow(product)
                }
            }
            Text("paywall.credits.note")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func creditPackRow(_ product: Product) -> some View {
        let credits = CreditCatalog.credits(forProductID: product.id) ?? 0
        let isBest = CreditCatalog.Pack(rawValue: product.id)?.isBestValue ?? false
        return Button {
            Task {
                try? await store.purchaseCredits(product)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: String(localized: "paywall.credits.pack"), credits))
                        .font(.headline)
                    if isBest {
                        Text("paywall.credits.bestvalue")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(isBest ? 0.14 : 0.07))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pro (PRIMARY — unlocks the marquee modes + unlimited + every style)

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("paywall.pro.title").font(.headline)
                    Text("paywall.pro.recommended")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundStyle(.orange)
                }
                Text("paywall.pro.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            featureCallouts
            ForEach(store.products, id: \.id) { product in
                productRow(product)
            }
            if store.products.isEmpty {
                loadingRow
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    private var featureCallouts: some View {
        VStack(alignment: .leading, spacing: 10) {
            featureRow(
                icon: "flame.fill",
                tint: .orange,
                title: "paywall.feature.vent",
                detail: "paywall.feature.vent.detail"
            )
            featureRow(
                icon: "bolt.fill",
                tint: .red,
                title: "paywall.feature.savage",
                detail: "paywall.feature.savage.detail"
            )
            featureRow(
                icon: "infinity",
                tint: .blue,
                title: "paywall.feature.unlimited",
                detail: "paywall.feature.unlimited.detail"
            )
        }
    }

    private func featureRow(
        icon: String,
        tint: Color,
        title: LocalizedStringResource,
        detail: LocalizedStringResource
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private func productRow(_ product: Product) -> some View {
        Button {
            Task { try? await store.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(product.displayName.isEmpty ? product.id : product.displayName)
                        .font(.headline)
                    Text(product.description.isEmpty ? product.id : product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let period = product.subscription?.subscriptionPeriod {
                        Text(periodLabel(period))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func periodLabel(_ period: Product.SubscriptionPeriod) -> String {
        let count = period.value
        let key: String.LocalizationValue
        switch period.unit {
        case .day:   key = "paywall.length.day"
        case .week:  key = "paywall.length.week"
        case .month: key = "paywall.length.month"
        case .year:  key = "paywall.length.year"
        @unknown default: return ""
        }
        return String(format: String(localized: key), count)
    }

    // MARK: - Legal footer (Apple 3.1.2(c) — EULA + Privacy + auto-renew disclosure)

    private var legalFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Link(destination: URL(string: "https://jasonyeyuhe.github.io/RoastMate/terms.html")!) {
                    Text("paywall.legal.terms")
                        .underline()
                }
                Text("·").foregroundStyle(.tertiary)
                Link(destination: URL(string: "https://jasonyeyuhe.github.io/RoastMate/privacy.html")!) {
                    Text("paywall.legal.privacy")
                        .underline()
                }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)

            Text("paywall.legal.note")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 4)
        }
        .padding(.top, 8)
    }

    private var loadingRow: some View {
        Text("paywall.loading")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    // MARK: - Wallet settlement

    /// The app installs the durable-first settler at bootstrap. As a
    /// safety net (e.g. paywall reached before bootstrap completed),
    /// install an equivalent one bound to this view's context if none
    /// exists. Idempotent: the wallet write is keyed by transaction id.
    private func installSettlerIfNeeded() {
        guard store.creditSettler == nil else { return }
        let ctx = context
        store.creditSettler = { txID, credits in
            let s = settingsQuery.first ?? HistoryService.userSettings(context: ctx)
            if s.hasGrantedCreditTx(txID) { return true }
            s.applyCreditGrant(txID: txID, credits: credits)
            do {
                try ctx.save()
                return true
            } catch {
                ctx.rollback()
                return false
            }
        }
    }
}
