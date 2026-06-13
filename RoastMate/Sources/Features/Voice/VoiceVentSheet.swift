#if os(iOS)
import SwiftUI

/// Modal on-device voice capture for the vent box. Shows the live
/// transcript and an explicit on-device/ephemeral disclosure at the
/// moment of use. On stop, the transcript is handed back; the audio is
/// already gone (the transcriber never persisted it).
///
/// Works on iOS 18+: `VoiceVentTranscriber` routes to `SpeechAnalyzer`
/// (iOS 26) or `SFSpeechRecognizer` (iOS 18–25) under the hood.
struct VoiceVentSheet: View {
    let appLocale: Locale
    let onComplete: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var transcriber = VoiceVentTranscriber()
    @State private var gate: VoiceVentGate?
    @State private var startFailed = false

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("voice.title").font(.title2.bold())
                Spacer()
                Button { finish(send: false) } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            switch gate {
            case .some(.ready), .none:
                recording
            case .some(.needsPermission):
                permissionPrompt
            case .some(.denied):
                message("voice.permission.denied")
            case .some(.localeUnsupported):
                message("voice.unsupported")
            }

            Spacer()

            Label("voice.disclosure", systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(minWidth: 320, minHeight: 420)
        .task {
            let g = await VoiceVentTranscriber.currentGate(appLocale: appLocale)
            gate = g
            if g == .ready { await beginRecording() }
        }
        .onDisappear {
            // Interactive/!button dismissal must still stop the mic.
            // stop() is idempotent, so this is safe even after finish().
            Task { await transcriber.stop() }
        }
    }

    private var recording: some View {
        VStack(spacing: 16) {
            if transcriber.isPreparing {
                ProgressView()
                Text("voice.preparing")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: transcriber.isRecording ? "waveform" : "mic.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
                .symbolEffect(.variableColor, isActive: transcriber.isRecording)

            ScrollView {
                Text(transcriber.partialText.isEmpty
                     ? String(localized: "voice.listening")
                     : transcriber.partialText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(transcriber.partialText.isEmpty ? .secondary : .primary)
            }
            .frame(maxHeight: 160)

            if startFailed {
                Text("voice.unsupported").font(.caption).foregroundStyle(.orange)
            }

            Button {
                finish(send: true)
            } label: {
                Label("voice.stop", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!transcriber.isRecording)
        }
    }

    private var permissionPrompt: some View {
        VStack(spacing: 14) {
            Text("voice.permission.needed")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("voice.permission.grant") {
                Task {
                    gate = await VoiceVentTranscriber.requestPermissions(appLocale: appLocale)
                    if gate == .ready { await beginRecording() }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func message(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.callout).foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    private func beginRecording() async {
        do { try await transcriber.start(appLocale: appLocale) }
        catch { startFailed = true }
    }

    private func finish(send: Bool) {
        Task {
            let text = await transcriber.stop()
            if send { onComplete(text) }
            dismiss()
        }
    }
}
#endif
