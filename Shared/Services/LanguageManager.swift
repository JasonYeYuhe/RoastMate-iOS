import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system = ""
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"

    var id: String { rawValue }

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

    private let key = "roastmate_app_language"

    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: key)
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
        let stored = UserDefaults.standard.string(forKey: key) ?? ""
        self.selectedLanguage = AppLanguage(rawValue: stored) ?? .system
    }
}
