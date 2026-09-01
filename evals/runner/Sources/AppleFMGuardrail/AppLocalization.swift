import Foundation

/// CLI stand-in for `Shared/Services/AppLocalization.swift`.
///
/// The production helper resolves a key against the in-app `.lproj` bundle,
/// which a Swift-package CLI has no access to. The ONLY localized value that
/// reaches the on-device prompt is a style's `displayName` (used once, in the
/// user prompt line "... in the <displayName> style"). That single string does
/// not influence the safety guardrail, but we still reproduce it faithfully:
/// the values below are copied verbatim from the four `Localizable.strings`
/// files for the five styles the eval corpus actually uses, keyed by the same
/// in-app language code the app would select for each cell's locale.
///
/// `currentLocale` is set by the harness before it builds each cell's prompt.
/// Cells run strictly serially, so a plain mutable global is safe here.
enum AppLocalization {
    nonisolated(unsafe) static var currentLocale: String = "en"

    /// key -> (in-app language code -> localized display name). Extracted from
    /// `Shared/{en,zh-Hans,zh-Hant,ja}.lproj/Localizable.strings`.
    private static let table: [String: [String: String]] = [
        "style.high_eq.name":            ["en": "High EQ",            "zh-Hans": "高 EQ",   "zh-Hant": "高 EQ",   "ja": "高EQ"],
        "style.passive_aggressive.name": ["en": "Passive Aggressive", "zh-Hans": "阴阳怪气", "zh-Hant": "陰陽怪氣", "ja": "パッシブ・アグレッシブ"],
        "style.literary.name":           ["en": "Literary",          "zh-Hans": "文学体",  "zh-Hant": "文學體",  "ja": "文学風"],
        "style.grandma.name":            ["en": "Grandma Wisdom",     "zh-Hans": "奶奶智慧", "zh-Hant": "奶奶智慧", "ja": "おばあちゃんの知恵"],
        "style.tweet.name":              ["en": "One-Liner",         "zh-Hans": "一句话",  "zh-Hant": "一句話",  "ja": "ワンライナー"],
    ]

    static func string(_ key: String) -> String {
        if let row = table[key] {
            return row[currentLocale] ?? row["en"] ?? key
        }
        // Any other key (e.g. intensity display/blurb) never reaches the prompt;
        // returning the key is harmless and keeps the copied sources compiling.
        return key
    }
}
