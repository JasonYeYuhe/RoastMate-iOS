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
    /// haven't been ported to the new picker yet. Private-draft intensities
    /// are recorded as `.ventDraft`; otherwise variants are `.normalRoast`.
    /// Use `appendSendableReply` to attach the second-pass rewrite after the
    /// user opts in.
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
        let kind: GeneratedRoastKind = intensity.isPrivateDraft ? .ventDraft : .normalRoast
        let sourceIntensity: Intensity? = intensity.isPrivateDraft ? intensity : nil
        for text in variants {
            let result = GeneratedRoast(
                text: text,
                styleId: styleId,
                locale: locale.identifier,
                kind: kind,
                sourceIntensity: sourceIntensity
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
    /// the reviewer (and new user) see the feature without typing. v1.4
    /// bumps the seed key because the sample shape changed:
    /// - vent demo pairs now seed as proper `.ventDraft` + `.sendableReply`
    ///   results (instead of a single normal-roast row that hid the killer
    ///   feature)
    /// - a multi-round sample SituationThread is added so the Threads UX
    ///   isn't empty on a fresh install
    static func seedSamplesIfNeeded(context: ModelContext) {
        let didSeedKey = "roastmate_samples_seeded_v2"
        guard !UserDefaults.standard.bool(forKey: didSeedKey) else { return }

        // v1 cleanup: if the user has a v1 seed marker, leave their data
        // alone — they may have favorited some samples. New install only.
        let v1Key = "roastmate_samples_seeded_v1"
        if UserDefaults.standard.bool(forKey: v1Key) {
            UserDefaults.standard.set(true, forKey: didSeedKey)
            return
        }

        let samples = SampleRoastsCatalog.shared.all
        guard !samples.isEmpty else { return }

        for sample in samples {
            let locale = Locale(identifier: sample.responseLocale)
            if sample.isVentDemo,
               let ventText = sample.ventResponse,
               let sendableText = sample.sendableResponse {
                seedVentDemoSession(
                    sample: sample,
                    locale: locale,
                    ventText: ventText,
                    sendableText: sendableText,
                    context: context
                )
            } else {
                seedStandardSampleSession(
                    sample: sample,
                    locale: locale,
                    context: context
                )
            }
        }

        seedSampleThread(context: context)

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: didSeedKey)
        } catch {
            logger.error("Failed to seed samples: \(error.localizedDescription)")
        }
    }

    /// Standard single-shot sample → one `.normalRoast` result.
    private static func seedStandardSampleSession(
        sample: SampleRoast,
        locale: Locale,
        context: ModelContext
    ) {
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

    /// Vent-demo sample → one session marked as `.vent` intensity, with a
    /// `.ventDraft` result paired to a `.sendableReply` rewrite. Visually
    /// identical to what the user gets when they hit "Make it sendable"
    /// themselves.
    private static func seedVentDemoSession(
        sample: SampleRoast,
        locale: Locale,
        ventText: String,
        sendableText: String,
        context: ModelContext
    ) {
        let session = RoastSession(
            situation: sample.situation(for: locale),
            mode: .roast,
            styleId: sample.styleId,
            locale: sample.responseLocale,
            intensity: .vent,
            isSampleData: true
        )
        let draft = GeneratedRoast(
            text: ventText,
            styleId: sample.styleId,
            locale: sample.responseLocale,
            kind: .ventDraft,
            sourceIntensity: .vent
        )
        session.results?.append(draft)
        let reply = GeneratedRoast(
            text: sendableText,
            styleId: sample.styleId,
            locale: sample.responseLocale,
            kind: .sendableReply,
            sourceVentDraftId: draft.id
        )
        session.results?.append(reply)
        context.insert(session)
    }

    /// One curated multi-round sample thread that demonstrates the
    /// "this same person came back at me — help me again" loop. Uses
    /// localized strings so it reads natively in the user's UI language.
    private static func seedSampleThread(context: ModelContext) {
        let category = SituationCategory.work
        let mood = SituationMood.wronged
        let title = String(localized: "sample.thread.title")
        let original = String(localized: "sample.thread.round1.situation")
        let thread = SituationThread(
            title: title,
            originalSituation: original,
            category: category,
            mood: mood,
            isSampleData: true
        )
        thread.isFavorite = true
        context.insert(thread)

        // Round 1: standard sharp roast — what I wish I'd said in the moment.
        let round1Locale = Locale.current
        let round1 = RoastSession(
            situation: original,
            mode: .roast,
            styleId: "high_eq",
            locale: round1Locale.identifier,
            intensity: .sharp,
            isSampleData: true
        )
        round1.thread = thread
        let round1Result = GeneratedRoast(
            text: String(localized: "sample.thread.round1.response"),
            styleId: "high_eq",
            locale: round1Locale.identifier,
            kind: .normalRoast
        )
        round1.results?.append(round1Result)
        context.insert(round1)

        // Round 2: same event, escalated. Vent draft + cool-off rewrite.
        let round2Locale = Locale.current
        let round2 = RoastSession(
            situation: String(localized: "sample.thread.round2.situation"),
            mode: .roast,
            styleId: "high_eq",
            locale: round2Locale.identifier,
            intensity: .vent,
            isSampleData: true
        )
        round2.thread = thread
        round2.createdAt = Date().addingTimeInterval(60 * 60 * 24)  // a day later
        let ventDraft = GeneratedRoast(
            text: String(localized: "sample.thread.round2.vent"),
            styleId: "high_eq",
            locale: round2Locale.identifier,
            kind: .ventDraft,
            sourceIntensity: .vent
        )
        ventDraft.generatedAt = round2.createdAt
        round2.results?.append(ventDraft)
        let sendable = GeneratedRoast(
            text: String(localized: "sample.thread.round2.sendable"),
            styleId: "high_eq",
            locale: round2Locale.identifier,
            kind: .sendableReply,
            sourceVentDraftId: ventDraft.id
        )
        sendable.generatedAt = round2.createdAt.addingTimeInterval(5)
        round2.results?.append(sendable)
        context.insert(round2)

        thread.updatedAt = round2.createdAt
    }

    static func clearSamples(context: ModelContext) {
        // Threads with cascade-delete on sessions will take their child
        // sessions with them. Do threads first to avoid orphaning sample
        // results that belong to sample threads.
        let threadDescriptor = FetchDescriptor<SituationThread>(
            predicate: #Predicate { $0.isSampleData }
        )
        if let sampleThreads = try? context.fetch(threadDescriptor) {
            for thread in sampleThreads {
                context.delete(thread)
            }
        }
        let sessionDescriptor = FetchDescriptor<RoastSession>(
            predicate: #Predicate { $0.isSampleData }
        )
        if let standaloneSamples = try? context.fetch(sessionDescriptor) {
            for sample in standaloneSamples {
                context.delete(sample)
            }
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

    // MARK: - Echoes / 替你出气 (Phase 5 Q2)

    /// Persist a completed Echoes transcript. Mirrors the
    /// `RoastSession`/`GeneratedRoast` parent-child save pattern but
    /// uses the dedicated `EchoTranscriptRecord` / `EchoMessageRecord`
    /// models (Codex audit catch — RoastSession.results' String text
    /// is too lossy for the structured-transcript shape).
    @discardableResult
    static func saveEchoTranscript(
        _ transcript: EchoTranscript,
        context: ModelContext,
        isPro: Bool
    ) -> EchoTranscriptRecord {
        let bridgeIntensity = transcript.messages.first { $0.role == .bridge }?.bridgeIntensity
        let record = EchoTranscriptRecord(
            situation: transcript.situation,
            locale: transcript.locale.identifier,
            tone: transcript.tone,
            voiceCount: transcript.voiceCount,
            scene: transcript.scene,
            bridgeIntensity: bridgeIntensity,
            cloudUsed: transcript.cloudUsed
        )
        for (idx, msg) in transcript.messages.enumerated() {
            let m = EchoMessageRecord(
                echoIndex: msg.echoIndex,
                role: msg.role,
                text: msg.text,
                deliveryDelayMs: msg.deliveryDelayMs,
                orderIndex: idx,
                bridgeIntensity: msg.bridgeIntensity
            )
            record.messages?.append(m)
        }
        context.insert(record)
        do {
            try context.save()
        } catch {
            logger.error("Failed to save EchoTranscriptRecord: \(error.localizedDescription)")
        }
        if !isPro {
            pruneFreeTierEchoes(context: context)
        }
        return record
    }

    /// Free-tier Echoes retention: keep at most the last 5 transcripts.
    /// Mirrors `pruneFreeTierHistory` in spirit (older records dropped).
    private static func pruneFreeTierEchoes(context: ModelContext) {
        let descriptor = FetchDescriptor<EchoTranscriptRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let all = try? context.fetch(descriptor), all.count > 5 else { return }
        for stale in all.dropFirst(5) {
            context.delete(stale)
        }
        try? context.save()
    }
}
