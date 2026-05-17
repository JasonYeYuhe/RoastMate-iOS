import XCTest
@testable import RoastMate

/// zh-first scenario pack. Pins the invariants that keep tapping a
/// scenario friendly: it must pre-fill a FREE-tier style + a non-Pro
/// intensity (so a free user isn't instantly walled), every category
/// is represented, and prompts localize with an English fallback.
@MainActor
final class ScenarioCatalogTests: XCTestCase {

    private var catalog: ScenarioCatalog { ScenarioCatalog.shared }

    func testCatalogLoadsAndIdsAreUnique() {
        let all = catalog.all
        XCTAssertGreaterThanOrEqual(all.count, 8)
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "Scenario ids must be unique")
    }

    func testAllCuratedCategoriesPresentInOrder() {
        XCTAssertEqual(catalog.orderedCategories, ScenarioCatalog.categoryOrder)
        for cat in ScenarioCatalog.categoryOrder {
            XCTAssertFalse(catalog.scenarios(in: cat).isEmpty, "Category \(cat) has no scenarios")
        }
    }

    func testEveryScenarioPrefillsAFreeStyleAndNonProIntensity() {
        for s in catalog.all {
            let style = StyleCatalog.shared.style(id: s.defaultStyleId)
            XCTAssertNotNil(style, "\(s.id): unknown styleId \(s.defaultStyleId)")
            XCTAssertEqual(style?.tier, .free,
                           "\(s.id): scenario must default to a FREE style, not paywall on prefill")
            XCTAssertFalse(s.intensity.requiresPro,
                           "\(s.id): scenario must default to a non-Pro intensity")
        }
    }

    func testPromptLocalizationAndFallback() {
        for s in catalog.all {
            XCTAssertFalse(s.prompt["en"]?.isEmpty ?? true, "\(s.id): missing en prompt")
            for code in ["zh-Hans", "zh-Hant", "ja"] {
                XCTAssertFalse(s.prompt[code]?.isEmpty ?? true, "\(s.id): missing \(code) prompt")
            }
            // zh-Hant locale resolves to the Traditional prompt…
            let hant = s.prompt(for: Locale(identifier: "zh-Hant-TW"))
            XCTAssertEqual(hant, s.prompt["zh-Hant"])
            // …and an unsupported locale falls back to English.
            XCTAssertEqual(s.prompt(for: Locale(identifier: "ko-KR")), s.prompt["en"])
        }
    }

    func testCategoryKeyMatchesLocalizationConvention() {
        for s in catalog.all {
            XCTAssertEqual(s.categoryKey, "scenario.cat.\(s.category)")
        }
    }
}
