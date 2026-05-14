import XCTest
@testable import RoastMate

@MainActor
final class StyleCatalogTests: XCTestCase {
    func testCatalogLoadsAtLeast15Styles() {
        let count = StyleCatalog.shared.all.count
        XCTAssertGreaterThanOrEqual(count, 15)
    }

    func testFreeAndProTiersExist() {
        let free = StyleCatalog.shared.byTier(.free)
        let pro = StyleCatalog.shared.byTier(.pro)
        XCTAssertGreaterThanOrEqual(free.count, 6)
        XCTAssertGreaterThanOrEqual(pro.count, 6)
    }

    func testCoreStyleIdsExist() {
        for id in ["high_eq", "passive_aggressive", "jp_workplace_keigo", "philosopher", "shakespeare", "mba_boss"] {
            XCTAssertNotNil(StyleCatalog.shared.style(id: id), "missing style: \(id)")
        }
    }

    func testStyleIdsUnique() {
        let ids = StyleCatalog.shared.all.map(\.id)
        let unique = Set(ids)
        XCTAssertEqual(ids.count, unique.count)
    }

    func testDefaultStyleIsFreeTier() {
        let defaultId = StyleCatalog.shared.defaultStyleId
        let style = StyleCatalog.shared.style(id: defaultId)
        XCTAssertEqual(style?.tier, .free)
    }
}
