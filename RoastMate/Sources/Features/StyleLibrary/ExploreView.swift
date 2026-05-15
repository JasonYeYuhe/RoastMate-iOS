import SwiftUI

/// Top-level "Explore" tab. Hosts the secondary feature entry points
/// (Reply Helper / Translator / Argument Simulator / Social Roast) and
/// the full style library grid. Replaces the older pure StyleLibraryView
/// so the four extra modes are discoverable without a 5th tab.
struct ExploreView: View {
    @State private var search: String = ""

    private var allStyles: [StylePreset] { StyleCatalog.shared.all }

    private var filteredStyles: [StylePreset] {
        let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return allStyles }
        return allStyles.filter {
            $0.displayName.lowercased().contains(trimmed)
            || $0.id.contains(trimmed)
            || $0.tags.contains(where: { $0.lowercased().contains(trimmed) })
        }
    }

    private let toolColumns = [GridItem(.adaptive(minimum: 160), spacing: 12)]
    private let styleColumns = [GridItem(.adaptive(minimum: 220), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("explore.tools.section")
                    .font(.title3.bold())
                    .padding(.horizontal)

                LazyVGrid(columns: toolColumns, spacing: 12) {
                    toolCard(
                        config: FeatureGeneratorConfigs.replyHelper,
                        destination: AnyView(FeatureGeneratorView(config: FeatureGeneratorConfigs.replyHelper))
                    )
                    toolCard(
                        config: FeatureGeneratorConfigs.emotionTranslator,
                        destination: AnyView(FeatureGeneratorView(config: FeatureGeneratorConfigs.emotionTranslator))
                    )
                    toolCard(
                        config: FeatureGeneratorConfigs.argumentSimulator,
                        destination: AnyView(ArgumentSimulatorView())
                    )
                    toolCard(
                        config: FeatureGeneratorConfigs.socialRoast,
                        destination: AnyView(FeatureGeneratorView(config: FeatureGeneratorConfigs.socialRoast))
                    )
                }
                .padding(.horizontal)

                Text("explore.samples.section")
                    .font(.title3.bold())
                    .padding(.horizontal)
                    .padding(.top, 4)

                NavigationLink {
                    SampleGalleryView()
                } label: {
                    HStack {
                        Image(systemName: "books.vertical")
                            .foregroundStyle(.orange)
                        Text("explore.samples.cta")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .padding(.horizontal)
                }

                Text("explore.styles.section")
                    .font(.title3.bold())
                    .padding(.horizontal)
                    .padding(.top, 4)

                LazyVGrid(columns: styleColumns, spacing: 12) {
                    ForEach(filteredStyles) { style in
                        styleCard(style)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(AppLocalization.string("tab.library"))
        .searchable(text: $search)
    }

    private func toolCard(config: FeatureGeneratorConfig, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: config.icon)
                        .font(.title2)
                        .foregroundStyle(.orange)
                    Spacer()
                    if config.proGated {
                        Text("Pro")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                            .foregroundStyle(.orange)
                    }
                }
                Text(config.emptyTitleKey)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                Text(config.emptySubtitleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func styleCard(_ style: StylePreset) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: style.icon)
                    .font(.title3)
                    .foregroundStyle(.orange)
                Spacer()
                if style.tier == .pro {
                    Text("Pro")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                        .foregroundStyle(.orange)
                }
            }
            Text(style.displayName).font(.headline)
            Text(style.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}
