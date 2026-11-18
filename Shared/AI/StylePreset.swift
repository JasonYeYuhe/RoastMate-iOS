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
        /// Content bucket the example is written in (`AppLanguage` raw value:
        /// en / zh-Hans / zh-Hant / ja). Needed because "contains Han" can't
        /// tell Simplified from Traditional: until 1.8.0 every zh-Hant prompt
        /// got the Simplified examples. nil = infer from the script (legacy).
        var lang: String? = nil
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
    /// Per-bucket preamble (`AppLanguage` raw value) for styles whose voice
    /// leaks one language into another — 台劇腔's 啦/喔/欸 showed up in 18/18
    /// English outputs (lens 1). Falls back to `systemPreamble`.
    var systemPreambleByLanguage: [String: String]? = nil

    /// The preamble for the output language.
    func systemPreamble(for locale: Locale) -> String {
        systemPreambleByLanguage?[AppLanguage.contentBucket(for: locale).rawValue] ?? systemPreamble
    }

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
