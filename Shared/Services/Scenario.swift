import Foundation
import os.log

/// Curated zh-first quick-start entry point. Tapping one pre-fills the
/// generator (situation + a sensible free-tier style + intensity) so a
/// user in the moment of rage doesn't face a blank box. Prompts are
/// regionally NATURAL per locale (not literal translations) — the
/// zh-Hant copy reads naturally for the HK/TW/diaspora wedge.
///
/// JSON-backed and localized via the per-locale `prompt` map (same
/// pattern as `SampleRoast`) so example text needs no .strings churn;
/// only the category labels are localized in Localizable.strings.
struct Scenario: Codable, Identifiable, Sendable {
    let id: String
    /// boss | ex | family | roommate | groupchat
    let category: String
    let prompt: [String: String]
    let defaultStyleId: String
    let defaultIntensity: String

    /// Localization key for the category chip header.
    var categoryKey: String { "scenario.cat.\(category)" }

    var intensity: Intensity {
        Intensity(rawValue: defaultIntensity) ?? .sharp
    }

    /// Picks the prompt for the user's language, falling back to
    /// English (mirrors `SampleRoast.situation(for:)`).
    func prompt(for locale: Locale) -> String {
        let code = locale.identifier
        if let direct = prompt[code] { return direct }
        if let lang = locale.language.languageCode?.identifier {
            if lang == "zh" {
                let isHant = locale.identifier.contains("Hant")
                let key = isHant ? "zh-Hant" : "zh-Hans"
                if let s = prompt[key] { return s }
            }
            if let s = prompt[lang] { return s }
        }
        return prompt["en"] ?? ""
    }
}

private struct ScenariosFile: Codable {
    let version: Int
    let scenarios: [Scenario]
}

@MainActor
final class ScenarioCatalog {
    static let shared = ScenarioCatalog()

    private(set) var all: [Scenario] = []
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "Scenarios")

    /// Stable display order of the curated entry-point categories.
    static let categoryOrder = ["boss", "ex", "family", "roommate", "groupchat"]

    private init() { load() }

    /// Scenarios for a category, in file order.
    func scenarios(in category: String) -> [Scenario] {
        all.filter { $0.category == category }
    }

    /// Categories that actually have at least one scenario, in the
    /// canonical order.
    var orderedCategories: [String] {
        Self.categoryOrder.filter { cat in all.contains { $0.category == cat } }
    }

    private func load() {
        guard let url = ResourceBundle.url(forResource: "Scenarios", withExtension: "json") else {
            logger.error("Scenarios.json not found in bundle.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(ScenariosFile.self, from: data)
            self.all = file.scenarios
        } catch {
            logger.error("Failed to decode Scenarios.json: \(error.localizedDescription)")
        }
    }
}
