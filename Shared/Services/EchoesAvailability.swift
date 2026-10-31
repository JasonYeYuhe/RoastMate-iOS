import Foundation

/// Where the Echoes surfaces exist. One answer for the Explore tile and the
/// Settings consent toggle: until 1.8.0 the toggle and its footer rendered in
/// every locale while the tile showed only in zh-Hans.
enum EchoesAvailability {

    /// The roommate group (虚拟舍友群) tile: zh-Hans only, and not remotely
    /// killed (`roommateGroupAllowed` also requires `echoes_enabled`).
    @MainActor
    static func roommateTileVisible(remote: RemoteConfigValues) -> Bool {
        let id = (LanguageManager.shared.locale ?? Locale.current).identifier
        return roommateTileVisible(localeIdentifier: id, remote: remote)
    }

    static func roommateTileVisible(localeIdentifier: String, remote: RemoteConfigValues) -> Bool {
        isSimplifiedChinese(localeIdentifier) && remote.roommateGroupAllowed
    }

    /// Same rule ExploreView used inline before 1.8.0.
    static func isSimplifiedChinese(_ identifier: String) -> Bool {
        let id = identifier.lowercased()
        return id.contains("hans") || id.hasPrefix("zh-cn") || id.hasPrefix("zh_cn") || id == "zh"
    }
}
