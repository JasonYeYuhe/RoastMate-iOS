import SwiftUI
import SwiftData

/// Standalone-session detail screen. Renders each `GeneratedRoast` row
/// and — crucially for v1.4 — exposes "Make it sendable" on any unpaired
/// private draft so the user can come back to a vent / feral draft from
/// History and rewrite it later. The rewrite reuses the same engine path
/// and `appendSendableReply` persistence used by the live Generator,
/// so the new sendable lands on this same session (no new session is
/// created from a historical rewrite).
struct HistorySessionDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    let session: RoastSession
    let onContinue: () -> Void

    @State private var rewritingDraftId: UUID?
    @State private var rewriteError: String?

    private var orderedResults: [GeneratedRoast] {
        (session.results ?? []).sorted { $0.generatedAt < $1.generatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.situation)
                    .font(.body)
                    .padding(.bottom)

                ForEach(orderedResults, id: \.id) { result in
                    GeneratedRoastCard(
                        result: result,
                        style: StyleCatalog.shared.style(id: result.styleId),
                        isRewriting: rewritingDraftId == result.id,
                        hasSendableReply: hasSendableReply(for: result),
                        pairedVentText: ShareCardPairing.ventText(for: result, in: orderedResults),
                        onRewrite: result.kind == .ventDraft && !hasSendableReply(for: result)
                            ? { triggerRewrite(draft: result) }
                            : nil
                    )
                }

                if let rewriteError {
                    Text(rewriteError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                }

                Button(action: onContinue) {
                    Label("thread.continue.button", systemImage: "arrow.turn.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle(StyleCatalog.shared.style(id: session.styleId)?.displayName ?? "")
    }

    private func hasSendableReply(for result: GeneratedRoast) -> Bool {
        guard result.kind == .ventDraft else { return false }
        return orderedResults.contains {
            $0.kind == .sendableReply && $0.sourceVentDraftId == result.id
        }
    }

    private func triggerRewrite(draft: GeneratedRoast) {
        guard rewritingDraftId == nil else { return }
        rewritingDraftId = draft.id
        rewriteError = nil
        Task {
            defer { rewritingDraftId = nil }
            do {
                _ = try await RewriteCoordinator.rewriteAsSendable(
                    draft: draft,
                    session: session,
                    context: context,
                    locale: locale
                )
                Haptics.play(.generated)
            } catch let err as RoastError {
                rewriteError = err.errorDescription
                Haptics.play(.error)
            } catch {
                rewriteError = String(localized: "rewrite.fallback.unavailable")
                Haptics.play(.error)
            }
        }
    }
}
