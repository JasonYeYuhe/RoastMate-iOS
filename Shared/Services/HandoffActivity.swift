import Foundation

/// Handoff between watchOS and iOS. When the user generates a roast on
/// the watch, the result is published via `NSUserActivity`, which the
/// iPhone picks up and opens into the Roast Generator pre-filled.
enum HandoffActivity {
    static let typeRoastSession = "yyh.roastmate.app.handoff.session"

    enum UserInfoKey {
        static let situation = "situation"
        static let styleId = "styleId"
        static let modeRaw = "modeRaw"
        static let locale = "locale"
    }

    static func payload(
        situation: String,
        styleId: String,
        mode: RoastMode,
        locale: Locale
    ) -> [String: any Sendable] {
        [
            UserInfoKey.situation: situation,
            UserInfoKey.styleId: styleId,
            UserInfoKey.modeRaw: mode.rawValue,
            UserInfoKey.locale: locale.identifier
        ]
    }

    struct ContinuationPayload: Sendable, Hashable {
        let situation: String
        let styleId: String
        let mode: RoastMode

        init?(from userInfo: [AnyHashable: Any]?) {
            guard let userInfo,
                  let situation = userInfo[UserInfoKey.situation] as? String,
                  let styleId = userInfo[UserInfoKey.styleId] as? String,
                  let modeRaw = userInfo[UserInfoKey.modeRaw] as? String,
                  let mode = RoastMode(rawValue: modeRaw) else {
                return nil
            }
            self.situation = situation
            self.styleId = styleId
            self.mode = mode
        }
    }
}
