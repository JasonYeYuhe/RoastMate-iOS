import SwiftUI
import StoreKit

struct PaywallView: View {
    @Binding var isPresented: Bool
    @State private var store = StoreService.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
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

            featureCallouts

            VStack(spacing: 12) {
                ForEach(store.products, id: \.id) { product in
                    productRow(product)
                }
                if store.products.isEmpty {
                    Text("Loading subscription options…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
            }

            Button("paywall.restore") {
                Task { await store.restorePurchases() }
            }
            .font(.footnote)
            .frame(maxWidth: .infinity)

            Spacer()

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
}
