import Foundation

/// The single place that answers "may THIS generation use the cloud?".
///
/// ## Why this exists
///
/// The answer is a three-step dance — read the remote config, run
/// `CloudConsentGate.decide`, then pick `cloudAllowed` vs
/// `cloudSendableAllowed` depending on whether the intensity is a private
/// draft. That dance was written out longhand in `RoastGeneratorViewModel`
/// and nowhere else, so `FeatureGenerator` and `ArgumentSimulator` silently
/// never got the sendable-cloud path: on an iOS-18 device with no on-device
/// model they would fail instead of falling back to cloud, even with the flag
/// on and consent granted. Found by the Track 0.2 eval (2026-09-03).
///
/// Same failure shape as the roommate Pro-token bug (M-b), where the token
/// dance lived privately inside `RoastEngine` and the second caller missed it.
/// A rule duplicated at call sites is a rule that will drift, so this one has
/// exactly one home.
///
/// `RoastEngine.generate`'s `cloudVentEnabled` parameter defaults to **false**,
/// so a caller that forgets this helper fails CLOSED — on-device only, never a
/// silent cloud upload. That default is load-bearing; do not remove it.
enum CloudPermission {

    struct Decision {
        /// The consent gate's verdict. `.needsConsent` means the surface must
        /// prompt (5.1.2(i)) before any cloud call.
        let gate: CloudConsentGate
        /// Pass straight into `RoastEngine.generate(cloudVentEnabled:)`.
        let cloudAllowed: Bool

        var needsConsent: Bool { gate == .needsConsent }
    }

    /// Resolve cloud permission for one generation.
    ///
    /// - Parameters:
    ///   - intensity: decides which remote flag applies — private drafts
    ///     (vent/feral) AND `vent_cloud_enabled`; sendable modes
    ///     (calm/sharp/savage) AND `cloud_sendable_enabled`.
    ///   - consent: the user's stored 5.1.2(i) grant, the source of truth.
    ///   - remote: injectable for tests. Defaults to `RemoteConfigValues.cached()`
    ///     — the lock-free App-Group read — rather than `RemoteConfig.shared.current`,
    ///     which is main-actor isolated and cannot be a default argument in a
    ///     nonisolated function. Same data; `EchoesEngine` reads it the same way.
    static func resolve(
        intensity: Intensity,
        consent: CloudConsent,
        remote: RemoteConfigValues = RemoteConfigValues.cached(),
        cloudConfigured: Bool = CloudConfig.isConfigured,
        onDeviceModelAvailable: Bool = RoastEngine.isOnDeviceModelAvailable
    ) -> Decision {
        let gate = CloudConsentGate.decide(
            isPrivateDraft: intensity.isPrivateDraft,
            cloudConfigured: cloudConfigured,
            consent: consent,
            onDeviceModelAvailable: onDeviceModelAvailable,
            cloudSendableEnabled: remote.cloudSendableEnabled
        )
        // RESTRICT-only: the remote flags can only SUBTRACT from the consent
        // grant. Neither can route text to cloud without it.
        let allowed = intensity.isPrivateDraft
            ? remote.cloudAllowed(consentAllowsCloud: gate.allowsCloud)
            : remote.cloudSendableAllowed(consentAllowsCloud: gate.allowsCloud)
        return Decision(gate: gate, cloudAllowed: allowed)
    }
}
