import Foundation

/// Reads UI-test launch arguments. Screenshots and UI tests need a
/// deterministic app: no onboarding wall, and a forced UI language so
/// `Text`/localized strings render in the target locale regardless of
/// the simulator's `-AppleLanguages` quirks.
///
/// Launch arguments (set by RoastMateUITests):
/// - `-uitest`            : enables UI-test mode (skips onboarding/age
///                          gate, makes sample data deterministic)
/// - `-uitestLang <code>` : forces the app UI language. `<code>` is one
///                          of `en`, `zh-Hans`, `zh-Hant`, `ja`.
enum AppLaunchEnvironment {
    static var isUITest: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }

    /// The forced UI-test language code, if `-uitestLang <code>` was
    /// passed. Returns nil outside UI-test mode.
    static var uiTestLanguageCode: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uitestLang"), i + 1 < args.count else {
            return nil
        }
        let code = args[i + 1]
        return code.isEmpty ? nil : code
    }
}
