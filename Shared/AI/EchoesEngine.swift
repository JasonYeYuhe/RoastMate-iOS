import Foundation
import os.log

/// Top-level engine for an Echoes transcript generation. Composes the
/// existing `RoastEngine` for low-level on-device generation; routes
/// Feral tone through cloud ONLY if the user granted the dedicated
/// `echoesFeralConsent` (separate from the existing `cloudConsent`
/// surface — Codex P0 audit catch on v2 plan).
///
/// Two scenes (see `EchoScene`): `.classic` = the shipped 1–2 voice
/// 替你出气; `.roommateGroup` = the 3-voice 虚拟舍友群 (Echoes vNext), gated
/// behind its own dark-by-default `roommate_group_enabled` flag (ANDed with
/// `echoes_enabled`).
///
/// All exit paths return a complete `EchoTranscript`. On parse failure or
/// model error, falls back to a curated static transcript (scene-matched)
/// and fires the scene's parse-fallback counter so we can measure parser
/// robustness. Always fires `markSuccessfulOutput()` because the user
/// always sees SOMETHING (regulation-tool framing: even fallback is relief).
actor EchoesEngine {
    static let shared = EchoesEngine()

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "EchoesEngine")
    /// Cloud Worker client — the 虚拟舍友群 scene routes through it (Apple's
    /// on-device FM blocks the harsh group-roast). Injectable for tests.
    private let cloudClient: CloudVentService

    /// Apple on-device backend, or `nil` on devices without Foundation Models
    /// (iOS 18 / macOS 14 / watchOS / AI off). Classic Echoes uses it; the
    /// roommate scene is cloud-only and ignores it.
    private nonisolated let fm: (any FMBackend)?

    init(cloudClient: CloudVentService = CloudVentClient.shared) {
        self.cloudClient = cloudClient
        self.fm = FMBackendFactory.make()
    }

    /// Caller-provided contract. The view layer decides tone / voiceCount /
    /// locale / scene and passes the resolved consent state. The engine does
    /// NOT mutate UserSettings — that stays in the view-layer consent flow.
    func generate(
        situation: String,
        tone: EchoTone,
        voiceCount: EchoVoiceCount,
        locale: Locale,
        feralCloudGranted: Bool,
        scene: EchoScene = .classic
    ) async throws -> EchoTranscript {
        // Remote kill-switch (health audit 2026-05-29 §4): read ONE config
        // snapshot at entry and let it govern BOTH the feature guard and the
        // cloud-routing gate, so there is no split-snapshot TOCTOU between
        // the view-model's read and the engine's (Gemini review 2026-05-29).
        // Lock-free App-Group read — no main-actor hop from this actor.
        let remoteConfig = RemoteConfigValues.cached()
        // Defense-in-depth: the Explore tile is hidden when echoes is
        // disabled remotely, so this guard only fires for an in-flight /
        // mid-session flip.
        guard remoteConfig.echoesEnabled else {
            throw EchoesGenerationError.featureDisabled
        }
        // The 虚拟舍友群 scene has its own dark-by-default flag (ANDed with
        // echoes). Its entry is hidden when disabled, so this guard is the
        // mid-session-flip / defense-in-depth case.
        if scene == .roommateGroup && !remoteConfig.roommateGroupAllowed {
            throw EchoesGenerationError.featureDisabled
        }

        // Input safety pass — reuse the existing strict filter; same rules
        // as the rewrite tool.
        try SafetyFilter.validateInput(situation)

        // The roommate scene is always 3 voices, regardless of the caller's
        // value; classic honours the 1/2 selection.
        let effectiveVoiceCount: EchoVoiceCount = (scene == .roommateGroup) ? .three : voiceCount

        let personas = EchoesPersonaCatalog.selectPersonas(
            locale: locale, voiceCount: effectiveVoiceCount, scene: scene
        )

        // 虚拟舍友群 is CLOUD-ONLY: Apple's on-device FM blocks the harsh
        // group-roast (guardrailViolation — 2026-06-06 eval; cloud validated at
        // 10% parse-fallback). Route it through the Worker (mode=roommate).
        // Classic Echoes stays on-device below.
        if scene == .roommateGroup {
            return try await generateRoommateViaCloud(
                situation: situation, tone: tone, locale: locale,
                personas: personas, feralCloudGranted: feralCloudGranted,
                remoteConfig: remoteConfig
            )
        }

        // RESTRICT-only remote gate folded into the cloud decision from the
        // SAME snapshot above: feral tone + dedicated consent + worker
        // configured + kill-switch allows cloud. `feralCloudGranted` is the
        // raw consent bool; `cloudAllowed` ANDs in `vent_cloud_enabled` /
        // `!force_local_only` (can only subtract, never expand).
        let cloudPath = (tone == .feral)
            && remoteConfig.cloudAllowed(consentAllowsCloud: feralCloudGranted)
            && CloudConfig.isConfigured
        // v1 keeps cloud OFF until the dedicated CloudVent path is extended
        // for the transcript-shape output. Feral falls back to on-device
        // which still produces stronger output than Casual because the
        // prompt's register line opens the lane.
        // TODO v0.2: wire cloud routing through CloudVentService.
        let useCloud = false  // explicit: cloud is gated v1 even when consented
        _ = cloudPath

        let prompt = EchoesPromptBuilder.systemPrompt(
            tone: tone,
            voiceCount: effectiveVoiceCount,
            personas: personas,
            locale: locale,
            scene: scene
        )
        let user = EchoesPromptBuilder.userPrompt(situation: situation, scene: scene)

        var messages: [EchoMessage] = []
        // v1: cloud routing is gated off (useCloud=false), so this never
        // flips. Kept (with `|| useCloud`) so v0.2's cloud wire-up sets it.
        let cloudUsed = false

        if let fm, fm.isAvailable {
            do {
                // v1 keeps the 600-token cap for BOTH scenes per the roommate
                // spec (§7: don't raise by guess — let the real-device eval
                // decide if 8–10 messages need more headroom). Fresh session
                // each call (classic Echoes never reuses context).
                let content = try await fm.respondFresh(
                    instructions: prompt,
                    to: user,
                    temperature: tone == .feral ? 0.95 : 0.85,
                    maxTokens: 600
                )
                if let parsed = EchoesParser.parse(content, scene: scene),
                   let safe = Self.safetyFilter(parsed, tone: tone) {
                    messages = safe
                } else {
                    // Parser rejected the output OR a line tripped the safety
                    // hard-rail — either way the model output is unusable, so
                    // fall back to the (scene-matched) curated transcript.
                    logger.warning("Echoes model output unusable (parse or safety) — falling back to curated transcript.")
                    recordParseFallback(scene: scene)
                    messages = curatedFallback(scene: scene, tone: tone, voiceCount: effectiveVoiceCount, personas: personas)
                }
            } catch {
                logger.warning("Echoes FM generation error — falling back to curated transcript.")
                recordParseFallback(scene: scene)
                messages = curatedFallback(scene: scene, tone: tone, voiceCount: effectiveVoiceCount, personas: personas)
            }
        } else {
            // Model UNAVAILABLE (AI off / unsupported device / iOS 18 with no
            // FM backend) — this is NOT a parse failure; we never attempted a
            // generation. Counting it as parse_fallback would falsely trip the
            // kill-criterion on every AI-off device. (Health audit 2026-05-29.)
            logger.notice("On-device model unavailable — using curated Echoes fallback.")
            EventLedger.shared.recordEchoesModelUnavailable()
            messages = curatedFallback(scene: scene, tone: tone, voiceCount: effectiveVoiceCount, personas: personas)
        }

        // Always mark a successful output — even curated fallback is
        // user-perceived relief. Same rule as `RoastEngine.curatedFallback`
        // from v1.0.5 audit.
        EventLedger.shared.markSuccessfulOutput()

        return EchoTranscript(
            situation: situation,
            tone: tone,
            voiceCount: effectiveVoiceCount,
            scene: scene,
            echoes: personas,
            messages: messages,
            cloudUsed: cloudUsed || useCloud,
            locale: locale
        )
    }

    /// 虚拟舍友群 (Option A): generate the 3-voice transcript via the cloud
    /// Worker (`mode=roommate`). Cloud consent is REQUIRED (no on-device
    /// fallback for this scene); the UI obtains it before calling, so a missing
    /// grant throws `.consentDenied` → the view shows the consent sheet. Any
    /// cloud failure degrades to the curated transcript so the user is never
    /// blocked. Only a cloud response that fails the strict parser counts as a
    /// parse-fallback (network/capacity errors don't pollute the rate).
    private func generateRoommateViaCloud(
        situation: String,
        tone: EchoTone,
        locale: Locale,
        personas: [EchoSpec],
        feralCloudGranted: Bool,
        remoteConfig: RemoteConfigValues
    ) async throws -> EchoTranscript {
        // Marketing-screenshot fixture: render an exact hand-picked transcript
        // (the judged-best real cloud generation) instead of a live roll, so
        // captures are deterministic. UI-test launch arg only; never set in
        // production. Parsed by the same strict contract the cloud path uses.
        if let fixture = AppLaunchEnvironment.uiTestRoommateFixture,
           let parsed = EchoesParser.parse(fixture, scene: .roommateGroup) {
            EventLedger.shared.markSuccessfulOutput()
            return EchoTranscript(
                situation: situation, tone: tone, voiceCount: .three, scene: .roommateGroup,
                echoes: personas, messages: parsed, cloudUsed: true, locale: locale
            )
        }
        guard feralCloudGranted else {
            throw EchoesGenerationError.consentDenied
        }
        // Consent granted. If the Worker isn't configured or the remote
        // kill-switch forces local / disables cloud, we can't do a real
        // generation — serve the curated transcript rather than block.
        let cloudReachable = CloudConfig.isConfigured
            && remoteConfig.cloudAllowed(consentAllowsCloud: true)

        var messages: [EchoMessage]
        var cloudUsed = false
        if cloudReachable {
            do {
                let req = CloudVentRequest(
                    situation: situation,
                    styleName: nil,
                    intensity: (tone == .feral) ? "feral" : "vent",
                    locale: locale.identifier,
                    deviceId: DeviceID.current(),
                    mode: "roommate"
                )
                let resp = try await cloudClient.generate(req)
                if let parsed = EchoesParser.parse(resp.text, scene: .roommateGroup),
                   let safe = Self.safetyFilter(parsed, tone: tone) {
                    messages = safe
                    cloudUsed = true
                } else {
                    // Cloud returned text but it failed the strict contract —
                    // a real parse fallback (the metric that gates the feature).
                    logger.warning("Roommate cloud output unusable (parse or safety) — curated fallback.")
                    EventLedger.shared.recordRoommateGroupParseFallback()
                    messages = FallbackRoasts.curatedRoommateTranscript(tone: tone, personas: personas)
                }
            } catch {
                // Network / rate-limit / cloud error (no text) — a connectivity
                // / capacity issue, NOT a parse failure. Curated fallback,
                // WITHOUT polluting the parse-fallback rate.
                logger.warning("Roommate cloud error — curated fallback: \(error.localizedDescription, privacy: .public)")
                messages = FallbackRoasts.curatedRoommateTranscript(tone: tone, personas: personas)
            }
        } else {
            logger.notice("Roommate cloud unreachable (config/remote) — curated fallback.")
            messages = FallbackRoasts.curatedRoommateTranscript(tone: tone, personas: personas)
        }

        EventLedger.shared.markSuccessfulOutput()
        return EchoTranscript(
            situation: situation, tone: tone, voiceCount: .three, scene: .roommateGroup,
            echoes: personas, messages: messages, cloudUsed: cloudUsed, locale: locale
        )
    }

    /// Scene-matched curated fallback (parser rejection / FM error / FM
    /// unavailable). Classic returns the 4–6 msg transcript; roommate the
    /// 8-msg 3-voice one.
    private func curatedFallback(
        scene: EchoScene, tone: EchoTone,
        voiceCount: EchoVoiceCount, personas: [EchoSpec]
    ) -> [EchoMessage] {
        switch scene {
        case .classic:
            return FallbackRoasts.curatedEchoTranscript(tone: tone, voiceCount: voiceCount, personas: personas)
        case .roommateGroup:
            return FallbackRoasts.curatedRoommateTranscript(tone: tone, personas: personas)
        }
    }

    /// Scene-specific parse-fallback counter so the roommate group's
    /// <15%/35% kill-criterion rate stays separate from classic Echoes.
    private func recordParseFallback(scene: EchoScene) {
        switch scene {
        case .classic:       EventLedger.shared.recordEchoesParseFallback()
        case .roommateGroup: EventLedger.shared.recordRoommateGroupParseFallback()
        }
    }

    /// Safety + bridge-intensity pass over parsed Echoes messages — parity
    /// with RoastEngine's OUTPUT contract (input is already filtered by
    /// `SafetyFilter.validateInput`; this filters the model's *output* too).
    /// Each line goes through `SafetyFilter.validateVentOutput`: the
    /// savage/profane venting register is allowed, but the self-harm /
    /// explicit-violence hard-rail is not. Returns `nil` if ANY line trips
    /// the hard-rail, so the caller drops the whole transcript to the curated
    /// fallback (same handling as a parse rejection). Also injects the
    /// tone-derived bridge intensity (the model no longer tags it).
    /// Codex pre-ship audit 2026-05-29.
    static func safetyFilter(_ parsed: [EchoMessage], tone: EchoTone) -> [EchoMessage]? {
        var out: [EchoMessage] = []
        out.reserveCapacity(parsed.count)
        for msg in parsed {
            guard let safeText = try? SafetyFilter.validateVentOutput(msg.text) else {
                return nil
            }
            let intensity = (msg.role == .bridge && msg.bridgeIntensity == nil)
                ? tone.bridgeIntensity : msg.bridgeIntensity
            out.append(EchoMessage(
                id: msg.id, echoIndex: msg.echoIndex, role: msg.role,
                text: safeText, deliveryDelayMs: msg.deliveryDelayMs,
                bridgeIntensity: intensity
            ))
        }
        return out
    }
}
