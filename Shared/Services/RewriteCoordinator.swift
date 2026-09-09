import Foundation
import SwiftData
import os.log

/// Shared "rewrite a private draft into a sendable reply" path used by
/// both the live Generator screen and the historical surfaces (HistoryView
/// session detail, ThreadDetailView round cards).
///
/// The Generator screen still owns its inline state (rewritingDraftId on
/// the view model), so it calls the engine + persistence directly. This
/// coordinator is a thin wrapper for the historical surfaces, which need
/// the same effect — rewrite the draft, append the result back onto the
/// SAME session — without dragging the Generator's view model along.
///
/// Returns the appended `GeneratedRoast` on success. Throws engine /
/// safety errors so callers can show an inline error without inventing a
/// second code path.
@MainActor
enum RewriteCoordinator {

    /// The appended row plus who wrote it. Callers must surface `.curated`
    /// — see `GenerationProvenance`.
    struct Outcome {
        let row: GeneratedRoast?
        let provenance: GenerationProvenance

        var isCurated: Bool { provenance == .curated }
    }

    private static let logger = Logger(subsystem: "yyh.roastmate.app", category: "RewriteCoordinator")

    /// Engine + persistence in one call. Idempotent at the model layer —
    /// if a `.sendableReply` already exists for this draft, this call
    /// short-circuits and returns nil instead of producing a duplicate.
    @discardableResult
    static func rewriteAsSendable(
        draft: GeneratedRoast,
        session: RoastSession,
        context: ModelContext,
        locale: Locale
    ) async throws -> Outcome? {
        guard draft.kind == .ventDraft else {
            return nil
        }
        let alreadyPaired = (session.results ?? []).contains { result in
            result.kind == .sendableReply && result.sourceVentDraftId == draft.id
        }
        if alreadyPaired {
            return nil
        }
        guard let style = StyleCatalog.shared.style(id: draft.styleId) else {
            logger.warning("Rewrite skipped — style not found: \(draft.styleId, privacy: .public)")
            return nil
        }
        // `rewriteAsSendableDetailed`, not the text-only shim: without an
        // on-device model this returns a random curated ROAST line that never
        // read the user's draft, and `appendSendableReply` persists it as a
        // `.sendableReply` — which `GeneratedRoastKind.isShareable` allows, so
        // it gets a share-as-image button. Unlabelled canned text on a
        // shareable card is the exact defect this wave exists to remove, so the
        // provenance has to reach the caller.
        let rewritten = try await RoastEngine.shared.rewriteAsSendableDetailed(
            ventDraft: draft.text,
            originalSituation: session.situation,
            style: style,
            locale: locale
        )
        let row = HistoryService.appendSendableReply(
            toSession: session,
            sourceVentDraft: draft,
            rewrittenText: rewritten.text,
            context: context
        )
        return Outcome(row: row, provenance: rewritten.provenance)
    }
}
