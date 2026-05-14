import Foundation
import SwiftData
import os.log

@MainActor
@Observable
final class RoastGeneratorViewModel {
    enum State: Equatable {
        case idle
        case loading
        case results
        case error(String)
    }

    var situation: String = ""
    var selectedStyleId: String
    var selectedIntensity: Intensity = .sharp
    var state: State = .idle
    var currentSession: RoastSession?
    var rewritingDraftId: UUID?
    var rewriteError: String?

    /// When non-nil, the next `generate()` call attaches the new session to
    /// this thread and feeds the prior-context summary into the engine.
    /// Cleared after one generation.
    var pendingThread: SituationThread?
    var pendingPriorContext: String?

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "GeneratorVM")

    init(initialStyleId: String? = nil) {
        self.selectedStyleId = initialStyleId ?? StyleCatalog.shared.defaultStyleId
    }

    func style() -> StylePreset? {
        StyleCatalog.shared.style(id: selectedStyleId)
    }

    func generate(context: ModelContext, locale: Locale) async {
        let text = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let style = style() else {
            state = .error(String(localized: "error.generic"))
            return
        }

        let settings = HistoryService.userSettings(context: context)
        let isPro = StoreService.shared.isPro
        guard isPro || style.tier != .pro else {
            state = .error(String(localized: "quota.exhausted.body"))
            return
        }
        guard isPro || !selectedIntensity.requiresPro else {
            state = .error(String(localized: "quota.exhausted.body"))
            return
        }
        if !isPro {
            guard settings.consumeFreeQuotaIfAvailable() else {
                state = .error(String(localized: "quota.exhausted.body"))
                return
            }
            try? context.save()
        }

        state = .loading
        currentSession = nil
        rewriteError = nil
        do {
            let variants = try await RoastEngine.shared.generate(
                situation: text,
                style: style,
                locale: locale,
                variantCount: isPro ? 3 : 1,
                intensity: selectedIntensity,
                safeMode: settings.safeModeEnabled,
                priorContext: pendingPriorContext
            )
            currentSession = HistoryService.saveSession(
                situation: text,
                mode: .roast,
                styleId: style.id,
                locale: locale,
                variants: variants,
                context: context,
                isPro: isPro,
                intensity: selectedIntensity,
                thread: pendingThread
            )
            pendingThread = nil
            pendingPriorContext = nil
            state = .results
            Haptics.play(.generated)
        } catch let err as RoastError {
            state = .error(err.localizedDescription)
            Haptics.play(.error)
        } catch {
            state = .error(error.localizedDescription)
            Haptics.play(.error)
        }
    }

    func rewriteAsSendable(
        draft: GeneratedRoast,
        session: RoastSession,
        context: ModelContext,
        locale: Locale
    ) async {
        guard draft.kind == .ventDraft, rewritingDraftId == nil else { return }
        guard let style = StyleCatalog.shared.style(id: draft.styleId) else {
            rewriteError = String(localized: "error.generic")
            return
        }

        rewritingDraftId = draft.id
        rewriteError = nil
        do {
            let rewritten = try await RoastEngine.shared.rewriteAsSendable(
                ventDraft: draft.text,
                originalSituation: session.situation,
                style: style,
                locale: locale
            )
            HistoryService.appendSendableReply(
                toSession: session,
                sourceVentDraft: draft,
                rewrittenText: rewritten,
                context: context
            )
            currentSession = session
            Haptics.play(.generated)
        } catch let err as RoastError {
            rewriteError = err.localizedDescription
            Haptics.play(.error)
        } catch {
            rewriteError = error.localizedDescription
            Haptics.play(.error)
        }
        rewritingDraftId = nil
    }

    func loadSample(_ sample: SampleRoast, locale: Locale) {
        situation = sample.situation(for: locale)
        selectedStyleId = sample.styleId
        selectedIntensity = .sharp
        currentSession = nil
        rewriteError = nil
        state = .idle
    }
}
