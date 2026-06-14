#if os(iOS)
import Foundation
import os.log
import AVFoundation
import Speech

/// On-device speech-to-text backend for the vent box. Mirrors the `FMBackend`
/// split: the protocol carries NO availability, so the iOS-18-capable
/// `VoiceVentTranscriber` can hold `(any SpeechRecognitionBackend)?`, while the
/// iOS-26-only `SpeechAnalyzer` symbols stay sealed inside the `@available`
/// `ModernSpeechBackend`. iOS 18–25 get `LegacySpeechBackend` (SFSpeechRecognizer).
///
/// LOAD-BEARING privacy rule (see `VoiceVent.swift`): 100% on-device, audio is
/// ephemeral, and a locale with no on-device model HIDES voice — there is NEVER
/// a cloud fallback. Every implementation must uphold this.
@MainActor
protocol SpeechRecognitionBackend: AnyObject {
    /// Begins live on-device transcription. Reports partial transcripts via
    /// `onPartial` and download/prepare state via `onPreparing`. Any thrown
    /// error must tear capture down first (no invisible live mic).
    func start(
        appLocale: Locale,
        onPartial: @MainActor @Sendable @escaping (String) -> Void,
        onPreparing: @MainActor @Sendable @escaping (Bool) -> Void
    ) async throws

    /// Stops capture and returns the final transcript. Idempotent.
    func stop() async -> String
}

/// Picks the right backend for the running OS. `@MainActor` because it
/// constructs `@MainActor` backend classes.
@MainActor
enum VoiceBackendFactory {
    static func make() -> (any SpeechRecognitionBackend)? {
        if #available(iOS 26.0, *) {
            return ModernSpeechBackend()
        }
        return LegacySpeechBackend()
    }

    /// True only when the locale has an ON-DEVICE model on this OS. False →
    /// the gate hides voice (never cloud).
    static func isLocaleSupported(_ appLocale: Locale) async -> Bool {
        if #available(iOS 26.0, *) {
            return await ModernSpeechBackend.isLocaleSupported(appLocale)
        }
        return await LegacySpeechBackend.isLocaleSupported(appLocale)
    }
}

/// iOS 18–25 backend built on `SFSpeechRecognizer`. Forces
/// `requiresOnDeviceRecognition = true` and only ever runs for locales whose
/// recognizer reports `supportsOnDeviceRecognition` — so no audio or text is
/// ever sent to Apple's servers. There is no pre-26 `AssetInventory` to
/// pre-provision the model, so a "supported" locale that fails at runtime
/// fails CLOSED (throws → curated/typed path), never to cloud.
@MainActor
final class LegacySpeechBackend: SpeechRecognitionBackend {
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "VoiceVent")
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onPartial: (@MainActor @Sendable (String) -> Void)?
    private var lastText = ""
    private var tapInstalled = false
    private var stopContinuation: CheckedContinuation<String, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var isStopping = false

    static func isLocaleSupported(_ appLocale: Locale) async -> Bool {
        SFSpeechRecognizer(locale: appLocale)?.supportsOnDeviceRecognition == true
    }

    func start(
        appLocale: Locale,
        onPartial: @MainActor @Sendable @escaping (String) -> Void,
        onPreparing: @MainActor @Sendable @escaping (Bool) -> Void
    ) async throws {
        // Re-check on-device support at the point of use (privacy rule):
        // never create a recognition task for a locale that would go to cloud.
        guard let recognizer = SFSpeechRecognizer(locale: appLocale),
              recognizer.supportsOnDeviceRecognition else {
            throw VoiceVentError.localeUnsupported
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true   // hard requirement: never network
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        self.request = request
        self.onPartial = onPartial
        // No model-download phase on the legacy path; we're already prepared.
        onPreparing(false)

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Runs on an arbitrary queue — extract plain value types first,
            // then hop to the main actor to touch state.
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let didError = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let text {
                    self.lastText = text
                    self.onPartial?(text)
                }
                if isFinal || didError {
                    self.resumeStopIfNeeded(returning: self.lastText)
                }
            }
        }

        let input = engine.inputNode
        let tapFormat = input.outputFormat(forBus: 0)
        // SFSpeechAudioBufferRecognitionRequest is built for live mic buffers;
        // the tap already delivers copies, so (unlike the modern AnalyzerInput
        // stream) no manual deep-copy is needed.
        input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { [request] buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true
        engine.prepare()
        try engine.start()
    }

    @discardableResult
    func stop() async -> String {
        guard task != nil || tapInstalled || engine.isRunning else { return lastText }
        // Re-entrancy guard: stop() suspends on the continuation below, and
        // because this type is @MainActor a SECOND stop() (a double-tap on Stop,
        // or Stop racing the sheet's onDisappear teardown) can run during that
        // suspension. It must NOT overwrite `stopContinuation` — that would
        // strand the first continuation forever and hang its caller. Bail with
        // the last transcript; the in-flight stop delivers the real final.
        // The check + set are atomic here (no await between them on @MainActor).
        if isStopping { return lastText }
        isStopping = true
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if engine.isRunning { engine.stop() }

        // Wait for the recognizer to publish its final result (or time out and
        // return the last partial) so the tail words aren't lost.
        let final = await withCheckedContinuation { (c: CheckedContinuation<String, Never>) in
            stopContinuation = c
            timeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(1500))
                self?.resumeStopIfNeeded(returning: self?.lastText ?? "")
            }
            request?.endAudio()
            task?.finish()
        }

        timeoutTask?.cancel()
        timeoutTask = nil
        task?.cancel()
        task = nil
        request = nil
        onPartial = nil
        isStopping = false
        return final
    }

    /// Resumes the `stop()` continuation exactly once (nil-then-resume so the
    /// main actor serializes against a double-resume from final + timeout).
    private func resumeStopIfNeeded(returning text: String) {
        guard let c = stopContinuation else { return }
        stopContinuation = nil
        c.resume(returning: text)
    }
}
#endif
