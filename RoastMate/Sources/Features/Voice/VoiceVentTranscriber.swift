#if os(iOS)
import Foundation
import AVFoundation
import Speech

/// UI-facing voice-vent coordinator (iOS 18+). Owns the observable capture
/// state and the mic/speech PERMISSION + gate logic (common to all OS
/// versions), and delegates the actual on-device transcription to a
/// `SpeechRecognitionBackend` chosen at runtime: `ModernSpeechBackend`
/// (iOS 26 `SpeechAnalyzer`) when available, else `LegacySpeechBackend`
/// (iOS 18 `SFSpeechRecognizer`). Both are 100% on-device; a locale with no
/// on-device model hides voice (never cloud); audio is ephemeral; teardown is
/// idempotent.
///
/// App-target only — it pulls in Speech/AVFoundation, which must NOT leak into
/// the hostless unit-test bundle that compiles `Shared/` directly. The pure
/// gate logic lives in `Shared/Services/VoiceVent.swift`.
@MainActor
@Observable
final class VoiceVentTranscriber {
    private(set) var partialText: String = ""
    private(set) var isRecording = false
    /// True while the on-device model for the locale is downloading (iOS 26
    /// only; the legacy path has no download phase).
    private(set) var isPreparing = false

    /// The OS-appropriate backend, or nil if none could be made. Private,
    /// immutable, existential — not an observed model dependency.
    private let backend: (any SpeechRecognitionBackend)? = VoiceBackendFactory.make()

    /// True only when the locale has an on-device model on this OS.
    static func supportedLocale(for appLocale: Locale) async -> Bool {
        await VoiceBackendFactory.isLocaleSupported(appLocale)
    }

    static func currentGate(appLocale: Locale) async -> VoiceVentGate {
        let localeSupported = await supportedLocale(for: appLocale)
        let mic: VoicePermission
        switch AVAudioApplication.shared.recordPermission {
        case .granted: mic = .granted
        case .denied: mic = .denied
        default: mic = .notDetermined
        }
        let speech: VoicePermission
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: speech = .granted
        case .denied, .restricted: speech = .denied
        default: speech = .notDetermined
        }
        return VoiceVentGate.decide(localeSupported: localeSupported, mic: mic, speech: speech)
    }

    static func requestPermissions(appLocale: Locale) async -> VoiceVentGate {
        _ = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { c.resume(returning: $0) }
        }
        _ = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        return await currentGate(appLocale: appLocale)
    }

    /// Begins live on-device transcription. Any thrown error tears capture
    /// down before propagating (no invisible live mic).
    func start(appLocale: Locale) async throws {
        guard let backend else { throw VoiceVentError.unavailable }
        partialText = ""
        do {
            try await backend.start(
                appLocale: appLocale,
                onPartial: { [weak self] text in self?.partialText = text },
                onPreparing: { [weak self] preparing in self?.isPreparing = preparing }
            )
            isRecording = true
        } catch {
            isPreparing = false
            isRecording = false
            _ = await backend.stop()
            throw error
        }
    }

    /// Stops capture and returns the final transcript. Idempotent.
    @discardableResult
    func stop() async -> String {
        guard let backend else { return partialText }
        let final = await backend.stop()
        isRecording = false
        isPreparing = false
        partialText = final
        return final
    }

    // No deinit: under Swift 6 strict concurrency a nonisolated deinit can't
    // touch this @MainActor type. Teardown is guaranteed instead by
    // VoiceVentSheet's `.onDisappear` (interactive dismissal) and the
    // Stop/Cancel buttons, all routing through the idempotent `stop()`.
}

enum VoiceVentError: Error, Sendable {
    case localeUnsupported
    case unavailable
}
#endif
