import SwiftUI

struct RoastCard: View {
    let text: String
    let style: StylePreset?
    /// The kind of result being shown, when the caller knows it. A
    /// `.ventDraft` is a private draft and gets no share affordance
    /// (v1.3.1); `nil` means "caller didn't say", treated as sendable to
    /// keep existing sendable-only call sites unchanged.
    var kind: GeneratedRoastKind? = nil

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
                    EventLedger.shared.recordOutputCopied()  // P5 Tier-1
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

                if kind != .ventDraft {
                    OutputShareButton(item: text) {
                        Label("result.share", systemImage: "square.and.arrow.up")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
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

    @Environment(\.modelContext) private var modelContext
    @State private var copied = false
    @State private var showShareCard = false

    /// Only sendable kinds (`.normalRoast` + `.sendableReply`) get the
    /// star toggle. Private drafts are framed as ephemeral catharsis;
    /// saving them across sessions would conflict with the "for yourself
    /// only, then move on" copy. Rewrites are a transient kind we don't
    /// surface separately.
    private var canBeSaved: Bool {
        switch result.kind {
        case .normalRoast, .sendableReply: return true
        case .ventDraft, .rewrite: return false
        }
    }

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
                    EventLedger.shared.recordOutputCopied()  // P5 Tier-1
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

                // Share (system share sheet) — sendable kinds ONLY. A
                // `.ventDraft` is a private draft the UI explicitly labels
                // "don't send"; offering one-tap egress directly beneath that
                // label contradicted it. Copy stays: it is a local action the
                // user drives, not an outbound share. (v1.3.1)
                if result.kind != .ventDraft {
                    OutputShareButton(item: result.text) {
                        Label("result.share", systemImage: "square.and.arrow.up")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                // Share as image — sendable kinds only; the private vent
                // draft itself is never offered as a shareable card.
                if result.kind == .normalRoast || result.kind == .sendableReply {
                    Button {
                        showShareCard = true
                    } label: {
                        Label("sharecard.button", systemImage: "photo.on.rectangle.angled")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

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

                Spacer()

                if canBeSaved {
                    Button {
                        toggleFavorite()
                    } label: {
                        Image(systemName: result.isFavorite ? "star.fill" : "star")
                            .font(.callout)
                            .foregroundStyle(result.isFavorite ? Color.yellow : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(result.isFavorite
                                        ? String(localized: "result.unfavorite")
                                        : String(localized: "result.favorite"))
                }
            }
            FeedbackBar()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
        .sheet(isPresented: $showShareCard) {
            ShareCardComposer(
                sentText: result.text,
                styleName: style?.displayName
            )
        }
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

    private func toggleFavorite() {
        result.isFavorite.toggle()
        Haptics.play(.selection)
        try? modelContext.save()
    }
}

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

/// ε2 (Phase 3 W1, ships in v1.0.2): tiny 👍 / 👎 row beneath each
/// generation card. 👎 opens a confirmation dialog with 8 tag categories.
/// Stored as A′ schema-v2 counters; **no raw text is ever logged**.
///
/// Submission state is per-view-instance only (resets when the card view
/// recycles). At low N=5-20 the over-count risk from a user re-rating an
/// older card after navigating away is bounded; persistent dedup is
/// deferred to W2's α3 if A′ shows it actually inflates signal.
struct FeedbackBar: View {
    @State private var submitted = false
    @State private var showTagDialog = false

    var body: some View {
        Group {
            if submitted {
                HStack {
                    Spacer()
                    Label("feedback.thanks", systemImage: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 18) {
                    Spacer()
                    Button {
                        EventLedger.shared.recordFeedbackUp()
                        Haptics.play(.selection)
                        submitted = true
                    } label: {
                        Image(systemName: "hand.thumbsup")
                            .font(.callout)
                    }
                    .accessibilityLabel(Text("feedback.up.accessibility"))

                    Button {
                        showTagDialog = true
                    } label: {
                        Image(systemName: "hand.thumbsdown")
                            .font(.callout)
                    }
                    .accessibilityLabel(Text("feedback.down.accessibility"))
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundStyle(.secondary)
                .confirmationDialog(
                    Text("feedback.tag.title"),
                    isPresented: $showTagDialog,
                    titleVisibility: .visible
                ) {
                    Button("feedback.tag.wrong_tone")        { submit(.wrongTone) }
                    Button("feedback.tag.too_soft")          { submit(.tooSoft) }
                    Button("feedback.tag.too_harsh")         { submit(.tooHarsh) }
                    Button("feedback.tag.wrong_language")    { submit(.wrongLanguage) }
                    Button("feedback.tag.wrong_style")       { submit(.wrongStyle) }
                    Button("feedback.tag.didnt_address")     { submit(.didntAddress) }
                    Button("feedback.tag.factually_wrong")   { submit(.factuallyWrong) }
                    Button("feedback.tag.other")             { submit(.other) }
                    Button("feedback.tag.cancel", role: .cancel) { /* abort, no record */ }
                }
            }
        }
        .padding(.top, 2)
    }

    private func submit(_ tag: EventLedger.FeedbackTag) {
        EventLedger.shared.recordFeedbackDown()
        EventLedger.shared.recordFeedbackTag(tag)
        Haptics.play(.selection)
        submitted = true
    }
}
