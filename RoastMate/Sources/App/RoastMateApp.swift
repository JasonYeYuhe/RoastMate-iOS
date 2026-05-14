import SwiftUI
import SwiftData

@main
struct RoastMateApp: App {
    let modelContainer: ModelContainer = SharedModelContainer.modelContainer
    private var languageManager = LanguageManager.shared
    @State private var bootstrapDone = false

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, languageManager.locale ?? .current)
                .task {
                    if !bootstrapDone {
                        await bootstrap()
                        bootstrapDone = true
                    }
                }
        }
        .modelContainer(modelContainer)
        #if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 980, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        #endif

        #if os(macOS)
        MenuBarExtra("RoastMate", systemImage: "flame") {
            MacMenuBarContent()
                .environment(\.locale, languageManager.locale ?? .current)
                .modelContainer(modelContainer)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .modelContainer(modelContainer)
                .environment(\.locale, languageManager.locale ?? .current)
                .frame(width: 520, height: 600)
        }
        #endif
    }

    @MainActor
    private func bootstrap() async {
        let context = modelContainer.mainContext
        _ = HistoryService.userSettings(context: context)
        HistoryService.seedSamplesIfNeeded(context: context)
        await StoreService.shared.loadProducts()
        await AuthService.shared.refreshCredentialStateOnLaunch()
    }
}
