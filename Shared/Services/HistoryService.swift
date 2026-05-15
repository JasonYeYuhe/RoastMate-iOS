import Foundation
import SwiftData
import os.log

@MainActor
enum HistoryService {
    private static let logger = Logger(subsystem: "yyh.roastmate.app", category: "History")

    /// Inserts a new session with its generated variants, retaining the
    /// free-tier history cap. Returns the inserted session.
    ///
    /// Intensity defaults to `.sharp` to preserve behavior for callers that
    /// haven't been ported to the new picker yet. When `intensity == .vent`,
    /// every variant is recorded as a `.ventDraft`; otherwise variants are
    /// `.normalRoast`. Use `appendSendableReply` to attach the second-pass
    /// rewrite after the user opts in.
    @discardableResult
    static func saveSession(
        situation: String,
        mode: RoastMode,
        styleId: String,
        locale: Locale,
        variants: [String],
        context: ModelContext,
        isPro: Bool,
        intensity: Intensity = .sharp,
        thread: SituationThread? = nil,
        isSampleData: Bool = false
    ) -> RoastSession {
        let session = RoastSession(
            situation: situation,
            mode: mode,
            styleId: styleId,
            locale: locale.identifier,
            intensity: intensity,
            isSampleData: isSampleData
        )
        let kind: GeneratedRoastKind = (intensity == .vent) ? .ventDraft : .normalRoast
        for text in variants {
            let result = GeneratedRoast(
                text: text,
                styleId: styleId,
                locale: locale.identifier,
                kind: kind
            )
            session.results?.append(result)
        }
        if let thread {
            session.thread = thread
            thread.updatedAt = Date()
        }
        context.insert(session)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save RoastSession: \(error.localizedDescription)")
        }

        if !isPro {
            pruneFreeTierHistory(context: context)
        }
        return session
    }

    /// Attaches a sendable-reply output to an existing session whose
    /// original variant(s) were vent drafts. The new `GeneratedRoast`
    /// records `sourceVentDraftId` so the UI can pair them in the history
    /// view.
    @discardableResult
    static func appendSendableReply(
        toSession session: RoastSession,
        sourceVentDraft: GeneratedRoast,
        rewrittenText: String,
        context: ModelContext
    ) -> GeneratedRoast {
        let reply = GeneratedRoast(
            text: rewrittenText,
            styleId: sourceVentDraft.styleId,
            locale: sourceVentDraft.localeRaw,
            kind: .sendableReply,
            sourceVentDraftId: sourceVentDraft.id
        )
        session.results?.append(reply)
        session.thread?.updatedAt = Date()
        do {
            try context.save()
        } catch {
            logger.error("Failed to attach sendable reply: \(error.localizedDescription)")
        }
        return reply
    }

    /// Free tier keeps at most 30 non-sample, non-favorited sessions.
    static func pruneFreeTierHistory(context: ModelContext, limit: Int = 30) {
        let descriptor = FetchDescriptor<RoastSession>(
            predicate: #Predicate { !$0.isFavorite && !$0.isSampleData },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor) else { return }
        guard all.count > limit else { return }
        for old in all.dropFirst(limit) {
            context.delete(old)
        }
        do {
            try context.save()
        } catch {
            logger.error("Failed to prune history: \(error.localizedDescription)")
        }
    }

    /// On first launch, populate the history with the bundled samples so
    /// the reviewer (and new user) see the feature without typing.
    static func seedSamplesIfNeeded(context: ModelContext) {
        let didSeedKey = "roastmate_samples_seeded_v1"
        guard !UserDefaults.standard.bool(forKey: didSeedKey) else { return }

        let samples = SampleRoastsCatalog.shared.all
        guard !samples.isEmpty else { return }

        for sample in samples {
            let locale = Locale(identifier: sample.responseLocale)
            let session = RoastSession(
                situation: sample.situation(for: locale),
                mode: .roast,
                styleId: sample.styleId,
                locale: sample.responseLocale,
                isSampleData: true
            )
            let result = GeneratedRoast(
                text: sample.response,
                styleId: sample.styleId,
                locale: sample.responseLocale
            )
            session.results?.append(result)
            context.insert(session)
        }
        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: didSeedKey)
        } catch {
            logger.error("Failed to seed samples: \(error.localizedDescription)")
        }
    }

    static func clearSamples(context: ModelContext) {
        let descriptor = FetchDescriptor<RoastSession>(
            predicate: #Predicate { $0.isSampleData }
        )
        guard let samples = try? context.fetch(descriptor) else { return }
        for sample in samples {
            context.delete(sample)
        }
        try? context.save()
    }

    /// Returns or creates the singleton UserSettings row.
    static func userSettings(context: ModelContext) -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let new = UserSettings()
        context.insert(new)
        try? context.save()
        return new
    }
}
