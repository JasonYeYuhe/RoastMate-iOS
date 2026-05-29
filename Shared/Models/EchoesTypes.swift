import Foundation

/// Top-level tone control for an Echoes transcript. The user picks at
/// setup time; downstream this drives the prompt register + the
/// cloud-routing gate.
enum EchoTone: String, CaseIterable, Sendable, Codable {
    case casual    // sharp register, light snark, on-device only
    case feral     // full register, on-device first, cloud via dedicated consent

    var requiresFeralConsentForCloud: Bool { self == .feral }

    /// Deterministic rewrite register the Bridge-to-Action CTA deep-links
    /// into. The model no longer emits this in the tag (it was the #1
    /// parse-failure trigger for the small on-device model — Gemini eval
    /// 2026-05-29); the engine injects it from tone after parsing.
    var bridgeIntensity: Intensity { self == .feral ? .savage : .sharp }
}

/// 1 or 2 voices in v1. 3-voice mode deferred to v0.2.
enum EchoVoiceCount: Int, CaseIterable, Sendable, Codable {
    case one = 1
    case two = 2
}

/// Required message-role structure for every Echoes transcript. Order
/// is fixed: validate → escalate (1–2x) → deescalate → bridge. The
/// `bridge` role is mandatory and always last — it is the single most
/// important strategic feature (Bridge to Action — Gemini decisive
/// catch in 2026-05-28 review). Without it, Echoes is a regulation
/// dead-end.
enum EchoMessageRole: String, CaseIterable, Sendable, Codable {
    case validate    // "you're right to be this mad"
    case escalate    // "honestly that's worse than you're making it sound"
    case deescalate  // "but don't let this ruin your night"
    case bridge      // "use Savage to send this →" CTA → opens RoastGenerator deep-link
}

/// In-memory representation of a single message in a transcript. The
/// SwiftData persistence form is `EchoMessageRecord` (paired with
/// `EchoTranscriptRecord`).
struct EchoMessage: Identifiable, Sendable {
    let id: UUID
    let echoIndex: Int               // 0 or 1 in v1 (matches EchoVoiceCount)
    let role: EchoMessageRole
    let text: String
    let deliveryDelayMs: Int         // for the chat-style type-out animation
    /// Only set on `.bridge` messages: the Intensity to pre-select in
    /// RoastGenerator after the Bridge-to-Action deep-link fires.
    let bridgeIntensity: Intensity?

    init(
        id: UUID = UUID(),
        echoIndex: Int,
        role: EchoMessageRole,
        text: String,
        deliveryDelayMs: Int = 600,
        bridgeIntensity: Intensity? = nil
    ) {
        self.id = id
        self.echoIndex = echoIndex
        self.role = role
        self.text = text
        self.deliveryDelayMs = deliveryDelayMs
        self.bridgeIntensity = bridgeIntensity
    }
}

/// One Echo persona, loaded from the bundled JSON catalog at setup time.
/// Persisted onto the SwiftData transcript record so the history view
/// can re-render the same handle / colour later. NEVER reflects a real
/// person — the App Review 4.0 banner depends on this.
struct EchoSpec: Identifiable, Sendable, Codable {
    let id: String              // stable key, e.g. "zh-Hans-tongue-empathy"
    let handle: String          // shown on bubble, e.g. "回声·甲"
    let archetype: String       // internal label, never user-visible (e.g. "毒舌共情型")
    let colorHex: String        // bubble background, e.g. "#FF9500"
    let promptFragment: String  // injected into the per-Echo prompt as the persona block
}

/// In-memory complete transcript, returned by EchoesEngine.generate().
/// Persisted via `HistoryService.saveEchoTranscript`.
struct EchoTranscript: Sendable {
    let situation: String
    let tone: EchoTone
    let voiceCount: EchoVoiceCount
    let echoes: [EchoSpec]      // 1 or 2 entries; matches voiceCount
    let messages: [EchoMessage] // 4–6 ordered; last is always .bridge
    let cloudUsed: Bool         // true iff feral-cloud-consent granted AND cloud succeeded
    let locale: Locale
}

/// Errors surfaced from EchoesEngine. Most paths fall back to a curated
/// transcript via FallbackRoasts; .consentDenied is the only path that
/// stops the user with a sheet.
enum EchoesGenerationError: Error, Sendable {
    case parseFailure
    case engineFailure(underlying: Error)
    case consentDenied
    case safetyTrippedAllVariants
}
