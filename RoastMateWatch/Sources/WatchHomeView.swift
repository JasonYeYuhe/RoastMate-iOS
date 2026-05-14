import SwiftUI

struct WatchHomeView: View {
    private let templates: [WatchTemplate] = [
        .init(key: "watch.template.late_excuse",       situationKey: "sample.late_excuse"),
        .init(key: "watch.template.refuse_overtime",   situationKey: "sample.overtime"),
        .init(key: "watch.template.ex_comeback",       situationKey: "sample.ex"),
        .init(key: "watch.template.noisy_roommate",    situationKey: "sample.roommate"),
        .init(key: "watch.template.family_marriage",   situationKey: "sample.marriage"),
        .init(key: "watch.template.tough_client",      situationKey: "sample.client")
    ]

    var body: some View {
        NavigationStack {
            List {
                ForEach(templates) { template in
                    NavigationLink {
                        WatchQuickPromptView(seedSituation: template.canonicalSituation)
                    } label: {
                        Text(template.title)
                    }
                }
            }
            .navigationTitle("watch.home.title")
        }
    }
}

struct WatchTemplate: Identifiable {
    let key: String
    let situationKey: String
    var id: String { key }

    var title: String {
        String(localized: String.LocalizationValue(key))
    }

    /// Canonical placeholder situation used to seed the quick-prompt screen.
    var canonicalSituation: String {
        switch key {
        case "watch.template.late_excuse":
            return String(localized: "Sample: I'm running late for the meeting and need a polite excuse.")
        case "watch.template.refuse_overtime":
            return String(localized: "Sample: My manager keeps asking me to work weekends.")
        case "watch.template.ex_comeback":
            return String(localized: "Sample: My ex just texted asking how I've been after 6 months.")
        case "watch.template.noisy_roommate":
            return String(localized: "Sample: My roommate plays loud games every night at 2 AM.")
        case "watch.template.family_marriage":
            return String(localized: "Sample: My family keeps asking when I will get married.")
        case "watch.template.tough_client":
            return String(localized: "Sample: A client keeps asking for free revisions outside scope.")
        default:
            return ""
        }
    }
}
