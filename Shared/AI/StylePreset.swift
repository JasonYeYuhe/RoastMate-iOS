import Foundation

/// Codable, immutable description of a roast style. Not a SwiftData model —
/// styles ship with the app via `StylePresets.json` and reference by string id.
struct StylePreset: Codable, Hashable, Sendable, Identifiable {
    enum Tier: String, Codable, Sendable {
        case free
        case pro
    }

    struct Example: Codable, Hashable, Sendable {
        let situation: String
        let response: String
    }

    let id: String
    let displayKey: String
    let blurbKey: String
    let icon: String
    let tier: Tier
    let temperature: Double
    let tags: [String]
    let systemPreamble: String
    let examples: [Example]
    let localesSupported: [String]?

    /// Localized display name resolved against the in-app selected language.
    var displayName: String {
        AppLocalization.string(displayKey)
    }

    /// Localized blurb / one-line description.
    var blurb: String {
        AppLocalization.string(blurbKey)
    }
}

struct StylePresetCatalogFile: Codable, Sendable {
    let version: Int
    let styles: [StylePreset]
}
