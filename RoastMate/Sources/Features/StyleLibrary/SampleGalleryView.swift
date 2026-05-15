import SwiftUI

/// Dedicated screen showing every bundled sample. Lets App Store reviewers
/// (and new users) browse the full feature surface without typing.
struct SampleGalleryView: View {
    @Environment(\.locale) private var locale
    @State private var selectedSample: SampleRoast?

    private var samples: [SampleRoast] { SampleRoastsCatalog.shared.all }

    var body: some View {
        List {
            Section {
                ForEach(samples) { sample in
                    Button {
                        selectedSample = sample
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if sample.isVentDemo {
                                    Text("sample.badge.vent_demo")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.orange.opacity(0.18)))
                                        .foregroundStyle(.orange)
                                } else {
                                    Text("sample.badge.standard")
                                        .font(.caption2.weight(.bold))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                                        .foregroundStyle(.blue)
                                }
                                if let style = StyleCatalog.shared.style(id: sample.styleId) {
                                    Text(style.displayName)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            Text(sample.situation(for: locale))
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("explore.samples.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(AppLocalization.string("explore.samples.section"))
        .sheet(item: $selectedSample) { sample in
            SampleDetailSheet(sample: sample)
        }
    }
}

private struct SampleDetailSheet: View {
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let sample: SampleRoast

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    if let style = StyleCatalog.shared.style(id: sample.styleId) {
                        Label(style.displayName, systemImage: style.icon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Text(sample.situation(for: locale))
                    .font(.headline)

                Divider()

                if let vent = sample.ventResponse, let sendable = sample.sendableResponse {
                    ventDemoBody(vent: vent, sendable: sendable)
                } else {
                    Text(sample.response)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 320, minHeight: 320)
    }

    @ViewBuilder
    private func ventDemoBody(vent: String, sendable: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("output.kind.vent_draft.label", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text(vent)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.08))
                )
            Text("output.vent.disclosure")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }

        VStack(alignment: .leading, spacing: 8) {
            Label("output.kind.sendable_reply.label", systemImage: "paperplane.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
            Text(sendable)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.blue.opacity(0.08))
                )
        }
    }
}
