import Foundation

/// Resolves a localization key against the language the user picked *inside
/// the app* (Settings → Language), not the system language.
///
/// `String(localized:)` and the macOS window-title chrome resolve against
/// `Bundle.main` + the system locale, so they ignore the in-app override.
/// SwiftUI `Text("key")` respects it only because it reads the injected
/// `\.environment(\.locale)`. Any string resolved outside that environment
/// (model computed properties, `.navigationTitle`, AppKit-bridged titles)
/// must go through this helper instead.
enum AppLocalization {
    /// Localized value for `key` in the in-app selected language. Falls back
    /// to the system-resolved string when the user follows the system
    /// language (`.system`) or the language bundle is unexpectedly missing.
    ///
    /// Reads the persisted code straight from `UserDefaults` rather than the
    /// `@MainActor` `LanguageManager`, so it is safe to call from nonisolated,
    /// `Sendable` model code under Swift 6 strict concurrency.
    static func string(_ key: String) -> String {
        let code = UserDefaults.standard.string(forKey: LanguageManager.storageKey) ?? ""
        if !code.isEmpty,
           let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return String(localized: String.LocalizationValue(key))
    }
}
