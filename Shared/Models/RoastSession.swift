import Foundation
import SwiftData

enum RoastMode: String, Codable, CaseIterable, Sendable {
    case roast
    case reply
    case argument
    case translate
    case social
}

@Model
final class RoastSession {
    var id: UUID = UUID()
    var situation: String = ""
    var createdAt: Date = Date()
    var modeRaw: String = RoastMode.roast.rawValue
    var styleId: String = ""
    var localeRaw: String = ""
    var isFavorite: Bool = false
    var tags: [String] = []
    var isSampleData: Bool = false

    /// Added in v1.x along with the Vent Mode / intensity rework. Nullable
    /// so that pre-existing SwiftData stores upgrade without migration.
    /// Reads back as `Intensity.legacyDefault` when missing.
    var intensityRaw: String?

    /// Optional back-pointer to the SituationThread that owns this session.
    /// Sessions can exist standalone (legacy + ad-hoc) or be grouped into a
    /// thread for the "continue this event" flow.
    var thread: SituationThread?

    /// Optional for CloudKit — required by SwiftData+CloudKit integration.
    /// Initialized to `[]` so callers can append without unwrapping first.
    /// `inverse` points at `GeneratedRoast.session` (CloudKit also requires
    /// every to-many relationship to have an inverse).
    @Relationship(deleteRule: .cascade, inverse: \GeneratedRoast.session)
    var results: [GeneratedRoast]? = []

    init(
        situation: String,
        mode: RoastMode = .roast,
        styleId: String,
        locale: String = Locale.current.identifier,
        intensity: Intensity = .sharp,
        isSampleData: Bool = false
    ) {
        self.id = UUID()
        self.situation = situation
        self.createdAt = Date()
        self.modeRaw = mode.rawValue
        self.styleId = styleId
        self.localeRaw = locale
        self.isFavorite = false
        self.tags = []
        self.isSampleData = isSampleData
        self.intensityRaw = intensity.rawValue
        self.results = []
    }

    var mode: RoastMode {
        get { RoastMode(rawValue: modeRaw) ?? .roast }
        set { modeRaw = newValue.rawValue }
    }

    var intensity: Intensity {
        get {
            guard let raw = intensityRaw, let value = Intensity(rawValue: raw) else {
                return .legacyDefault
            }
            return value
        }
        set { intensityRaw = newValue.rawValue }
    }
}
