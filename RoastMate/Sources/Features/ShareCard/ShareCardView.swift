import SwiftUI

/// The rendered artifact. Laid out for a fixed pixel canvas (passed in)
/// so `ImageRenderer` produces an exact-size export. Two layouts:
/// Comeback Card (single line) and Vent→Sent (before/after). The vent
/// panel only shows real text when `content.revealVent` is true; when
/// false it renders an obscured placeholder, so a non-opted-in export
/// can never carry the private draft.
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

                if content.hasVentPairing {
                    ventVsSent
                } else {
                    comeback
                }

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

    private var ventVsSent: some View {
        VStack(alignment: .leading, spacing: 28 * s) {
            panel(labelKey: "sharecard.before_label",
                  accent: .pink,
                  body: ventBody,
                  obscured: !content.revealVent)
            Image(systemName: "arrow.down")
                .font(.system(size: 40 * s, weight: .bold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity)
            panel(labelKey: "sharecard.after_label",
                  accent: .green,
                  body: content.sentText,
                  obscured: false)
        }
    }

    private var ventBody: String { content.ventText ?? "" }

    private func panel(labelKey: LocalizedStringKey,
                       accent: Color,
                       body: String,
                       obscured: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14 * s) {
            Text(labelKey)
                .font(.system(size: 28 * s, weight: .bold, design: .rounded))
                .foregroundStyle(accent)
            if obscured {
                HStack(spacing: 12 * s) {
                    Image(systemName: "lock.fill")
                    Text("sharecard.vent_hidden")
                        .font(.system(size: 30 * s, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, minHeight: 150 * s)
                .background(
                    RoundedRectangle(cornerRadius: 22 * s)
                        .fill(.white.opacity(0.06))
                )
            } else {
                Text(body)
                    .font(.system(size: 40 * s, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(6 * s)
                    .minimumScaleFactor(0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24 * s)
                    .background(
                        RoundedRectangle(cornerRadius: 22 * s)
                            .fill(.white.opacity(0.06))
                    )
            }
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
