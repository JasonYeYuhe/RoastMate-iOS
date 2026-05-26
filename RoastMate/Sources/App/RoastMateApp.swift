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
        // A′ telemetry: mirror the canonical UserSettings opt-in into the
        // App-Group defaults EventLedger reads lock-free, then record
        // this session start. Opt-out by default → setOptIn(false) is the
        // no-op default and recordSessionStart is a no-op until the user
        // explicitly enables telemetry in Settings.
        EventLedger.shared.setOptIn(settings.telemetryOptedIn)
        EventLedger.shared.recordSessionStart()
        // α3: per-session "this session produced at least one generation"
        // gate re-arms on cold launch. sessions_with_generation /
        // session_starts is the D7/D30 return-to-tool proxy.
        EventLedger.shared.resetSessionMarkers()
        // ε1: per-session rating-prompt counters start fresh on cold
        // launch so the 3-successful-generations gate resets each session.
        RatingPromptService.shared.resetSession()
        if AppLaunchEnvironment.isUITest {
            // Deterministic UI-test state: no onboarding / age gate /
            // content-notice walls so screenshots land on the real UI.
            settings.hasSeenOnboarding = true
            settings.hasAcknowledgedAgeGate = true
            settings.hasAcknowledgedContentNotice = true
            try? context.save()
        }
        HistoryService.seedSamplesIfNeeded(context: context)
        // Install the durable-first credit settler: persist the grant +
        // the exactly-once ledger and save BEFORE StoreService finishes
        // the StoreKit transaction. Returning false (save failed) leaves
        // the transaction unfinished for StoreKit to replay — no lost
        // paid credits, no double-grant. Local-only; no backend.
        StoreService.shared.creditSettler = { txID, credits in
            let s = HistoryService.userSettings(context: context)
            if s.hasGrantedCreditTx(txID) { return true }
            // β3: pass context so the grant lands as a
            // CreditLedgerEntry(.grant, txID:) record — cross-device
            // safe under set-union merge instead of scalar last-write-
            // wins on creditBalanceRaw.
            s.applyCreditGrant(txID: txID, credits: credits, context: context)
            do {
                try context.save()
                return true
            } catch {
                // Roll back so the in-memory ledger matches persisted
                // truth — otherwise a later settle would see the txID as
                // granted and finish the transaction without it ever
                // being durable. false ⇒ leave unfinished for replay.
                context.rollback()
                return false
            }
        }
        // β3: recompute the cached balance from the ledger on every
        // cold launch so contextless readers see the latest merged
        // truth (modulo CloudKit sync latency). Idempotent.
        CreditWallet.recomputeBalance(context: context, settings: settings)
        try? context.save()
        // β2: write StoreKit-verified Pro state through to UserSettings
        // so CloudKit can mirror it to other devices on the same Apple
        // ID. StoreKit stays canonical — this is a trust-signal mirror
        // only. Clearing on `isPro = false` resets the optimistic grace
        // window everywhere.
        StoreService.shared.proPersister = { isPro in
            let s = HistoryService.userSettings(context: context)
            s.proLastVerifiedAt = isPro ? Date() : nil
            try? context.save()
        }
        // β2: optimistic Pro seed from CloudKit — lights up Pro
        // capabilities immediately on a fresh device while StoreKit
        // verifies in the background. Stale grants outside the grace
        // window are ignored; StoreKit will downgrade if the
        // entitlement has actually expired.
        StoreService.shared.seedOptimisticPro(verifiedAt: settings.proLastVerifiedAt)
        await StoreService.shared.loadProducts()
        // β2: StoreKit verification AFTER products load — this is the
        // canonical path. Confirms or revokes the optimistic seed and
        // (via proPersister) refreshes proLastVerifiedAt for sibling
        // devices' next optimistic seed.
        await StoreService.shared.refreshSubscriptionStatus()
        // Recover any consumable delivered while the app was not
        // foregrounded (Ask-to-Buy approval, interrupted purchase).
        await StoreService.shared.settleConsumables()
        await AuthService.shared.refreshCredentialStateOnLaunch()
    }
}
