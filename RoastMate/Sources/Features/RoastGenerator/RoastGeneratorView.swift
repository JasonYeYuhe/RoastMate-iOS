import SwiftUI
import SwiftData

struct RoastGeneratorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = RoastGeneratorViewModel()
    @State private var showPaywall = false
    @State private var threadContinuationBanner: String? = nil
    #if os(iOS)
    @State private var voiceGate: VoiceVentGate? = nil
    @State private var showVoiceSheet = false
    #endif
    @Query private var settingsQuery: [UserSettings]
    @Query private var threads: [SituationThread]

    private var styles: [StylePreset] { StyleCatalog.shared.all }
    private var samples: [SampleRoast] { SampleRoastsCatalog.shared.all }

    private var settings: UserSettings? { settingsQuery.first }
    private var isPro: Bool { StoreService.shared.isPro }

    @FocusState private var situationFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let banner = threadContinuationBanner {
                    continuationBanner(banner)
                }
                situationCard
                styleRow
                intensityRow
                generateButton
                resultsSection
                if case .idle = viewModel.state {
                    scenarioSection
                    sampleSection
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: scenePhase) { _, phase in
            // Control tapped while the app was already foregrounded ON
            // the generator tab: onAppear won't re-fire, so consume the
            // Quick Vent request here too.
            if phase == .active { applyQuickVentIfPending() }
        }
        .onChange(of: viewModel.state) { _, newValue in
            // Dismiss the keyboard the moment we start generating so the
            // result has the full screen to breathe in. Without this the
            // TextEditor keeps focus and the keyboard covers the bottom
            // half of the result card on smaller phones.
            if newValue == .loading || newValue == .results {
                situationFocused = false
            }
            // Clear the "Continuing this event" banner once results land
            // so the user knows the continuation has been consumed.
            if newValue == .results {
                threadContinuationBanner = nil
            }
        }
        .navigationTitle(AppLocalization.string("generator.title"))
        .onAppear {
            // Quick Vent (Control Center / Lock Screen / Action Button /
            // Siri) lands here: pre-select Vent and focus the box. Pro
            // gating + the credit wallet still apply on Generate.
            applyQuickVentIfPending()
            if let payload = HandoffStore.shared.consume() {
                viewModel.situation = payload.situation
                viewModel.selectedStyleId = payload.styleId
            }
            if let cont = ThreadContinuationStore.shared.consume() {
                if let styleId = cont.suggestedStyleId {
                    viewModel.selectedStyleId = styleId
                }
                if let thread = threads.first(where: { $0.id == cont.threadId }) {
                    viewModel.pendingThread = thread
                    viewModel.pendingPriorContext = cont.priorContext
                    if let original = (thread.sessions ?? [])
                        .sorted(by: { $0.createdAt > $1.createdAt }).first {
                        viewModel.situation = ""
                        threadContinuationBanner = original.situation
                    } else {
                        viewModel.situation = ""
                        threadContinuationBanner = thread.originalSituation
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !isPro, let settings {
                    quotaChip(for: settings)
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
        .sheet(isPresented: $viewModel.pendingCloudConsent) {
            CloudConsentSheet(
                onAllow: {
                    Task { await viewModel.resolveCloudConsent(true, context: context, locale: locale) }
                },
                onDeny: {
                    Task { await viewModel.resolveCloudConsent(false, context: context, locale: locale) }
                }
            )
        }
        #if os(iOS)
        .task(id: locale) {
            voiceGate = await VoiceVentTranscriber.currentGate(appLocale: locale)
        }
        .sheet(isPresented: $showVoiceSheet) {
            VoiceVentSheet(appLocale: locale) { transcript in
                viewModel.applyVoiceTranscript(transcript)
                situationFocused = false
            }
        }
        #endif
    }

    /// Drains a pending Quick Vent request (from a Control / Action
    /// Button / Siri) exactly once and pre-selects the Vent intensity.
    /// Idempotent: consume clears the flag, so a follow-up scenePhase
    /// or onAppear is a no-op.
    private func applyQuickVentIfPending() {
        if LaunchRouter.shared.consumeQuickVent() {
            viewModel.selectedIntensity = .vent
            situationFocused = true
        }
    }

    @ViewBuilder
    private func quotaChip(for settings: UserSettings) -> some View {
        if settings.isInStarterWindow(), settings.starterTrickleRemaining() > 0 {
            VStack(alignment: .trailing, spacing: 0) {
                Text(String(format: String(localized: "wallet.starter"), settings.starterTrickleRemaining()))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("wallet.starter.hint")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else {
            Text(String(format: String(localized: "wallet.credits"), settings.availableCreditsNow()))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func continuationBanner(_ priorSituation: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.turn.up.right")
                .foregroundStyle(.orange)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text("generator.continuation.title")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text(priorSituation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Text("generator.continuation.hint")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            Spacer()
            Button {
                viewModel.pendingThread = nil
                viewModel.pendingPriorContext = nil
                threadContinuationBanner = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.10))
        )
    }

    private var situationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("generator.empty.title")
                .font(.headline)
            TextEditor(text: $viewModel.situation)
                .focused($situationFocused)
                .frame(minHeight: 110)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.secondary.opacity(0.08))
                )
                .overlay(alignment: .topLeading) {
                    if viewModel.situation.isEmpty {
                        Text("generator.placeholder")
                            .foregroundStyle(.tertiary)
                            .padding(14)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    #if os(iOS)
                    if voiceGate?.showsAffordance == true {
                        Button {
                            showVoiceSheet = true
                        } label: {
                            Image(systemName: "mic.fill")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.orange)
                                .padding(8)
                                .background(Circle().fill(Color.orange.opacity(0.14)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("voice.button"))
                        .padding(10)
                    }
                    #endif
                }
            Text("generator.empty.subtitle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var styleRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("generator.style_label")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(styles) { style in
                        StyleChip(
                            style: style,
                            isSelected: viewModel.selectedStyleId == style.id,
                            isLocked: !isPro && style.tier == .pro
                        ) {
                            if !isPro && style.tier == .pro {
                                showPaywall = true
                            } else {
                                viewModel.selectedStyleId = style.id
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var generateButton: some View {
        Button {
            // Dismiss keyboard immediately on tap — the on-state-change
            // hook also fires once .loading begins, but doing it here
            // means the user sees the keyboard slide down the moment
            // they hit Generate, not after the model warms up.
            situationFocused = false
            if !isPro && viewModel.selectedIntensity.requiresPro {
                showPaywall = true
            } else if !isPro && settings?.canSpendNow() == false {
                // Intent-triggered paywall: fire at the peak moment the
                // user reaches for a generation with an empty wallet —
                // not at onboarding.
                showPaywall = true
            } else {
                Task { await viewModel.generate(context: context, locale: locale) }
            }
        } label: {
            HStack {
                if case .loading = viewModel.state {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "flame.fill")
                }
                Text(viewModel.state == .idle
                     ? "generator.generate"
                     : "result.regenerate")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.situation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                  || viewModel.state == .loading)
    }

    private var intensityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("generator.intensity_label")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Intensity.allCases, id: \.self) { intensity in
                        IntensityChip(
                            intensity: intensity,
                            isSelected: viewModel.selectedIntensity == intensity,
                            isLocked: !isPro && intensity.requiresPro
                        ) {
                            if !isPro && intensity.requiresPro {
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
    private var resultsSection: some View {
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
                        Text(message)
                            .font(.callout)
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
                            hasSendableReply: hasSendableReply(for: result, in: session),
                            pairedVentText: session.sourceVentText(for: result)
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
                Text(message)
                    .font(.callout)
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

    @ViewBuilder
    private var scenarioSection: some View {
        let catalog = ScenarioCatalog.shared
        let cats = catalog.orderedCategories
        if !cats.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("scenario.section")
                    .font(.headline)
                    .padding(.top, 4)
                ForEach(cats, id: \.self) { cat in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey("scenario.cat.\(cat)"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(catalog.scenarios(in: cat)) { scenario in
                                    Button {
                                        viewModel.loadScenario(scenario, locale: locale)
                                        situationFocused = false
                                    } label: {
                                        Text(scenario.prompt(for: locale))
                                            .font(.caption)
                                            .multilineTextAlignment(.leading)
                                            .lineLimit(3)
                                            .frame(width: 200, alignment: .leading)
                                            .padding(10)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(Color.orange.opacity(0.08))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }
                }
            }
        }
    }

    private var sampleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("generator.sample_section")
                .font(.headline)
                .padding(.top, 4)
            ForEach(samples.prefix(5)) { sample in
                Button {
                    viewModel.loadSample(sample, locale: locale)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sample.situation(for: locale))
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.primary)
                            if let style = StyleCatalog.shared.style(id: sample.styleId) {
                                Text(style.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle")
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
