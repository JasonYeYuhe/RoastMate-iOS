import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Rasterises a `ShareCardView` to a temp PNG and returns its file URL
/// (universally shareable via `ShareLink`). Rendering is local; no
/// network, no analytics.
enum ShareCardRenderer {
    @MainActor
    static func renderPNG(_ content: ShareCardContent,
                          format: ShareCardFormat,
                          locale: Locale) -> URL? {
        let size = format.pixelSize
        let renderer = ImageRenderer(
            content: ShareCardView(content: content, pixelSize: size)
                .environment(\.locale, locale)
        )
        renderer.proposedSize = ProposedViewSize(size)
        renderer.isOpaque = true
        renderer.scale = 1

        let data: Data
        #if canImport(UIKit)
        guard let image = renderer.uiImage, let png = image.pngData() else { return nil }
        data = png
        #elseif canImport(AppKit)
        guard let cg = renderer.cgImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        data = png
        #else
        return nil
        #endif

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("RoastMate-\(UUID().uuidString.prefix(8)).png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
