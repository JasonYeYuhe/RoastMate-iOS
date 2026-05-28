import Foundation

/// Pure decision core for the Echoes Feral cloud-routing gate. Mirrors
/// `CloudConsentGate` exactly in shape but reads a SEPARATE consent
/// surface (`UserSettings.echoesFeralConsent`) — see v2 plan §5 and
/// Codex 2026-05-28 audit catch on purpose creep.
///
/// Reusing the existing `cloudConsent` for Echoes Feral would silently
/// repurpose a grant the user gave for "vent translation" into a grant
/// for "multi-voice squad pile-on transcript" — same class of consent
/// breach as the dropped α2′ scope on the Phase 4 plan.
enum EchoesFeralConsentGate: Sendable, Equatable {
    /// Feral + cloud configured + dedicated consent granted → cloud allowed.
    case proceedCloud
    /// Feral + cloud configured + not yet asked → UI MUST present the
    /// dedicated consent sheet before generating.
    case needsConsent
    /// Denied, or not Feral, or cloud not configured → on-device.
    case useLocal

    /// Pure decision for one Echoes generation. No I/O, no frameworks
    /// — unit-testable.
    static func decide(
        tone: EchoTone,
        cloudConfigured: Bool,
        consent: CloudConsent
    ) -> EchoesFeralConsentGate {
        // Casual stays on-device regardless of consent state — Casual
        // doesn't open the cloud lane in v1 (and probably ever; the
        // register doesn't need it). Short-circuit to local.
        guard tone == .feral, cloudConfigured else { return .useLocal }
        switch consent {
        case .granted:  return .proceedCloud
        case .denied:   return .useLocal
        case .notAsked: return .needsConsent
        }
    }

    /// Engine-bound bool for "is cloud actually permitted right now?"
    var allowsCloud: Bool { self == .proceedCloud }
}
