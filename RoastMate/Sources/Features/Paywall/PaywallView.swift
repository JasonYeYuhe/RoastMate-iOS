import SwiftUI
import SwiftData
import StoreKit

/// v1.1 hybrid monetization paywall. Consumables are PRIMARY (the
/// zh-first pay-as-you-go path) and shown first; Pro is positioned as
/// the unlimited best-value tier for heavy users. Credits are a
/// quantity knob only — Savage / Feral / Vent and the Pro style shelf
/// stay subscription-only no matter how many credits are bought.
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
                creditPacksSection
                Divider()
                proSection

                Button("paywall.restore") {
                    Task { await store.restorePurchases() }
                }
                .font(.footnote)
                .frame(maxWidth: .infinity)

                Button("paywall.continue_free") {
                    isPresented = false
                }
                .frame(maxWidth: .infinity)
            }
            .padding(24)
        }
        .frame(minWidth: 360, minHeight: 480)
        .task {
            await store.loadProducts()
            drainPendingCredits()
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

    // MARK: - Credit packs (primary)

    private var creditPacksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("paywall.credits.title").font(.headline)
                Text("paywall.credits.subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                drainPendingCredits()
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

    // MARK: - Pro (best value for heavy users)

    private var proSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("paywall.pro.title").font(.headline)
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

    private var loadingRow: some View {
        Text("Loading…")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    // MARK: - Wallet grant

    /// Moves credits from a verified consumable purchase into the
    /// on-device wallet (which owns persistence) and zeroes the staging
    /// counter. Local-only by design — no server reconciliation.
    private func drainPendingCredits() {
        let pending = store.pendingCreditGrant
        guard pending > 0 else { return }
        settings.grantCredits(pending)
        store.pendingCreditGrant = 0
        try? context.save()
    }
}
