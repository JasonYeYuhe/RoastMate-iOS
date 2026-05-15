import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsQuery: [UserSettings]
    @State private var showOnboarding = false
    @State private var selection: AppSection = .generator

    private var settings: UserSettings? { settingsQuery.first }

    var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView {
                sidebar
            } detail: {
                detail
            }
            #else
            TabView(selection: $selection) {
                NavigationStack { RoastGeneratorView() }
                    .tabItem { Label("tab.generator", systemImage: "flame") }
                    .tag(AppSection.generator)

                NavigationStack { ExploreView() }
                    .tabItem { Label("tab.library", systemImage: "books.vertical") }
                    .tag(AppSection.library)

                NavigationStack { HistoryView(onContinueGenerator: { selection = .generator }) }
                    .tabItem { Label("tab.history", systemImage: "clock.arrow.circlepath") }
                    .tag(AppSection.history)

                NavigationStack { SettingsView() }
                    .tabItem { Label("tab.settings", systemImage: "gear") }
                    .tag(AppSection.settings)
            }
            #endif
        }
        .onAppear {
            // UI-test mode never shows onboarding — screenshots need the
            // main UI immediately, in the forced language.
            if AppLaunchEnvironment.isUITest { return }
            if let s = settings, !s.hasSeenOnboarding {
                showOnboarding = true
            }
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .interactiveDismissDisabled(true)
        }
        .onContinueUserActivity(HandoffActivity.typeRoastSession) { activity in
            if let payload = HandoffActivity.ContinuationPayload(from: activity.userInfo) {
                HandoffStore.shared.pending = payload
                selection = .generator
            }
        }
    }

    #if os(macOS)
    private var sidebar: some View {
        List(selection: $selection) {
            Label("tab.generator", systemImage: "flame").tag(AppSection.generator)
            Label("tab.library", systemImage: "books.vertical").tag(AppSection.library)
            Label("tab.history", systemImage: "clock.arrow.circlepath").tag(AppSection.history)
            Label("tab.settings", systemImage: "gear").tag(AppSection.settings)
        }
        .frame(minWidth: 180)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .generator: RoastGeneratorView()
        case .library:   ExploreView()
        case .history:   HistoryView(onContinueGenerator: { selection = .generator })
        case .settings:  SettingsView()
        }
    }
    #endif
}

enum AppSection: Hashable, Sendable {
    case generator, library, history, settings
}
