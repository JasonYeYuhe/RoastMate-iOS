import SwiftUI
import SwiftData

/// Read-mostly view of a SituationThread — the chain of rounds the user
/// has had about the same underlying event. Tapping "Continue this event"
/// stages a continuation into ThreadContinuationStore and switches the
/// user back to the Generator tab.
struct ThreadDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let thread: SituationThread

    /// Set by the parent tab container; tapping Continue flips this back
    /// to the Generator tab. Optional so this view also works pushed onto
    /// non-tab nav stacks (e.g. macOS / tests).
    var onContinue: (() -> Void)? = nil

    @State private var editingTitle = false
    @State private var draftTitle = ""

    private var orderedSessions: [RoastSession] {
        thread.sessions.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                titleHeader
                metaRow

                if !thread.originalSituation.isEmpty {
                    Text("thread.original_situation")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(thread.originalSituation)
                        .font(.body)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.08))
                        )
                }

                ForEach(Array(orderedSessions.enumerated()), id: \.element.id) { index, session in
                    roundCard(session: session, roundNumber: index + 1)
                }

                continueButton
                Spacer(minLength: 8)
            }
            .padding()
        }
        .navigationTitle(thread.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(thread.isResolved
                            ? "thread.mark_unresolved"
                            : "thread.mark_resolved") {
                        ThreadService.markResolved(thread, resolved: !thread.isResolved, context: context)
                    }
                    Button("thread.rename") {
                        draftTitle = thread.title
                        editingTitle = true
                    }
                    Button(thread.isFavorite
                            ? "thread.unfavorite"
                            : "thread.favorite") {
                        thread.isFavorite.toggle()
                        thread.updatedAt = Date()
                        try? context.save()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("thread.rename", isPresented: $editingTitle) {
            TextField("thread.untitled", text: $draftTitle)
            Button("common.save") {
                let trimmed = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    thread.title = trimmed
                    thread.updatedAt = Date()
                    try? context.save()
                }
            }
            Button("common.cancel", role: .cancel) { }
        }
    }

    private var titleHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(thread.title)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
            if thread.isFavorite {
                Image(systemName: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(.yellow)
            }
            if thread.isResolved {
                Text("thread.badge.resolved")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.18)))
                    .foregroundStyle(.green)
            }
            Spacer()
        }
    }

    private var metaRow: some View {
        HStack(spacing: 8) {
            Label(thread.category.displayName, systemImage: "folder")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let mood = thread.mood {
                Label(mood.displayName, systemImage: "face.smiling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(thread.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func roundCard(session: RoastSession, roundNumber: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(format: String(localized: "thread.round.number"), roundNumber))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
                    .foregroundStyle(.orange)
                if let style = StyleCatalog.shared.style(id: session.styleId) {
                    Text(style.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(session.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Show subsequent rounds' situation only — round 1's situation
            // is already in the "original_situation" header above.
            if roundNumber > 1, !session.situation.isEmpty {
                Text(session.situation)
                    .font(.callout)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.06))
                    )
            }

            ForEach(session.results.sorted { $0.generatedAt < $1.generatedAt }, id: \.id) { result in
                Text(result.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(result.kind == .ventDraft
                                  ? Color.orange.opacity(0.08)
                                  : Color.blue.opacity(0.06))
                    )
            }
        }
        .padding(.vertical, 6)
    }

    private var continueButton: some View {
        Button {
            ThreadContinuationStore.shared.stage(
                thread: thread,
                suggestedStyleId: orderedSessions.last?.styleId
            )
            onContinue?()
            dismiss()
        } label: {
            Label("thread.continue.button", systemImage: "arrow.turn.up.right")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }
}
