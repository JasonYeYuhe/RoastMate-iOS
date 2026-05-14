import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @Binding var isPresented: Bool
    @State private var page: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                onboardingPage(
                    icon: "flame.fill",
                    title: "onboarding.welcome.title",
                    body: "onboarding.welcome.body"
                ).tag(0)

                onboardingPage(
                    icon: "lock.shield",
                    title: "onboarding.privacy.title",
                    body: "onboarding.privacy.body"
                ).tag(1)

                onboardingPage(
                    icon: "hand.raised",
                    title: "onboarding.safety.title",
                    body: "onboarding.safety.body"
                ).tag(2)

                ageGatePage.tag(3)
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif

            HStack {
                if page > 0 {
                    Button(String(localized: "common.back")) { page -= 1 }
                }
                Spacer()
                if page < 3 {
                    Button(String(localized: "common.next")) { page += 1 }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(minWidth: 360, minHeight: 480)
    }

    private func onboardingPage(icon: String, title: LocalizedStringResource, body: LocalizedStringResource) -> some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .padding(.top, 48)
            Text(title)
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            Text(body)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
        }
        .padding()
    }

    private var ageGatePage: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .padding(.top, 48)
            Text("ageGate.title")
                .font(.title)
                .bold()
                .multilineTextAlignment(.center)
            Text("ageGate.body")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            Button {
                completeOnboarding()
            } label: {
                Text("ageGate.confirm")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .padding()
    }

    @MainActor
    private func completeOnboarding() {
        let settings = HistoryService.userSettings(context: context)
        settings.hasSeenOnboarding = true
        settings.hasAcknowledgedAgeGate = true
        settings.hasAcknowledgedContentNotice = true
        try? context.save()
        isPresented = false
    }
}
