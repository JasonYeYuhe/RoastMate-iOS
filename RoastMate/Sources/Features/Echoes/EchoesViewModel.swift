import Foundation
import SwiftData
import os.log

/// Drives the Echoes (替你出气) feature: setup → generate → reveal.
/// Pro-gated; calls `EchoesEngine` for the actual transcript and
/// `HistoryService.saveEchoTranscript` to persist.
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

    // Setup input.
    var situation: String = ""
    var tone: EchoTone = .casual
    var voiceCount: EchoVoiceCount = .two

    // Phase / output.
    var phase: Phase = .setup
    var visibleMessages: [EchoMessage] = []
    var hasRegenerated: Bool = false  // single regenerate per session — v2 plan §2 anti-slot-machine

    // Consent sheet flag (driven from view).
    var pendingFeralConsentRequest: Bool = false

    // Telemetry hook — fires once per generation session.
    func startSession() {
        EventLedger.shared.recordEchoesSessionStarted()
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
        // Resolve consent for Feral.
        if tone == .feral {
            let gate = EchoesFeralConsentGate.decide(
                tone: tone,
                cloudConfigured: cloudConfigured,
                consent: currentFeralConsent
            )
            if gate == .needsConsent {
                // Hand off to the view's consent sheet. The view rewrites
                // `currentFeralConsent` on user choice + re-calls
                // `generate()` with the new state.
                pendingFeralConsentRequest = true
                return
            }
        }

        phase = .generating
        visibleMessages = []

        do {
            let granted = (currentFeralConsent == .granted)
            let transcript = try await EchoesEngine.shared.generate(
                situation: situation,
                tone: tone,
                voiceCount: voiceCount,
                locale: locale,
                feralCloudGranted: granted
            )
            // Persist immediately. Animation drives the reveal but the
            // record is durable from generation-complete onward.
            HistoryService.saveEchoTranscript(transcript, context: modelContext, isPro: isPro)
            phase = .revealing(transcript)
            await revealMessages(transcript)
            phase = .done(transcript)
            EventLedger.shared.recordEchoesCompleted()
        } catch let err as EchoesGenerationError {
            switch err {
            case .consentDenied:
                phase = .setup
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
        EventLedger.shared.recordEchoesRegenerated()
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
        guard message.role == .bridge,
              let intensity = message.bridgeIntensity else { return }
        EchoBridgeStore.shared.pending = EchoBridgeStore.Payload(
            situation: situation,
            suggestedIntensity: intensity
        )
        EventLedger.shared.recordEchoesBridgeTap()
    }

    func reset() {
        situation = ""
        tone = .casual
        voiceCount = .two
        phase = .setup
        visibleMessages = []
        hasRegenerated = false
    }
}
