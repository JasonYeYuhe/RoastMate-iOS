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

    /// For `.ventDraft` results: which private-draft intensity actually
    /// produced this row (`.vent` mild release vs `.feral` profanity-
    /// unlocked rage). The kind enum stays as `.ventDraft` for both so
    /// legacy rows still classify as private drafts; the UI distinguishes
    /// the label / disclosure based on this field.
    ///
    /// Nil on rows written before this field existed — treat nil as
    /// `.vent` (the only private-draft intensity that existed at the
    /// time) so old vent drafts continue to render correctly.
    var sourceIntensityRaw: String?

    /// Back-pointer required by CloudKit-backed SwiftData: every to-many
    /// relationship (`RoastSession.results`) must have an inverse on the
    /// child side. Set automatically by SwiftData when the GeneratedRoast
    /// is appended to a session's `results`.
    var session: RoastSession?

    init(
        text: String,
        styleId: String,
        locale: String = Locale.current.identifier,
        kind: GeneratedRoastKind = .normalRoast,
        sourceVentDraftId: UUID? = nil,
        sourceIntensity: Intensity? = nil
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
        self.sourceIntensityRaw = sourceIntensity?.rawValue
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

    /// Resolved source intensity for `.ventDraft` rows. Legacy rows return
    /// `.vent`; new rows return whichever private intensity actually
    /// produced them. Returns nil for non-private-draft kinds so the UI
    /// can ignore the field for normal roasts and sendable replies.
    var sourceIntensity: Intensity? {
        get {
            guard kind == .ventDraft else { return nil }
            if let raw = sourceIntensityRaw, let value = Intensity(rawValue: raw) {
                return value
            }
            return .vent
        }
        set { sourceIntensityRaw = newValue?.rawValue }
    }
}
