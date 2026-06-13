#if os(iOS)
import Foundation
import os.log
import Speech
import AVFoundation

/// Live on-device dictation for the vent box (iOS 26 `DictationTranscriber`
/// + `SpeechAnalyzer`). App-target only — it pulls in Speech/AVFoundation,
/// which must NOT leak into the hostless unit-test bundle that compiles
/// `Shared/` directly. The pure gate logic lives in `Shared/`.
///
/// `@MainActor` so UI state is observable without data races. Audio is
/// ephemeral: the realtime mic tap deep-COPIES each transient engine
/// buffer (the engine reuses its own), forwards the copy through a
/// BOUNDED `Sendable` stream, and never writes audio anywhere. Every
/// error path and dismissal tears capture down.
///
/// `@available(iOS 26.0, *)`: this is built entirely on the iOS-26 Speech
/// API (`SpeechAnalyzer` / `DictationTranscriber` / `AssetInventory`), which
/// has no in-scope pre-26 equivalent. On iOS 18 the voice affordance is
/// simply hidden (the gate query is skipped) and the user types instead.
@available(iOS 26.0, *)
@MainActor
@Observable
final class VoiceVentTranscriber {
    private(set) var partialText: String = ""
    private(set) var isRecording = false
    /// True while the on-device model for the locale is downloading.
    private(set) var isPreparing = false

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "VoiceVent")
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var tapInstalled = false

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

    static func requestPermissions(appLocale: Locale) async -> VoiceVentGate {
        _ = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { c.resume(returning: $0) }
        }
        _ = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        return await currentGate(appLocale: appLocale)
    }

    /// Deep-copies a transient engine buffer so it can safely outlive
    /// the realtime tap callback (the engine reuses its own buffer).
    /// `nonisolated static` — runs on the audio thread, touches no
    /// actor state.
    nonisolated static func detachedCopy(of buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                          frameCapacity: buffer.frameCapacity) else { return nil }
        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        if let s = buffer.floatChannelData, let d = copy.floatChannelData {
            for ch in 0..<channels { memcpy(d[ch], s[ch], frames * MemoryLayout<Float>.size) }
        } else if let s = buffer.int16ChannelData, let d = copy.int16ChannelData {
            for ch in 0..<channels { memcpy(d[ch], s[ch], frames * MemoryLayout<Int16>.size) }
        } else if let s = buffer.int32ChannelData, let d = copy.int32ChannelData {
            for ch in 0..<channels { memcpy(d[ch], s[ch], frames * MemoryLayout<Int32>.size) }
        } else {
            return nil
        }
        return copy
    }

    /// Begins live on-device transcription. Any thrown error tears
    /// capture down before propagating (no invisible live mic).
    func start(appLocale: Locale) async throws {
        do {
            guard let resolved = await Self.supportedLocale(for: appLocale) else {
                throw VoiceVentError.localeUnsupported
            }
            let transcriber = DictationTranscriber(locale: resolved, preset: .progressiveShortDictation)
            self.transcriber = transcriber

            // 1. Ensure the on-device model exists BEFORE capturing any
            //    audio (otherwise transcription silently yields nothing
            //    on a device that hasn't downloaded the locale model).
            let status = await AssetInventory.status(forModules: [transcriber])
            if status == .unsupported { throw VoiceVentError.unavailable }
            if status != .installed {
                isPreparing = true
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await request.downloadAndInstall()
                }
                isPreparing = false
            }

            guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
                throw VoiceVentError.unavailable
            }

            // 2. Bounded stream — caps in-memory audio so a slow/failed
            //    analyzer can't accumulate raw mic buffers.
            let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream(
                bufferingPolicy: .bufferingNewest(8))
            self.inputContinuation = continuation
            let analyzer = SpeechAnalyzer(inputSequence: stream, modules: [transcriber])
            self.analyzer = analyzer

            let log = logger
            resultsTask = Task { [weak self] in
                do {
                    for try await result in transcriber.results {
                        let text = String(result.text.characters)
                        await MainActor.run { self?.partialText = text }
                    }
                } catch {
                    log.error("transcribe stream: \(error.localizedDescription)")
                }
            }

            // 3. Prepare the analyzer BEFORE the mic starts feeding it,
            //    so the first words aren't lost to startup latency.
            try await analyzer.prepareToAnalyze(in: format)

            let input = engine.inputNode
            let tapFormat = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                // Realtime thread: copy the transient buffer, forward
                // the copy, capture ONLY the Sendable continuation.
                if let safe = VoiceVentTranscriber.detachedCopy(of: buffer) {
                    continuation.yield(AnalyzerInput(buffer: safe))
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
            isRecording = true
            partialText = ""
        } catch {
            isPreparing = false
            await teardown()
            throw error
        }
    }

    /// Stops capture and returns the final transcript. Drains the
    /// finalized results before reading, so the last words aren't lost.
    /// Idempotent.
    @discardableResult
    func stop() async -> String {
        guard isRecording || analyzer != nil || tapInstalled else { return partialText }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        engine.stop()
        inputContinuation?.finish()
        // Finalize publishes the last results; awaiting the reader task
        // (the stream ends after finalize) guarantees we consumed them
        // BEFORE reading partialText. Do not cancel — that would drop
        // the tail.
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value
        let final = partialText
        await teardown()
        return final
    }

    private func teardown() async {
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if engine.isRunning { engine.stop() }
        inputContinuation?.finish()
        resultsTask?.cancel()
        isRecording = false
        isPreparing = false
        analyzer = nil
        transcriber = nil
        inputContinuation = nil
        resultsTask = nil
    }

    // No deinit: under Swift 6 strict concurrency a nonisolated deinit
    // can't touch this @MainActor type's stored audio handles. Teardown
    // is guaranteed instead by VoiceVentSheet's `.onDisappear`
    // (interactive dismissal) and the Stop/Cancel buttons, all routing
    // through the idempotent `stop()`/`teardown()`.
}

enum VoiceVentError: Error, Sendable {
    case localeUnsupported
    case unavailable
}
#endif
