#if os(iOS)
import Foundation
import os.log
import AVFoundation
import Speech

/// iOS 26+ backend: live on-device dictation via `SpeechAnalyzer` +
/// `DictationTranscriber`. Sealed behind `@available(iOS 26.0, *)` so its
/// iOS-26-only symbols never leak into the iOS-18-compilable coordinator
/// (`VoiceVentTranscriber`). This is the v1.1 shipping pipeline, moved here
/// verbatim and reporting through `onPartial`/`onPreparing` instead of writing
/// observable state directly. Audio is ephemeral: the realtime mic tap
/// deep-COPIES each transient engine buffer (the engine reuses its own),
/// forwards the copy through a BOUNDED `Sendable` stream, and never writes
/// audio anywhere. Every error path and dismissal tears capture down.
@available(iOS 26.0, *)
@MainActor
final class ModernSpeechBackend: SpeechRecognitionBackend {
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "VoiceVent")
    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var tapInstalled = false
    private var lastText = ""

    static func isLocaleSupported(_ appLocale: Locale) async -> Bool {
        await DictationTranscriber.supportedLocale(equivalentTo: appLocale) != nil
    }

    /// Deep-copies a transient engine buffer so it can safely outlive the
    /// realtime tap callback (the engine reuses its own buffer). `nonisolated
    /// static` — runs on the audio thread, touches no actor state.
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

    func start(
        appLocale: Locale,
        onPartial: @MainActor @Sendable @escaping (String) -> Void,
        onPreparing: @MainActor @Sendable @escaping (Bool) -> Void
    ) async throws {
        do {
            guard let resolved = await DictationTranscriber.supportedLocale(equivalentTo: appLocale) else {
                throw VoiceVentError.localeUnsupported
            }
            let transcriber = DictationTranscriber(locale: resolved, preset: .progressiveShortDictation)
            self.transcriber = transcriber

            // 1. Ensure the on-device model exists BEFORE capturing any audio
            //    (otherwise transcription silently yields nothing on a device
            //    that hasn't downloaded the locale model).
            let status = await AssetInventory.status(forModules: [transcriber])
            if status == .unsupported { throw VoiceVentError.unavailable }
            if status != .installed {
                onPreparing(true)
                if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                    try await request.downloadAndInstall()
                }
                onPreparing(false)
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
                        self?.lastText = text
                        onPartial(text)
                    }
                } catch {
                    log.error("transcribe stream: \(error.localizedDescription)")
                }
            }

            // 3. Prepare the analyzer BEFORE the mic starts feeding it, so the
            //    first words aren't lost to startup latency.
            try await analyzer.prepareToAnalyze(in: format)

            let input = engine.inputNode
            let tapFormat = input.outputFormat(forBus: 0)
            input.installTap(onBus: 0, bufferSize: 4096, format: tapFormat) { buffer, _ in
                // Realtime thread: copy the transient buffer, forward the copy,
                // capture ONLY the Sendable continuation.
                if let safe = ModernSpeechBackend.detachedCopy(of: buffer) {
                    continuation.yield(AnalyzerInput(buffer: safe))
                }
            }
            tapInstalled = true
            engine.prepare()
            try engine.start()
        } catch {
            onPreparing(false)
            await teardown()
            throw error
        }
    }

    @discardableResult
    func stop() async -> String {
        guard analyzer != nil || tapInstalled || engine.isRunning else { return lastText }
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if engine.isRunning { engine.stop() }
        inputContinuation?.finish()
        // Finalize publishes the last results; awaiting the reader task (the
        // stream ends after finalize) guarantees we consumed them BEFORE
        // reading lastText. Do not cancel — that would drop the tail.
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        await resultsTask?.value
        let final = lastText
        await teardown()
        return final
    }

    private func teardown() async {
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
        if engine.isRunning { engine.stop() }
        inputContinuation?.finish()
        resultsTask?.cancel()
        analyzer = nil
        transcriber = nil
        inputContinuation = nil
        resultsTask = nil
    }
}
#endif
