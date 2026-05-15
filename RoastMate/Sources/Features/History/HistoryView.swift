import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @Query(sort: [SortDescriptor(\RoastSession.createdAt, order: .reverse)])
    private var sessions: [RoastSession]
    @Query(sort: [SortDescriptor(\SituationThread.updatedAt, order: .reverse)])
    private var threads: [SituationThread]

    /// Optional hook so the parent (RootView) can switch tabs back to the
    /// Generator when "Continue this event" is tapped from a thread.
    var onContinueGenerator: (() -> Void)? = nil

    /// Sessions not yet attached to a thread — shown in the "Recent rounds"
    /// section below the Threads section.
    private var standaloneSessions: [RoastSession] {
        sessions.filter { $0.thread == nil }
    }

    private var activeThreads: [SituationThread] {
        threads.filter { !$0.isResolved }
    }

    private var resolvedThreads: [SituationThread] {
        threads.filter { $0.isResolved }
    }

    var body: some View {
        Group {
            if sessions.isEmpty && threads.isEmpty {
                ContentUnavailableView {
                    Label("history.empty.title", systemImage: "clock")
                } description: {
                    Text("history.empty.subtitle")
                }
            } else {
                List {
                    if !activeThreads.isEmpty {
                        Section("thread.section.unresolved") {
                            ForEach(activeThreads) { thread in
                                NavigationLink(value: thread.id) {
                                    threadRow(thread)
                                }
                            }
                            .onDelete { offsets in
                                deleteThreads(activeThreads, at: offsets)
                            }
                        }
                    }
                    if !resolvedThreads.isEmpty {
                        Section("thread.section.resolved") {
                            ForEach(resolvedThreads) { thread in
                                NavigationLink(value: thread.id) {
                                    threadRow(thread)
                                }
                            }
                            .onDelete { offsets in
                                deleteThreads(resolvedThreads, at: offsets)
                            }
                        }
                    }
                    if !standaloneSessions.isEmpty {
                        Section("history.section.recent_rounds") {
                            ForEach(standaloneSessions) { session in
                                NavigationLink(value: session.id) {
                                    sessionRow(session)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        promoteToThread(session)
                                    } label: {
                                        Label("thread.promote.action", systemImage: "rectangle.stack.badge.plus")
                                    }
                                    .tint(.orange)
                                }
                            }
                            .onDelete(perform: deleteStandalone)
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let thread = threads.first(where: { $0.id == id }) {
                        ThreadDetailView(thread: thread, onContinue: onContinueGenerator)
                    } else if let session = sessions.first(where: { $0.id == id }) {
                        sessionDetail(session)
                    }
                }
            }
        }
        .navigationTitle("tab.history")
    }

    private func threadRow(_ thread: SituationThread) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(thread.title)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                if thread.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                Spacer()
                Text(String(format: String(localized: "thread.round_count"), thread.sessions?.count ?? 0))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Label(thread.category.displayName, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(thread.updatedAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func sessionRow(_ session: RoastSession) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if session.isSampleData {
                    Text("sample.badge.standard")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                        .foregroundStyle(.blue)
                }
                if let style = StyleCatalog.shared.style(id: session.styleId) {
                    Text(style.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(session.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(session.situation)
                .font(.callout)
                .lineLimit(2)
        }
    }

    private func sessionDetail(_ session: RoastSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(session.situation)
                    .font(.body)
                    .padding(.bottom)

                ForEach((session.results ?? []).sorted { $0.generatedAt < $1.generatedAt }, id: \.id) { result in
                    GeneratedRoastCard(
                        result: result,
                        style: StyleCatalog.shared.style(id: result.styleId),
                        isRewriting: false,
                        hasSendableReply: hasSendableReply(for: result, in: session),
                        onRewrite: nil
                    )
                }

                Button {
                    promoteAndContinue(session)
                } label: {
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

    private func hasSendableReply(for result: GeneratedRoast, in session: RoastSession) -> Bool {
        guard result.kind == .ventDraft else { return false }
        return (session.results ?? []).contains {
            $0.kind == .sendableReply && $0.sourceVentDraftId == result.id
        }
    }

    private func promoteToThread(_ session: RoastSession) {
        _ = ThreadService.promoteToThread(session: session, context: context)
    }

    private func promoteAndContinue(_ session: RoastSession) {
        let thread = ThreadService.promoteToThread(session: session, context: context)
        ThreadContinuationStore.shared.stage(
            thread: thread,
            suggestedStyleId: session.styleId
        )
        onContinueGenerator?()
    }

    private func deleteStandalone(at offsets: IndexSet) {
        for offset in offsets {
            context.delete(standaloneSessions[offset])
        }
        try? context.save()
    }

    private func deleteThreads(_ source: [SituationThread], at offsets: IndexSet) {
        for offset in offsets {
            context.delete(source[offset])
        }
        try? context.save()
    }
}
