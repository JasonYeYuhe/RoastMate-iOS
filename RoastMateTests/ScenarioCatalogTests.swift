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

    /// Every curated category header must RESOLVE in every shipped locale —
    /// not just exist as a convention. `localizedString(forKey:)` returns the
    /// key itself when the table misses, which is exactly the raw
    /// "scenario.cat.boss" regression this pins against.
    func testCategoryHeadersResolveInEveryLocale() {
        // Bundle.main is the xctest runner here (see ResourceBundle) — resolve
        // the app bundle via a type compiled into the RoastMate module.
        let appBundle = Bundle(for: ScenarioCatalog.self)
        for code in ["en", "zh-Hans", "zh-Hant", "ja"] {
            guard let path = appBundle.path(forResource: code, ofType: "lproj"),
                  let bundle = Bundle(path: path) else {
                XCTFail("Missing \(code).lproj in app bundle")
                continue
            }
            for cat in ScenarioCatalog.categoryOrder {
                let key = "scenario.cat.\(cat)"
                let value = bundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertNotEqual(value, key, "\(code): '\(key)' does not resolve")
                XCTAssertFalse(value.isEmpty, "\(code): '\(key)' resolves to empty")
            }
        }
    }
}
