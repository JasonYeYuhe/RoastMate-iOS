import SwiftUI

/// Shown *instead of* generating when the user's own input signals
/// self-harm / suicidal ideation. Deliberately calm and warm — NOT the
/// orange "error" styling the rest of the app uses for blocks. The input
/// is never generated; nothing was sent anywhere (on-device detection).
struct CrisisSupportView: View {
    @Environment(\.locale) private var locale
    @Environment(\.openURL) private var openURL
    /// Lets the user return to editing their message (resets generator state).
    var onDismiss: () -> Void

    private var resources: [CrisisResource] {
        CrisisResources.regionalResources(for: locale)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "heart.circle.fill")
                    .font(.title)
                    .foregroundStyle(.teal)
                Text("crisis.title")
                    .font(.title3.weight(.semibold))
            }

            Text("crisis.body")
                .font(.callout)
                .foregroundStyle(.primary)

            Text("crisis.privacy_note")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                openURL(CrisisResources.directoryURL)
            } label: {
                HStack {
                    Image(systemName: "globe")
                    Text("crisis.directory_cta")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)

            if !resources.isEmpty {
                Text("crisis.regional_label")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                VStack(spacing: 8) {
                    ForEach(resources) { resource in
                        resourceRow(resource)
                    }
                }
            }

            Text("crisis.emergency_note")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                onDismiss()
            } label: {
                Text("crisis.dismiss")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.teal.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.teal.opacity(0.25), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func resourceRow(_ resource: CrisisResource) -> some View {
        let content = HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(resource.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.primary)
                Text(resource.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if resource.url != nil {
                Image(systemName: "phone.fill")
                    .foregroundStyle(.teal)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.04))
        )

        if let url = resource.url {
            Button { openURL(url) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Compact, calm banner shown *alongside* a generated roast when the
/// input tripped the `.soft` self-harm tier. Venting still works; this
/// just offers a quiet door to help.
struct CrisisBanner: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.circle.fill")
                .foregroundStyle(.teal)
            Text("crisis.banner")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button {
                openURL(CrisisResources.directoryURL)
            } label: {
                Text("crisis.banner.cta")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.teal)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.teal.opacity(0.10))
        )
    }
}
