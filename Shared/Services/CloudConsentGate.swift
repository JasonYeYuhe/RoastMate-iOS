import Foundation

/// Apple App Review Guideline **5.1.2(i)** (enforced 2025-11-13): an app
/// must disclose where personal data is shared with third-party AI and
/// obtain the user's **explicit permission before doing so**.
///
/// RoastMate's only third-party-AI path is the Vent / Feral cloud proxy
/// (Cloudflare Worker → Groq / OpenRouter). This file is the pure,
/// unit-tested decision core (same `Shared/`-only convention as
/// `VoiceVentGate`): the heavy UI lives in the app target.
///
/// Compliance-critical behaviour change vs. the old `cloudVentEnabled`
/// default: the prior model treated a fresh/legacy install as
/// **opted-in** (cloud-on so "the feature works first time"). Sending
/// the user's situation text to a third-party LLM with no prior explicit
/// permission is exactly what 5.1.2(i) forbids. The new default is
/// `notAsked`, and `notAsked` **never** auto-clouds — the generator
/// prompts for an explicit one-time choice first.

/// Persisted tri-state consent for the third-party-AI (cloud) path.
/// Stored on `UserSettings`; `notAsked` is the safe default.
enum CloudConsent: String, Sendable, Equatable, CaseIterable {
    /// Never shown the consent prompt → must ask before any cloud call.
    case notAsked
    /// User explicitly allowed cloud Vent / Feral.
    case granted
    /// User explicitly declined → stay on-device, do not re-nag mid-flow.
    case denied
}

/// Pure decision for a single generation: go cloud, ask first, or stay
/// on-device. No I/O, no frameworks — fully unit-tested.
enum CloudConsentGate: Sendable, Equatable {
    /// Private draft + cloud configured + consent granted → cloud allowed.
    case proceedCloud
    /// Private draft + cloud configured + not yet asked → the UI MUST
    /// present the explicit consent choice *before* generating.
    case needsConsent
    /// Denied, or not a private draft, or cloud not configured → the
    /// on-device path (no third-party data leaves the device).
    case useLocal

    static func decide(isPrivateDraft: Bool,
                        cloudConfigured: Bool,
                        consent: CloudConsent) -> CloudConsentGate {
        // Calm / Sharp / Savage and any pre-deploy build never touch the
        // cloud regardless of consent — short-circuit to local.
        guard isPrivateDraft, cloudConfigured else { return .useLocal }
        switch consent {
        case .granted:  return .proceedCloud
        case .denied:   return .useLocal
        case .notAsked: return .needsConsent
        }
    }

    /// Convenience for the engine-bound bool. Cloud is permitted ONLY on
    /// an explicit prior grant — `needsConsent`/`useLocal` both stay local.
    var allowsCloud: Bool { self == .proceedCloud }
}
