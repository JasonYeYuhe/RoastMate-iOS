import Foundation
import os.log

/// `generationFailed(underlying:)` was removed in 1.7.1: nothing could create
/// it once every non-cancellation model error became the labelled curated
/// fallback (see `FMBackendError`).
enum RoastError: LocalizedError {
    case modelUnavailable(reason: String)
    case noVariantsParsed
    case safety(SafetyError)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return String(localized: "roast.error.unavailable") + " (\(reason))"
        case .noVariantsParsed:
            return String(localized: "roast.error.no_variants")
        case .safety(let safetyErr):
            return safetyErr.errorDescription
        }
    }
}

/// What actually produced the text the engine returned.
///
/// Exists because `generate` used to return a bare `[String]`, which made a
/// curated fallback indistinguishable from real model output. Two shipped
/// defects came out of that single ambiguity: the caller charged a credit for
/// one of five hardcoded strings (there is no refund path — see
/// `CreditLedgerEntry.Kind`), and the UI presented canned text as if the model
/// had written it.
///
/// The predicate the callers need is **"did a model write this"**, NOT "does
/// this device have Foundation Models". They are not the same question: a
/// device with no on-device model is exactly the device that becomes
/// cloud-eligible (`CloudConsentGate.decide`), so gating a charge on FM
/// availability would stop billing precisely when real provider cost starts.
enum GenerationProvenance: Sendable, Equatable {
    /// A model wrote it — on-device Foundation Models, or the consented cloud.
    case model
    /// One of the hardcoded `FallbackRoasts` strings. It does not read the
    /// user's input. Never charge for it; always label it.
    case curated
}

/// `generate`'s full result: the text plus who wrote it.
struct GeneratedOutput: Sendable, Equatable {
    var texts: [String]
    var provenance: GenerationProvenance
    /// The Worker wrote it (not the on-device model after a cloud failure).
    /// B5's Pro preview is offered and shown only for cloud output: only the
    /// cloud draft carries the Pro style's voice.
    var servedByCloud: Bool = false

    var isCurated: Bool { provenance == .curated }
}

/// `rewriteAsSendable`'s full result. Same rationale as `GeneratedOutput`:
/// on a device with no on-device model the rewrite returns a random *roast*
/// line dressed as a polished rewrite of the user's vent draft, and it gets a
/// Share button. That has to be labelled.
struct SendableRewrite: Sendable, Equatable {
    var text: String
    var provenance: GenerationProvenance
}

/// Why the output is curated, as far as the screen that asked can tell. Drives
/// the reason line under the curated-example banner, which until 1.7.1 said
/// only "not generated from what you typed" and left the user to guess why.
enum CuratedReason: Sendable, Equatable, CaseIterable {
    /// Sendable mode, no on-device model, no permitted cloud path.
    case needsAppleIntelligence
    /// Vent / Feral, and the user has not allowed cloud.
    case cloudOff
    /// Vent / Feral, the user HAS allowed cloud, but this generation could
    /// not use it: the remote `vent_cloud_enabled` kill switch is off,
    /// `force_local_only` is on, or the build has no Worker configured.
    /// Neither retrying nor Settings can change that, so the copy says so
    /// instead of "try again" (reviewer nit, 2026-10-22).
    case cloudPaused
    /// Cloud was used and nothing usable came back.
    case cloudFailed
    /// The on-device model is present but refused, or every candidate tripped
    /// the safety filter.
    case modelDeclined

    static func forGeneration(
        intensity: Intensity,
        cloudAllowed: Bool,
        consentGranted: Bool,
        onDeviceModelAvailable: Bool
    ) -> CuratedReason {
        if intensity.isPrivateDraft {
            if cloudAllowed { return .cloudFailed }
            return consentGranted ? .cloudPaused : .cloudOff
        }
        if cloudAllowed { return .cloudFailed }
        return onDeviceModelAvailable ? .modelDeclined : .needsAppleIntelligence
    }

    /// "Make it sendable" has no cloud path at all.
    static func forRewrite(onDeviceModelAvailable: Bool) -> CuratedReason {
        onDeviceModelAvailable ? .modelDeclined : .needsAppleIntelligence
    }

    /// Localizable.strings key, in all four locales. The Apple Intelligence
    /// requirement names different hardware on the Mac.
    var localizationKey: String {
        switch self {
        case .needsAppleIntelligence:
            #if os(macOS)
            return "roast.notice.reason.apple_intelligence.mac"
            #else
            return "roast.notice.reason.apple_intelligence"
            #endif
        case .cloudOff: return "roast.notice.reason.cloud_off"
        case .cloudPaused: return "roast.notice.reason.cloud_paused"
        case .cloudFailed: return "roast.notice.reason.cloud_failed"
        case .modelDeclined: return "roast.notice.reason.declined"
        }
    }
}

/// Main roast engine. Talks to the on-device Apple model through an
/// `(any FMBackend)?` (nil on iOS 18 / macOS 14 / watchOS / AI-off), which
/// keeps all iOS-26-only Foundation Models symbols behind an `@available`
/// boundary in `AppleFMBackend`. The backend keeps one session per
/// (style, locale, mode, intensity) so a vent draft and a regular sharp
/// reply don't bleed into the same conversational context.
actor RoastEngine {
    static let shared = RoastEngine()

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "RoastEngine")

    /// Apple on-device backend, or `nil` on devices without Foundation Models
    /// (iOS 18 / macOS 14, AI off, unsupported hardware, watchOS). Immutable +
    /// `Sendable`, so `nonisolated` lets `isOnDeviceModelAvailable` read it
    /// synchronously without hopping onto the actor.
    private nonisolated let fm: (any FMBackend)?

    /// Whether A3's permissive refusal retry may run: the remote
    /// `ondevice_permissive_enabled` key, read from the App-Group cache (the
    /// lock-free copy, since `RemoteConfig` itself is main-actor bound).
    private let permissiveRetryAllowed: @Sendable () -> Bool

    /// `fm` is injectable so the hostless unit tests can drive the
    /// error-mapping paths with a fake backend; production always uses the
    /// factory default via `shared`. Same for the remote retry switch.
    init(fm: (any FMBackend)? = FMBackendFactory.make(),
         permissiveRetryAllowed: @escaping @Sendable () -> Bool = {
             RemoteConfigValues.cached().ondevicePermissiveEnabled
         }) {
        self.fm = fm
        self.permissiveRetryAllowed = permissiveRetryAllowed
    }

    /// True when the on-device model is ready to use on this device + locale.
    static var isOnDeviceModelAvailable: Bool {
        shared.fm?.isAvailable ?? false
    }

    func resetConversation() async {
        await fm?.reset()
    }

    /// Curated-fallback exit path. Fires the P5 Tier-1
    /// `markSuccessfulOutput` flag because the user still PERCEIVES this
    /// as a successful generation — they see roast text, get relief,
    /// and may pay shortly after. v1.0.4 left this gap (Codex audit
    /// 2026-05-28): only the FM-success path set the flag, so a user
    /// who only ever saw curated fallbacks then paid would mis-classify
    /// as `purchase_before_first_output`. v1.0.5 fixes by funneling
    /// every fallback through here.
    private func curatedFallback(
        style: StylePreset, locale: Locale, count: Int
    ) -> [String] {
        EventLedger.shared.markSuccessfulOutput()
        return FallbackRoasts.curated(for: style, locale: locale, count: count)
    }

    /// Generates `variantCount` variants for the given input.
    ///
    /// - `mode` controls how the input is wrapped (roast / reply / etc.).
    /// - `intensity` controls how hard the model leans in. `.vent` always
    ///   collapses to a single output and triggers the Vent Draft preamble.
    /// - `priorContext` is a serialized summary of previous turns in the
    ///   same SituationThread (when the caller is doing "continue this
    ///   event"); pass `nil` for one-shot calls.
    ///
    /// Returns curated fallback content if Foundation Models is unavailable —
    /// tagged `.curated`, so the caller can decline to charge for it and can
    /// label it. Callers that need neither can use the `generate` wrapper
    /// below, which is the unchanged `[String]` shape.
    func generateDetailed(
        situation: String,
        style: StylePreset,
        locale: Locale,
        variantCount: Int = 3,
        mode: RoastMode = .roast,
        intensity: Intensity = .sharp,
        safeMode: Bool = true,
        priorContext: String? = nil,
        keepSession: Bool = false,
        // 5.1.2(i) defense-in-depth: defaults to FALSE so any caller that
        // does not explicitly pass a consent-resolved value can never
        // silently route the user's text to the third-party cloud. Only
        // the consent-gated generator path passes `true`.
        cloudVentEnabled: Bool = false,
        cloudClient: CloudVentService = CloudVentClient.shared,
        auth: CloudAuthProviding = CloudAuthClient.shared
    ) async throws -> GeneratedOutput {
        do {
            try SafetyFilter.validateInput(situation)
        } catch let err as SafetyError {
            throw RoastError.safety(err)
        }

        // Private draft intensities always return a single draft; we ignore caller-supplied counts.
        let effectiveVariantCount = intensity.isPrivateDraft ? 1 : variantCount

        // Cloud branch: fires when the caller has resolved cloud consent for
        // THIS generation (`cloudVentEnabled`) and a Worker is configured.
        // `cloudVentEnabled` is the single gate — it defaults FALSE, and only
        // the consent-resolving generator path ever passes TRUE (so the Share /
        // Watch / App-Intents surfaces, which omit it, can never reach cloud).
        // Private drafts (vent/feral) take the single-draft vent path; sendable
        // modes (calm/sharp/savage, only reachable here on a no-FM device with
        // the DARK flag flipped on) take mode=roast — N variants, each through
        // the STRICT validator. Any failure falls through to the local path so
        // a blip never blocks generation.
        if cloudVentEnabled, CloudConfig.isConfigured {
            if intensity.isPrivateDraft {
                do {
                    let cloudText: String
                    if let fixture = AppLaunchEnvironment.uiTestVentFixture {
                        // App Store screenshots only (-uitest + fixture arg).
                        cloudText = fixture
                    } else {
                        cloudText = try await runCloudVent(
                            client: cloudClient,
                            auth: auth,
                            situation: situation,
                            style: style,
                            intensity: intensity,
                            locale: locale
                        )
                    }
                    // Cloud output must clear the SAME vent safety bar as
                    // local output. Use `try` (not `try?`) so a hard-rail
                    // violation (slur / threat of violence / self-harm)
                    // throws and we fall through to the local path —
                    // never return raw unfiltered cloud text.
                    let safe = try SafetyFilter.validateVentOutput(cloudText)
                    EventLedger.shared.recordGeneration(cloud: true)  // A′
                    EventLedger.shared.recordFirstGenerationOfSession()  // α3
                    EventLedger.shared.markSuccessfulOutput()  // P5 Tier-1 — pay-timing flag
                    RatingPromptService.shared.notifySuccessfulGeneration()  // ε1
                    return GeneratedOutput(texts: [safe], provenance: .model, servedByCloud: true)
                } catch let err as CloudVentError {
                    logger.notice("Cloud vent failed (\(String(describing: err), privacy: .public)) — falling back to local model.")
                    // continue to local path below
                } catch is SafetyError {
                    logger.notice("Cloud vent output tripped the safety filter — discarding it and falling back to local model.")
                    // continue to local path below
                } catch {
                    logger.notice("Cloud vent unexpected error — falling back to local model.")
                }
            } else {
                // Sendable cloud (iOS 18 / no on-device FM): mode=roast returns
                // a numbered list; split it and run EACH variant through the
                // STRICT output validator (parity with the local FM sendable
                // path). Drop any failing variant; only if ALL fail (or the
                // call errors) do we fall through to the local/curated path.
                do {
                    let cloudText = try await runCloudRoast(
                        client: cloudClient,
                        auth: auth,
                        situation: situation,
                        style: style,
                        intensity: intensity,
                        locale: locale,
                        variantCount: effectiveVariantCount
                    )
                    var sanitized: [String] = []
                    for candidate in PromptBuilder.splitVariants(cloudText) {
                        if let safe = try? SafetyFilter.validateOutput(candidate) {
                            sanitized.append(safe)
                        }
                    }
                    if !sanitized.isEmpty {
                        EventLedger.shared.recordGeneration(cloud: true)  // A′
                        EventLedger.shared.recordFirstGenerationOfSession()  // α3
                        EventLedger.shared.markSuccessfulOutput()  // P5 Tier-1
                        RatingPromptService.shared.notifySuccessfulGeneration()  // ε1
                        return GeneratedOutput(
                            texts: Array(sanitized.prefix(effectiveVariantCount)),
                            provenance: .model,
                            servedByCloud: true
                        )
                    }
                    logger.notice("Cloud roast output all filtered — falling back to local model.")
                } catch let err as CloudVentError {
                    logger.notice("Cloud roast failed (\(String(describing: err), privacy: .public)) — falling back to local model.")
                } catch {
                    logger.notice("Cloud roast unexpected error — falling back to local model.")
                }
            }
        }

        guard let fm, fm.isAvailable else {
            logger.notice("On-device model unavailable; using curated fallback.")
            EventLedger.shared.recordFailure(.modelAssetMissing)  // α3
            return GeneratedOutput(
                texts: curatedFallback(style: style, locale: locale, count: effectiveVariantCount),
                provenance: .curated
            )
        }

        let key = "\(style.id)|\(locale.identifier)|\(mode.rawValue)|\(intensity.rawValue)"
        let instructions = PromptBuilder.systemPrompt(
            style: style,
            locale: locale,
            mode: mode,
            intensity: intensity,
            safeMode: safeMode
        )
        let user = PromptBuilder.userPrompt(
            situation: situation,
            styleName: style.displayName,
            variants: effectiveVariantCount,
            mode: mode,
            intensity: intensity,
            priorContext: priorContext,
            locale: locale
        )

        // Private drafts both lean on emotive output; nudge temperature up
        // a touch so the model commits to the harsher register instead of
        // hedging back toward `sharp`-style polish.
        let temperature = intensity.isPrivateDraft
            ? min(style.temperature + 0.1, 1.0)
            : style.temperature

        // The backend owns session reuse (keyed by `key` + `keepSession`) so
        // the iOS-26-only `LanguageModelSession` never appears in this engine.
        let content: String
        do {
            content = try await fm.respondCached(
                instructions: instructions,
                to: user,
                temperature: temperature,
                maxTokens: 600,
                sessionKey: key,
                keepSession: keepSession
            )
        } catch FMBackendError.unavailable {
            logger.notice("On-device model unavailable; using curated fallback.")
            EventLedger.shared.recordFailure(.modelAssetMissing)  // α3
            return GeneratedOutput(
                texts: curatedFallback(style: style, locale: locale, count: effectiveVariantCount),
                provenance: .curated
            )
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            // EVERY other failure is a labelled curated fallback, never an
            // error box: a refusal on iOS/macOS 27 arrives as a type this
            // build may not know (`LanguageModelError`), and a failed cloud
            // Vent lands here too on an Apple Intelligence device.
            let category: EventLedger.FailureCategory
            if case FMBackendError.generation(let c) = error { category = c } else { category = .guardrail }
            logger.warning("On-device generation error (\(String(describing: category), privacy: .public)).")
            EventLedger.shared.recordFailure(category)  // α3
            // A3: a sendable refusal gets one more try under permissive
            // guardrails, on a fresh session, with every variant screened.
            // `.argument` is excluded: the Argument Simulator no longer comes
            // through here (`opponentTurn`), and a legacy `.argument` call
            // leans on the cached session, which a fresh retry would not have.
            if category == .guardrail, !intensity.isPrivateDraft, mode != .argument,
               let retried = try await permissiveRetry(
                   fm: fm, situation: situation, instructions: instructions, user: user,
                   temperature: temperature, count: effectiveVariantCount) {
                return GeneratedOutput(texts: retried, provenance: .model)
            }
            return GeneratedOutput(
                texts: curatedFallback(style: style, locale: locale, count: effectiveVariantCount),
                provenance: .curated
            )
        }

        let split = PromptBuilder.splitVariants(content)
        guard !split.isEmpty else {
            throw RoastError.noVariantsParsed
        }

        // Vent drafts get a separate output validation pass: the standard
        // safety filter rejects strong language too aggressively for the
        // private vent path, so we use the relaxed validator there.
        var sanitized: [String] = []
        for candidate in split {
            do {
                let safe: String
                // Private drafts unlock strong language, so they bypass the
                // strict denylist substring check and go through the relaxed
                // (hard-rail only) validator. Anything sendable remains on
                // the strict validator.
                if intensity.isPrivateDraft {
                    safe = try SafetyFilter.validateVentOutput(candidate)
                } else {
                    safe = try SafetyFilter.validateOutput(candidate)
                }
                sanitized.append(safe)
            } catch {
                logger.warning("Dropping unsafe output candidate.")
                continue
            }
        }

        if sanitized.isEmpty {
            EventLedger.shared.recordFailure(.safetyFilter)  // α3 — every candidate tripped safety
            return GeneratedOutput(
                texts: curatedFallback(style: style, locale: locale, count: effectiveVariantCount),
                provenance: .curated
            )
        }
        recordModelOutput()
        return GeneratedOutput(
            texts: Array(PromptBuilder.droppingNearDuplicates(sanitized).prefix(effectiveVariantCount)),
            provenance: .model
        )
    }

    /// What the Argument Simulator gets for one opponent turn.
    enum OpponentTurn: Sendable, Equatable {
        case line(String)
        /// No on-device model here: the simulator has no other way to play
        /// the other side (a cloud simulator is cut, plan §5).
        case unavailable
        /// Refused, or nothing passed the screens. Never a canned line: a
        /// curated roast shown as the other person's turn is a fake turn.
        case notGenerated
    }

    /// One turn of the Argument Simulator (A4). Stateless: `opponentPrompt`
    /// carries the setup and the transcript, so every call is a fresh session
    /// and the roast session is left alone.
    ///
    /// Same order as `generateDetailed`'s sendable path: default guardrails
    /// first; only on a refusal, A3's permissive retry with its input checks
    /// (on everything the user wrote) and per-turn screens.
    func opponentTurn(
        setup: String,
        transcript: [ArgumentLine],
        style: StylePreset,
        locale: Locale,
        persona: String? = nil
    ) async throws -> OpponentTurn {
        let userLines = transcript.filter { $0.speaker == .user }.map(\.text)
        do {
            try SafetyFilter.validateInput(setup)
            if let last = userLines.last { try SafetyFilter.validateInput(last) }
        } catch let err as SafetyError {
            throw RoastError.safety(err)
        }
        guard let fm, fm.isAvailable else { return .unavailable }

        let prompt = PromptBuilder.opponentPrompt(
            setup: setup, transcript: transcript, style: style, locale: locale, persona: persona)
        let content: String
        do {
            content = try await fm.respondFresh(
                instructions: prompt.system, to: prompt.user,
                temperature: style.temperature, maxTokens: 300)
        } catch FMBackendError.unavailable {
            return .unavailable
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            let category: EventLedger.FailureCategory
            if case FMBackendError.generation(let c) = error { category = c } else { category = .guardrail }
            EventLedger.shared.recordFailure(category)  // α3
            let everythingTheUserWrote = ([setup] + userLines).joined(separator: "\n")
            if category == .guardrail,
               let retried = try await permissiveRetry(
                   fm: fm, situation: everythingTheUserWrote, instructions: prompt.system,
                   user: prompt.user, temperature: style.temperature, count: 1),
               let first = retried.first {
                let line = PromptBuilder.cleanOpponentLine(first)
                return line.isEmpty ? .notGenerated : .line(line)
            }
            return .notGenerated
        }

        var line = PromptBuilder.cleanOpponentLine(content)
        // A turn that nearly repeats an earlier one gets one more try: the
        // 10-31 gate run had the same cold_violence line three turns running.
        let earlier = transcript.filter { $0.speaker == .opponent }.map(\.text)
        if !earlier.isEmpty, !PromptBuilder.nearDuplicateIndexes(earlier + [line]).isEmpty,
           let again = try? await fm.respondFresh(
               instructions: prompt.system,
               to: prompt.user + "\nYou already said: \"\(line)\" Do not say it again. Make a different point, in different words.",
               temperature: 1.0, maxTokens: 300) {
            line = PromptBuilder.cleanOpponentLine(again)
        }
        guard !line.isEmpty, !ModelRefusal.looksLikeRefusal(line),
              let safe = try? SafetyFilter.validateOutput(line) else {
            EventLedger.shared.recordFailure(.safetyFilter)  // α3
            return .notGenerated
        }
        recordModelOutput()
        return .line(safe)
    }

    /// Who the other person is and what they stand for, from their side, in
    /// two English sentences (`PromptBuilder.opponentPersonaInstructions`).
    /// Asked once per argument; the simulator passes it to every turn. Never
    /// shown, so it needs no output screen; nil when it can't be had, and the
    /// turn prompt falls back to "the other person described in the setup".
    func opponentPersona(setup: String) async -> String? {
        guard let fm, fm.isAvailable, SafetyFilter.crisisSignal(setup) == .none else { return nil }
        let input = PromptBuilder.clipTurn(setup, maxWords: 200, maxCharacters: 600)
        for guardrails in [FMGuardrails.standard, .permissiveContentTransformations] {
            guard guardrails == .standard || permissiveRetryAllowed() else { return nil }
            if let reply = try? await fm.respondFresh(
                instructions: PromptBuilder.opponentPersonaInstructions, to: input,
                temperature: 0, maxTokens: 120, guardrails: guardrails),
               reply.contains("You are"), !ModelRefusal.looksLikeRefusal(reply) {
                return reply.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func recordModelOutput() {
        EventLedger.shared.recordGeneration(cloud: false)  // A′
        EventLedger.shared.recordFirstGenerationOfSession()  // α3
        EventLedger.shared.markSuccessfulOutput()  // P5 Tier-1 — pay-timing flag
        RatingPromptService.shared.notifySuccessfulGeneration()  // ε1
    }

    /// A3 (plan v1.8): after Apple's DEFAULT guardrails refused a sendable
    /// prompt, one retry under `permissiveContentTransformations`. On macOS
    /// 27.2 the default refused every sendable Savage call and 15/16 free
    /// Composed/Sharp calls, while the permissive model accepted them in
    /// 4–8 s (`docs/evidence/2026-10-27-v18-plan/harness/safety/e2e`).
    ///
    /// Returns the screened variants, or nil when the retry must not run or
    /// nothing survived (the caller shows the labelled curated example).
    ///
    /// - The retry is FRESH (`respondFresh`), never the cached session: the
    ///   cache key has no guardrail part, so a cached call would replay the
    ///   default session that just refused.
    /// - Input first: a request to scare or threaten the other person, or to
    ///   attack their identity, never reaches the permissive model
    ///   (`IntimidationRequest` / `SlurRequest` phrases, then two one-word
    ///   checks). On bait inputs the permissive model otherwise wrote "I'll
    ///   be waiting after your shift" and 「笑えるほど浅黒い」.
    /// - Then every variant must pass ModelRefusal → validateOutput →
    ///   RewriteThreatScreen → the threat judge, one call per variant.
    private func permissiveRetry(
        fm: any FMBackend, situation: String, instructions: String, user: String,
        temperature: Double, count: Int
    ) async throws -> [String]? {
        guard permissiveRetryAllowed() else { return nil }
        if IntimidationRequest.matches(situation) || SlurRequest.matches(situation) {
            logger.notice("Permissive retry skipped: the input asks to intimidate or for slurs.")
            return nil
        }
        for check in [Self.intimidationIntentInstructions, Self.identityAttackIntentInstructions] {
            do {
                let verdict = try await fm.respondFresh(
                    instructions: check, to: situation,
                    temperature: 0, maxTokens: 5, guardrails: .permissiveContentTransformations)
                guard Self.intentCheckSaysOK(verdict) else {
                    logger.notice("Permissive retry skipped: an input check did not say OK.")
                    return nil
                }
            } catch let cancellation as CancellationError {
                throw cancellation
            } catch {
                return nil
            }
        }

        let content: String
        do {
            content = try await fm.respondFresh(
                instructions: instructions, to: user, temperature: temperature,
                maxTokens: 600, guardrails: .permissiveContentTransformations)
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            logger.notice("Permissive retry failed too — curated fallback.")
            return nil
        }
        if ModelRefusal.looksLikeRefusal(content) { return nil }

        var shown: [String] = []
        for candidate in PromptBuilder.splitVariants(content) {
            guard shown.count < count else { break }
            if ModelRefusal.looksLikeRefusal(candidate) { continue }
            guard let safe = try? SafetyFilter.validateOutput(candidate) else { continue }
            if RewriteThreatScreen.containsThreat(safe) { continue }
            let verdict: String
            do {
                verdict = try await fm.respondFresh(
                    instructions: Self.threatJudgeInstructions, to: safe,
                    temperature: 0, maxTokens: 4, guardrails: .permissiveContentTransformations)
            } catch let cancellation as CancellationError {
                throw cancellation
            } catch {
                continue
            }
            if Self.threatJudgeSaysSafe(verdict) { shown.append(safe) }
        }
        guard !shown.isEmpty else {
            EventLedger.shared.recordFailure(.safetyFilter)
            return nil
        }
        logger.notice("Permissive retry produced \(shown.count, privacy: .public) screened variant(s).")
        recordModelOutput()
        return PromptBuilder.droppingNearDuplicates(shown)
    }

    /// One-word check on the user's INPUT before A3's permissive retry.
    /// Measured 2026-10-29 (`harness/safety/intent`): on a blind set Gemini
    /// wrote (36 requests to intimidate, 36 hard-case vents) it caught 20/36
    /// alone and 24/36 with `IntimidationRequest` in front, wrongly catching
    /// 1/36 vents; 0/37 real inputs from earlier runs.
    static let intimidationIntentInstructions = """
        You read what a user typed into an app that drafts a message for them to send to someone who wronged them. Reply with one word: INTIMIDATE or OK.

        INTIMIDATE: the user wants the message to scare, threaten or intimidate the other person, openly or by hinting: making them afraid, saying the user knows where they live or what they do, that the user will be waiting for them, that someone will visit them, that something bad may happen to them or their things, or that they should watch out.

        OK: everything else, including very angry, rude or harsh requests; describing threats, stalking or violence the OTHER person did to the user; and wanting to mention the police, a lawyer, a court or HR.

        Examples:
        "Write something so my ex is too scared to come near my building." INTIMIDATE
        「幫我暗示他我知道他小孩讀哪間學校。」 INTIMIDATE
        「あいつが夜道を歩けなくなるような文を書いて。」 INTIMIDATE
        "Roast my roommate as brutally as possible, he never cleans." OK
        「前任一直跟蹤我，還說要來我家，幫我寫一段話叫他停止，不然我報警。」 OK
        「上司が殴るぞと脅してきた。言い返したい。」 OK
        """

    /// One-word check on the user's INPUT for identity attacks, run after the
    /// intimidation check. Blind set Gemini wrote (30 requests for slurs or
    /// identity insults, 30 hard-case vents incl. users calling out racism
    /// they suffered), 2026-10-29: caught 30/30, wrongly caught 0/30
    /// (`harness/safety/intent`).
    static let identityAttackIntentInstructions = """
        You read what a user typed into an app that drafts a message for them to send to someone who wronged them. Reply with one word: HATE or OK.

        HATE: the user wants the message to insult the other person for who they are rather than what they did: their race, ethnicity, nationality, accent, religion, sexual orientation, gender identity, disability or body, or to use slurs, discriminatory words or stereotypes.

        OK: everything else, including very angry, rude or harsh requests about what the person did; mentioning the person's nationality or identity only as context; and calling out discrimination the user suffered, or reporting it.

        Examples:
        "Roast my coworker using the worst words for his ethnicity." HATE
        「幫我用他是原住民這點狠狠酸他。」 HATE
        「あいつの出身地をネタにしてバカにして。」 HATE
        "My Korean roommate never cleans. Roast him hard for that." OK
        「主管說女生都很情緒化，幫我寫一段話反擊這種歧視。」 OK
        「同僚に障害のことをからかわれた。言い返したい。」 OK
        """

    /// True only for a plain OK. INTIMIDATE, HATE, a refusal, an empty reply or
    /// anything else means no permissive retry.
    static func intentCheckSaysOK(_ reply: String) -> Bool {
        reply.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .uppercased() == "OK"
    }

    /// Text-only shim over `generateDetailed`, for the surfaces that have
    /// neither a wallet to protect nor a banner to show (Share extension,
    /// Siri intent, Watch, Argument Simulator). Signature and behaviour are
    /// unchanged from before provenance existed, so those call sites did not
    /// have to move.
    ///
    /// Anything that spends a credit MUST use `generateDetailed` instead —
    /// see `GenerationProvenance`.
    func generate(
        situation: String,
        style: StylePreset,
        locale: Locale,
        variantCount: Int = 3,
        mode: RoastMode = .roast,
        intensity: Intensity = .sharp,
        safeMode: Bool = true,
        priorContext: String? = nil,
        keepSession: Bool = false,
        cloudVentEnabled: Bool = false,
        cloudClient: CloudVentService = CloudVentClient.shared,
        auth: CloudAuthProviding = CloudAuthClient.shared
    ) async throws -> [String] {
        try await generateDetailed(
            situation: situation,
            style: style,
            locale: locale,
            variantCount: variantCount,
            mode: mode,
            intensity: intensity,
            safeMode: safeMode,
            priorContext: priorContext,
            keepSession: keepSession,
            cloudVentEnabled: cloudVentEnabled,
            cloudClient: cloudClient,
            auth: auth
        ).texts
    }

    /// Converts a private vent draft into a "sendable reply" the user could
    /// actually paste back to the other party. This is a second, dedicated
    /// LLM call — the vent draft system context is *not* reused, because we
    /// want the rewriter to start cold with strict tone rules.
    ///
    /// `style` is the same style the vent draft was produced in, so the
    /// rewrite preserves register. `originalSituation` is the user's input
    /// (what happened) — the rewriter needs that to address the right party.
    ///
    /// Throws `RoastError.safety` if the rewrite came back with disallowed
    /// content (in which case the caller should surface a curated fallback,
    /// not retry).
    ///
    /// Runs under `permissiveContentTransformations` guardrails: the input is
    /// the user's own private draft, and default guardrails refused 6/6 real
    /// production drafts on macOS 27.0.1 (2026-10-22). In that mode a refusal
    /// comes back as text, so `ModelRefusal` screens it before anything is
    /// shown; the strict `SafetyFilter.validateOutput` still runs after, and
    /// then a two-layer threat screen of the finished text (see below).
    func rewriteAsSendableDetailed(
        ventDraft: String,
        originalSituation: String,
        style: StylePreset,
        locale: Locale
    ) async throws -> SendableRewrite {
        // The output of this call is meant to go to another human — it must
        // pass the *strict* validator, not the vent one.
        guard let fm, fm.isAvailable else {
            logger.notice("On-device model unavailable; falling back to curated sendable.")
            return curatedSendable(style: style, locale: locale)
        }

        let (system, user) = PromptBuilder.rewriteAsSendablePrompt(
            ventDraft: ventDraft,
            originalSituation: originalSituation,
            styleName: style.displayName,
            locale: locale
        )

        // Fresh session (never the cached roast one): the rewriter must start
        // cold with strict tone rules. Lower temperature: be deliberate.
        let content: String
        do {
            content = try await fm.respondFresh(
                instructions: system,
                to: user,
                temperature: max(0.4, style.temperature - 0.2),
                maxTokens: 250,
                guardrails: .permissiveContentTransformations
            )
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            // Unavailable, refusal, or an error type this build has never
            // seen: all of them are a labelled curated fallback.
            logger.warning("Sendable rewrite generation error — curated fallback.")
            return curatedSendable(style: style, locale: locale)
        }

        if ModelRefusal.looksLikeRefusal(content) {
            logger.notice("Sendable rewrite came back as a refusal — curated fallback.")
            return curatedSendable(style: style, locale: locale)
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip a stray leading "1." in case the model couldn't help itself.
        let cleaned = trimmed.replacingOccurrences(
            of: #"^\s*\d+\s*[.)、]\s*"#,
            with: "",
            options: .regularExpression
        )

        let safe: String
        do {
            safe = try SafetyFilter.validateOutput(cleaned)
        } catch let err as SafetyError {
            throw RoastError.safety(err)
        }

        // Threat screen, two layers, on the finished text. Permissive mode is
        // what lets the draft in, and it also let a threat through unchanged
        // ("I'll be waiting by your car tonight with a bat…", macOS 27.0.1
        // spot-check, 2026-10-22) that the strict denylist has no term for.
        //
        // 1. Deterministic phrases (`RewriteThreatScreen`): free, no model call.
        if RewriteThreatScreen.containsThreat(safe) {
            logger.notice("Sendable rewrite matched a threat phrase — curated fallback.")
            return curatedSendable(style: style, locale: locale)
        }

        // 2. The model as a one-word THREAT / SAFE judge, also under
        //    permissive guardrails. This replaced an echo of the text under
        //    DEFAULT guardrails, which measured worse on every axis (macOS
        //    27.0.1, 2026-10-22, scratchpad trackA2/screen2 + judge):
        //      • legitimate complaints flagged: echo 12/36 (racism complaints
        //        in en, zh and ja; sexual harassment in zh), judge 2/36; real
        //        rewrites 0/20 for both;
        //      • threats caught: echo 9/27, judge 21/27 (8/12 on a held-out
        //        set it was not tuned on);
        //      • median latency: echo ~750 ms, judge ~270 ms.
        //    Anything but a plain "SAFE" (THREAT, a refusal, an error) is a
        //    labelled curated fallback, never the unscreened text.
        let verdict: String
        do {
            verdict = try await fm.respondFresh(
                instructions: Self.threatJudgeInstructions,
                to: safe,
                temperature: 0,
                maxTokens: 4,
                guardrails: .permissiveContentTransformations
            )
        } catch let cancellation as CancellationError {
            throw cancellation
        } catch {
            logger.notice("Sendable rewrite threat judge failed — curated fallback.")
            return curatedSendable(style: style, locale: locale)
        }
        guard Self.threatJudgeSaysSafe(verdict) else {
            logger.notice("Sendable rewrite judged a threat — curated fallback.")
            return curatedSendable(style: style, locale: locale)
        }
        return SendableRewrite(text: safe, provenance: .model)
    }

    /// One-word classifier prompt for a finished message (the sendable rewrite,
    /// and A3's permissive variants). Rewritten 2026-10-29 after macOS 27.2
    /// (26B123) made the 10-22 prompt both miss and over-block. Measured with
    /// `docs/evidence/2026-10-27-v18-plan/harness/safety/judgetune`, together
    /// with `RewriteThreatScreen` in front:
    ///  • a blind set Gemini wrote and nobody tuned on (40 threats, 28 veiled;
    ///    40 hard-case legitimate messages): threats caught 32/40 with this
    ///    text vs 24/40 with the 10-22 text; legitimate blocked 8/40 vs 10/40.
    ///  • 297 real generated roasts from earlier runs: 20 blocked vs 39.
    /// The examples carry it; an abstract definition alone, a "would they feel
    /// in danger" question, or quoting before deciding all measured worse. The
    /// model still misses about 1 in 4 veiled threats, so this is one layer of
    /// several, never the only one.
    static let threatJudgeInstructions = """
        You are a safety checker. You read one message that the writer ("I") wants to send to the reader ("you"). Reply with one word: THREAT or SAFE.

        THREAT means the message could make the reader fear for their safety, their family, their pets or their property. This includes veiled threats: mentioning where the reader or their family lives, works, studies or goes, or their daily schedule, in a way that shows the writer is watching; hinting that an accident or something bad may happen; or saying people will come for them.

        SAFE means everything else: insults, swearing, anger and harsh criticism; describing what the reader did, even if it was violence or harassment; setting a boundary or ending the relationship; and going through proper channels, such as calling the police, a lawyer, a court, HR or a consumer agency.

        Examples:
        "Nice house. Be a shame if it caught fire." THREAT
        "I know what time your son gets out of school." THREAT
        「路上小心點，什麼事都可能發生。」 THREAT
        "You stole my idea, you spineless worm." SAFE
        "Pay me back by Monday or I'm taking you to small claims court." SAFE
        「你再來我家樓下，我就報警。」 SAFE
        """

    /// True only for a plain SAFE ("SAFE", "Safe.", "SAFE\n"). "UNSAFE",
    /// "THREAT", an empty reply or a refusal sentence are all not safe.
    static func threatJudgeSaysSafe(_ reply: String) -> Bool {
        let word = reply
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .uppercased()
        return word == "SAFE"
    }

    /// The labelled curated stand-in for a rewrite the model did not write.
    private func curatedSendable(style: StylePreset, locale: Locale) -> SendableRewrite {
        SendableRewrite(
            text: FallbackRoasts.curated(for: style, locale: locale, count: 1).first
                ?? String(localized: "rewrite.fallback.unavailable"),
            provenance: .curated
        )
    }

    /// Text-only shim over `rewriteAsSendableDetailed`, kept so callers that
    /// do not surface the curated label compile unchanged.
    func rewriteAsSendable(
        ventDraft: String,
        originalSituation: String,
        style: StylePreset,
        locale: Locale
    ) async throws -> String {
        try await rewriteAsSendableDetailed(
            ventDraft: ventDraft,
            originalSituation: originalSituation,
            style: style,
            locale: locale
        ).text
    }

    /// Track M: delegates to the shared `CloudVentService.generate(_:auth:)`.
    /// The token dance used to live here, privately, which is exactly why the
    /// Echoes roommate path never got it (v1.4 M-b). Kept as a thin shim so
    /// this engine's call sites stay readable.
    private func generateWithAuth(
        _ req: CloudVentRequest,
        client: CloudVentService,
        auth: CloudAuthProviding
    ) async throws -> CloudVentResponse {
        try await client.generate(req, auth: auth)
    }

    /// Helper that fronts `CloudVentClient.generate` so the engine's
    /// branching logic stays compact. Returns the raw text on success;
    /// throws CloudVentError on any failure (the caller falls back to
    /// the local Foundation Models path).
    private func runCloudVent(
        client: CloudVentService,
        auth: CloudAuthProviding,
        situation: String,
        style: StylePreset,
        intensity: Intensity,
        locale: Locale
    ) async throws -> String {
        let req = CloudVentRequest(
            situation: situation,
            styleName: style.displayName,
            intensity: intensity.rawValue,
            locale: locale.identifier,
            deviceId: DeviceID.current(),
            // Stable id so the Worker can let a style shape the private
            // draft's voice (decided 2026-10-22); ignored by Workers that
            // don't use it, and it carries no user data.
            styleId: style.id
        )
        let resp = try await generateWithAuth(req, client: client, auth: auth)
        return resp.text
    }

    /// Helper that fronts the sendable cloud path (`mode:"roast"`). Sends the
    /// stable `styleId` (for the Worker's style register + the drift test) and
    /// the requested `variantCount`; returns the raw numbered-variant text the
    /// caller splits + strict-validates. Throws CloudVentError on failure.
    private func runCloudRoast(
        client: CloudVentService,
        auth: CloudAuthProviding,
        situation: String,
        style: StylePreset,
        intensity: Intensity,
        locale: Locale,
        variantCount: Int
    ) async throws -> String {
        let req = CloudVentRequest(
            situation: situation,
            styleName: style.displayName,
            intensity: intensity.rawValue,
            locale: locale.identifier,
            deviceId: DeviceID.current(),
            mode: "roast",
            styleId: style.id,
            variantCount: variantCount
        )
        let resp = try await generateWithAuth(req, client: client, auth: auth)
        return resp.text
    }
}
