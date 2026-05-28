import SwiftUI

/// 5.1.2(i) consent sheet shown the first time the user picks Feral
/// tone in Echoes. Distinct from the existing Vent/Feral consent sheet
/// — this one is feature-specific to Echoes Feral squad transcripts
/// (Codex audit catch on the v2 plan: reusing the existing
/// `cloudAIConsentRaw` would be purpose creep on a grant the user
/// gave for a different feature).
struct EchoesFeralConsentSheet: View {
    /// Called with the user's choice. The caller persists to
    /// `UserSettings.echoesFeralConsent`.
    let onChoice: (CloudConsent) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "cloud.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("echoes.consent.title")
                    .font(.title2.weight(.semibold))
                Spacer()
            }
            Text("echoes.consent.body")
                .font(.body)
                .foregroundStyle(.primary)
            Text("echoes.consent.notice")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 10) {
                Button {
                    EventLedger.shared.recordEchoesFeralCloudConsentGranted()
                    onChoice(.granted)
                    dismiss()
                } label: {
                    Text("echoes.consent.allow")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                Button {
                    EventLedger.shared.recordEchoesFeralCloudConsentDenied()
                    onChoice(.denied)
                    dismiss()
                } label: {
                    Text("echoes.consent.deny")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                Button("echoes.consent.cancel") {
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(22)
        .frame(maxWidth: 480)
    }
}
