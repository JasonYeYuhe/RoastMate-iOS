#if os(iOS)
import Foundation
import os.log
import Speech
import AVFoundation

/// Live on-device dictation for the vent box (iOS 26 `DictationTranscriber`
/// + `SpeechAnalyzer`). Lives in the app target — it pulls in
/// Speech/AVFoundation, which must NOT leak into the hostless unit-test
/// bundle that compiles `Shared/` directly. The pure gate logic
/// (`VoiceVentGate`, `VoicePermission`) is in `Shared/`.
///
/// `@MainActor` so UI state is observable without data races; the
/// realtime mic tap forwards buffers through a `Sendable` AsyncStream
/// and never touches actor state or persists audio.
@MainActor
@Observable
final class VoiceVentTranscriber {
    private(set) var partialText: String = ""
    private(set) var isRecording = false

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "VoiceVent")
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    /// On-device locale for the app language, or nil if unsupported
    /// (caller hides voice — no cloud fallback, ever).
    static func supportedLocale(for appLocale: Locale) async -> Locale? {
        await DictationTranscriber.supportedLocale(equivalentTo: appLocale)
    }

    static func currentGate(appLocale: Locale) async -> VoiceVentGate {
        let localeSupported = await supportedLocale(for: appLocale) != nil
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

    /// Requests both permissions; returns the resulting gate.
    static func requestPermissions(appLocale: Locale) async -> VoiceVentGate {
        _ = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { c.resume(returning: $0) }
        }
        _ = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        return await currentGate(appLocale: appLocale)
    }

    /// Begins live on-device transcription. Buffers are streamed and
    /// dropped — nothing is persisted.
    func start(appLocale: Locale) async throws {
        guard let resolved = await Self.supportedLocale(for: appLocale) else {
            throw VoiceVentError.localeUnsupported
        }
        // Short-form, live partial results — the right shape for a
        // quick spoken vent (not a long-form dictation).
        let transcriber = DictationTranscriber(locale: resolved, preset: .progressiveShortDictation)
        self.transcriber = transcriber

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw VoiceVentError.unavailable
        }

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation
        let analyzer = SpeechAnalyzer(inputSequence: stream, modules: [transcriber])
        self.analyzer = analyzer

        // Capture the local transcriber (not self) so the stream task
        // doesn't touch MainActor state until it hops back explicitly.
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await MainActor.run { self?.partialText = text }
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run { self?.logger.error("transcribe stream: \(message)") }
            }
        }

        let input = engine.inputNode
        let tapFormat = input.outputFormat(forBus: 0)
        // The tap fires on a realtime audio thread. Capture ONLY the
        // Sendable continuation — never `self` / MainActor state — and
        // forward the buffer straight through. Buffers are not retained.
        input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
            continuation.yield(AnalyzerInput(buffer: buffer))
        }
        engine.prepare()
        try engine.start()
        try await analyzer.prepareToAnalyze(in: format)
        isRecording = true
        partialText = ""
    }

    /// Stops capture and returns the final transcript. Tears down the
    /// engine; no audio survives this call.
    @discardableResult
    func stop() async -> String {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        inputContinuation?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        resultsTask?.cancel()
        isRecording = false
        let final = partialText
        analyzer = nil
        transcriber = nil
        inputContinuation = nil
        resultsTask = nil
        return final
    }
}

enum VoiceVentError: Error, Sendable {
    case localeUnsupported
    case unavailable
}
#endif
