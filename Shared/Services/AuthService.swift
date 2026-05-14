import Foundation
import AuthenticationServices
import os.log

/// Holds the user's Sign in with Apple identity. Sign-in is **optional** —
/// every RoastMate feature works without an identity. The identity is used
/// to display a name on the Account screen and (when the optional CloudKit
/// sync ships in a later release) to disambiguate iCloud account state.
struct AppleIdentity: Codable, Equatable, Sendable {
    let userID: String          // Apple's stable, app-scoped identifier.
    let fullName: String?       // Only set on the very first sign-in.
    let email: String?          // Only set on the very first sign-in. May be a private relay.
}

@MainActor
@Observable
final class AuthService {
    static let shared = AuthService()

    private(set) var identity: AppleIdentity?

    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "Auth")

    private init() {
        identity = Self.loadFromKeychain()
        listenForCredentialRevocation()
    }

    var isSignedIn: Bool { identity != nil }

    var displayName: String? {
        identity?.fullName
    }

    /// Persist a fresh identity returned from `ASAuthorizationAppleIDCredential`.
    /// Pass `fullName` / `email` only the first time the user signs in — Apple
    /// only returns them on the initial authorization.
    func recordSignIn(userID: String, fullName: String?, email: String?) {
        var keptFullName = fullName
        var keptEmail = email
        if keptFullName == nil { keptFullName = KeychainStore.get(.appleFullName) }
        if keptEmail == nil { keptEmail = KeychainStore.get(.appleEmail) }

        KeychainStore.set(userID, for: .appleUserID)
        KeychainStore.set(keptFullName, for: .appleFullName)
        KeychainStore.set(keptEmail, for: .appleEmail)

        identity = AppleIdentity(userID: userID, fullName: keptFullName, email: keptEmail)
        logger.info("Apple identity stored.")
    }

    /// Removes the identity. Local history is **not** touched.
    func signOut() {
        KeychainStore.remove(.appleUserID)
        KeychainStore.remove(.appleFullName)
        KeychainStore.remove(.appleEmail)
        identity = nil
        logger.info("Apple identity cleared.")
    }

    /// Called on app launch. If the underlying Apple credential has been
    /// revoked (user removed RoastMate AI from Apple ID > Sign in with Apple)
    /// we wipe local state.
    func refreshCredentialStateOnLaunch() async {
        guard let id = identity?.userID else { return }
        let provider = ASAuthorizationAppleIDProvider()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            provider.getCredentialState(forUserID: id) { [weak self] state, _ in
                Task { @MainActor in
                    switch state {
                    case .authorized:
                        break
                    case .revoked, .notFound, .transferred:
                        self?.signOut()
                    @unknown default:
                        break
                    }
                    cont.resume()
                }
            }
        }
    }

    private func listenForCredentialRevocation() {
        NotificationCenter.default.addObserver(
            forName: ASAuthorizationAppleIDProvider.credentialRevokedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.signOut() }
        }
    }

    private static func loadFromKeychain() -> AppleIdentity? {
        guard let userID = KeychainStore.get(.appleUserID) else { return nil }
        return AppleIdentity(
            userID: userID,
            fullName: KeychainStore.get(.appleFullName),
            email: KeychainStore.get(.appleEmail)
        )
    }
}

extension AppleIdentity {
    /// Build a display string from `PersonNameComponents` returned by Apple.
    init?(fromAuthorization auth: ASAuthorization) {
        guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
            return nil
        }
        let name: String?
        if let comps = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let formatted = formatter.string(from: comps).trimmingCharacters(in: .whitespaces)
            name = formatted.isEmpty ? nil : formatted
        } else {
            name = nil
        }
        self.init(
            userID: credential.user,
            fullName: name,
            email: credential.email
        )
    }
}
