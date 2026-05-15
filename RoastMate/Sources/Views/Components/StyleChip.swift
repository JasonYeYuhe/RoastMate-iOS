import SwiftUI

struct StyleChip: View {
    let style: StylePreset
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: style.icon)
                Text(style.displayName)
                    .font(.subheadline.weight(.medium))
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? Color.orange : Color.primary)
        }
        .buttonStyle(.plain)
    }
}

struct IntensityChip: View {
    let intensity: Intensity
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                    Text(intensity.displayName)
                        .font(.subheadline.weight(.semibold))
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                    }
                }
                Text(intensity.blurb)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.orange.opacity(0.85) : Color.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 142, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.orange.opacity(0.18) : Color.secondary.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 1.5)
            )
            .foregroundStyle(isSelected ? Color.orange : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch intensity {
        case .calm:
            return "leaf"
        case .sharp:
            return "bolt"
        case .savage:
            return "flame"
        case .feral:
            return "flame.fill"
        case .vent:
            return "lock.open"
        }
    }
}
