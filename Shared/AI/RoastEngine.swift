import Foundation
import os.log
#if canImport(FoundationModels)
import FoundationModels
#endif

enum RoastError: LocalizedError {
    case modelUnavailable(reason: String)
    case generationFailed(underlying: Error)
    case noVariantsParsed
    case safety(SafetyError)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let reason):
            return String(localized: "roast.error.unavailable") + " (\(reason))"
        case .generationFailed(let underlying):
            return underlying.localizedDescription
        case .noVariantsParsed:
            return String(localized: "roast.error.no_variants")
        case .safety(let safetyErr):
            return safetyErr.errorDescription
        }
    }
}

/// Wraps Apple's on-device `LanguageModelSession`. Keeps one session per
/// (style, mode, intensity) so a vent draft and a regular sharp reply
/// don't accidentally bleed into the same conversational context.
actor RoastEngine {
    static let shared = RoastEngine()

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "RoastEngine")

    #if canImport(FoundationModels)
    private var currentSession: LanguageModelSession?
    private var currentSessionKey: String?
    #endif

    /// True when the on-device model is ready to use on this device + locale.
    static var isOnDeviceModelAvailable: Bool {
        #if canImport(FoundationModels)
        return SystemLanguageModel.default.availability == .available
        #else
        return false
        #endif
    }

    func resetConversation() {
        #if canImport(FoundationModels)
        currentSession = nil
        currentSessionKey = nil
        #endif
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
    /// Returns curated fallback content if Foundation Models is unavailable.
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
        // 5.1.2(i) defense-in-depth: defaults to FALSE so any caller that
        // does not explicitly pass a consent-resolved value can never
        // silently route the user's text to the third-party cloud. Only
        // the consent-gated generator path passes `true`.
        cloudVentEnabled: Bool = false,
        cloudClient: CloudVentService = CloudVentClient.shared
    ) async throws -> [String] {
        do {
            try SafetyFilter.validateInput(situation)
        } catch let err as SafetyError {
            throw RoastError.safety(err)
        }

        // Private draft intensities always return a single draft; we ignore caller-supplied counts.
        let effectiveVariantCount = intensity.isPrivateDraft ? 1 : variantCount

        // Cloud branch: only for private drafts (vent + feral), only when
        // the developer has actually configured a Worker URL, and only
        // when the user hasn't opted out. Any failure here falls through
        // to the local path so a network blip never blocks a vent.
        if intensity.isPrivateDraft,
           cloudVentEnabled,
           CloudConfig.isConfigured {
            do {
                let cloudText = try await runCloudVent(
                    client: cloudClient,
                    situation: situation,
                    style: style,
                    intensity: intensity,
                    locale: locale
                )
                // Cloud output must clear the SAME vent safety bar as
                // local output. Use `try` (not `try?`) so a hard-rail
                // violation (slur / threat of violence / self-harm)
                // throws and we fall through to the local path —
                // never return raw unfiltered cloud text. The earlier
                // `(try? …) ?? cloudText` form silently shipped
                // disallowed content on a safety failure.
                let safe = try SafetyFilter.validateVentOutput(cloudText)
                EventLedger.shared.recordGeneration(cloud: true)  // A′
                RatingPromptService.shared.notifySuccessfulGeneration()  // ε1
                return [safe]
            } catch let err as CloudVentError {
                logger.notice("Cloud vent failed (\(String(describing: err), privacy: .public)) — falling back to local model.")
                // continue to local path below
            } catch is SafetyError {
                logger.notice("Cloud vent output tripped the safety filter — discarding it and falling back to local model.")
                // continue to local path below
            } catch {
                logger.notice("Cloud vent unexpected error — falling back to local model.")
            }
        }

        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.availability == .available else {
            logger.notice("Foundation Models unavailable; using curated fallback.")
            return FallbackRoasts.curated(for: style, locale: locale, count: effectiveVariantCount)
        }

        let key = "\(style.id)|\(locale.identifier)|\(mode.rawValue)|\(intensity.rawValue)"
        if !keepSession || currentSessionKey != key || currentSession == nil {
            let instructions = PromptBuilder.systemPrompt(
                style: style,
                locale: locale,
                mode: mode,
                intensity: intensity,
                safeMode: safeMode
            )
            currentSession = LanguageModelSession(instructions: instructions)
            currentSessionKey = key
        }
        guard let session = currentSession else {
            return FallbackRoasts.curated(for: style, locale: locale, count: effectiveVariantCount)
        }

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

        let response: LanguageModelSession.Response<String>
        do {
            response = try await session.respond(
                to: user,
                options: GenerationOptions(
                    temperature: temperature,
                    maximumResponseTokens: 600
                )
            )
        } catch let genErr as LanguageModelSession.GenerationError {
            logger.warning("Foundation Models generation error: \(String(describing: genErr))")
            return FallbackRoasts.curated(for: style, locale: locale, count: effectiveVariantCount)
        } catch {
            throw RoastError.generationFailed(underlying: error)
        }

        let split = PromptBuilder.splitVariants(response.content)
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
            return FallbackRoasts.curated(for: style, locale: locale, count: effectiveVariantCount)
        }
        EventLedger.shared.recordGeneration(cloud: false)  // A′
        RatingPromptService.shared.notifySuccessfulGeneration()  // ε1
        return Array(sanitized.prefix(effectiveVariantCount))
        #else
        return FallbackRoasts.curated(for: style, locale: locale, count: effectiveVariantCount)
        #endif
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
    func rewriteAsSendable(
        ventDraft: String,
        originalSituation: String,
        style: StylePreset,
        locale: Locale
    ) async throws -> String {
        // The output of this call is meant to go to another human — it must
        // pass the *strict* validator, not the vent one.
        #if canImport(FoundationModels)
        guard SystemLanguageModel.default.availability == .available else {
            logger.notice("Foundation Models unavailable; falling back to curated sendable.")
            return FallbackRoasts.curated(for: style, locale: locale, count: 1).first
                ?? String(localized: "rewrite.fallback.unavailable")
        }

        let (system, user) = PromptBuilder.rewriteAsSendablePrompt(
            ventDraft: ventDraft,
            originalSituation: originalSituation,
            styleName: style.displayName,
            locale: locale
        )

        let session = LanguageModelSession(instructions: system)
        let response: LanguageModelSession.Response<String>
        do {
            response = try await session.respond(
                to: user,
                options: GenerationOptions(
                    // Lower temperature: rewriter should be deliberate.
                    temperature: max(0.4, style.temperature - 0.2),
                    maximumResponseTokens: 250
                )
            )
        } catch let genErr as LanguageModelSession.GenerationError {
            logger.warning("Sendable rewrite generation error: \(String(describing: genErr))")
            return FallbackRoasts.curated(for: style, locale: locale, count: 1).first
                ?? String(localized: "rewrite.fallback.unavailable")
        } catch {
            throw RoastError.generationFailed(underlying: error)
        }

        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip a stray leading "1." in case the model couldn't help itself.
        let cleaned = trimmed.replacingOccurrences(
            of: #"^\s*\d+\s*[.)、]\s*"#,
            with: "",
            options: .regularExpression
        )

        do {
            return try SafetyFilter.validateOutput(cleaned)
        } catch let err as SafetyError {
            throw RoastError.safety(err)
        }
        #else
        return FallbackRoasts.curated(for: style, locale: locale, count: 1).first
            ?? String(localized: "rewrite.fallback.unavailable")
        #endif
    }

    /// Helper that fronts `CloudVentClient.generate` so the engine's
    /// branching logic stays compact. Returns the raw text on success;
    /// throws CloudVentError on any failure (the caller falls back to
    /// the local Foundation Models path).
    private func runCloudVent(
        client: CloudVentService,
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
            deviceId: DeviceID.current()
        )
        let resp = try await client.generate(req)
        return resp.text
    }
}
