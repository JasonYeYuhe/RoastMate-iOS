import SwiftUI
import SwiftData

/// Drives the four secondary generator features (Reply Helper, Emotion
/// Translator, Argument Simulator, Social Roast). They all share the
/// same input → style → generate → results flow that the headline
/// Roast Generator uses; only the prompt framing and copy differ.
struct FeatureGeneratorConfig {
    let mode: RoastMode
    let titleKey: LocalizedStringResource
    let promptPlaceholderKey: LocalizedStringResource
    let emptyTitleKey: LocalizedStringResource
    let emptySubtitleKey: LocalizedStringResource
    let icon: String
    let proGated: Bool
    let defaultStyleId: String?
}

@MainActor
@Observable
final class FeatureGeneratorViewModel {
    enum State: Equatable {
        case idle
        case loading
        case results
        case error(String)
        /// Input signalled the user's own self-harm risk — show
        /// supportive resources instead of generating.
        case crisis
    }

    let config: FeatureGeneratorConfig
    var input: String = ""
    var selectedStyleId: String
    var selectedIntensity: Intensity = .sharp
    var state: State = .idle
    var currentSession: RoastSession?
    var rewritingDraftId: UUID?
    var rewriteError: String?
    /// Soft self-harm signal: results still shown, plus a supportive banner.
    var crisisBanner: Bool = false

    init(config: FeatureGeneratorConfig) {
        self.config = config
        self.selectedStyleId = config.defaultStyleId ?? StyleCatalog.shared.defaultStyleId
    }

    func style() -> StylePreset? {
        StyleCatalog.shared.style(id: selectedStyleId)
    }

    func generate(context: ModelContext, locale: Locale) async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // Self-harm handoff (two-tier). `.hard` intercepts BEFORE quota /
        // Pro gating / the engine so a person in distress gets care, not
        // an error or a paywall, and no free quota is spent. `.soft`
        // keeps generating (it's a venting app) but flags a supportive
        // banner. Filters stay unchanged.
        switch SafetyFilter.crisisSignal(text) {
        case .hard:
            crisisBanner = false
            state = .crisis
            return
        case .soft:
            crisisBanner = true
        case .none:
            crisisBanner = false
        }
        guard let style = style() else {
            state = .error(String(localized: "error.generic"))
            return
        }

        let settings = HistoryService.userSettings(context: context)
        let isPro = StoreService.shared.isPro

        if config.proGated && !isPro {
            state = .error(String(localized: "quota.exhausted.body"))
            return
        }

        guard isPro || style.tier != .pro else {
            state = .error(String(localized: "quota.exhausted.body"))
            return
        }
        guard isPro || !selectedIntensity.requiresPro else {
            state = .error(String(localized: "quota.exhausted.body"))
            return
        }

        if !isPro {
            // Credits add quantity only; the Pro-only guards above are
            // unchanged. View intent-triggers the paywall first — this
            // is the safety net. β3: pass context so the spend lands as
            // a CreditLedgerEntry, not a creditBalanceRaw decrement.
            guard settings.spendOneCredit(context: context) else {
                state = .error(String(localized: "paywall.out_of_credits.body"))
                return
            }
            try? context.save()
        }

        state = .loading
        currentSession = nil
        rewriteError = nil
        do {
            // Track 0.2 fix: this surface never resolved cloud permission, so
            // on an iOS-18 device with no on-device model it failed instead of
            // falling back to cloud — even with consent granted and the flag
            // on. It does NOT prompt for consent (that UI lives in the
            // generator tab); without a prior grant this resolves to false and
            // stays on-device, exactly as before.
            let cloud = CloudPermission.resolve(
                intensity: selectedIntensity,
                consent: settings.cloudConsent,
                locale: locale
            )
            let variants = try await RoastEngine.shared.generate(
                situation: text,
                style: style,
                locale: locale,
                variantCount: isPro ? 3 : 1,
                mode: config.mode,
                intensity: selectedIntensity,
                safeMode: settings.safeModeEnabled,
                cloudVentEnabled: cloud.cloudAllowed
            )
            currentSession = HistoryService.saveSession(
                situation: text,
                mode: config.mode,
                styleId: style.id,
                locale: locale,
                variants: variants,
                context: context,
                isPro: isPro,
                intensity: selectedIntensity
            )
            state = .results
            Haptics.play(.generated)
        } catch let err as RoastError {
            state = .error(err.localizedDescription)
            Haptics.play(.error)
        } catch {
            state = .error(error.localizedDescription)
            Haptics.play(.error)
        }
    }

    func rewriteAsSendable(
        draft: GeneratedRoast,
        session: RoastSession,
        context: ModelContext,
        locale: Locale
    ) async {
        guard draft.kind == .ventDraft, rewritingDraftId == nil else { return }
        guard let style = StyleCatalog.shared.style(id: draft.styleId) else {
            rewriteError = String(localized: "error.generic")
            return
        }

        rewritingDraftId = draft.id
        rewriteError = nil
        do {
            let rewritten = try await RoastEngine.shared.rewriteAsSendable(
                ventDraft: draft.text,
                originalSituation: session.situation,
                style: style,
                locale: locale
            )
            HistoryService.appendSendableReply(
                toSession: session,
                sourceVentDraft: draft,
                rewrittenText: rewritten,
                context: context
            )
            currentSession = session
            Haptics.play(.generated)
        } catch let err as RoastError {
            rewriteError = err.localizedDescription
            Haptics.play(.error)
        } catch {
            rewriteError = error.localizedDescription
            Haptics.play(.error)
        }
        rewritingDraftId = nil
    }
}

struct FeatureGeneratorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var viewModel: FeatureGeneratorViewModel
    @State private var showPaywall = false
    @Query private var settingsQuery: [UserSettings]

    private var settings: UserSettings? { settingsQuery.first }

    private var styles: [StylePreset] {
        if viewModel.config.proGated {
            return StyleCatalog.shared.all
        }
        return StyleCatalog.shared.all
    }
    private var isPro: Bool { StoreService.shared.isPro }

    init(config: FeatureGeneratorConfig) {
        _viewModel = State(wrappedValue: FeatureGeneratorViewModel(config: config))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerCard
                inputCard
                styleRow
                intensityRow
                generateButton
                results
            }
            .padding()
        }
        .navigationTitle(AppLocalization.string(viewModel.config.titleKey.key))
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
        .onAppear {
            if viewModel.config.proGated && !isPro {
                EventLedger.shared.recordPaywallImpression(source: .proTap)
                showPaywall = true
            }
        }
    }

    private var headerCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: viewModel.config.icon)
                .font(.title2)
                .foregroundStyle(.orange)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.config.emptyTitleKey)
                    .font(.headline)
                Text(viewModel.config.emptySubtitleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.config.proGated {
                Text("Pro")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.18)))
                    .foregroundStyle(.orange)
            }
        }
    }

    private var inputCard: some View {
        TextEditor(text: $viewModel.input)
            .frame(minHeight: 120)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
            )
            .overlay(alignment: .topLeading) {
                if viewModel.input.isEmpty {
                    Text(viewModel.config.promptPlaceholderKey)
                        .foregroundStyle(.tertiary)
                        .padding(14)
                        .allowsHitTesting(false)
                }
            }
    }

    private var styleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("generator.style_label").font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(styles) { style in
                        StyleChip(
                            style: style,
                            isSelected: viewModel.selectedStyleId == style.id,
                            isLocked: !isPro && style.tier == .pro
                        ) {
                            if !isPro && style.tier == .pro {
                                EventLedger.shared.recordPaywallImpression(source: .styleLocked)
                                showPaywall = true
                            } else {
                                viewModel.selectedStyleId = style.id
                            }
                        }
                    }
                }
            }
        }
    }

    private var generateButton: some View {
        Button {
            if !isPro && viewModel.selectedIntensity.requiresPro {
                EventLedger.shared.recordPaywallImpression(source: .intensityLocked)
                showPaywall = true
            } else if !isPro && settings?.canSpendNow() == false {
                // Intent-triggered paywall at the peak moment.
                EventLedger.shared.recordPaywallImpression(source: .lowCredits)
                showPaywall = true
            } else {
                Task { await viewModel.generate(context: context, locale: locale) }
            }
        } label: {
            HStack {
                if case .loading = viewModel.state {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "flame.fill")
                }
                Text(viewModel.state == .idle ? "generator.generate" : "result.regenerate")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  || viewModel.state == .loading)
    }

    private var intensityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("generator.intensity_label").font(.subheadline.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Intensity.allCases, id: \.self) { intensity in
                        IntensityChip(
                            intensity: intensity,
                            isSelected: viewModel.selectedIntensity == intensity,
                            isLocked: !isPro && intensity.requiresPro
                        ) {
                            if !isPro && intensity.requiresPro {
                                EventLedger.shared.recordPaywallImpression(source: .intensityLocked)
                                showPaywall = true
                            } else {
                                viewModel.selectedIntensity = intensity
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var results: some View {
        switch viewModel.state {
        case .results:
            VStack(alignment: .leading, spacing: 12) {
                if viewModel.crisisBanner {
                    CrisisBanner()
                }
                if let message = viewModel.rewriteError {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                        Text(message).font(.callout)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.12))
                    )
                }
                if let session = viewModel.currentSession {
                    ForEach(sortedResults(session), id: \.id) { result in
                        GeneratedRoastCard(
                            result: result,
                            style: StyleCatalog.shared.style(id: result.styleId),
                            isRewriting: viewModel.rewritingDraftId == result.id,
                            hasSendableReply: hasSendableReply(for: result, in: session)
                        ) {
                            Task {
                                await viewModel.rewriteAsSendable(
                                    draft: result,
                                    session: session,
                                    context: context,
                                    locale: locale
                                )
                            }
                        }
                    }
                }
            }
        case .error(let message):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text(message).font(.callout)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.orange.opacity(0.12))
            )
        case .crisis:
            CrisisSupportView(onDismiss: { viewModel.state = .idle })
        case .idle, .loading:
            EmptyView()
        }
    }

    private func sortedResults(_ session: RoastSession) -> [GeneratedRoast] {
        (session.results ?? []).sorted { $0.generatedAt < $1.generatedAt }
    }

    private func hasSendableReply(for result: GeneratedRoast, in session: RoastSession) -> Bool {
        guard result.kind == .ventDraft else { return false }
        return (session.results ?? []).contains {
            $0.kind == .sendableReply && $0.sourceVentDraftId == result.id
        }
    }
}

enum FeatureGeneratorConfigs {
    static let replyHelper = FeatureGeneratorConfig(
        mode: .reply,
        titleKey: "feature.reply.title",
        promptPlaceholderKey: "feature.reply.placeholder",
        emptyTitleKey: "feature.reply.empty_title",
        emptySubtitleKey: "feature.reply.empty_subtitle",
        icon: "arrowshape.turn.up.left",
        proGated: false,
        defaultStyleId: "high_eq"
    )

    static let emotionTranslator = FeatureGeneratorConfig(
        mode: .translate,
        titleKey: "feature.translator.title",
        promptPlaceholderKey: "feature.translator.placeholder",
        emptyTitleKey: "feature.translator.empty_title",
        emptySubtitleKey: "feature.translator.empty_subtitle",
        icon: "arrow.left.arrow.right",
        proGated: false,
        defaultStyleId: "high_eq"
    )

    static let argumentSimulator = FeatureGeneratorConfig(
        mode: .argument,
        titleKey: "feature.argument.title",
        promptPlaceholderKey: "feature.argument.placeholder",
        emptyTitleKey: "feature.argument.empty_title",
        emptySubtitleKey: "feature.argument.empty_subtitle",
        icon: "person.2.wave.2",
        proGated: true,
        defaultStyleId: "cold_violence"
    )

    static let socialRoast = FeatureGeneratorConfig(
        mode: .social,
        titleKey: "feature.social.title",
        promptPlaceholderKey: "feature.social.placeholder",
        emptyTitleKey: "feature.social.empty_title",
        emptySubtitleKey: "feature.social.empty_subtitle",
        icon: "bubble.left.and.bubble.right",
        proGated: false,
        defaultStyleId: "tweet_short"
    )

    /// Echoes / 替你出气 (Phase 5 Q2). Pro-gated. Distinct from the
    /// other tool configs: doesn't use FeatureGeneratorView under the
    /// hood — has its own EchoesView (chat-style transcript reveal).
    /// Config is here only so the tile copy / icon / Pro-gating is
    /// consistent with the other Explore tools.
    static let echoes = FeatureGeneratorConfig(
        mode: .roast,  // unused — EchoesView has its own engine
        titleKey: "feature.echoes.title",
        promptPlaceholderKey: "feature.echoes.placeholder",
        emptyTitleKey: "feature.echoes.empty_title",
        emptySubtitleKey: "feature.echoes.empty_subtitle",
        icon: "text.bubble.fill",
        proGated: true,
        defaultStyleId: "savage"
    )

    static let roommateGroup = FeatureGeneratorConfig(
        mode: .roast,  // unused — EchoesView(scene:.roommateGroup) has its own (cloud) engine
        titleKey: "feature.roommate.title",
        promptPlaceholderKey: "feature.roommate.placeholder",
        emptyTitleKey: "feature.roommate.empty_title",
        emptySubtitleKey: "feature.roommate.empty_subtitle",
        icon: "person.3.fill",
        proGated: true,
        defaultStyleId: "savage"
    )
}
