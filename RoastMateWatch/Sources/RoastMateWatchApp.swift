import SwiftUI
import SwiftData

@main
struct RoastMateWatchApp: App {
    let modelContainer: ModelContainer = SharedModelContainer.modelContainer

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        .modelContainer(modelContainer)
    }
}
