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

    /// Favorited threads pin to the top regardless of resolved state.
    /// A thread either appears in Favorites OR in Active/Resolved — never
    /// in both, so the section list stays unambiguous.
    private var favoriteThreads: [SituationThread] {
        threads.filter { $0.isFavorite }
    }

    private var activeThreads: [SituationThread] {
        threads.filter { !$0.isResolved && !$0.isFavorite }
    }

    private var resolvedThreads: [SituationThread] {
        threads.filter { $0.isResolved && !$0.isFavorite }
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
                    if !favoriteThreads.isEmpty {
                        Section("thread.section.favorites") {
                            ForEach(favoriteThreads) { thread in
                                NavigationLink(value: thread.id) {
                                    threadRow(thread)
                                }
                                .swipeActions(edge: .leading) {
                                    favoriteSwipeAction(thread)
                                }
                            }
                            .onDelete { offsets in
                                deleteThreads(favoriteThreads, at: offsets)
                            }
                        }
                    }
                    if !activeThreads.isEmpty {
                        Section("thread.section.unresolved") {
                            ForEach(activeThreads) { thread in
                                NavigationLink(value: thread.id) {
                                    threadRow(thread)
                                }
                                .swipeActions(edge: .leading) {
                                    favoriteSwipeAction(thread)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        ThreadService.markResolved(thread, resolved: true, context: context)
                                    } label: {
                                        Label("thread.mark_resolved", systemImage: "checkmark")
                                    }
                                    .tint(.green)
                                }
                            }
                            .onDelete { offsets in
                                deleteThreads(activeThreads, at: offsets)
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
                    if !resolvedThreads.isEmpty {
                        Section("thread.section.resolved") {
                            ForEach(resolvedThreads) { thread in
                                NavigationLink(value: thread.id) {
                                    threadRow(thread)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        ThreadService.markResolved(thread, resolved: false, context: context)
                                    } label: {
                                        Label("thread.mark_unresolved", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.orange)
                                }
                            }
                            .onDelete { offsets in
                                deleteThreads(resolvedThreads, at: offsets)
                            }
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { id in
                    if let thread = threads.first(where: { $0.id == id }) {
                        ThreadDetailView(thread: thread, onContinue: onContinueGenerator)
                    } else if let session = sessions.first(where: { $0.id == id }) {
                        HistorySessionDetailView(
                            session: session,
                            onContinue: { promoteAndContinue(session) }
                        )
                    }
                }
            }
        }
        .navigationTitle("tab.history")
    }

    @ViewBuilder
    private func favoriteSwipeAction(_ thread: SituationThread) -> some View {
        Button {
            thread.isFavorite.toggle()
            thread.updatedAt = Date()
            try? context.save()
        } label: {
            Label(thread.isFavorite ? "thread.unfavorite" : "thread.favorite",
                  systemImage: thread.isFavorite ? "star.slash" : "star")
        }
        .tint(.yellow)
    }

    private func threadRow(_ thread: SituationThread) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                if thread.isSampleData {
                    Text("sample.badge.standard")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.blue.opacity(0.18)))
                        .foregroundStyle(.blue)
                }
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
