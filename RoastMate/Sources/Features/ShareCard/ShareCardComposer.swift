import SwiftUI

/// The share-as-image sheet. Renders ONLY the sendable line — the polished
/// comeback the user could actually send.
///
/// The private vent draft is deliberately unreachable from here. There is no
/// opt-in, no redaction preview, and no editable field: the rendered text is
/// **immutable**, so the only way to change what appears on the card is to
/// edit the draft and re-generate, which re-runs `SafetyFilter`. That keeps a
/// branded RoastMate image from ever carrying either the user's private vent
/// or arbitrary free-typed text.
struct ShareCardComposer: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    /// The polished, sendable line. Already `SafetyFilter`-validated at
    /// generation time (`RoastEngine`), and not user-editable here.
    private let sentText: String
    private let styleName: String?
    /// The kind `sentText` came from. Required, and checked below: the type
    /// system stops a vent being rendered ALONGSIDE a sendable (there is no
    /// vent field), but nothing stopped a caller passing a vent draft AS the
    /// sendable. Same fail-open shape we removed from `RoastCard.kind`, so it
    /// gets the same treatment.
    private let kind: GeneratedRoastKind

    @State private var format: ShareCardFormat = .portrait45
    @State private var exportURL: URL?
    /// A.1. Composer-local on purpose: NOT persisted onto `GeneratedRoast`.
    /// Adding a stored property to a CloudKit-mirrored SwiftData model is a
    /// migration risk for every existing user, and the choice is only meaningful
    /// while this sheet is open. Starts `nil` — the card renders exactly as it
    /// does today until the user deliberately picks a setup.
    @State private var selectedScenario: ShareCardScenario?
    /// Counted once per presentation, not per re-render — switching the format
    /// picker re-renders the card and would otherwise inflate the denominator
    /// of the generated-vs-shared ratio B.8 exists to measure.
    @State private var didCountGeneration = false

    init(sentText: String, styleName: String?, kind: GeneratedRoastKind) {
        self.sentText = sentText
        self.styleName = styleName
        self.kind = kind
    }

    /// Only sendable output may be rendered onto a shareable image.
    /// Single source of truth: `GeneratedRoastKind.isShareable`.
    private var isShareable: Bool { kind.isShareable }

    /// B.2 defense-in-depth, applied in this order and no other:
    ///   1. `Redactor.redactForPublicShare` — structured PII + CJK contact
    ///      forms + an on-device NER pass.
    ///   2. `SafetyFilter.validateOutput` (the STRICT validator) runs LAST,
    ///      immediately before render. A public share is a stricter register
    ///      than a private draft, so a failure BLOCKS the export rather than
    ///      falling back to raw text.
    ///
    /// `nil` means "do not render" — the composer shows the block notice
    /// instead of a card. There is deliberately no path that renders
    /// unredacted or unvalidated text.
    private var safeText: String? {
        let redacted = Redactor.redactForPublicShare(sentText, locale: locale)
        return try? SafetyFilter.validateOutput(redacted)
    }

    /// A.1. The setup line is a LOCALIZED CONSTANT chosen from a closed catalog
    /// by the user — never model output and never free text — so it cannot carry
    /// PII onto the canvas. See `ShareCardScenario` for why that is the design.
    ///
    /// It still runs the same Redactor + strict SafetyFilter pass as `sentText`.
    /// That is belt-and-braces on an authored constant and should always pass;
    /// the point is that the rule has ONE home, so a future change to the
    /// catalog cannot quietly bypass the gate. Failure here degrades the setup
    /// line to `nil` — it must never block a card whose comeback is fine, which
    /// is why this is separate from `safeText`'s all-or-nothing gate.
    private var safeSetupText: String? {
        guard setupEnabled, let scenario = selectedScenario else { return nil }
        let raw = AppLocalization.string(scenario.displayKey)
        let redacted = Redactor.redactForPublicShare(raw, locale: locale)
        return try? SafetyFilter.validateOutput(redacted)
    }

    private var setupEnabled: Bool { RemoteConfigValues.cached().shareCardSetupEnabled }

    private var content: ShareCardContent? {
        guard let safeText else { return nil }
        return ShareCardContent(styleName: styleName,
                                sentText: safeText,
                                setupText: safeSetupText,
                                showsGrowthBadge: RemoteConfigValues.cached().shareCardEnabled)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    preview
                    formatPicker
                    setupPicker
                    privacyNote
                }
                .padding()
            }
            .navigationTitle(AppLocalization.string("sharecard.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("sharecard.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if content == nil {
                        // Safety gate refused the line — no share affordance at
                        // all, rather than a spinner that never resolves.
                        EmptyView()
                    } else if let url = exportURL {
                        // OutputShareButton fires recordOutputShareTap +
                        // notifySuccessfulShare ONLY on confirmed
                        // completion (iOS) — was previously tap-only, so
                        // a cancelled share still bumped both counters
                        // and triggered the rating prompt. v1.0.5 upgrade
                        // per Codex/Gemini audit 2026-05-28.
                        OutputShareButton(
                            item: url,
                            onConfirmedShare: {
                                EventLedger.shared.recordShareCardShared()
                                RatingPromptService.shared.notifySuccessfulShare()
                            }
                        ) {
                            Label("sharecard.share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .task(id: renderKey) { await render() }
        .opacity(isShareable ? 1 : 0)
    }

    /// Everything the exported PNG depends on. The setup selection MUST be in
    /// here: `.task(id:)` only re-fires when this changes, so omitting it would
    /// leave the preview showing a new chip while the exported file silently
    /// kept the old one — a wrong artifact rather than a missing one.
    private var renderKey: String {
        "\(format.rawValue)|\(safeText?.hashValue ?? 0)|\(selectedScenario?.rawValue ?? "-")"
    }

    @ViewBuilder
    private var preview: some View {
        if let content {
            GeometryReader { geo in
                let scale = geo.size.width / format.pixelSize.width
                ShareCardView(content: content, pixelSize: format.pixelSize)
                    .frame(width: format.pixelSize.width, height: format.pixelSize.height)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: geo.size.width,
                           height: format.pixelSize.height * scale)
            }
            .frame(height: format == .portrait45 ? 360 : 480)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            blockedNotice
        }
    }

    /// Shown when the safety gate refuses the line. Rare by construction —
    /// `sentText` already passed `validateOutput` at generation — but the
    /// redaction pass can change the text, so it is re-validated here and the
    /// result has to be honoured.
    private var blockedNotice: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("sharecard.blocked")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(0.08))
        )
    }

    /// B.9. The card is the one place the app asks a privacy-anxious user to
    /// produce something public, so it should say plainly what is and is not
    /// happening — on the screen where the worry actually occurs, not buried in
    /// Settings.
    private var privacyNote: some View {
        Label("sharecard.privacy_note", systemImage: "lock.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// A.1. A closed catalog of taps — no keyboard, no text field, no "other".
    ///
    /// This is the deliberate difference from the editable field v1.3.1 removed.
    /// Selecting a case from a fixed enum cannot put user-typed bytes onto a
    /// branded image, so the property that made the purge necessary is
    /// preserved. And because several of these describe conduct — credit taken,
    /// blame shifted, a promise broken — the person who knows what actually
    /// happened is the one asserting it, not a classifier that guessed.
    ///
    /// Default is NO setup. The card a user gets without touching this is
    /// exactly today's shipped card.
    @ViewBuilder
    private var setupPicker: some View {
        if setupEnabled {
            VStack(alignment: .leading, spacing: 8) {
                Text("sharecard.setup_picker_title")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip(title: AppLocalization.string("sharecard.setup_none"),
                             isSelected: selectedScenario == nil) {
                            selectedScenario = nil
                        }
                        ForEach(ShareCardScenario.ordered) { scenario in
                            chip(title: AppLocalization.string(scenario.displayKey),
                                 isSelected: selectedScenario == scenario) {
                                // Tapping the active chip clears it, so removing a
                                // setup is always one tap and never a hunt for the
                                // "none" chip after scrolling.
                                selectedScenario = (selectedScenario == scenario) ? nil : scenario
                            }
                            .accessibilityIdentifier("sharecard.scenario.\(scenario.rawValue)")
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.callout)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected
                                   ? Color.accentColor.opacity(0.22)
                                   : Color.secondary.opacity(0.12))
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var formatPicker: some View {
        Picker("sharecard.format_label", selection: $format) {
            ForEach(ShareCardFormat.allCases) { f in
                Text(f.labelKey).tag(f)
            }
        }
        .pickerStyle(.segmented)
    }

    @MainActor
    private func render() async {
        guard isShareable else {
            // Loud in debug, inert in production — never a silent leak.
            assertionFailure("ShareCardComposer got a non-sendable kind: \(kind)")
            exportURL = nil
            return
        }
        guard let content else {
            // Safety gate refused post-redaction. No card, no fallback.
            exportURL = nil
            if !didCountGeneration {
                didCountGeneration = true
                EventLedger.shared.recordShareCardBlocked()
            }
            return
        }
        exportURL = ShareCardRenderer.renderPNG(content, format: format, locale: locale)
        if exportURL != nil, !didCountGeneration {
            didCountGeneration = true
            EventLedger.shared.recordShareCardGenerated()
        }
    }
}
