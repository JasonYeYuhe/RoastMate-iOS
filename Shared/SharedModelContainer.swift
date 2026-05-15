import Foundation
import SwiftData
import os.log

/// Shared SwiftData container. Each target (iOS, watchOS, macOS) keeps its
/// own local store; cross-device sync flows through CloudKit's private
/// database (entitlement: `iCloud.yyh.roastmate.app`), which only works
/// when the configuration uses the default store URL — a custom `url:`
/// silently disables CloudKit. The Share extension does not use SwiftData
/// (it relays input via Handoff), so dropping the App-Group-backed store
/// costs nothing.
enum SharedModelContainer {
    /// App Group is still defined here so non-SwiftData consumers (Keychain
    /// for SIWA tokens) can reference it. Not used for the model store.
    static let appGroupIdentifier = "group.yyh.roastmate.app"

    static let modelContainer: ModelContainer = {
        let schema = Schema([
            RoastSession.self,
            GeneratedRoast.self,
            SavedSituation.self,
            UserSettings.self,
            SituationThread.self
        ])
        // Default-location configuration is required for SwiftData's
        // automatic CloudKit mirroring. CloudKit picks the iCloud
        // container from the app's entitlements
        // (`iCloud.yyh.roastmate.app`).
        let config = ModelConfiguration("RoastMate", schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            let logger = Logger(subsystem: "yyh.roastmate.app", category: "ModelContainer")
            logger.error("Failed to create ModelContainer: \(error.localizedDescription)")
            // Last-ditch fallback so the app at least launches in a usable
            // state for diagnostics; CloudKit may be unavailable but local
            // SwiftData will still work.
            do {
                return try ModelContainer(for: schema)
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }
    }()
}
