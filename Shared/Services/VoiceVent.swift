import Foundation

/// Voice Venting (next-wave 3/5) — pure, testable core.
///
/// Speak the rage → on-device transcript → it pre-fills the existing
/// vent box → the normal vent→rewrite flow.
///
/// Hard rules (load-bearing for the privacy brand):
/// - 100% on-device. A locale with no on-device model hides voice —
///   NEVER a silent cloud fallback.
/// - Audio is EPHEMERAL: nothing is written to disk or SwiftData.
/// - Voice is a free INPUT modality; the downstream generate/rewrite
///   still spends a credit exactly as typed input does.
///
/// Only this pure decision logic lives in `Shared/` (so it compiles
/// into the hostless unit-test bundle and is unit-tested). The actual
/// Speech/AVFoundation engine is `VoiceVentTranscriber` in the app
/// target — the codebase convention: heavy/framework code stays out of
/// `Shared/`, only testable logic goes in.

/// Tri-state permission, decoupled from system frameworks so the gate
/// is pure and unit-testable.
enum VoicePermission: Sendable, Equatable {
    case notDetermined, granted, denied
}

/// Pure decision: should the mic affordance show, and what happens on
/// tap. No audio, no system calls — fully unit-tested.
enum VoiceVentGate: Sendable, Equatable {
    /// Mic + speech granted and the locale has on-device support.
    case ready
    /// On-device transcription unavailable for this locale → hide voice
    /// entirely (we never fall back to a cloud recognizer).
    case localeUnsupported
    /// At least one permission still undetermined → ask on tap.
    case needsPermission
    /// A permission was denied → point the user at Settings.
    case denied

    static func decide(localeSupported: Bool,
                        mic: VoicePermission,
                        speech: VoicePermission) -> VoiceVentGate {
        guard localeSupported else { return .localeUnsupported }
        if mic == .denied || speech == .denied { return .denied }
        if mic == .notDetermined || speech == .notDetermined { return .needsPermission }
        return .ready
    }

    /// The mic button is shown unless the locale simply has no
    /// on-device model (then voice doesn't exist for this user).
    var showsAffordance: Bool { self != .localeUnsupported }
}
