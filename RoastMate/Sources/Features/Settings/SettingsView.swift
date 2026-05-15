import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsQuery: [UserSettings]
    @State private var languageManager = LanguageManager.shared
    @State private var showAbout = false
    @State private var showPaywall = false

    private var settings: UserSettings? { settingsQuery.first }
    private var version: String {
        let s = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return s
    }

    var body: some View {
        Form {
            AccountSection()

            Section(header: Text("settings.section.ai")) {
                Toggle("settings.safe_mode", isOn: Binding(
                    get: { settings?.safeModeEnabled ?? true },
                    set: { newValue in
                        settings?.safeModeEnabled = newValue
                        try? context.save()
                    }
                ))
                Text("settings.safe_mode.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("settings.cloud_vent", isOn: Binding(
                    get: { settings?.cloudVentEnabled ?? true },
                    set: { newValue in
                        settings?.cloudVentEnabled = newValue
                        try? context.save()
                    }
                ))
                Text("settings.cloud_vent.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showAbout = true
                } label: {
                    HStack {
                        Label("settings.about_ai.title", systemImage: "cpu")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }

            Section(header: Text("settings.section.appearance")) {
                Picker("settings.language", selection: $languageManager.selectedLanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang)
                    }
                }
            }

            Section(header: Text("settings.section.subscription")) {
                if StoreService.shared.isPro {
                    Label("Pro", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.orange)
                } else {
                    Button("settings.subscription.upgrade") { showPaywall = true }
                        .foregroundStyle(.orange)
                }
                Button("settings.subscription.restore") {
                    Task { await StoreService.shared.restorePurchases() }
                }
            }

            Section(header: Text("settings.section.about")) {
                Link(destination: URL(string: "https://jasonyeyuhe.github.io/RoastMate/privacy.html")!) {
                    HStack {
                        Label("settings.privacy_policy", systemImage: "lock.shield")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Link(destination: URL(string: "https://jasonyeyuhe.github.io/RoastMate/terms.html")!) {
                    HStack {
                        Label("settings.terms", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Link(destination: URL(string: "https://jasonyeyuhe.github.io/RoastMate/support.html")!) {
                    HStack {
                        Label("settings.support", systemImage: "questionmark.circle")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)

                Button("settings.clear_samples") {
                    HistoryService.clearSamples(context: context)
                }
                .foregroundStyle(.red)
                Text("settings.clear_samples.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("settings.version")
                    Spacer()
                    Text(version)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(AppLocalization.string("settings.title"))
        .sheet(isPresented: $showAbout) {
            AboutAIView(isPresented: $showAbout)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(isPresented: $showPaywall)
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

struct AboutAIView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "cpu")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("settings.about_ai.title")
                    .font(.title2.bold())
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Text("settings.about_ai.body")
                .font(.body)
                .multilineTextAlignment(.leading)
            Divider()
            Label("Apple Foundation Models · on-device", systemImage: "checkmark.seal")
                .foregroundStyle(.green)
            Label("No OpenAI / Anthropic / Google", systemImage: "xmark.shield")
                .foregroundStyle(.secondary)
            Label("settings.about_ai.privacy_label", systemImage: "lock.shield")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 380)
    }
}
