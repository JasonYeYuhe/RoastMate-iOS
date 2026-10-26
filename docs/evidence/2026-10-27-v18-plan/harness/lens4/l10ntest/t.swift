import Foundation
let b = Bundle(path: CommandLine.arguments[1])!
print("localizations:", b.localizations, "preferred for zh-Hant-TW:", Bundle.preferredLocalizations(from: b.localizations, forPreferences: ["zh-Hant-TW"]))
// Simulate the app's language resolution: localizedString with an explicit localization
let s1 = b.localizedString(forKey: "echoes.tone.casual", value: nil, table: nil)
print("main-bundle style lookup (process prefs):", s1)
if #available(macOS 13, *) {
  let s2 = String(localized: "echoes.tone.casual", bundle: b, locale: Locale(identifier: "zh-Hant-TW"))
  let s3 = String(localized: "shared.key", bundle: b, locale: Locale(identifier: "zh-Hant-TW"))
  print("String(localized:bundle:locale zh-Hant-TW) missing key ->", s2, "| present key ->", s3)
}
let lp = Bundle(path: b.path(forResource: "zh-Hant", ofType: "lproj")!)!
print("AppLocalization-style lproj bundle missing key ->", lp.localizedString(forKey: "echoes.tone.casual", value: nil, table: nil))
