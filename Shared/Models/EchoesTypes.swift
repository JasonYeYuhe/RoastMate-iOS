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

/// Number of synthetic voices in a transcript. 1–2 = the classic 替你出气
/// experience; 3 = the 虚拟舍友群 roommate-group scene (Echoes vNext). Raw
/// values are stable and `.three` is purely additive, so old persisted
/// `voiceCountRaw` values (1 / 2) keep decoding with no migration.
enum EchoVoiceCount: Int, CaseIterable, Sendable, Codable {
    case one = 1
    case two = 2
    case three = 3
}

/// Which Echoes experience a transcript belongs to. `.classic` = the
/// shipped 1–2 voice 替你出气. `.roommateGroup` = the 3-voice 虚拟舍友群
/// (Echoes vNext). Persisted as an OPTIONAL raw string on
/// `EchoTranscriptRecord` — a nil `sceneRaw` decodes as `.classic`, so
/// every pre-existing record stays valid with no destructive migration.
enum EchoScene: String, CaseIterable, Sendable, Codable {
    case classic
    case roommateGroup

    /// The voice count this scene is generated with. Classic transcripts
    /// carry their own 1/2 selection; the roommate group is always 3.
    var fixedVoiceCount: EchoVoiceCount? { self == .roommateGroup ? .three : nil }
}

/// Required message-role structure for every Echoes transcript. Order
/// is fixed: validate → escalate (1–2x) → deescalate → bridge. The
/// `bridge` role is mandatory and always last — it is the single most
/// important strategic feature (Bridge to Action — Gemini decisive
/// catch in 2026-05-28 review). Without it, Echoes is a regulation
/// dead-end. The roommate-group scene reuses these same four roles
/// (multiple `escalate` messages carry the group pile-on / banter,
/// `deescalate` is the reframe) so there is NO new persisted role case.
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
    let echoIndex: Int               // 0/1 classic, 0/1/2 roommate (matches EchoVoiceCount)
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
    let scene: EchoScene        // .classic (1–2 voice) or .roommateGroup (3 voice)
    let echoes: [EchoSpec]      // entries match voiceCount
    let messages: [EchoMessage] // classic 4–6 / roommate 8–10; last is always .bridge
    let cloudUsed: Bool         // true iff feral-cloud-consent granted AND cloud succeeded
    let locale: Locale

    init(
        situation: String,
        tone: EchoTone,
        voiceCount: EchoVoiceCount,
        scene: EchoScene = .classic,
        echoes: [EchoSpec],
        messages: [EchoMessage],
        cloudUsed: Bool,
        locale: Locale
    ) {
        self.situation = situation
        self.tone = tone
        self.voiceCount = voiceCount
        self.scene = scene
        self.echoes = echoes
        self.messages = messages
        self.cloudUsed = cloudUsed
        self.locale = locale
    }
}

/// Errors surfaced from EchoesEngine. Most paths fall back to a curated
/// transcript via FallbackRoasts; .consentDenied is the only path that
/// stops the user with a sheet.
enum EchoesGenerationError: Error, Sendable {
    case parseFailure
    case engineFailure(underlying: Error)
    case consentDenied
    case safetyTrippedAllVariants
    /// The remote kill-switch (`RemoteConfig.echoesEnabled == false`)
    /// disabled Echoes. The Explore tile is also hidden when this is set,
    /// so this is the rare in-flight / mid-session case. See RemoteConfig
    /// + the 2026-05-29 health audit §4.
    case featureDisabled
}
