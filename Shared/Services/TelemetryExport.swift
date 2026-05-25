import Foundation

/// A′ telemetry export — builds the single JSON snapshot the user can
/// share via the iOS/macOS Share Sheet. Pure, deterministic, unit-tested.
/// Schema documented in `docs/A_PRIME_TELEMETRY.md`.

public struct TelemetrySnapshot: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let exportedAtWeek: String     // e.g. "2026-W21"
    public let appVersion: String         // MARKETING_VERSION
    public let build: String              // CURRENT_PROJECT_VERSION
    public let platform: String           // "iOS" | "macOS"
    public let osMajor: Int
    public let locale: String             // BCP-47, e.g. "zh-Hans"
    public let installWeek: String?       // nil if firstLaunchDate never set
    public let consentState: String       // "notAsked" | "granted" | "denied"
    public let optInWeek: String?         // ISO week telemetry was first enabled
    public let counters: [String: Int]

    // Lock the JSON key names — they're a public schema. Don't auto-snake-
    // case via JSONEncoder; spell them explicitly.
    private enum CodingKeys: String, CodingKey {
        case schemaVersion   = "schema_version"
        case exportedAtWeek  = "exported_at_week"
        case appVersion      = "app_version"
        case build
        case platform
        case osMajor         = "os_major"
        case locale
        case installWeek     = "install_week"
        case consentState    = "consent_state"
        case optInWeek       = "opt_in_week"
        case counters
    }
}

public enum TelemetryExport {
    /// Build a snapshot from the live counters + caller-supplied context.
    /// `now` defaults to `Date()`; tests inject a fixed clock.
    public static func buildSnapshot(
        counters: [String: Int],
        appVersion: String,
        build: String,
        platform: String,
        osMajor: Int,
        locale: String,
        installDate: Date?,
        consentState: String,
        optInDate: Date?,
        now: Date = Date()
    ) -> TelemetrySnapshot {
        TelemetrySnapshot(
            // schema v2 (ships in v1.0.2): adds feedback_thumbsup/down +
            // feedback_tag_* counters end-of-enum. v1 keys all preserved.
            schemaVersion: 2,
            exportedAtWeek: isoWeek(now),
            appVersion: appVersion,
            build: build,
            platform: platform,
            osMajor: osMajor,
            locale: locale,
            installWeek: installDate.map(isoWeek),
            consentState: consentState,
            optInWeek: optInDate.map(isoWeek),
            counters: counters
        )
    }

    /// Encode the snapshot to JSON bytes. Pretty-printed + sorted keys
    /// means a diff between two exports is meaningful, not noise.
    public static func jsonData(_ snapshot: TelemetrySnapshot,
                                pretty: Bool = true) throws -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = pretty
            ? [.prettyPrinted, .sortedKeys]
            : [.sortedKeys]
        return try enc.encode(snapshot)
    }

    /// ISO-8601 week stamp ("2026-W21") in UTC. Used for both
    /// `installWeek` and `optInWeek` so dates round to a granularity that
    /// can't fingerprint a session.
    public static func isoWeek(_ date: Date) -> String {
        let year = Self.utcISOCalendar.component(.yearForWeekOfYear, from: date)
        let week = Self.utcISOCalendar.component(.weekOfYear, from: date)
        return String(format: "%04d-W%02d", year, week)
    }

    /// Single shared UTC ISO-8601 calendar used for all week rounding.
    /// Class-level lazy const to keep `isoWeek` allocation-free on the
    /// hot path. ISO calendar so the year-for-week-of-year math matches
    /// the standard "weeks belong to the year of their Thursday" rule.
    static let utcISOCalendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        if let utc = TimeZone(identifier: "UTC") { c.timeZone = utc }
        return c
    }()

    /// Encode + write the snapshot to a temp-file URL ready to feed a
    /// SwiftUI `ShareLink(item:)`. File name embeds the ISO week so the
    /// user can tell snapshots apart in Files / Mail.
    public static func writeJSONFile(_ snapshot: TelemetrySnapshot) throws -> URL {
        let data = try jsonData(snapshot)
        let name = "roastmate-anon-usage-\(snapshot.exportedAtWeek).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Live device context helpers (UI callers)
    // Pure tests should construct context fields directly instead.

    public static var currentPlatform: String {
        #if os(iOS)
        return "iOS"
        #elseif os(macOS)
        return "macOS"
        #elseif os(watchOS)
        return "watchOS"
        #else
        return "other"
        #endif
    }

    public static var currentOSMajor: Int {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion
    }

    public static var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    public static var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }
}
