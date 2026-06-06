import SwiftUI

/// Top-level "Explore" tab. Hosts the secondary feature entry points
/// (Reply Helper / Translator / Argument Simulator / Social Roast) and
/// the full style library grid. Replaces the older pure StyleLibraryView
/// so the four extra modes are discoverable without a 5th tab.
struct ExploreView: View {
    /// Optional closure passed in from RootView. When the Echoes
    /// Bridge-to-Action CTA fires, the EchoesView calls this to ask
    /// the parent tab container to switch to the Generator tab so the
    /// pre-filled RoastGenerator picks up the staged
    /// `EchoBridgeStore.pending` payload in its `.onAppear`.
    var onContinueGenerator: (() -> Void)?

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
                    // Echoes / 替你出气 — v1 zh-Hans only per v2 plan §8.
                    // Other locales don't see the tile; v0.2 adds en /
                    // zh-Hant / ja persona catalogs and removes this gate.
                    // Also gated by the remote kill-switch: a fetched
                    // `echoes_enabled:false` hides the tile (the primary
                    // gate; EchoesEngine is guarded too). Reading the
                    // @Observable singleton's `current` in body registers a
                    // dependency, so a kill applied by the launch refresh
                    // takes effect immediately (the tile disappears that
                    // session) and persists across relaunch via the cached
                    // config. Immediate effect is the goal for a disaster
                    // kill-switch. (Health audit 2026-05-29 §4.)
                    if isZhHansLocale() && RemoteConfig.shared.current.echoesEnabled {
                        toolCard(
                            config: FeatureGeneratorConfigs.echoes,
                            destination: AnyView(EchoesView(onBridgeTap: { onContinueGenerator?() }))
                        )
                        .accessibilityIdentifier("echoes.tile")
                    }
                    // 虚拟舍友群 (Echoes vNext) — cloud-generated 3-roommate group
                    // chat (Apple's on-device FM blocks the harsh roast). DARK by
                    // default (roommate_group_enabled:false): the tile appears only
                    // once the flag is flipped AND echoes is on (roommateGroupAllowed).
                    // zh-Hans v1, like classic Echoes.
                    if isZhHansLocale() && RemoteConfig.shared.current.roommateGroupAllowed {
                        toolCard(
                            config: FeatureGeneratorConfigs.roommateGroup,
                            destination: AnyView(EchoesView(scene: .roommateGroup, onBridgeTap: { onContinueGenerator?() }))
                        )
                        .accessibilityIdentifier("roommate.tile")
                    }
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

    /// Echoes v1 is zh-Hans-only — tile only shows when the resolved
    /// locale resolves to zh-Hans. Mirrors how the app picks the
    /// underlying generation locale.
    private func isZhHansLocale() -> Bool {
        // If user explicitly picked a language, honor it; otherwise fall
        // back to the system locale.
        let id: String
        if let l = LanguageManager.shared.locale {
            id = l.identifier.lowercased()
        } else {
            id = Locale.current.identifier.lowercased()
        }
        return id.contains("hans") || id.hasPrefix("zh-cn") || id == "zh"
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
