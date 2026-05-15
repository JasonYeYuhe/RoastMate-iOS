import Foundation
import SwiftData

/// Higher-level grouping for the "continue this event" flow. A user typically
/// goes through several rounds of roasting / replying / venting about the
/// same underlying incident ("boss dumped the project on me", "ex texted me
/// after six months"). Each round is a `RoastSession`; a `SituationThread`
/// groups those rounds together so the model can be given the prior context
/// on the next turn.
///
/// Threads are **incremental** — existing one-off RoastSessions remain
/// thread-less and continue to work unchanged. New "continue this" actions
/// upgrade an existing session into a thread by creating one of these and
/// pointing both sessions at it.
enum SituationCategory: String, Codable, CaseIterable, Sendable {
    case work
    case relationship
    case family
    case friends
    case internet
    case other

    var displayKey: String { "category.\(rawValue).name" }
    var displayName: String { String(localized: String.LocalizationValue(displayKey)) }
}

enum SituationMood: String, Codable, CaseIterable, Sendable {
    case angry
    case wronged
    case speechless
    case anxious
    case petty
    case amused

    var displayKey: String { "mood.\(rawValue).name" }
    var displayName: String { String(localized: String.LocalizationValue(displayKey)) }
}

@Model
final class SituationThread {
    var id: UUID = UUID()

    /// Auto-generated short label, e.g. "老板临时甩锅" / "Roommate ate my food".
    /// Editable by the user.
    var title: String = ""

    /// Free-text first description by the user (what originally happened).
    /// Subsequent escalations live in the child `RoastSession.situation`
    /// fields, with this as the root context.
    var originalSituation: String = ""

    var categoryRaw: String = SituationCategory.other.rawValue
    var moodRaw: String?

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var isFavorite: Bool = false
    var isResolved: Bool = false

    /// True for in-bundle seeded sample threads (one ships with v1.4 to
    /// demonstrate the multi-round "continue this situation" flow to App
    /// Store reviewers + new users). Cleanup honors this flag the same way
    /// `RoastSession.isSampleData` does, so the user can wipe demo data
    /// from Settings without touching their own threads.
    var isSampleData: Bool = false

    /// Inverse relationship to the sessions inside this thread. Cascade on
    /// thread deletion is intentional — deleting the thread removes the
    /// session records too. Optional + default `[]` for CloudKit
    /// compatibility (SwiftData+CloudKit requires all to-many relationships
    /// be optional).
    @Relationship(deleteRule: .cascade, inverse: \RoastSession.thread)
    var sessions: [RoastSession]? = []

    init(
        title: String,
        originalSituation: String,
        category: SituationCategory = .other,
        mood: SituationMood? = nil,
        isSampleData: Bool = false
    ) {
        let now = Date()
        self.id = UUID()
        self.title = title
        self.originalSituation = originalSituation
        self.categoryRaw = category.rawValue
        self.moodRaw = mood?.rawValue
        self.createdAt = now
        self.updatedAt = now
        self.isFavorite = false
        self.isResolved = false
        self.isSampleData = isSampleData
        self.sessions = []
    }

    var category: SituationCategory {
        get { SituationCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var mood: SituationMood? {
        get { moodRaw.flatMap(SituationMood.init(rawValue:)) }
        set { moodRaw = newValue?.rawValue }
    }
}
