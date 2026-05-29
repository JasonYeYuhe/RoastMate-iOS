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
