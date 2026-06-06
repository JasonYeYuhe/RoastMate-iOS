import Foundation
import SwiftData
import os.log

/// Drives the Echoes (替你出气) feature: setup → generate → reveal.
/// Pro-gated; calls `EchoesEngine` for the actual transcript and
/// `HistoryService.saveEchoTranscript` to persist.
///
/// Reused for the 虚拟舍友群 (roommate group) scene via `scene`: same flow,
/// but cloud-only (so it ALWAYS needs cloud consent) and fixed at 3 voices.
@MainActor
@Observable
final class EchoesViewModel {
    enum Phase {
        case setup
        case generating
        case revealing(EchoTranscript)
        case done(EchoTranscript)
        case error(String)
    }

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "EchoesViewModel")

    /// `.classic` (替你出气) or `.roommateGroup` (虚拟舍友群, cloud-only). Fixed
    /// at init by the entry tile; drives cloud routing + the always-consent
    /// gate + which telemetry counters fire.
    let scene: EchoScene

    // Setup input.
    var situation: String = ""
    var tone: EchoTone = .casual
    var voiceCount: EchoVoiceCount = .two

    // Phase / output.
    var phase: Phase = .setup
    var visibleMessages: [EchoMessage] = []
    var hasRegenerated: Bool = false  // single regenerate per session — v2 plan §2 anti-slot-machine

    init(scene: EchoScene = .classic) {
        self.scene = scene
        if scene == .roommateGroup { voiceCount = .three }  // roommate is always 3 voices
    }

    /// Which modal the view should present. The VM owns this directly so
    /// there is NO `.onChange` mirror race: `generate()` sets
    /// `activeSheet = .feralConsent` synchronously on the main actor, and
    /// the view's single `.sheet(item:)` reacts to it. (An earlier
    /// design mirrored a `pendingFeralConsentRequest` Bool into a view
    /// `@State` via `.onChange`, which SwiftUI dropped when the mutation
    /// landed in the same render pass — the consent sheet never showed.
    /// Caught by EchoesFlowUITests 2026-05-29.)
    enum ActiveSheet: Identifiable, Equatable {
        case paywall
        case feralConsent
        var id: Int { hashValue }
    }
    var activeSheet: ActiveSheet?

    // Telemetry hook — fires once per generation session.
    func startSession() {
        if scene == .roommateGroup {
            EventLedger.shared.recordRoommateGroupStarted()
        } else {
            EventLedger.shared.recordEchoesSessionStarted()
        }
    }

    /// Kick off generation. Caller must have already resolved
    /// Pro-gating; this method does NOT show the paywall.
    func generate(
        locale: Locale,
        currentFeralConsent: CloudConsent,
        cloudConfigured: Bool,
        modelContext: ModelContext,
        isPro: Bool
    ) async {
        // Re-entrancy guard: a second tap (or a tap racing the consent
        // grant on a large/iPad layout where the setup button stays
        // tappable behind the sheet) could launch two concurrent
        // EchoesEngine runs → two transcripts, double `echoes_completed`
        // + double `markSuccessfulOutput`. Block any call while a
        // generation/reveal is in flight. (Codex audit 2026-05-29 #1.)
        // The consent re-call path is safe: it returns at the gate with
        // phase still `.setup` before this guard matters.
        if case .generating = phase { return }
        if case .revealing = phase { return }

        // Resolve cloud consent. Feral (classic) needs it; the roommate scene
        // is cloud-ONLY so it ALWAYS needs it (treat it as feral for the gate
        // regardless of the chosen register).
        if tone == .feral || scene == .roommateGroup {
            let gate = EchoesFeralConsentGate.decide(
                tone: scene == .roommateGroup ? .feral : tone,
                cloudConfigured: cloudConfigured,
                consent: currentFeralConsent
            )
            if gate == .needsConsent {
                // Present the consent sheet directly via VM-owned state —
                // synchronous on the main actor, no .onChange mirror. The
                // view rewrites `currentFeralConsent` on the user's choice
                // and re-calls `generate()` with the new state.
                activeSheet = .feralConsent
                return
            }
        }

        phase = .generating
        visibleMessages = []

        do {
            // Pass the RAW dedicated-Feral consent. EchoesEngine applies the
            // remote kill-switch gate (`force_local_only` / `vent_cloud_enabled`)
            // against its OWN single config snapshot, so the feature guard and
            // the cloud decision can't read mismatched snapshots (no TOCTOU —
            // Gemini review 2026-05-29). Still RESTRICT-only end to end.
            let granted = (currentFeralConsent == .granted)
            let transcript = try await EchoesEngine.shared.generate(
                situation: situation,
                tone: tone,
                voiceCount: voiceCount,
                locale: locale,
                feralCloudGranted: granted,
                scene: scene
            )
            // Persist immediately. Animation drives the reveal but the
            // record is durable from generation-complete onward.
            HistoryService.saveEchoTranscript(transcript, context: modelContext, isPro: isPro)
            phase = .revealing(transcript)
            await revealMessages(transcript)
            phase = .done(transcript)
            if scene == .roommateGroup {
                EventLedger.shared.recordRoommateGroupCompleted()
            } else {
                EventLedger.shared.recordEchoesCompleted()
            }
        } catch let err as EchoesGenerationError {
            switch err {
            case .consentDenied:
                phase = .setup
            case .featureDisabled:
                // Remote kill-switch disabled the feature (the tile is also
                // hidden, so this is the rare in-flight case). Not a
                // warning — surface the generic error rather than silently
                // bouncing to setup, which would read as a no-op bug.
                phase = .error(String(localized: "echoes.error.generic"))
            default:
                logger.warning("Echoes generation error: \(String(describing: err))")
                phase = .error(String(localized: "echoes.error.generic"))
            }
        } catch {
            logger.warning("Echoes unexpected error: \(error.localizedDescription)")
            phase = .error(String(localized: "echoes.error.generic"))
        }
    }

    private func revealMessages(_ transcript: EchoTranscript) async {
        for msg in transcript.messages {
            try? await Task.sleep(nanoseconds: UInt64(msg.deliveryDelayMs) * 1_000_000)
            visibleMessages.append(msg)
        }
    }

    func regenerate(
        locale: Locale,
        currentFeralConsent: CloudConsent,
        cloudConfigured: Bool,
        modelContext: ModelContext,
        isPro: Bool
    ) async {
        guard !hasRegenerated else { return }
        hasRegenerated = true
        if scene == .roommateGroup {
            EventLedger.shared.recordRoommateGroupRegenerated()
        } else {
            EventLedger.shared.recordEchoesRegenerated()
        }
        await generate(
            locale: locale,
            currentFeralConsent: currentFeralConsent,
            cloudConfigured: cloudConfigured,
            modelContext: modelContext,
            isPro: isPro
        )
    }

    /// Called from the view when the user taps the bridge CTA. Stages
    /// the deep-link payload on EchoBridgeStore and tells the parent
    /// to switch to the Generator tab.
    func tapBridge(message: EchoMessage) {
        guard message.role == .bridge else { return }
        // Default to .sharp rather than no-op'ing if the intensity is
        // somehow nil — a bridge bubble must never be a dead tap. (The
        // engine injects tone-derived intensity after parsing, and the
        // curated fallback sets it too, so nil shouldn't happen — but a
        // silent dead bridge would be the worst failure mode.)
        let intensity = message.bridgeIntensity ?? .sharp
        EchoBridgeStore.shared.pending = EchoBridgeStore.Payload(
            situation: situation,
            suggestedIntensity: intensity
        )
        if scene == .roommateGroup {
            EventLedger.shared.recordRoommateGroupBridgeTapped()
        } else {
            EventLedger.shared.recordEchoesBridgeTap()
        }
    }

    func reset() {
        situation = ""
        tone = .casual
        voiceCount = (scene == .roommateGroup) ? .three : .two
        phase = .setup
        visibleMessages = []
        hasRegenerated = false
    }
}
