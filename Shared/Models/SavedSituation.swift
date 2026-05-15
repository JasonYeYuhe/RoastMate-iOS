import Foundation
import SwiftData

@Model
final class SavedSituation {
    var id: UUID = UUID()
    var title: String = ""
    var situation: String = ""
    var defaultStyleId: String?
    var createdAt: Date = Date()

    init(title: String, situation: String, defaultStyleId: String? = nil) {
        self.id = UUID()
        self.title = title
        self.situation = situation
        self.defaultStyleId = defaultStyleId
        self.createdAt = Date()
    }
}
