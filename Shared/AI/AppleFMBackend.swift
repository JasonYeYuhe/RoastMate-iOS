// The ONLY file in the app that references Foundation Models symbols.
//
// Guarded by `canImport(FoundationModels) && (os(iOS) || os(macOS))` so it is
// excluded entirely from the watchOS target (which compiles `Shared` but has
// no Foundation Models framework) and from any non-FM SDK. The conforming
// type is `@available(iOS 26.0, macOS 26.0, *)`, which is what allows the rest
// of the app — `RoastEngine`, `EchoesEngine`, the protocol `FMBackend` — to
// compile for the lowered iOS 18 / macOS 14 deployment target.
#if canImport(FoundationModels) && (os(iOS) || os(macOS))
import Foundation
import FoundationModels

/// Apple on-device backend. An `actor` (not a `final class`) so the mutable
/// `LanguageModelSession` cache is data-race-safe under Swift 6 strict
/// concurrency without resorting to `@unchecked Sendable` + a manual lock.
@available(iOS 26.0, macOS 26.0, *)
actor AppleFMBackend: FMBackend {
    private var session: LanguageModelSession?
    private var sessionKey: String?

    /// Reads only the global `SystemLanguageModel.default` (no actor state),
    /// so it is safe `nonisolated` and callable synchronously.
    nonisolated var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func reset() {
        session = nil
        sessionKey = nil
    }

    func respondCached(
        instructions: String, to prompt: String,
        temperature: Double, maxTokens: Int,
        sessionKey key: String, keepSession: Bool
    ) async throws -> String {
        // Same reuse rule the engine used to own: rebuild the session when
        // the caller doesn't want continuity, when the key changed, or when
        // there's no live session.
        if !keepSession || sessionKey != key || session == nil {
            session = LanguageModelSession(instructions: instructions)
            sessionKey = key
        }
        guard let session else { throw FMBackendError.unavailable }
        return try await run(session, prompt: prompt, temperature: temperature, maxTokens: maxTokens)
    }

    func respondFresh(
        instructions: String, to prompt: String,
        temperature: Double, maxTokens: Int
    ) async throws -> String {
        let fresh = LanguageModelSession(instructions: instructions)
        return try await run(fresh, prompt: prompt, temperature: temperature, maxTokens: maxTokens)
    }

    private func run(
        _ session: LanguageModelSession, prompt: String,
        temperature: Double, maxTokens: Int
    ) async throws -> String {
        guard SystemLanguageModel.default.availability == .available else {
            throw FMBackendError.unavailable
        }
        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: temperature, maximumResponseTokens: maxTokens)
            )
            return response.content
        } catch let genErr as LanguageModelSession.GenerationError {
            throw FMBackendError.generation(Self.failureCategory(for: genErr))
        } catch {
            throw FMBackendError.other(error)
        }
    }

    /// α3: map a Foundation Models `GenerationError` to an A′ failure category
    /// by string-introspection so the mapping survives API additions — new
    /// cases fall through to `.guardrail` (the conservative bucket) until we
    /// add a specific branch. (Moved here from `RoastEngine` so the 26-only
    /// `GenerationError` type stays behind the availability boundary.)
    private static func failureCategory(
        for error: LanguageModelSession.GenerationError
    ) -> EventLedger.FailureCategory {
        let desc = String(describing: error).lowercased()
        if desc.contains("guardrail") || desc.contains("safety") {
            return .guardrail
        }
        if desc.contains("context") || desc.contains("token") {
            return .quota
        }
        if desc.contains("asset") || desc.contains("unavailable")
            || desc.contains("language") || desc.contains("locale") {
            return .modelAssetMissing
        }
        return .guardrail  // default to the safety bucket so we never under-count refusals
    }
}
#endif
