import Foundation
import os.log

/// In-bundle curated sample. Used in the empty-state of History and on
/// the Generator's sample row so App Store reviewers can see the feature
/// without typing.
///
/// Two flavors:
/// - Standard roast: `response` is populated, `ventResponse` is nil.
/// - Vent demo pair: both `ventResponse` (raw, private) and
///   `sendableResponse` (cooled-off rewrite) are populated. The detail
///   sheet shows them side-by-side so reviewers see the killer "vent then
///   send" flow without typing.
struct SampleRoast: Codable, Identifiable, Sendable {
    let id: String
    let situation: [String: String]
    let styleId: String
    let responseLocale: String
    let response: String
    let ventResponse: String?
    let sendableResponse: String?

    /// True when this sample is a vent-then-sendable demo pair rather than
    /// a single-shot roast.
    var isVentDemo: Bool { ventResponse != nil && sendableResponse != nil }

    /// Picks the situation text for the user's current language, falling
    /// back to English.
    func situation(for locale: Locale) -> String {
        let code = locale.identifier
        if let direct = situation[code] { return direct }
        if let lang = locale.language.languageCode?.identifier {
            if lang == "zh" {
                let isHant = locale.identifier.contains("Hant")
                let key = isHant ? "zh-Hant" : "zh-Hans"
                if let s = situation[key] { return s }
            }
            if let s = situation[lang] { return s }
        }
        return situation["en"] ?? ""
    }
}

private struct SampleRoastsFile: Codable {
    let version: Int
    let samples: [SampleRoast]
}

@MainActor
final class SampleRoastsCatalog {
    static let shared = SampleRoastsCatalog()

    private(set) var all: [SampleRoast] = []
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "SampleRoasts")

    private init() {
        load()
    }

    private func load() {
        guard let url = ResourceBundle.url(forResource: "SampleRoasts", withExtension: "json") else {
            logger.error("SampleRoasts.json not found in bundle.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(SampleRoastsFile.self, from: data)
            self.all = file.samples
        } catch {
            logger.error("Failed to decode SampleRoasts.json: \(error.localizedDescription)")
        }
    }
}
