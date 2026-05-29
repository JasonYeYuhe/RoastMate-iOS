import Foundation
import os.log
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Top-level engine for an Echoes transcript generation. Composes the
/// existing `RoastEngine` for low-level on-device generation; routes
/// Feral tone through cloud ONLY if the user granted the dedicated
/// `echoesFeralConsent` (separate from the existing `cloudConsent`
/// surface — Codex P0 audit catch on v2 plan).
///
/// All exit paths return a complete `EchoTranscript`. On parse failure
/// or model error, falls back to a curated static transcript via
/// `FallbackRoasts.curatedEchoTranscript` and fires the
/// `echoes_parse_fallback` counter so we can measure parser robustness.
/// Always fires `markSuccessfulOutput()` because the user always sees
/// SOMETHING (regulation-tool framing: even fallback is relief).
actor EchoesEngine {
    static let shared = EchoesEngine()

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "EchoesEngine")

    #if canImport(FoundationModels)
    private var session: LanguageModelSession?
    #endif

    /// Caller-provided contract. The view layer decides tone /
    /// voiceCount / locale and passes the resolved consent state. The
    /// engine does NOT mutate UserSettings — that stays in the
    /// view-layer consent flow.
    func generate(
        situation: String,
        tone: EchoTone,
        voiceCount: EchoVoiceCount,
        locale: Locale,
        feralCloudGranted: Bool
    ) async throws -> EchoTranscript {
        // Input safety pass — reuse the existing strict filter; same
        // rules as the rewrite tool.
        try SafetyFilter.validateInput(situation)

        let personas = EchoesPersonaCatalog.selectPersonas(locale: locale, voiceCount: voiceCount)

        let cloudPath = (tone == .feral) && feralCloudGranted && CloudConfig.isConfigured
        // v1 keeps cloud OFF until the dedicated CloudVent path is
        // extended for the transcript-shape output. Feral falls back to
        // on-device which still produces stronger output than Casual
        // because the prompt's register line opens the lane.
        // TODO v0.2: wire cloud routing through CloudVentService with
        // an EchoesCloudRequest variant.
        let useCloud = false  // explicit: cloud is gated v1 even when consented
        _ = cloudPath

        let prompt = EchoesPromptBuilder.systemPrompt(
            tone: tone,
            voiceCount: voiceCount,
            personas: personas,
            locale: locale
        )
        let user = EchoesPromptBuilder.userPrompt(situation: situation)

        var messages: [EchoMessage] = []
        var cloudUsed = false

        #if canImport(FoundationModels)
        if SystemLanguageModel.default.availability == .available {
            do {
                let s = LanguageModelSession(instructions: prompt)
                session = s
                let response = try await s.respond(
                    to: user,
                    options: GenerationOptions(temperature: tone == .feral ? 0.95 : 0.85, maximumResponseTokens: 600)
                )
                if let parsed = EchoesParser.parse(response.content) {
                    // The model no longer tags the bridge with a register
                    // suffix; inject the tone-derived intensity so the
                    // Bridge-to-Action deep link still carries a register.
                    messages = parsed.map { msg in
                        guard msg.role == .bridge, msg.bridgeIntensity == nil else { return msg }
                        return EchoMessage(
                            id: msg.id, echoIndex: msg.echoIndex, role: msg.role,
                            text: msg.text, deliveryDelayMs: msg.deliveryDelayMs,
                            bridgeIntensity: tone.bridgeIntensity
                        )
                    }
                } else {
                    logger.warning("Echoes parser rejected model output — falling back to curated transcript.")
                    EventLedger.shared.recordEchoesParseFallback()
                    messages = FallbackRoasts.curatedEchoTranscript(
                        tone: tone, voiceCount: voiceCount, personas: personas
                    )
                }
            } catch {
                logger.warning("Echoes FM generation error — falling back to curated transcript.")
                EventLedger.shared.recordEchoesParseFallback()
                messages = FallbackRoasts.curatedEchoTranscript(
                    tone: tone, voiceCount: voiceCount, personas: personas
                )
            }
        } else {
            logger.notice("Foundation Models unavailable — using curated Echoes fallback.")
            EventLedger.shared.recordEchoesParseFallback()
            messages = FallbackRoasts.curatedEchoTranscript(
                tone: tone, voiceCount: voiceCount, personas: personas
            )
        }
        #else
        EventLedger.shared.recordEchoesParseFallback()
        messages = FallbackRoasts.curatedEchoTranscript(
            tone: tone, voiceCount: voiceCount, personas: personas
        )
        #endif

        // Always mark a successful output — even curated fallback is
        // user-perceived relief. Same rule as `RoastEngine.curatedFallback`
        // from v1.0.5 audit.
        EventLedger.shared.markSuccessfulOutput()

        return EchoTranscript(
            situation: situation,
            tone: tone,
            voiceCount: voiceCount,
            echoes: personas,
            messages: messages,
            cloudUsed: cloudUsed || useCloud,
            locale: locale
        )
    }
}
