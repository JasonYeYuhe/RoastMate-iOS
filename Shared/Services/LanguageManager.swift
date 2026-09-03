import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = ""
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    var id: String { rawValue }

    /// Maps an arbitrary `Locale` onto the four CONTENT buckets the app
    /// actually generates for. Never returns `.system`.
    ///
    /// Needed because a device locale is not one of these strings — it is
    /// `zh_Hans_CN`, `zh-Hant-TW`, `en_GB`, `ja_JP`. Anything that gates
    /// behaviour per language has to normalise first, and doing that inline at
    /// each site is how the zh-Hant/zh-Hans distinction gets fumbled.
    static func contentBucket(for locale: Locale) -> AppLanguage {
        let id = locale.identifier
        switch locale.language.languageCode?.identifier {
        case "zh":
            // Script subtag is authoritative; fall back to region for the
            // common Traditional territories, which often omit it.
            if id.contains("Hant") { return .traditionalChinese }
            if id.contains("Hans") { return .simplifiedChinese }
            let region = locale.region?.identifier ?? ""
            return ["TW", "HK", "MO"].contains(region) ? .traditionalChinese
                                                       : .simplifiedChinese
        case "ja": return .japanese
        default:   return .english
        }
    }

    var displayName: String {
        switch self {
        case .system: return String(localized: "settings.language.system")
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        }
    }
}

@MainActor
@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    /// UserDefaults key for the persisted in-app language code. `nonisolated`
    /// so `AppLocalization` can read it off the main actor.
    nonisolated static let storageKey = "roastmate_app_language"

    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: Self.storageKey)
        }
    }

    var locale: Locale? {
        guard selectedLanguage != .system else { return nil }
        return Locale(identifier: selectedLanguage.rawValue)
    }

    private init() {
        // UI-test mode pins the language so screenshots / UI tests are
        // deterministic regardless of the simulator's -AppleLanguages
        // resolution. This takes precedence over the stored preference.
        if let code = AppLaunchEnvironment.uiTestLanguageCode,
           let forced = AppLanguage(rawValue: code) {
            self.selectedLanguage = forced
            return
        }
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.selectedLanguage = AppLanguage(rawValue: stored) ?? .system
    }
}
