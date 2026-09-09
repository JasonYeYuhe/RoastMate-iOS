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

    /// Guards the rule rather than the instances: any CJK term whose
    /// Traditional form differs must have both forms present, or the next term
    /// someone adds reintroduces the same gap.
    ///
    /// This test used to cover exactly ONE list (the JSON denylist) with a
    /// hand-written six-character map, two entries of which (刘/国) matched no
    /// term at all. It stayed green while four more Simplified-only lists sat
    /// in SafetyFilter.swift — including `ventHardRail`, the last gate on
    /// cloud vent output. It now walks EVERY matching list in the file, and it
    /// walks them in BOTH directions, because the real defect is an *unpaired*
    /// term, not specifically a Simplified one (了結自己 shipped
    /// Traditional-only and left zh-Hans unguarded).
    private static let simplifiedToTraditional: [Character: Character] = [
        "杀": "殺", "残": "殘", "强": "強", "奸": "姦", "刘": "劉", "国": "國",
        "着": "著", "没": "沒", "义": "義", "脱": "脫", "撑": "撐", "聋": "聾",
        "伤": "傷", "们": "們", "妈": "媽", "结": "結", "轻": "輕", "写": "寫",
        "发": "發", "泄": "洩", "谢": "謝", "线": "線", "别": "別", "复": "覆",
    ]

    /// Kana means the term is Japanese, where these characters are simply the
    /// correct spelling and have no Traditional "twin" (自殺したい,
    /// 自分を傷つけ). Without this guard the walk reports false positives.
    private func containsKana(_ term: String) -> Bool {
        term.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
    }

    private func assertScriptParity(_ terms: [String], listName: String) {
        let s2t = Self.simplifiedToTraditional
        let t2s = Dictionary(uniqueKeysWithValues: s2t.map { ($0.value, $0.key) })
        let set = Set(terms)
        for term in terms where !containsKana(term) {
            for (name, map) in [("Traditional", s2t), ("Simplified", t2s)] {
                let converted = String(term.map { map[$0] ?? $0 })
                guard converted != term else { continue }   // script-identical, fine
                XCTAssertTrue(set.contains(converted),
                              "[\(listName)] '\(term)' has a distinct \(name) form "
                              + "'\(converted)' that is NOT in the list — the other "
                              + "script would be unguarded")
            }
        }
    }

    func testEveryCJKDenylistTermHasBothScriptForms() throws {
        assertScriptParity(try SafetyFilter.denylistTermsForTesting(),
                           listName: "ForbiddenTerms.json")
    }

    /// The instance-agnostic half: every in-code matching list, not just the
    /// JSON one. A new list added to `matchingListsForTesting()` is covered
    /// automatically; a new list NOT added there is the thing to watch for.
    func testEveryInCodeCJKMatchingListHasBothScriptForms() {
        let lists = SafetyFilter.matchingListsForTesting()
        XCTAssertFalse(lists.isEmpty, "no matching lists exposed — accessor regressed")
        for (name, terms) in lists {
            assertScriptParity(terms, listName: name)
        }
    }

    /// The specific P0 that shipped: the vent hard rail is the ONLY denylist
    /// applied to private drafts and to cloud vent output, and it carried
    /// 杀了你 / 自杀 without their Traditional twins.
    func testVentHardRailBlocksBothScriptsOfTheHardCases() {
        for term in ["杀了你", "殺了你", "自杀", "自殺", "去死"] {
            XCTAssertThrowsError(try SafetyFilter.validateVentOutput("你这种人\(term)算了"),
                                 "vent hard rail did not block '\(term)'")
        }
    }

    /// Both scripts of the self-harm phrases must reach the same tier, or a
    /// Traditional user in distress silently gets a roast instead of care.
    func testCrisisSignalIsScriptSymmetric() {
        for (hans, hant) in [("我想自杀", "我想自殺"), ("了结自己", "了結自己")] {
            XCTAssertEqual(SafetyFilter.crisisSignal(hans), SafetyFilter.crisisSignal(hant),
                           "'\(hans)' and '\(hant)' resolved to different crisis tiers")
            XCTAssertEqual(SafetyFilter.crisisSignal(hant), .hard,
                           "'\(hant)' should be a HARD self-harm signal")
        }
        for (hans, hant) in [("活着没意思", "活著沒意思"), ("我撑不下去", "我撐不下去"),
                             ("解脱算了", "解脫算了")] {
            XCTAssertEqual(SafetyFilter.crisisSignal(hans), SafetyFilter.crisisSignal(hant),
                           "'\(hans)' and '\(hant)' resolved to different crisis tiers")
            XCTAssertEqual(SafetyFilter.crisisSignal(hant), .soft,
                           "'\(hant)' should be a SOFT self-harm signal")
        }
    }
}
