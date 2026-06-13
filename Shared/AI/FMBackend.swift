import Foundation

/// Errors thrown by an ``FMBackend``. Deliberately carries NO Foundation
/// Models types, so it can be `catch`-matched in code compiled for
/// iOS 18 / macOS 14 (where `FoundationModels` is absent). The Apple backend
/// maps the real, iOS-26-only `LanguageModelSession.GenerationError` into
/// `.generation(_:)` internally — the FM error type never crosses this
/// boundary.
///
/// Not annotated `Sendable` on purpose: it can wrap an arbitrary `Error`
/// (`.other`), exactly like the existing `RoastError.generationFailed`, and
/// thrown errors are exempt from the `Sendable` crossing requirement.
enum FMBackendError: Error {
    /// The on-device model is not available: no FM backend at all (iOS 18),
    /// Apple Intelligence off, unsupported device, or asset still downloading.
    case unavailable
    /// A recoverable generation failure, already classified into an A′
    /// failure category. The caller should fall back to curated output.
    case generation(EventLedger.FailureCategory)
    /// An unexpected error the caller should surface as a hard failure.
    case other(Error)
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
        temperature: Double, maxTokens: Int
    ) async throws -> String

    /// Drops the cached session (parity with `resetConversation`).
    func reset() async
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
