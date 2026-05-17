import SwiftUI
import SwiftData

@main
struct RoastMateApp: App {
    let modelContainer: ModelContainer = SharedModelContainer.modelContainer
    private var languageManager = LanguageManager.shared
    @State private var bootstrapDone = false

    init() {
        // UI-test screenshots need a deterministic UI language.
        // `.environment(\.locale,)` alone doesn't reliably switch
        // `Text("key")` bundle localization across OS versions, so
        // when `-uitestLang <code>` is present we force the bundle's
        // language resolution by writing AppleLanguages before any
        // view (or Bundle localization lookup) is resolved. This runs
        // in the App initializer, the earliest SwiftUI entry point.
        if let code = AppLaunchEnvironment.uiTestLanguageCode {
            UserDefaults.standard.set([code], forKey: "AppleLanguages")
        }
    }

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
        let settings = HistoryService.userSettings(context: context)
        // Grant the one-time seeded trial wallet (fresh installs + a
        // single top-up for users upgrading into v1.1). Idempotent.
        settings.ensureTrialWalletSeeded()
        try? context.save()
        if AppLaunchEnvironment.isUITest {
            // Deterministic UI-test state: no onboarding / age gate /
            // content-notice walls so screenshots land on the real UI.
            settings.hasSeenOnboarding = true
            settings.hasAcknowledgedAgeGate = true
            settings.hasAcknowledgedContentNotice = true
            try? context.save()
        }
        HistoryService.seedSamplesIfNeeded(context: context)
        await StoreService.shared.loadProducts()
        // Drain any consumable credits delivered while the app was not
        // foregrounded (Ask-to-Buy approval, interrupted purchase) into
        // the on-device wallet. Local-only; no server reconciliation by
        // design. The paywall drains again on appear for the live case.
        let pendingCredits = StoreService.shared.pendingCreditGrant
        if pendingCredits > 0 {
            settings.grantCredits(pendingCredits)
            StoreService.shared.pendingCreditGrant = 0
            try? context.save()
        }
        await AuthService.shared.refreshCredentialStateOnLaunch()
    }
}
