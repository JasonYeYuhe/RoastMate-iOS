import SwiftUI

/// The share-as-image sheet. Enforces the locked privacy model: the
/// vent ("before") side is obscured by default; including the real
/// text requires an explicit, warned opt-in, after which the text is
/// locally PII-redacted and remains user-editable, with a live preview
/// before anything leaves the app.
struct ShareCardComposer: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    /// The polished line + optional source vent (the raw draft text).
    private let sentText: String
    private let styleName: String?
    private let sourceVent: String?

    @State private var format: ShareCardFormat = .portrait45
    @State private var includeVent = false
    @State private var showVentWarning = false
    @State private var editableVent = ""
    @State private var exportURL: URL?
    @State private var rendering = false

    init(sentText: String, styleName: String?, sourceVent: String?) {
        self.sentText = sentText
        self.styleName = styleName
        self.sourceVent = sourceVent?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasVent: Bool { !(sourceVent ?? "").isEmpty }

    private var content: ShareCardContent {
        ShareCardContent(
            styleName: styleName,
            sentText: sentText,
            ventText: hasVent ? (includeVent ? editableVent : sourceVent) : nil,
            revealVent: includeVent
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    preview
                    formatPicker
                    if hasVent { ventControls }
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
                        ShareLink(item: url) {
                            Label("sharecard.share", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        ProgressView()
                    }
                }
            }
        }
        .task(id: renderKey) { await render() }
        .alert("sharecard.warn.title", isPresented: $showVentWarning) {
            Button("sharecard.warn.cancel", role: .cancel) { includeVent = false }
            Button("sharecard.warn.confirm", role: .destructive) {
                editableVent = Redactor.redact(sourceVent ?? "")
                includeVent = true
            }
        } message: {
            Text("sharecard.warn.body")
        }
    }

    private var renderKey: String {
        "\(format.rawValue)|\(includeVent)|\(editableVent.hashValue)"
    }

    private var preview: some View {
        GeometryReader { geo in
            let scale = geo.size.width / content.cardPixelWidth(format)
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

    private var ventControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("sharecard.include_vent", isOn: Binding(
                get: { includeVent },
                set: { newValue in
                    if newValue { showVentWarning = true }
                    else { includeVent = false }
                }
            ))
            Text("sharecard.include_vent.hint")
                .font(.caption)
                .foregroundStyle(.secondary)

            if includeVent {
                Text("sharecard.edit_label")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextEditor(text: $editableVent)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.secondary.opacity(0.08))
                    )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pink.opacity(0.07))
        )
    }

    @MainActor
    private func render() async {
        rendering = true
        exportURL = ShareCardRenderer.renderPNG(content, format: format, locale: locale)
        rendering = false
    }
}

private extension ShareCardContent {
    func cardPixelWidth(_ format: ShareCardFormat) -> CGFloat {
        format.pixelSize.width
    }
}
