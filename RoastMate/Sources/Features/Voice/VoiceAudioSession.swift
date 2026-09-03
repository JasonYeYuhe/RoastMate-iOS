#if os(iOS)
import Foundation
import AVFoundation
import os.log

/// Configures and tears down the shared `AVAudioSession` around a voice-vent
/// capture. Both speech backends must call this — neither did.
///
/// ## Why this exists
///
/// Nothing in the app ever configured `AVAudioSession`. iOS's default category
/// does **not** permit microphone input, and the failure is SILENT: the engine
/// starts, the tap installs, and the input node simply delivers zeros. No
/// crash, no thrown error — the user taps the mic, the sheet opens, and no text
/// ever appears. That is why it survived code review and a passing test suite;
/// only running it on a device would have shown it.
///
/// The session must be record-capable and ACTIVE before `AVAudioEngine`'s
/// `inputNode` is touched, because the input node's format is derived from the
/// active route. Reading it first can also yield a 0 Hz format, which makes
/// `installTap(format:)` throw.
///
/// `.record` rather than `.playAndRecord`: this feature only captures, never
/// plays. `.measurement` mode disables the system's added signal processing,
/// which is what Apple's own speech-recognition samples use — speech models
/// want the rawest signal available. `.duckOthers` lowers other audio instead
/// of stopping it, so venting over music does not kill the music.
@MainActor
enum VoiceAudioSession {
    private static let logger = Logger(subsystem: "yyh.roastmate.app", category: "VoiceVent")

    /// Make the session record-capable and active. Throws so the caller can
    /// tear capture down — never start an engine on a session that failed.
    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: [])
    }

    /// Release the session so other apps' audio resumes.
    ///
    /// Deliberately non-throwing: this runs on teardown paths that must always
    /// complete (including error unwinds), and a failure to deactivate is not
    /// worth propagating over the transcript the user is waiting for.
    static func deactivate() {
        do {
            try AVAudioSession.sharedInstance()
                .setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            logger.notice("VoiceVent: audio session deactivate failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
