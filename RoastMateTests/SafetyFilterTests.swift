import XCTest
@testable import RoastMate

final class SafetyFilterTests: XCTestCase {
    func testEmptyInputBlocked() {
        XCTAssertThrowsError(try SafetyFilter.validateInput("   "))
    }

    func testTooLongInputBlocked() {
        let big = String(repeating: "x", count: 2000)
        XCTAssertThrowsError(try SafetyFilter.validateInput(big))
    }

    func testNormalInputPasses() {
        XCTAssertNoThrow(try SafetyFilter.validateInput("My roommate plays music at 3am."))
    }

    func testDenylistInputBlocked() {
        XCTAssertThrowsError(try SafetyFilter.validateInput("I'm going to kill yourself"))
        XCTAssertThrowsError(try SafetyFilter.validateInput("我要弄死你"))
    }

    func testOutputTrimmingAndPass() throws {
        let result = try SafetyFilter.validateOutput("  hello world  ")
        XCTAssertEqual(result, "hello world")
    }

    func testOutputDenylistBlocked() {
        XCTAssertThrowsError(try SafetyFilter.validateOutput("You should drink bleach."))
    }

    // MARK: - Script parity in the denylist (regression, fixed 2026-09-06)
    //
    // 強姦 / 自殘 / 我要殺 were absent while 强奸 / 自残 / 我要杀 were present, so
    // this denylist — which guards user input AND the share-card render — was
    // weaker for zh-Hant than for zh-Hans. Same defect class as the Redactor
    // leak fixed in 500ffdb: a Simplified-only list on a shipped Traditional
    // locale. Written as SCRIPT PAIRS so the suite cannot again report coverage
    // one script does not have.

    func testDenylistBlocksBothScripts() {
        let pairs = [("我要杀了他", "我要殺了他"),
                     ("我想自残", "我想自殘"),
                     ("强奸", "強姦")]
        for (hans, hant) in pairs {
            XCTAssertThrowsError(try SafetyFilter.validateInput(hans),
                                 "Simplified not blocked: \(hans)")
            XCTAssertThrowsError(try SafetyFilter.validateInput(hant),
                                 "Traditional not blocked: \(hant)")
            XCTAssertThrowsError(try SafetyFilter.validateOutput(hant),
                                 "Traditional not blocked on OUTPUT: \(hant)")
        }
    }

    /// Guards the rule rather than the three instances: any CJK term whose
    /// Traditional form differs must have both forms present, or the next term
    /// someone adds reintroduces the same gap.
    func testEveryCJKDenylistTermHasBothScriptForms() throws {
        let simplifiedToTraditional: [Character: Character] = [
            "杀": "殺", "残": "殘", "强": "強", "奸": "姦", "刘": "劉", "国": "國",
        ]
        let terms = try SafetyFilter.denylistTermsForTesting()
        for term in terms {
            let converted = String(term.map { simplifiedToTraditional[$0] ?? $0 })
            guard converted != term else { continue }   // script-identical, fine
            XCTAssertTrue(terms.contains(converted),
                          "'\(term)' has a distinct Traditional form '\(converted)' "
                          + "that is NOT in the denylist — zh-Hant would be unguarded")
        }
    }
}
