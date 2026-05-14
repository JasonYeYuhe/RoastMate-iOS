import Foundation
import os.log

/// Loads `StylePresets.json` from the app bundle once and exposes lookup helpers.
@MainActor
final class StyleCatalog {
    static let shared = StyleCatalog()

    private(set) var all: [StylePreset] = []
    private var index: [String: StylePreset] = [:]
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "StyleCatalog")

    private init() {
        load()
    }

    private func load() {
        guard let url = ResourceBundle.url(forResource: "StylePresets", withExtension: "json") else {
            logger.error("StylePresets.json not found in bundle.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(StylePresetCatalogFile.self, from: data)
            self.all = file.styles
            self.index = Dictionary(uniqueKeysWithValues: file.styles.map { ($0.id, $0) })
        } catch {
            logger.error("Failed to decode StylePresets.json: \(error.localizedDescription)")
        }
    }

    func style(id: String) -> StylePreset? {
        index[id]
    }

    func byTier(_ tier: StylePreset.Tier) -> [StylePreset] {
        all.filter { $0.tier == tier }
    }

    func byTag(_ tag: String) -> [StylePreset] {
        all.filter { $0.tags.contains(tag) }
    }

    var defaultStyleId: String {
        all.first(where: { $0.tier == .free })?.id ?? "high_eq"
    }
}
