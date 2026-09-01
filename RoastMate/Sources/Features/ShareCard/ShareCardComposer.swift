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

    init(sentText: String, styleName: String?, kind: GeneratedRoastKind) {
        self.sentText = sentText
        self.styleName = styleName
        self.kind = kind
    }

    /// Only sendable output may be rendered onto a shareable image.
    /// Single source of truth: `GeneratedRoastKind.isShareable`.
    private var isShareable: Bool { kind.isShareable }

    private var content: ShareCardContent {
        ShareCardContent(styleName: styleName, sentText: sentText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    preview
                    formatPicker
                }
                .padding()
            }
            .navigationTitle(AppLocalization.string("sharecard.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("sharecard.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if let url = exportURL {
                        // OutputShareButton fires recordOutputShareTap +
                        // notifySuccessfulShare ONLY on confirmed
                        // completion (iOS) — was previously tap-only, so
                        // a cancelled share still bumped both counters
                        // and triggered the rating prompt. v1.0.5 upgrade
                        // per Codex/Gemini audit 2026-05-28.
                        OutputShareButton(
                            item: url,
                            onConfirmedShare: {
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

    private var renderKey: String { format.rawValue }

    private var preview: some View {
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
        exportURL = ShareCardRenderer.renderPNG(content, format: format, locale: locale)
    }
}
