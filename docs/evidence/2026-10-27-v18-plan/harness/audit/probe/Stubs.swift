import Foundation
// Stubs so production PromptBuilder / Intensity / StylePreset / SafetyFilter / ModelRefusal
// compile in a CLI. AppLanguage.contentBucket is a verbatim copy of LanguageManager.swift:19-33.
enum RoastMode: String, Codable, CaseIterable, Sendable { case roast, reply, argument, translate, social }
enum AppLanguage: String, CaseIterable, Sendable {
    case system = "", english = "en", simplifiedChinese = "zh-Hans", traditionalChinese = "zh-Hant", japanese = "ja"
    static func contentBucket(for locale: Locale) -> AppLanguage {
        let id = locale.identifier
        switch locale.language.languageCode?.identifier {
        case "zh":
            if id.contains("Hant") { return .traditionalChinese }
            if id.contains("Hans") { return .simplifiedChinese }
            let region = locale.region?.identifier ?? ""
            return ["TW", "HK", "MO"].contains(region) ? .traditionalChinese : .simplifiedChinese
        case "ja": return .japanese
        default:   return .english
        }
    }
}
enum AppLocalization {
    nonisolated(unsafe) static var currentLang: String = "zh-Hant"
    nonisolated(unsafe) static var tables: [String: [String: String]] = [:]
    static func string(_ key: String) -> String {
        if tables[currentLang] == nil {
            let p = "/Users/jason/Documents/RoastMate/Shared/\(currentLang).lproj/Localizable.strings"
            tables[currentLang] = (NSDictionary(contentsOfFile: p) as? [String: String]) ?? [:]
        }
        return tables[currentLang]?[key] ?? key
    }
}
enum ResourceBundle {
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        URL(fileURLWithPath: "/Users/jason/Documents/RoastMate/Shared/Resources/\(name).\(ext)")
    }
}
