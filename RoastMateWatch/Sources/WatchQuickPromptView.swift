import SwiftUI
import SwiftData

struct WatchQuickPromptView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale

    @State var seedSituation: String
    @State private var output: String? = nil
    @State private var isLoading: Bool = false
    @State private var error: String? = nil
    @State private var styleId: String = StyleCatalog.shared.defaultStyleId

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(seedSituation)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                }

                if let output {
                    Text(output)
                        .font(.body)
                        .padding(.vertical, 4)
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button {
                    Task { await generate() }
                } label: {
                    Label("generator.generate", systemImage: "flame.fill")
                }
                .disabled(isLoading)

                if output != nil {
                    Label("watch.send_to_phone", systemImage: "iphone.gen3")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("watch.home.title")
        .task { await generate() }
        .userActivity(
            HandoffActivity.typeRoastSession,
            isActive: output != nil
        ) { activity in
            activity.title = String(localized: "watch.home.title")
            activity.isEligibleForHandoff = true
            activity.requiredUserInfoKeys = [HandoffActivity.UserInfoKey.situation]
            activity.addUserInfoEntries(
                from: HandoffActivity.payload(
                    situation: seedSituation,
                    styleId: styleId,
                    mode: .roast,
                    locale: locale
                )
            )
        }
    }

    private func generate() async {
        isLoading = true
        defer { isLoading = false }
        guard let style = StyleCatalog.shared.style(id: styleId) else {
            error = String(localized: "error.generic")
            return
        }
        do {
            let variants = try await RoastEngine.shared.generate(
                situation: seedSituation,
                style: style,
                locale: locale,
                variantCount: 1
            )
            output = variants.first
            error = nil
            HistoryService.saveSession(
                situation: seedSituation,
                mode: .roast,
                styleId: styleId,
                locale: locale,
                variants: variants,
                context: context,
                isPro: StoreService.shared.isPro
            )
        } catch let err as RoastError {
            error = err.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
