import Foundation
import Security

/// Minimal Keychain wrapper used by `AuthService` to persist the Sign in with Apple
/// identity across launches and to share the same identity between the host iOS app
/// and the Share Extension via the App Group's shared access group.
///
/// Keys live under `kSecClassGenericPassword`, scoped to `accessGroup` (the App
/// Group's team-prefixed identifier). Values are stored as UTF-8 data.
enum KeychainStore {
    /// The shared access group string. The runtime resolves this against the
    /// entitlement `keychain-access-groups` automatically when the entitlement
    /// contains `$(AppIdentifierPrefix)group.yyh.roastmate.app`. When the
    /// entitlement isn't present (older builds), Security falls back to the
    /// per-app keychain — reads/writes still succeed inside the main app.
    static let accessGroup: String = "group.yyh.roastmate.app"

    enum Key: String {
        case appleUserID = "apple.user.id"
        case appleFullName = "apple.user.full_name"
        case appleEmail = "apple.user.email"
        /// Stable per-install opaque UUID. Sent to the Cloud Vent Worker
        /// as the rate-limit bucket key. Pre-existing case kept for
        /// schema migration safety.
        case deviceID = "device.id"
        /// Reserved for a future BYOK path; not used by the current
        /// proxy-based cloud architecture. Left here to avoid renaming
        /// the enum on a hypothetical opt-in BYOK toggle later.
        case openRouterAPIKey = "openrouter.api_key"
    }

    @discardableResult
    static func set(_ value: String?, for key: Key) -> Bool {
        guard let value = value, !value.isEmpty else { return remove(key) }
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessGroup as String: accessGroup
        ]
        let attrs: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var add = query
            add.merge(attrs) { _, new in new }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
        return false
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func remove(_ key: Key) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessGroup as String: accessGroup
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
