import XCTest
@testable import RoastMate

/// Pillar D: two-tier self-harm crisis handoff. Also pins the
/// guarantee that the crisis layer is *additive* — the existing
/// safety filters must behave exactly as before.
final class CrisisDetectionTests: XCTestCase {

    // MARK: - Hard tier (explicit ideation → intercept, do not generate)

    func testHard_english() {
        XCTAssertEqual(SafetyFilter.crisisSignal("I want to kill myself"), .hard)
        XCTAssertEqual(SafetyFilter.crisisSignal("I feel suicidal tonight"), .hard)
        XCTAssertEqual(SafetyFilter.crisisSignal("there's no reason to live"), .hard)
    }

    func testHard_chinese() {
        XCTAssertEqual(SafetyFilter.crisisSignal("我不想活了"), .hard)
        XCTAssertEqual(SafetyFilter.crisisSignal("我想自杀"), .hard)
        XCTAssertEqual(SafetyFilter.crisisSignal("我想自殺"), .hard)   // Traditional
    }

    func testHard_japanese() {
        XCTAssertEqual(SafetyFilter.crisisSignal("もう自殺したい"), .hard)
    }

    // MARK: - Soft tier (hyperbole-prone → still generate, show banner)

    func testSoft_isNotHard() {
        XCTAssertEqual(SafetyFilter.crisisSignal("this meeting makes me want to die"), .soft)
        XCTAssertEqual(SafetyFilter.crisisSignal("唉我想死"), .soft)
        XCTAssertEqual(SafetyFilter.crisisSignal("もう死にたい"), .soft)
    }

    // MARK: - None (normal / anger-at-others is not a self-harm signal)

    func testNone_normalAndSecondPerson() {
        XCTAssertEqual(SafetyFilter.crisisSignal("My roommate plays music at 3am."), .none)
        XCTAssertEqual(SafetyFilter.crisisSignal("我同事抢了我的功劳"), .none)
        // Aimed at *others* — denylist territory, not the user's own risk.
        XCTAssertEqual(SafetyFilter.crisisSignal("I'm going to kill yourself"), .none)
        XCTAssertEqual(SafetyFilter.crisisSignal("我要弄死你"), .none)
    }

    // MARK: - Additive guarantee: existing filters unchanged

    func testExistingFiltersUnchanged() {
        // Denylist still blocks (regression of SafetyFilterTests).
        XCTAssertThrowsError(try SafetyFilter.validateInput("I'm going to kill yourself"))
        XCTAssertThrowsError(try SafetyFilter.validateInput("我要弄死你"))
        // Normal input still passes.
        XCTAssertNoThrow(try SafetyFilter.validateInput("My roommate plays music at 3am."))
        // Output validator still trims + passes.
        XCTAssertEqual(try SafetyFilter.validateOutput("  hi  "), "hi")
        // crisisSignal is pure (no throw) and doesn't change later filters.
        _ = SafetyFilter.crisisSignal("I want to kill myself")
        XCTAssertNoThrow(try SafetyFilter.validateInput("My roommate plays music at 3am."))
    }

    // MARK: - Crisis resources

    func testRegionalResourcesNonEmptyAndRouted() {
        let hant = CrisisResources.regionalResources(for: Locale(identifier: "zh-Hant"))
        XCTAssertTrue(hant.contains { $0.id == "hk-sbhk" })

        let ja = CrisisResources.regionalResources(for: Locale(identifier: "ja"))
        XCTAssertTrue(ja.contains { $0.id.hasPrefix("jp-") })

        let en = CrisisResources.regionalResources(for: Locale(identifier: "en-US"))
        XCTAssertTrue(en.contains { $0.id == "us-988" })

        let hans = CrisisResources.regionalResources(for: Locale(identifier: "zh-Hans"))
        XCTAssertFalse(hans.isEmpty)

        XCTAssertEqual(CrisisResources.directoryURL.host, "findahelpline.com")
    }
}
