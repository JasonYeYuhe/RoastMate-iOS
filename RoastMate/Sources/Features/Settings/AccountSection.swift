import SwiftUI
import AuthenticationServices

/// Embedded in `SettingsView`. Shows either the user's signed-in identity
/// (with a Sign Out button) or a Sign in with Apple button followed by a
/// short explanation that signing in is optional.
struct AccountSection: View {
    @Bindable private var auth = AuthService.shared

    var body: some View {
        Section(header: Text("settings.section.account")) {
            if let identity = auth.identity {
                HStack {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(identity.fullName ?? String(localized: "account.signed_in.anonymous"))
                            .font(.body.weight(.medium))
                        if let email = identity.email, !email.isEmpty {
                            Text(email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Button("account.sign_out", role: .destructive) {
                    auth.signOut()
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handle(result: result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .accessibilityLabel(Text("account.sign_in.button.a11y"))

                Text("account.sign_in.footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func handle(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let identity = AppleIdentity(fromAuthorization: auth) else { return }
            AuthService.shared.recordSignIn(
                userID: identity.userID,
                fullName: identity.fullName,
                email: identity.email
            )
        case .failure:
            // User cancelled or system error — keep quiet, no banner needed.
            break
        }
    }
}
