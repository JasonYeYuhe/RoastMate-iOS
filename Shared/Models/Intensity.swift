import Foundation

/// How aggressive the generator should be. Independent from `RoastMode`
/// (which controls *what kind* of generation: reply / translate / argument /
/// etc.). Any mode can be invoked at any intensity.
///
/// Tier policy (enforced at the call-site, not by this enum):
/// - `.calm` and `.sharp` are free-tier.
/// - `.savage` requires Pro.
/// - `.feral` and `.vent` require Pro **and** produce private drafts that
///   we intentionally never advertise as sendable messages. A second LLM
///   call (`RoastEngine.rewriteAsSendable`) converts a private draft into a
///   Sendable Reply when the user explicitly asks for it.
enum Intensity: String, Codable, CaseIterable, Sendable {
    case calm
    case sharp
    case savage
    /// Pro-only private rage draft. Profanity unlocked; universal safety
    /// rules (no slurs, no threats, no sexual content, no identity attacks)
    /// still apply. It is intentionally not sendable as-is.
    case feral
    case vent

    /// Default intensity for legacy sessions that pre-date this field.
    static var legacyDefault: Intensity { .sharp }

    /// True when this intensity should produce a private draft instead of an
    /// immediately-sendable reply. The UI must label these clearly as "for
    /// yourself only" and surface a rewrite-as-sendable action.
    var isPrivateDraft: Bool {
        self == .feral || self == .vent
    }

    /// Backward-compatible semantic helper used by older call sites/tests.
    var isVent: Bool { self == .vent }

    /// True when this intensity requires Pro entitlement.
    var requiresPro: Bool {
        switch self {
        case .calm, .sharp: return false
        case .savage, .feral, .vent: return true
        }
    }

    /// Localization key for the user-facing chip label.
    var displayKey: String {
        switch self {
        case .calm: return "intensity.calm.name"
        case .sharp: return "intensity.sharp.name"
        case .savage: return "intensity.savage.name"
        case .feral: return "intensity.feral.name"
        case .vent: return "intensity.vent.name"
        }
    }

    /// Localization key for a short blurb under the chip.
    var blurbKey: String {
        switch self {
        case .calm: return "intensity.calm.blurb"
        case .sharp: return "intensity.sharp.blurb"
        case .savage: return "intensity.savage.blurb"
        case .feral: return "intensity.feral.blurb"
        case .vent: return "intensity.vent.blurb"
        }
    }

    /// Localized name resolved via Localizable.strings.
    var displayName: String {
        String(localized: String.LocalizationValue(displayKey))
    }

    var blurb: String {
        String(localized: String.LocalizationValue(blurbKey))
    }
}

/// What sort of result a `GeneratedRoast` represents. Pre-Intensity sessions
/// only used `normalRoast`; the new flow distinguishes between an
/// intentionally rough "vent draft" and the cleaned-up "sendable reply"
/// produced by a second-pass rewrite.
enum GeneratedRoastKind: String, Codable, Sendable {
    case normalRoast
    case ventDraft
    case sendableReply
    case rewrite

    static var legacyDefault: GeneratedRoastKind { .normalRoast }

    /// True if this output should be labelled "for yourself only" in the UI
    /// and accompanied by a rewrite-as-sendable button.
    var isPrivateVent: Bool { self == .ventDraft }
}
