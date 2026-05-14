import SwiftUI

/// SwiftUI surface inside the Share Extension. Lets the user pick a
/// style, generate a single roast, and copy. Runs in the extension
/// process — limited memory budget — so we cap to 1 variant.
struct ShareRootView: View {
    let sharedText: String
    let onDone: () -> Void
    let onCancel: () -> Void

    @State private var selectedStyleId: String = StyleCatalog.shared.defaultStyleId
    @State private var output: String? = nil
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var mode: RoastMode = .reply
    @State private var copied = false

    private var styles: [StylePreset] { StyleCatalog.shared.byTier(.free) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    sharedInputCard
                    modePicker
                    styleRow
                    generateButton
                    if let output {
                        outputCard(output)
                    }
                    if let error {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
                .padding()
            }
            .navigationTitle("share.title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done", action: onDone)
                }
            }
        }
    }

    private var sharedInputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("share.shared_input")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(sharedText.isEmpty ? String(localized: "share.empty_input") : sharedText)
                .font(.callout)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.10)))
        }
    }

    private var modePicker: some View {
        Picker("share.mode", selection: $mode) {
            Text("feature.reply.title").tag(RoastMode.reply)
            Text("feature.translator.title").tag(RoastMode.translate)
            Text("feature.social.title").tag(RoastMode.social)
        }
        .pickerStyle(.segmented)
    }

    private var styleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(styles) { style in
                    StyleChipShare(
                        style: style,
                        isSelected: selectedStyleId == style.id
                    ) {
                        selectedStyleId = style.id
                    }
                }
            }
        }
    }

    private var generateButton: some View {
        Button {
            Task { await generate() }
        } label: {
            HStack {
                if isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "flame.fill")
                }
                Text("generator.generate")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isLoading || sharedText.isEmpty)
    }

    private func outputCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                Button {
                    UIPasteboard.general.string = text
                    copied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        copied = false
                    }
                } label: {
                    Label(copied ? "result.copied" : "result.copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.08)))
    }

    private func generate() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        output = nil
        guard let style = StyleCatalog.shared.style(id: selectedStyleId) else {
            error = String(localized: "error.generic")
            return
        }
        do {
            let variants = try await RoastEngine.shared.generate(
                situation: sharedText,
                style: style,
                locale: Locale.current,
                variantCount: 1,
                mode: mode
            )
            output = variants.first
        } catch let err as RoastError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Minimal style chip duplicated for the extension to avoid pulling
/// in the iOS app's full Views/Components tree. The extension target
/// only compiles Shared + RoastMateShare/Sources.
private struct StyleChipShare: View {
    let style: StylePreset
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: style.icon)
                Text(style.displayName)
                    .font(.footnote.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.12))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? Color.orange : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
