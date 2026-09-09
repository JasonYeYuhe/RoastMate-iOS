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
        /// Input signalled the user's own self-harm risk — show
        /// supportive resources instead of generating.
        case crisis
    }

    var situation: String = ""
    var selectedStyleId: String
    var selectedIntensity: Intensity = .sharp
    var state: State = .idle
    var currentSession: RoastSession?
    var rewritingDraftId: UUID?
    var rewriteError: String?
    /// Soft self-harm signal: results still shown, plus a supportive banner.
    var crisisBanner: Bool = false
    /// True when the results on screen came from `FallbackRoasts`, not a
    /// model. Drives the honest "these are curated examples" note. NOT an
    /// error state — the user still gets usable text, and routing this through
    /// `.error` would render zero cards and block the default action on every
    /// device without an on-device model (App Review 2.1 risk).
    var curatedNotice: Bool = false

    /// Drives the one-time 5.1.2(i) cloud-AI consent sheet. Set when a
    /// Vent/Feral generation needs explicit permission before any
    /// third-party request; `resolveCloudConsent` records the choice and
    /// resumes generation.
    var pendingCloudConsent: Bool = false

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
        // Re-entry guard: a rapid double-tap (or a tap that races the Generate
        // button's `.disabled(state == .loading)` before it propagates to the
        // view) must not spend a second credit or launch a second generation.
        // `state` flips to `.loading` synchronously below — before the first
        // `await` — so a second concurrent call returns here. (Codex pre-ship
        // audit 2026-05-29; mirrors EchoesViewModel's re-entrancy guard.)
        if state == .loading { return }
        let text = situation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // Self-harm handoff (two-tier). `.hard` intercepts BEFORE quota /
        // Pro gating / the engine so a person in distress gets care, not
        // an error or a paywall, and no free quota is spent. `.soft`
        // keeps generating (it's a venting app) but flags a supportive
        // banner. Filters stay unchanged.
        switch SafetyFilter.crisisSignal(text) {
        case .hard:
            crisisBanner = false
            state = .crisis
            return
        case .soft:
            crisisBanner = true
        case .none:
            crisisBanner = false
        }
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

        // 5.1.2(i): before the FIRST cloud (third-party-AI) Vent/Feral
        // request, the user must explicitly choose. `.needsConsent` halts
        // here — no credit spent, nothing generated — and shows the
        // consent sheet; `resolveCloudConsent` records the choice and
        // re-enters `generate`. Crisis handoff already ran above, so a
        // person in distress never reaches this prompt.
        // Sendable modes (calm/sharp/savage) become cloud-eligible ONLY on a
        // device with no on-device model (iOS 18 / AI off) AND when the DARK
        // `cloud_sendable_enabled` flag is flipped on remotely. Private drafts
        // (vent/feral) keep their existing cloud path. When the on-device model
        // is present, sendable stays local (unchanged).
        // Single resolution point — see CloudPermission. This logic used to
        // live here and only here, which is why the other surfaces missed it.
        let cloud = CloudPermission.resolve(
            intensity: selectedIntensity,
            consent: settings.cloudConsent,
            locale: locale
        )
        if cloud.needsConsent {
            pendingCloudConsent = true
            return
        }

        if !isPro {
            // Credits are a quantity knob only — the Pro-only intensity
            // and style guards above are unchanged, so spending a credit
            // never unlocks a capability. The View intent-triggers the
            // paywall before reaching here; this is the safety net.
            //
            // P1.1: PEEK only. The charge itself moved to after generation
            // (below) so curated fallback text — which never reads the user's
            // input — is never billed. `canSpendNow` is a documented read-only
            // probe, so paywall behaviour is unchanged: an empty wallet still
            // stops here, before anything is generated.
            guard settings.canSpendNow() else {
                state = .error(String(localized: "paywall.out_of_credits.body"))
                return
            }
        }

        state = .loading
        currentSession = nil
        rewriteError = nil
        curatedNotice = false
        do {
            let output = try await RoastEngine.shared.generateDetailed(
                situation: text,
                style: style,
                locale: locale,
                variantCount: isPro ? 3 : 1,
                intensity: selectedIntensity,
                safeMode: settings.safeModeEnabled,
                priorContext: pendingPriorContext,
                // RESTRICT-only remote kill-switch: AND the consent gate
                // (source of truth) with the remote flags so a fetched
                // `false` can force this generation on-device. Can only
                // subtract from the consent grant, never route to cloud
                // without it. (Health audit 2026-05-29 §4.) Private drafts AND
                // `vent_cloud_enabled`; sendable modes AND `cloud_sendable_enabled`.
                cloudVentEnabled: cloud.cloudAllowed
            )
            // P1.1: spend LAST, and only for output a model actually wrote.
            // The ledger has no refund primitive (`CreditLedgerEntry.Kind` is
            // grant | spend | legacyBaseline) and grants are keyed by a
            // StoreKit txID, so "charge then reverse" is not available — not
            // charging is the only correct shape. The predicate is provenance,
            // NOT `isOnDeviceModelAvailable`: a device with no on-device model
            // is exactly the one that becomes cloud-eligible, so gating on FM
            // availability would zero revenue the moment `cloud_sendable_enabled`
            // flips. Worst case here is a free generation if the app dies
            // mid-save, which fails in the user's favour.
            if !isPro, output.provenance == .model {
                _ = settings.spendOneCredit(context: context)
                try? context.save()
            }
            curatedNotice = output.isCurated
            currentSession = HistoryService.saveSession(
                situation: text,
                mode: .roast,
                styleId: style.id,
                locale: locale,
                variants: output.texts,
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

    /// Records the user's one-time 5.1.2(i) choice for the cloud
    /// (third-party-AI) path, then resumes the generation they were
    /// trying to run. `allow == false` is a durable `.denied` — Vent/
    /// Feral simply proceed on-device and the prompt never re-appears.
    func resolveCloudConsent(_ allow: Bool,
                             context: ModelContext,
                             locale: Locale) async {
        let settings = HistoryService.userSettings(context: context)
        settings.cloudConsent = allow ? .granted : .denied
        try? context.save()
        pendingCloudConsent = false
        await generate(context: context, locale: locale)
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
            let rewritten = try await RoastEngine.shared.rewriteAsSendableDetailed(
                ventDraft: draft.text,
                originalSituation: session.situation,
                style: style,
                locale: locale
            )
            // Without an on-device model this "rewrite" is a random curated
            // ROAST line, not a rewrite of the user's draft — and it gets a
            // Share button. Label it with the same note the generator uses.
            if rewritten.provenance == .curated { curatedNotice = true }
            HistoryService.appendSendableReply(
                toSession: session,
                sourceVentDraft: draft,
                rewrittenText: rewritten.text,
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

    /// Pre-fills the vent box from an on-device voice transcript. Pure
    /// prefill — voice is a free input modality; the transcript then
    /// goes through the SAME generate() path as typed text, so the
    /// crisis/safety preflight and credit/Pro gating are inherited
    /// unchanged (a new input path must not bypass the safety net).
    func applyVoiceTranscript(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        situation = trimmed
        currentSession = nil
        rewriteError = nil
        crisisBanner = false
        curatedNotice = false
        state = .idle
    }

    /// Pre-fills the generator from a curated zh-first scenario (situation
    /// + a free-tier style + intensity). Pure prefill — generation still
    /// goes through the normal credit/Pro gating on Generate.
    func loadScenario(_ scenario: Scenario, locale: Locale) {
        situation = scenario.prompt(for: locale)
        selectedStyleId = scenario.defaultStyleId
        selectedIntensity = scenario.intensity
        currentSession = nil
        rewriteError = nil
        crisisBanner = false
        curatedNotice = false
        state = .idle
    }

    func loadSample(_ sample: SampleRoast, locale: Locale) {
        situation = sample.situation(for: locale)
        selectedStyleId = sample.styleId
        selectedIntensity = .sharp
        currentSession = nil
        rewriteError = nil
        crisisBanner = false
        curatedNotice = false
        state = .idle
    }
}
