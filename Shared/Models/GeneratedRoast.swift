import Foundation
import SwiftData

@Model
final class GeneratedRoast {
    var id: UUID = UUID()
    var text: String = ""
    var styleId: String = ""
    var localeRaw: String = ""
    var generatedAt: Date = Date()
    var wasShared: Bool = false
    var rating: Int = 0

    /// Distinguishes vent drafts (private) from sendable replies (the cleaned
    /// rewrite) and ordinary roasts. Nullable so old stores upgrade without
    /// migration; reads back as `.legacyDefault` (`.normalRoast`) when nil.
    var kindRaw: String?

    /// If this output is a `.sendableReply` produced by rewriting a
    /// `.ventDraft`, this is the id of that source draft. Empty otherwise.
    var sourceVentDraftIdRaw: String?

    /// Per-output favorite flag. Lets users star the *exact* variant they
    /// liked rather than the whole session.
    var isFavorite: Bool = false

    init(
        text: String,
        styleId: String,
        locale: String = Locale.current.identifier,
        kind: GeneratedRoastKind = .normalRoast,
        sourceVentDraftId: UUID? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.styleId = styleId
        self.localeRaw = locale
        self.generatedAt = Date()
        self.wasShared = false
        self.rating = 0
        self.kindRaw = kind.rawValue
        self.sourceVentDraftIdRaw = sourceVentDraftId?.uuidString
        self.isFavorite = false
    }

    var kind: GeneratedRoastKind {
        get {
            guard let raw = kindRaw, let value = GeneratedRoastKind(rawValue: raw) else {
                return .legacyDefault
            }
            return value
        }
        set { kindRaw = newValue.rawValue }
    }

    var sourceVentDraftId: UUID? {
        get {
            guard let s = sourceVentDraftIdRaw, !s.isEmpty else { return nil }
            return UUID(uuidString: s)
        }
        set { sourceVentDraftIdRaw = newValue?.uuidString }
    }
}
