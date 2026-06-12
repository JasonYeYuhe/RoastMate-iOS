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

    /// A canned 虚拟舍友群 transcript (raw `[ROLE/IDX] …` tagged text)
    /// injected for DETERMINISTIC marketing screenshots via
    /// `-uitestRoommateFixture <text>`. When present, the roommate scene
    /// renders this exact transcript instead of calling the cloud — so the
    /// hand-picked best generation appears, not a lucky live roll. UI-test
    /// only; nil in production (the arg is never passed by real users).
    static var uiTestRoommateFixture: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uitestRoommateFixture"), i + 1 < args.count else {
            return nil
        }
        let raw = args[i + 1]
        guard !raw.isEmpty else { return nil }
        // Base64-encoded so the multi-line transcript survives the
        // env-var → launch-argument chain intact (raw newlines get
        // flattened in transit, which made the parser reject it).
        if let data = Data(base64Encoded: raw),
           let decoded = String(data: data, encoding: .utf8), !decoded.isEmpty {
            return decoded
        }
        return raw
    }
}
