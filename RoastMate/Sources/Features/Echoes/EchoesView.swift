import SwiftUI
import SwiftData

/// Echoes / 替你出气 — chat-style transcript of synthetic voices backing
/// the user up about a grievance. Two phases: setup → transcript reveal.
/// Pro-gated; first-1 free per `UserSettings` (TODO post-Q1 research:
/// switch to Pro-only-day-1 if conversion data supports).
///
/// Bridge-to-Action: the final message's tappable CTA stages the
/// situation + suggested intensity on `EchoBridgeStore` and asks the
/// caller (RootView) to switch to the Generator tab. The caller wires
/// the tab-switch via the `onBridgeTap` closure.
struct EchoesView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query private var settingsQuery: [UserSettings]

    @State private var viewModel = EchoesViewModel()

    // Sheet presentation is owned by the VM (`viewModel.activeSheet`) so
    // there's no `.onChange` mirror race — see EchoesViewModel.ActiveSheet.
    // A SINGLE `.sheet(item:)` drives both modals (paywall + feralConsent);
    // two stacked `.sheet(isPresented:)` silently drop the second.

    /// Called when the bridge CTA is tapped. RootView typically sets
    /// `selectedTab = .generator` in response.
    var onBridgeTap: () -> Void

    private var settings: UserSettings? { settingsQuery.first }
    private var isPro: Bool { StoreService.shared.isPro }
    private var feralConsent: CloudConsent { settings?.echoesFeralConsent ?? .notAsked }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("echoes.title")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {  // cross-platform (.topBarTrailing is iOS-only)
                        if case .done = viewModel.phase {
                            Button("echoes.action.new") {
                                viewModel.reset()
                            }
                        }
                    }
                }
        }
        .onAppear {
            viewModel.startSession()
            if !isPro {
                EventLedger.shared.recordEchoesPaywallHit()
                EventLedger.shared.recordPaywallImpression(source: .proTap)
                viewModel.activeSheet = .paywall
            }
        }
        .sheet(item: $viewModel.activeSheet) { sheet in
            switch sheet {
            case .paywall:
                PaywallView(isPresented: Binding(
                    get: { viewModel.activeSheet == .paywall },
                    set: { if !$0 { viewModel.activeSheet = nil } }
                ))
            case .feralConsent:
                EchoesFeralConsentSheet { choice in
                    guard let settings else { return }
                    settings.echoesFeralConsent = choice
                    try? context.save()
                    if choice == .granted {
                        Task {
                            await viewModel.generate(
                                locale: locale,
                                currentFeralConsent: .granted,
                                cloudConfigured: CloudConfig.isConfigured,
                                modelContext: context,
                                isPro: isPro
                            )
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .setup:
            setupView
        case .generating:
            ProgressView("echoes.generating")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .revealing, .done:
            transcriptView
        case .error(let msg):
            VStack(spacing: 16) {
                Text(msg)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("echoes.action.back") {
                    viewModel.reset()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    // MARK: - Setup

    private var setupView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("echoes.setup.intro")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("echoes.setup.situation_label")
                    .font(.headline)
                TextEditor(text: $viewModel.situation)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                    .accessibilityIdentifier("echoes.situation")

                Text("echoes.setup.tone_label").font(.headline)
                Picker("echoes.setup.tone_label", selection: $viewModel.tone) {
                    Text("echoes.tone.casual").tag(EchoTone.casual)
                    Text("echoes.tone.feral").tag(EchoTone.feral)
                }
                .pickerStyle(.segmented)
                Text(viewModel.tone == .feral ? "echoes.tone.feral.blurb" : "echoes.tone.casual.blurb")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("echoes.setup.voice_count_label").font(.headline)
                Picker("echoes.setup.voice_count_label", selection: $viewModel.voiceCount) {
                    Text("echoes.voice_count.1").tag(EchoVoiceCount.one)
                    Text("echoes.voice_count.2").tag(EchoVoiceCount.two)
                }
                .pickerStyle(.segmented)

                Text("echoes.setup.privacy_banner")
                    .font(.caption)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.08))
                    )

                Button {
                    Task {
                        await viewModel.generate(
                            locale: locale,
                            currentFeralConsent: feralConsent,
                            cloudConfigured: CloudConfig.isConfigured,
                            modelContext: context,
                            isPro: isPro
                        )
                    }
                } label: {
                    Text("echoes.action.generate")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("echoes.generate")
                .disabled(viewModel.situation.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 || !isPro)
            }
            .padding(16)
        }
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        VStack(spacing: 0) {
            // Persistent synthetic-voices banner — required for the
            // App Review 4.0 mitigation (v2 plan §6).
            Text("echoes.transcript.banner")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.05))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.visibleMessages) { msg in
                        EchoBubble(
                            message: msg,
                            handle: echoes()?[safe: msg.echoIndex]?.handle ?? "Echo",
                            colorHex: echoes()?[safe: msg.echoIndex]?.colorHex ?? "#FF9500",
                            onBridgeTap: msg.role == .bridge ? {
                                viewModel.tapBridge(message: msg)
                                onBridgeTap()
                            } : nil
                        )
                    }
                }
                .padding(16)
            }

            if case .done = viewModel.phase {
                actionBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }

    private func echoes() -> [EchoSpec]? {
        switch viewModel.phase {
        case .revealing(let t), .done(let t):
            return t.echoes
        default:
            return nil
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if !viewModel.hasRegenerated {
                Button {
                    Task {
                        await viewModel.regenerate(
                            locale: locale,
                            currentFeralConsent: feralConsent,
                            cloudConfigured: CloudConfig.isConfigured,
                            modelContext: context,
                            isPro: isPro
                        )
                    }
                } label: {
                    Label("echoes.action.regenerate", systemImage: "arrow.clockwise")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
            Spacer()
            Button {
                viewModel.reset()
            } label: {
                Label("echoes.action.new", systemImage: "square.and.pencil")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// Single chat-style bubble. Bridge bubble shows the tappable CTA arrow.
private struct EchoBubble: View {
    let message: EchoMessage
    let handle: String
    let colorHex: String
    let onBridgeTap: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(handle)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Group {
                if let onBridgeTap {
                    Button(action: onBridgeTap) {
                        bubbleText
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("echoes.bridge")
                } else {
                    bubbleText
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bubbleText: some View {
        Text(message.text)
            .font(.body)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(bubbleColor.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(bubbleColor.opacity(0.30), lineWidth: 0.5)
            )
            .foregroundStyle(.primary)
    }

    private var bubbleColor: Color {
        Color(hex: colorHex) ?? .orange
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >>  8) & 0xFF) / 255.0
        let b = Double( v        & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
