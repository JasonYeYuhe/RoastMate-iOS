import Foundation

/// Errors thrown by an ``FMBackend``. Deliberately carries NO Foundation
/// Models types, so it can be `catch`-matched in code compiled for
/// iOS 18 / macOS 14 (where `FoundationModels` is absent). The Apple backend
/// maps every error Foundation Models throws into `.generation(_:)`
/// internally — the FM error types never cross this boundary.
///
/// There is deliberately no "surface this as a hard error" case any more.
/// v1.6.0 switched the build to SDK 27, and on iOS/macOS 27 a model refusal
/// arrives as the new `LanguageModelError` instead of
/// `LanguageModelSession.GenerationError`. The backend only matched the old
/// type, so every refusal fell into the old `.other` case and the user saw an
/// error box instead of the labelled curated example (measured on macOS
/// 27.0.1, 2026-10-22). Anything the model throws is now a generation failure;
/// only `CancellationError` propagates unchanged.
enum FMBackendError: Error, Sendable {
    /// The on-device model is not available: no FM backend at all (iOS 18),
    /// Apple Intelligence off, unsupported device, or asset still downloading.
    case unavailable
    /// A generation failure (refusal, guardrail, context, timeout, or an error
    /// type this build has never seen), already classified into an A′ failure
    /// category. The caller falls back to labelled curated output.
    case generation(EventLedger.FailureCategory)
}

/// Which safety guardrails a one-shot generation runs under. FM-free so the
/// protocol below compiles for iOS 18 / macOS 14.
enum FMGuardrails: Sendable {
    /// `SystemLanguageModel.Guardrails.default` — every generation except the
    /// rewrite below.
    case standard
    /// `SystemLanguageModel.Guardrails.permissiveContentTransformations`.
    /// ONLY for "make it sendable" and its threat judge: the rewrite's input
    /// is the user's own private vent draft, which default guardrails refuse
    /// outright (6/6 real drafts on macOS 27.0.1), and the judge's input is
    /// the finished rewrite, where default guardrails refused legitimate
    /// racism and harassment complaints (12/36). In this mode Apple returns a
    /// refusal as ordinary text instead of throwing, so the caller MUST screen
    /// the result (`ModelRefusal.looksLikeRefusal` for the rewrite; the judge
    /// accepts nothing but a plain "SAFE") before acting on it.
    case permissiveContentTransformations
}

/// Abstraction over Apple's on-device language model.
///
/// The protocol itself has **no availability annotation**, so an engine that
/// must exist on iOS 18 / macOS 14 can hold an `(any FMBackend)?` (nil when
/// the device has no Foundation Models). The sole conforming type,
/// `AppleFMBackend`, is `@available(iOS 26.0, macOS 26.0, *)` and is the
/// ONLY place Foundation Models symbols appear in the whole app — which is
/// what lets the rest of the codebase compile for a sub-26 deployment target.
protocol FMBackend: Sendable {
    /// True when the on-device model is ready on this device + locale.
    /// Implemented `nonisolated` on the concrete actor so callers can read it
    /// synchronously (keeps `RoastEngine.isOnDeviceModelAvailable` sync).
    var isAvailable: Bool { get }

    /// Cached-session generation. Reuses the cached session when `sessionKey`
    /// matches the previous call **and** `keepSession`; otherwise rebuilds it
    /// with `instructions`. Mirrors `RoastEngine`'s existing per-key session
    /// reuse so a vent draft and a sharp reply don't share context.
    func respondCached(
        instructions: String, to prompt: String,
        temperature: Double, maxTokens: Int,
        sessionKey: String, keepSession: Bool
    ) async throws -> String

    /// One-shot generation on a **fresh** session that never touches the
    /// cached one — used by `rewriteAsSendable` and Echoes, which must start
    /// cold and must not clobber the roast session.
    func respondFresh(
        instructions: String, to prompt: String,
        temperature: Double, maxTokens: Int,
        guardrails: FMGuardrails
    ) async throws -> String

    /// Drops the cached session (parity with `resetConversation`).
    func reset() async
}

extension FMBackend {
    /// Standard-guardrail shorthand, so Echoes and every other caller keep
    /// their exact behaviour.
    func respondFresh(
        instructions: String, to prompt: String,
        temperature: Double, maxTokens: Int
    ) async throws -> String {
        try await respondFresh(
            instructions: instructions, to: prompt,
            temperature: temperature, maxTokens: maxTokens,
            guardrails: .standard
        )
    }
}

/// Single construction point for the on-device backend. Returns `nil` on any
/// platform / OS without Foundation Models (iOS 18, watchOS, a non-FM SDK),
/// so every engine gets one nil-safe entry point and the `#available` /
/// `#if canImport` dance lives in exactly one place.
enum FMBackendFactory {
    static func make() -> (any FMBackend)? {
        #if canImport(FoundationModels) && (os(iOS) || os(macOS))
        if #available(iOS 26.0, macOS 26.0, *) {
            return AppleFMBackend()
        }
        #endif
        return nil
    }
}
