import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Entry point for the iOS Share Extension. Hosts the SwiftUI share UI
/// inside a UIKit shell so the extension's bundle ID
/// `yyh.roastmate.app.share` registers as a system Share target.
final class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await loadSharedText() }
    }

    @MainActor
    private func loadSharedText() async {
        let text = await extractSharedText()
        let host = UIHostingController(
            rootView: ShareRootView(
                sharedText: text,
                onDone: { [weak self] in self?.close() },
                onCancel: { [weak self] in self?.close() }
            )
        )
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func extractSharedText() async -> String {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return "" }
        for item in items {
            guard let providers = item.attachments else { continue }
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = try? await provider.loadItem(
                        forTypeIdentifier: UTType.plainText.identifier
                    ) as? String {
                        return text
                    }
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = try? await provider.loadItem(
                        forTypeIdentifier: UTType.url.identifier
                    ) as? URL {
                        return url.absoluteString
                    }
                }
            }
        }
        return ""
    }

    private func close() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
