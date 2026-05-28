import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settingsQuery: [UserSettings]
    @State private var languageManager = LanguageManager.shared
    @State private var showAbout = false
    @State private var showPaywall = false
    @State private var preparedTelemetryURL: URL?

    /// Sunset date for the Phase 5 Q1 research recruit tile.
    /// 2026-11-01 00:00 UTC = end of Phase 5 Q1 (Oct 5) + ~4 weeks buffer
    /// for slow-rolling interview tails. After this date the tile auto-
    /// hides without needing a new app ship. To run another research
    /// wave, bump this constant + re-ship.
    static let researchRecruitDeadline: Date = {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 1
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .iso8601).date(from: comps) ?? .distantFuture
    }()

    private var settings: UserSettings? { settingsQuery.first }
    private var version: String {
        let s = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return s
    }

    /// Build the live A′ snapshot from the EventLedger + the user's
    /// `UserSettings` (the canonical source for opt-in/install dates).
    private func makeTelemetrySnapshot() -> TelemetrySnapshot {
        TelemetryExport.buildSnapshot(
            counters: EventLedger.shared.snapshot(),
            appVersion: TelemetryExport.currentAppVersion,
            build: TelemetryExport.currentBuild,
            platform: TelemetryExport.currentPlatform,
            osMajor: TelemetryExport.currentOSMajor,
            locale: Locale.current.identifier,
            installDate: settings?.firstLaunchDate,
            consentState: settings?.cloudConsent.rawValue ?? "notAsked",
            optInDate: settings?.telemetryOptInDate
        )
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

            Section(header: Text("settings.section.telemetry")) {
                Toggle("settings.telemetry.opt_in", isOn: Binding(
                    get: { settings?.telemetryOptedIn ?? false },
                    set: { newValue in
                        settings?.telemetryOptedIn = newValue
                        try? context.save()
                        // Mirror the canonical flag into the App-Group
                        // defaults EventLedger reads lock-free.
                        EventLedger.shared.setOptIn(newValue)
                        // Opting back out clears the buffer so a
                        // re-opt-in starts from zero.
                        if !newValue {
                            EventLedger.shared.resetCounters()
                            preparedTelemetryURL = nil
                        }
                    }
                ))
                Text("settings.telemetry.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings?.telemetryOptedIn == true {
                    if let url = preparedTelemetryURL {
                        ShareLink(item: url) {
                            Label("settings.telemetry.share",
                                  systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button("settings.telemetry.prepare_export") {
                            preparedTelemetryURL =
                                try? TelemetryExport.writeJSONFile(makeTelemetrySnapshot())
                        }
                    }
                    Button("settings.telemetry.reset", role: .destructive) {
                        EventLedger.shared.resetCounters()
                        preparedTelemetryURL = nil
                    }
                }
            }

            // P5 Q1 W1 — distribution-research recruit tile. Intentionally
            // NOT gated by `telemetryOptedIn`: per App Review 2.2 and the
            // research protocol §1, compensation cannot be conditional on
            // data-consent. Opens a Safari link to the self-hosted form at
            // roastmate.app/research (no embedded WebView, keeps the
            // recruit channel out of the app's data surface).
            //
            // v1.0.5 addition: auto-hide after Self.researchRecruitDeadline
            // (currently 2026-11-01 UTC = end of Phase 5 Q1 + 1 month
            // buffer). Both advisors flagged a permanent-UX-for-2-week-
            // sprint smell in the 2026-05-28 audit; rather than ship a
            // remote feature-flag service for one tile, hardcode a sunset
            // date and re-ship a new cutoff (or remove the tile) when the
            // next research wave is scoped.
            if Date() < Self.researchRecruitDeadline {
                Section(header: Text("settings.section.research")) {
                    Link(destination: URL(string: "https://roastmate.app/research")!) {
                        HStack {
                            Label("settings.research.tile", systemImage: "person.fill.questionmark")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    Text("settings.research.footer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                    HStack {
                        Text("settings.credits.balance")
                        Spacer()
                        Text(verbatim: "\(settings?.availableCreditsNow() ?? 0)")
                            .foregroundStyle(.secondary)
                    }
                    Button("settings.credits.buy") {
                        EventLedger.shared.recordPaywallImpression(source: .lowCredits)
                        showPaywall = true
                    }
                        .foregroundStyle(.orange)
                    Button("settings.subscription.upgrade") {
                        EventLedger.shared.recordPaywallImpression(source: .proTap)
                        showPaywall = true
                    }
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
            Label("settings.about_ai.ondevice_label", systemImage: "checkmark.seal")
                .foregroundStyle(.green)
            Label("settings.about_ai.cloud_label", systemImage: "cloud")
                .foregroundStyle(.secondary)
            Label("settings.about_ai.no_bigai_label", systemImage: "xmark.shield")
                .foregroundStyle(.secondary)
            Label("settings.about_ai.privacy_label", systemImage: "lock.shield")
                .foregroundStyle(.secondary)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Label("trust.not_companion.title", systemImage: "person.crop.circle.badge.xmark")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("trust.not_companion.body")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 480)
    }
}
