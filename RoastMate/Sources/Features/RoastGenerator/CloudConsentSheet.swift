import SwiftUI

/// One-time explicit consent for the third-party-AI (cloud Vent / Feral)
/// path — Apple App Review Guideline 5.1.2(i). Shown the first time a
/// user runs a Vent/Feral generation; the choice is durable and
/// changeable later in Settings. Declining keeps everything on-device.
struct CloudConsentSheet: View {
    let onAllow: () -> Void
    let onDeny: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
                .padding(.top, 28)

            Text("cloud.consent.title")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("cloud.consent.body")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Label("cloud.consent.point.what", systemImage: "arrow.up.forward.app")
                Label("cloud.consent.point.nostore", systemImage: "externaldrive.badge.xmark")
                Label("cloud.consent.point.local", systemImage: "iphone")
                Label("cloud.consent.point.change", systemImage: "gearshape")
            }
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 4)

            VStack(spacing: 10) {
                Button {
                    onAllow()
                    dismiss()
                } label: {
                    Text("cloud.consent.allow")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onDeny()
                    dismiss()
                } label: {
                    Text("cloud.consent.deny")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            }

            Text("cloud.consent.footnote")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }
}
