import SwiftUI

/// The rendered artifact. Laid out for a fixed pixel canvas (passed in)
/// so `ImageRenderer` produces an exact-size export.
///
/// ONE layout: the Comeback Card — the sendable line only. The former
/// Vent→Sent (before/after) layout was removed in v1.3.1: rendering the
/// user's private draft onto a branded, shareable image contradicts the
/// "your vent stays private" contract the rest of the app makes.
struct ShareCardView: View {
    let content: ShareCardContent
    let pixelSize: CGSize

    private var s: CGFloat { pixelSize.width / 1080 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.08, blue: 0.16),
                         Color(red: 0.20, green: 0.09, blue: 0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 36 * s) {
                if let styleName = content.styleName {
                    Text(styleName.uppercased())
                        .font(.system(size: 30 * s, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .tracking(2 * s)
                }

                comeback

                Spacer(minLength: 0)
                watermark
            }
            .padding(80 * s)
        }
        .frame(width: pixelSize.width, height: pixelSize.height)
        .clipped()
    }

    private var comeback: some View {
        VStack(alignment: .leading, spacing: 20 * s) {
            Text("sharecard.comeback_eyebrow")
                .font(.system(size: 30 * s, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            Text(content.sentText)
                .font(.system(size: 66 * s, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineSpacing(8 * s)
                .minimumScaleFactor(0.4)
        }
    }

    private var watermark: some View {
        HStack(spacing: 14 * s) {
            Image(systemName: "flame.fill")
                .font(.system(size: 30 * s))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2 * s) {
                Text("RoastMate")
                    .font(.system(size: 32 * s, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("sharecard.watermark")
                    .font(.system(size: 22 * s, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}
