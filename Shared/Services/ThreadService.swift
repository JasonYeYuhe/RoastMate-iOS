import Foundation
import SwiftData
import os.log

/// Manages `SituationThread` lifecycle — creating threads, promoting a
/// loose `RoastSession` into the first session of a thread, building the
/// "prior context" string the engine needs for the next turn, and querying
/// threads for the history view.
///
/// Design note: threads are **opt-in**. Existing one-shot sessions still
/// work; we only create / attach a thread when the user explicitly hits
/// "continue this event" or starts in a categorized flow.
@MainActor
enum ThreadService {
    private static let logger = Logger(subsystem: "yyh.roastmate.app", category: "Thread")

    /// Builds a thread around an existing session. Used the first time a
    /// user taps "continue this event" on a session that wasn't yet
    /// threaded. The session keeps its data; we just add it as the root
    /// session of a new thread.
    @discardableResult
    static func promoteToThread(
        session: RoastSession,
        title: String? = nil,
        category: SituationCategory = .other,
        mood: SituationMood? = nil,
        context: ModelContext
    ) -> SituationThread {
        if let existing = session.thread {
            return existing
        }
        let inferredTitle = title ?? autoTitle(from: session.situation)
        let thread = SituationThread(
            title: inferredTitle,
            originalSituation: session.situation,
            category: category,
            mood: mood
        )
        context.insert(thread)
        session.thread = thread
        thread.sessions = [session]
        do {
            try context.save()
        } catch {
            logger.error("Failed to promote session to thread: \(error.localizedDescription)")
        }
        return thread
    }

    /// Returns a compact string summarizing the prior turns in this thread,
    /// suitable to pass as `priorContext` to `RoastEngine.generate`. We
    /// include each session's situation + the *user-favorited* output
    /// (falling back to the first output if none is favorited), capped to
    /// the last 4 turns to keep token budget sane.
    static func priorContextSummary(thread: SituationThread, excluding excludedSessionID: UUID? = nil) -> String {
        let turns = (thread.sessions ?? [])
            .filter { $0.id != excludedSessionID }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(4)
        guard !turns.isEmpty else { return "" }

        var lines: [String] = []
        lines.append("Original situation: \(thread.originalSituation)")
        for (i, turn) in turns.enumerated() {
            let results = turn.results ?? []
            let pick = results.first(where: { $0.isFavorite })
                ?? results.first(where: { $0.kind == .sendableReply })
                ?? results.first
            lines.append("Round \(i + 1) update: \(turn.situation)")
            if let pick {
                lines.append("Round \(i + 1) response we sent / wished we sent: \(pick.text)")
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Threads sorted for the history view: unresolved first, then by
    /// `updatedAt` desc, then resolved threads at the bottom.
    static func allThreads(context: ModelContext) -> [SituationThread] {
        let descriptor = FetchDescriptor<SituationThread>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let all = (try? context.fetch(descriptor)) ?? []
        let active = all.filter { !$0.isResolved }
        let resolved = all.filter { $0.isResolved }
        return active + resolved
    }

    static func threads(matching category: SituationCategory, context: ModelContext) -> [SituationThread] {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<SituationThread>(
            predicate: #Predicate { $0.categoryRaw == raw },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func favoriteThreads(context: ModelContext) -> [SituationThread] {
        let descriptor = FetchDescriptor<SituationThread>(
            predicate: #Predicate { $0.isFavorite },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func markResolved(_ thread: SituationThread, resolved: Bool, context: ModelContext) {
        thread.isResolved = resolved
        thread.updatedAt = Date()
        try? context.save()
    }

    /// Best-effort short title from a free-text situation. The UI lets the
    /// user edit this immediately after thread creation, so we only need
    /// to produce a reasonable first guess.
    private static func autoTitle(from situation: String) -> String {
        let trimmed = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return String(localized: "thread.untitled") }
        // Strip leading "I" / "我" type pronouns and grab the first ~20
        // chars worth of meaningful text.
        let limit = 24
        let prefix = trimmed.prefix(while: { !".!?。!?\n".contains($0) })
        let candidate = String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.count <= limit {
            return candidate.isEmpty ? String(localized: "thread.untitled") : candidate
        }
        let endIndex = candidate.index(candidate.startIndex, offsetBy: limit)
        return String(candidate[..<endIndex]) + "…"
    }
}
