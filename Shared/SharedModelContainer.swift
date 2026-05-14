import Foundation
import SwiftData
import os.log

/// Shared SwiftData container backed by the App Group so iOS, macOS, and watchOS
/// observe the same RoastMate database.
enum SharedModelContainer {
    static let appGroupIdentifier = "group.yyh.roastmate.app"

    static var storeURL: URL {
        let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return containerURL.appendingPathComponent("RoastMate.store")
    }

    static let modelContainer: ModelContainer = {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        let config = ModelConfiguration(
            "RoastMate",
            schema: schema,
            url: storeURL,
            allowsSave: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let logger = Logger(subsystem: "yyh.roastmate.app", category: "ModelContainer")
            logger.error(
                "Failed ModelContainer at \(storeURL.path): \(error.localizedDescription). Falling back to default location — App Group data will not sync."
            )
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }()
}
