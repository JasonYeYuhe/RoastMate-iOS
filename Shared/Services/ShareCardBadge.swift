import Foundation
// CoreImage does NOT exist on watchOS, and this file lives in Shared/, which
// the watch target globs in wholesale. Guard the import (and everything that
// needs it) rather than moving the file: the campaign URL below is useful to
// any target, and only the QR rendering is CoreImage-bound.
#if canImport(CoreImage)
import CoreImage
import CoreImage.CIFilterBuiltins
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// The card's growth layer (v1.4 Track B, B.4 + B.5).
///
/// ## Why a QR and not a URL
///
/// The card is a static PNG posted to Xiaohongshu / WeChat / Instagram. On all
/// of them a URL printed in the image is **inert** — it is pixels, not a link.
/// Nobody retypes a URL from a screenshot. So the acquisition path has to be
/// something a phone can act on directly (a QR the camera resolves) plus
/// something a human can act on (a "search RoastMate in the App Store" line),
/// which is how every Chinese social surface actually bridges image → app.
///
/// ## Attribution
///
/// `EventLedger` is opt-in and captures a small share of users, so it can show
/// a cohort trend but cannot measure acquisition. The QR therefore carries an
/// App Store **campaign token** (`ct`), which Apple reports back in App
/// Analytics per-campaign — real store-level attribution that does not depend
/// on the user having opted into our telemetry, and that adds no tracking of
/// our own.
enum ShareCardBadge {
    /// Apple's campaign-token parameter. `pt`/`mt` are omitted deliberately —
    /// `ct` alone is what App Analytics buckets on, and every extra parameter
    /// is more QR payload, which means a denser, harder-to-scan code.
    static let campaignToken = "sharecard_v14"

    static let appStoreID = "6769317103"

    /// Destination encoded into the QR. A plain App Store URL rather than a
    /// Universal Link: a Universal Link only opens the app for people who
    /// already have it, and this code exists for people who do not.
    static var campaignURL: URL {
        URL(string: "https://apps.apple.com/app/id\(appStoreID)?ct=\(campaignToken)")!
    }

    /// Renders the QR at a size suited to the card canvas.
    ///
    /// `CIQRCodeGenerator` emits a tiny bitmap (roughly one pixel per module),
    /// so it must be scaled with **nearest-neighbour** interpolation. Scaling it
    /// smoothly blurs the module edges and makes the code materially harder for
    /// a camera to lock onto — the failure mode here is silent, so it is worth
    /// being explicit about.
    static func qrImage(sidePixels: CGFloat) -> CGImage? {
        #if canImport(CoreImage)
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(campaignURL.absoluteString.utf8)
        // "M" — ~15% recovery. Enough for a screenshot that gets recompressed
        // by a social app, without inflating module count the way "H" would.
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scale = max(1, sidePixels / max(output.extent.width, 1))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return CIContext(options: [.useSoftwareRenderer: true])
            .createCGImage(scaled, from: scaled.extent)
        #else
        // watchOS: no CoreImage, and no share card either. Returning nil keeps
        // the shared file compiling for every target.
        return nil
        #endif
    }
}
