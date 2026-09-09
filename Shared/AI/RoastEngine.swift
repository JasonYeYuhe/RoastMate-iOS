import Foundation
import os.log

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

    init() {
        fm = FMBackendFactory.make()
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
                    let cloudText = try await runCloudVent(
                        client: cloudClient,
                        auth: auth,
                        situation: situation,
                        style: style,
                        intensity: intensity,
                        locale: locale
                    )
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
                    return GeneratedOutput(texts: [safe], provenance: .model)
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
                            provenance: .model
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
        } catch FMBackendError.generation(let category) {
            logger.warning("On-device generation error (\(String(describing: category), privacy: .public)).")
            EventLedger.shared.recordFailure(category)  // α3
            return GeneratedOutput(
                texts: curatedFallback(style: style, locale: locale, count: effectiveVariantCount),
                provenance: .curated
            )
        } catch FMBackendError.other(let underlying) {
            throw RoastError.generationFailed(underlying: underlying)
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
        EventLedger.shared.recordGeneration(cloud: false)  // A′
        EventLedger.shared.recordFirstGenerationOfSession()  // α3
        EventLedger.shared.markSuccessfulOutput()  // P5 Tier-1 — pay-timing flag
        RatingPromptService.shared.notifySuccessfulGeneration()  // ε1
        return GeneratedOutput(
            texts: Array(sanitized.prefix(effectiveVariantCount)),
            provenance: .model
        )
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
            return SendableRewrite(
                text: FallbackRoasts.curated(for: style, locale: locale, count: 1).first
                    ?? String(localized: "rewrite.fallback.unavailable"),
                provenance: .curated
            )
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
                maxTokens: 250
            )
        } catch FMBackendError.unavailable {
            logger.notice("On-device model unavailable; falling back to curated sendable.")
            return SendableRewrite(
                text: FallbackRoasts.curated(for: style, locale: locale, count: 1).first
                    ?? String(localized: "rewrite.fallback.unavailable"),
                provenance: .curated
            )
        } catch FMBackendError.generation {
            logger.warning("Sendable rewrite generation error.")
            return SendableRewrite(
                text: FallbackRoasts.curated(for: style, locale: locale, count: 1).first
                    ?? String(localized: "rewrite.fallback.unavailable"),
                provenance: .curated
            )
        } catch FMBackendError.other(let underlying) {
            throw RoastError.generationFailed(underlying: underlying)
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip a stray leading "1." in case the model couldn't help itself.
        let cleaned = trimmed.replacingOccurrences(
            of: #"^\s*\d+\s*[.)、]\s*"#,
            with: "",
            options: .regularExpression
        )

        do {
            return SendableRewrite(
                text: try SafetyFilter.validateOutput(cleaned),
                provenance: .model
            )
        } catch let err as SafetyError {
            throw RoastError.safety(err)
        }
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
            deviceId: DeviceID.current()
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
