import Foundation

/// Per-install stable identifier sent to the Cloud Vent Worker so it can
/// enforce a daily rate limit without seeing the user's Apple ID.
/// Generated once and stored in Keychain (NOT UserDefaults) so it
/// survives app reinstalls within the same App Group as long as the
/// keychain item isn't purged.
///
/// The value is opaque: a v4 UUID. The Worker treats it as a string and
/// only uses it as a bucket key for the rate-limit counter.
enum DeviceID {
    static func current() -> String {
        if let existing = KeychainStore.get(.deviceID), !existing.isEmpty {
            return existing
        }
        let new = UUID().uuidString
        _ = KeychainStore.set(new, for: .deviceID)
        return new
    }
}
