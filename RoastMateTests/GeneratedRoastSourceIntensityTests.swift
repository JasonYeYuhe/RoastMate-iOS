import SwiftData
import XCTest
@testable import RoastMate

/// Verifies the v1.4 `sourceIntensity` field on `GeneratedRoast`:
/// - Persisted distinctly for vent vs feral private drafts.
/// - Legacy rows (`sourceIntensityRaw == nil`) read back as `.vent`,
///   preserving the only private-draft intensity that existed pre-v1.4.
/// - Returns nil for non-private-draft kinds so the UI can ignore the
///   field on normal roasts and sendable replies.
@MainActor
final class GeneratedRoastSourceIntensityTests: XCTestCase {
    func testSaveSessionWritesVentSourceForVentIntensity() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "X",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["draft text"],
            context: context,
            isPro: true,
            intensity: .vent
        )
        let result = try XCTUnwrap(session.results?.first)
        XCTAssertEqual(result.kind, .ventDraft)
        XCTAssertEqual(result.sourceIntensity, .vent)
        XCTAssertEqual(result.sourceIntensityRaw, "vent")
    }

    func testSaveSessionWritesFeralSourceForFeralIntensity() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "X",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["raging draft"],
            context: context,
            isPro: true,
            intensity: .feral
        )
        let result = try XCTUnwrap(session.results?.first)
        XCTAssertEqual(result.kind, .ventDraft,
                       "Feral still uses the ventDraft kind so legacy UI continues to treat it as private.")
        XCTAssertEqual(result.sourceIntensity, .feral)
        XCTAssertEqual(result.sourceIntensityRaw, "feral")
    }

    func testSaveSessionDoesNotWriteSourceIntensityForSendableIntensities() throws {
        let context = try makeContext()
        let session = HistoryService.saveSession(
            situation: "X",
            mode: .roast,
            styleId: "high_eq",
            locale: Locale(identifier: "en_US"),
            variants: ["polished reply"],
            context: context,
            isPro: true,
            intensity: .sharp
        )
        let result = try XCTUnwrap(session.results?.first)
        XCTAssertEqual(result.kind, .normalRoast)
        XCTAssertNil(result.sourceIntensityRaw,
                     "Non-private intensities must not populate sourceIntensityRaw.")
        XCTAssertNil(result.sourceIntensity,
                     "Non-private-draft kinds expose nil sourceIntensity to the UI.")
    }

    func testLegacyVentDraftNilSourceReadsAsVent() throws {
        // Simulates a pre-v1.4 row: ventDraft kind, but `sourceIntensityRaw`
        // was never written. The getter must fall back to `.vent` so old
        // drafts continue to render with the vent label / disclosure.
        let legacy = GeneratedRoast(
            text: "legacy vent draft",
            styleId: "high_eq",
            kind: .ventDraft
        )
        XCTAssertNil(legacy.sourceIntensityRaw)
        XCTAssertEqual(legacy.sourceIntensity, .vent,
                       "Legacy nil sourceIntensity must read as `.vent` to preserve old UI behavior.")
    }

    func testSourceIntensityNilForNonPrivateDraftKindsEvenIfRawIsSet() throws {
        // Defensive: if some path wrote sourceIntensityRaw on a non-vent
        // kind, the getter should still return nil so the UI doesn't
        // accidentally label a normal roast as a feral draft.
        let weird = GeneratedRoast(
            text: "polished reply",
            styleId: "high_eq",
            kind: .normalRoast
        )
        weird.sourceIntensityRaw = "feral"
        XCTAssertNil(weird.sourceIntensity,
                     "sourceIntensity getter is gated on kind==.ventDraft.")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration("SourceIntensityTests", schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }
}
