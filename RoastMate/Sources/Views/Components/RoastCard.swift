import SwiftUI

struct RoastCard: View {
    let text: String
    let style: StylePreset?

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let style {
                Label(style.displayName, systemImage: style.icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                Button {
                    copyToPasteboard(text)
                    copied = true
                    Haptics.play(.selection)
                    Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        copied = false
                    }
                } label: {
                    Label(copied ? "result.copied" : "result.copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                ShareLink(item: text) {
                    Label("result.share", systemImage: "square.and.arrow.up")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

struct GeneratedRoastCard: View {
    let result: GeneratedRoast
    let style: StylePreset?
    let isRewriting: Bool
    let hasSendableReply: Bool
    let onRewrite: (() -> Void)?

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let style {
                    Label(style.displayName, systemImage: style.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if result.kind != .normalRoast {
                    Text(kindLabel)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(kindColor.opacity(0.14)))
                        .foregroundStyle(kindColor)
                }
            }

            if result.kind == .ventDraft {
                Label(disclosureKey, systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(privateDraftAccent)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(privateDraftAccent.opacity(0.10))
                    )
            }

            Text(result.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                Button {
                    copyToPasteboard(result.text)
                    copied = true
                    Haptics.play(.selection)
                    Task {
                        try? await Task.sleep(nanoseconds: 1_400_000_000)
                        copied = false
                    }
                } label: {
                    Label(copied ? "result.copied" : "result.copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                ShareLink(item: result.text) {
                    Label("result.share", systemImage: "square.and.arrow.up")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if result.kind == .ventDraft, !hasSendableReply, let onRewrite {
                    Button {
                        onRewrite()
                    } label: {
                        if isRewriting {
                            Label("output.rewrite.in_progress", systemImage: "hourglass")
                                .font(.callout)
                        } else {
                            Label("output.rewrite.button", systemImage: "wand.and.stars")
                                .font(.callout)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isRewriting)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
    }

    private var kindLabel: LocalizedStringKey {
        switch result.kind {
        case .ventDraft:
            return result.sourceIntensity == .feral
                ? "output.kind.feral_draft.label"
                : "output.kind.vent_draft.label"
        case .sendableReply:
            return "output.kind.sendable_reply.label"
        case .normalRoast, .rewrite:
            return ""
        }
    }

    private var disclosureKey: LocalizedStringKey {
        result.sourceIntensity == .feral
            ? "output.feral.disclosure"
            : "output.vent.disclosure"
    }

    /// Color used for both the kind chip and the disclosure ribbon on a
    /// private draft. Feral runs hotter (pink/red-ish) than vent (orange)
    /// so a glance at History tells you which intensity you used.
    private var privateDraftAccent: Color {
        result.sourceIntensity == .feral ? .pink : .orange
    }

    private var kindColor: Color {
        switch result.kind {
        case .ventDraft:
            return privateDraftAccent
        case .sendableReply:
            return .green
        case .normalRoast, .rewrite:
            return .secondary
        }
    }

    private var backgroundColor: Color {
        switch result.kind {
        case .ventDraft:
            return privateDraftAccent.opacity(0.08)
        case .sendableReply:
            return Color.green.opacity(0.08)
        case .normalRoast, .rewrite:
            return Color.secondary.opacity(0.08)
        }
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
