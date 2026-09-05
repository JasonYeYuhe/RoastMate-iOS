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

                // Two spacers, not one: the block is CENTRED in the space
                // between the style eyebrow and the watermark.
                //
                // With a single trailing Spacer the content was top-weighted and
                // a short line left ~70% of a 9:16 canvas as bare gradient —
                // visibly a template with the text missing rather than a
                // composed poster. That is a second, independent reason the card
                // read as unshareable, separate from the missing setup line, and
                // it is only visible in a rendered PNG (measured across 12
                // renders, 2026-09-06). Spacers have the lowest layout priority,
                // so they still collapse to nothing when a long line needs the
                // room, and ViewThatFits keeps choosing the same step.
                Spacer(minLength: 0)
                comeback
                Spacer(minLength: 0)
                watermark
            }
            .padding(80 * s)
        }
        .frame(width: pixelSize.width, height: pixelSize.height)
        .clipped()
    }

    /// Candidate type sizes are written out largest-first below.
    /// `ViewThatFits` picks the first that fits the fixed canvas, so a short English punchline stays poster-
    /// sized while a long zh-Hans line steps down instead of overflowing.
    ///
    /// B.7: `minimumScaleFactor` alone was not enough here. It shrinks to fit
    /// the proposed height, but the canvas is a FIXED 1080x1350 / 1080x1920 and
    /// the surrounding VStack has a Spacer, so a long line could still be
    /// clipped at the bottom rather than scaled. Stepping the font explicitly
    /// and letting ViewThatFits choose is deterministic — which matters,
    /// because this renders straight to a PNG with no chance to reflow.
    /// A.1: setup and comeback are sized as ONE joint candidate set.
    ///
    /// The obvious implementation — put the setup block above this and leave the
    /// existing `ViewThatFits` alone — is wrong on a fixed canvas with no reflow
    /// chance: the candidates would measure only the comeback, so a tall setup
    /// line could push the punchline into a clip that nothing detects until you
    /// look at the exported PNG. Sizing them together means the whole block
    /// steps down as a unit and the pair always fits.
    ///
    /// The setup deliberately steps at ~45% of the punchline: it is context, and
    /// it must never out-shout the line it sets up.
    private var comeback: some View {
        // Children MUST be written out statically: ViewThatFits picks among the
        // ViewBuilder's own children, and a ForEach would collapse into a single
        // candidate, defeating the whole point.
        ViewThatFits(in: .vertical) {
            setupAndComeback(size: 66)
            setupAndComeback(size: 54)
            setupAndComeback(size: 44)
            setupAndComeback(size: 36)
            // Final fallback: smallest step, allowed to scale further rather
            // than clip. Reaching this means the line is far longer than
            // anything the generator should produce.
            setupAndComeback(size: 30, allowScaling: true)
        }
    }

    @ViewBuilder
    private func setupAndComeback(size: CGFloat, allowScaling: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 28 * s) {
            if let setupText = content.setupText {
                VStack(alignment: .leading, spacing: 12 * s) {
                    Text("sharecard.setup_eyebrow")
                        .font(.system(size: 26 * s, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange.opacity(0.85))
                    Text(setupText)
                        .font(.system(size: max(26, size * 0.45) * s,
                                      weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: 20 * s) {
                Text("sharecard.comeback_eyebrow")
                    .font(.system(size: 30 * s, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                comebackText(size: size)
                    .minimumScaleFactor(allowScaling ? 0.5 : 1)
            }
        }
    }

    private func comebackText(size: CGFloat) -> some View {
        Text(content.sentText)
            .font(.system(size: size * s, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .lineSpacing(min(8, size / 8) * s)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var watermark: some View {
        HStack(alignment: .center, spacing: 14 * s) {
            Image(systemName: "flame.fill")
                .font(.system(size: 30 * s))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2 * s) {
                Text("RoastMate")
                    .font(.system(size: 32 * s, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                if content.showsGrowthBadge {
                    // A printed URL is inert on a static image, so the human-
                    // readable half tells people what to SEARCH.
                    Text("sharecard.findus")
                        .font(.system(size: 22 * s, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text("sharecard.watermark")
                        .font(.system(size: 22 * s, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            if content.showsGrowthBadge {
                Spacer(minLength: 0)
                qrBadge
            }
        }
    }

    /// The machine-readable half: a camera-resolvable QR to the campaign-tagged
    /// App Store link. Rendered on a white plate because QR contrast is
    /// required against a dark gradient — a code drawn straight onto the
    /// background scans poorly or not at all.
    @ViewBuilder
    private var qrBadge: some View {
        let side = 132 * s
        if let cg = ShareCardBadge.qrImage(sidePixels: side * 2) {
            Image(decorative: cg, scale: 1)
                .resizable()
                .interpolation(.none)   // keep module edges crisp
                .frame(width: side, height: side)
                .padding(10 * s)
                .background(RoundedRectangle(cornerRadius: 12 * s).fill(.white))
        }
    }
}
