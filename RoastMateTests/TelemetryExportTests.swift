import XCTest
@testable import RoastMate

final class TelemetryExportTests: XCTestCase {

    // MARK: - ISO week rounding

    func test_isoWeek_format() {
        // ISO 8601 calendar, UTC. A known reference: 2026-05-23 (the day
        // RoastMate iOS went live) is a Saturday in ISO week 21 of 2026.
        let comps = DateComponents(year: 2026, month: 5, day: 23)
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: comps)!
        XCTAssertEqual(TelemetryExport.isoWeek(date), "2026-W21")
    }

    func test_isoWeek_yearBoundaryFollowsThursdayRule() {
        // 2025-12-29 is a Monday → ISO week 1 of 2026 ("weeks belong to
        // the year of their Thursday"). Same date in a Gregorian-week
        // calendar would say week 52 of 2025; we must NOT do that.
        let comps = DateComponents(year: 2025, month: 12, day: 29)
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: comps)!
        XCTAssertEqual(TelemetryExport.isoWeek(date), "2026-W01")
    }

    // MARK: - Snapshot shape + Codable

    func test_buildSnapshot_populatesAllFields() {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 25))!
        let install = cal.date(from: DateComponents(year: 2026, month: 5, day: 18))!

        let snap = TelemetryExport.buildSnapshot(
            counters: ["paywall_impressions": 3, "generations_total": 7],
            appVersion: "1.0.0",
            build: "7",
            platform: "iOS",
            osMajor: 26,
            locale: "zh-Hant",
            installDate: install,
            consentState: "granted",
            optInDate: install,
            now: now
        )

        XCTAssertEqual(snap.schemaVersion, 1)
        XCTAssertEqual(snap.exportedAtWeek, "2026-W22")
        XCTAssertEqual(snap.appVersion, "1.0.0")
        XCTAssertEqual(snap.build, "7")
        XCTAssertEqual(snap.platform, "iOS")
        XCTAssertEqual(snap.osMajor, 26)
        XCTAssertEqual(snap.locale, "zh-Hant")
        XCTAssertEqual(snap.installWeek, "2026-W21")
        XCTAssertEqual(snap.consentState, "granted")
        XCTAssertEqual(snap.optInWeek, "2026-W21")
        XCTAssertEqual(snap.counters["generations_total"], 7)
        XCTAssertEqual(snap.counters["paywall_impressions"], 3)
    }

    func test_buildSnapshot_nilDates_returnNilWeeks() {
        let snap = TelemetryExport.buildSnapshot(
            counters: [:], appVersion: "1.0.0", build: "1",
            platform: "iOS", osMajor: 26, locale: "en-US",
            installDate: nil, consentState: "notAsked", optInDate: nil
        )
        XCTAssertNil(snap.installWeek)
        XCTAssertNil(snap.optInWeek)
    }

    // MARK: - JSON output is deterministic

    func test_jsonData_isDeterministic_andUsesSnakeKeys() throws {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 23))!
        let snap = TelemetryExport.buildSnapshot(
            counters: ["share_taps": 4, "generations_cloud": 1, "generations_total": 2],
            appVersion: "1.0.0", build: "7",
            platform: "macOS", osMajor: 26, locale: "ja",
            installDate: nil, consentState: "notAsked", optInDate: nil,
            now: now
        )
        let data1 = try TelemetryExport.jsonData(snap)
        let data2 = try TelemetryExport.jsonData(snap)
        XCTAssertEqual(data1, data2, "JSON output must be byte-deterministic.")

        let str = String(data: data1, encoding: .utf8) ?? ""
        // Snake-cased schema fields are stable contract — names locked.
        XCTAssertTrue(str.contains("\"schema_version\" : 1"))
        XCTAssertTrue(str.contains("\"exported_at_week\" : \"2026-W21\""))
        XCTAssertTrue(str.contains("\"os_major\" : 26"))
        XCTAssertTrue(str.contains("\"counters\""))
        // No leaking PII / free-text fields — only counters + context.
        XCTAssertFalse(str.contains("situation"))
        XCTAssertFalse(str.contains("vent"))
    }

    func test_jsonData_roundTrips() throws {
        let snap = TelemetryExport.buildSnapshot(
            counters: ["session_starts": 9],
            appVersion: "1.0.0", build: "7",
            platform: "iOS", osMajor: 26, locale: "en-US",
            installDate: nil, consentState: "denied", optInDate: nil
        )
        let data = try TelemetryExport.jsonData(snap)
        let decoded = try JSONDecoder().decode(TelemetrySnapshot.self, from: data)
        XCTAssertEqual(decoded, snap)
    }

    // MARK: - File writer

    func test_writeJSONFile_writesValidFile() throws {
        let snap = TelemetryExport.buildSnapshot(
            counters: ["session_starts": 1],
            appVersion: "1.0.0", build: "7",
            platform: "iOS", osMajor: 26, locale: "en-US",
            installDate: nil, consentState: "notAsked", optInDate: nil
        )
        let url = try TelemetryExport.writeJSONFile(snap)
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "json")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(TelemetrySnapshot.self, from: data)
        XCTAssertEqual(decoded.counters["session_starts"], 1)
    }
}
