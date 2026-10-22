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
        temperature: Double, maxTokens: Int,
        guardrails: FMGuardrails
    ) async throws -> String {
        let model = Self.model(for: guardrails)
        let fresh = LanguageModelSession(model: model, instructions: instructions)
        return try await run(fresh, model: model, prompt: prompt, temperature: temperature, maxTokens: maxTokens)
    }

    /// `SystemLanguageModel(useCase:guardrails:)` and
    /// `Guardrails.permissiveContentTransformations` are iOS 26.0 / macOS 26.0
    /// API (FoundationModels swiftinterface, SDK 27: `@available(iOS 26.0,
    /// macOS 26.0, …)`), the same floor as this type, so no extra gate.
    private static func model(for guardrails: FMGuardrails) -> SystemLanguageModel {
        switch guardrails {
        case .standard:
            return .default
        case .permissiveContentTransformations:
            return SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
        }
    }

    private func run(
        _ session: LanguageModelSession, model: SystemLanguageModel = .default, prompt: String,
        temperature: Double, maxTokens: Int
    ) async throws -> String {
        guard model.availability == .available else {
            throw FMBackendError.unavailable
        }
        do {
            let response = try await session.respond(
                to: prompt,
                options: GenerationOptions(temperature: temperature, maximumResponseTokens: maxTokens)
            )
            return response.content
        } catch {
            throw Self.backendError(for: error)
        }
    }

    /// Maps whatever Foundation Models threw onto ``FMBackendError``.
    ///
    /// Every error except cancellation becomes `.generation`, so the engine
    /// returns labelled curated text instead of an error box. This used to
    /// match `LanguageModelSession.GenerationError` only; apps built with SDK
    /// 27 (RoastMate since 1.6.0) receive `LanguageModelError` on iOS/macOS 27
    /// instead (FoundationModels swiftinterface:1527, `@available(iOS 27.0,
    /// macOS 27.0, …)`), so every refusal fell through to the old hard-error
    /// case. Matching by type would break again the next time Apple adds one.
    static func backendError(for error: any Error) -> any Error {
        if error is CancellationError { return error }
        return FMBackendError.generation(failureCategory(for: error))
    }

    /// α3: map a Foundation Models error to an A′ failure category by
    /// string-introspection so the mapping survives API additions — unknown
    /// shapes fall through to `.guardrail` (the conservative bucket). Reads
    /// both the description (`GenerationError` puts its case name there:
    /// "guardrailViolation(…)") and `LocalizedError.errorDescription`
    /// (`LanguageModelError` describes itself as "May contain unsafe content"
    /// and its errorDescription is "The model's safety guardrails were
    /// triggered.", measured on macOS 27.0.1). Not `localizedDescription`: for
    /// a non-LocalizedError that string embeds the domain
    /// ("FoundationModels.LanguageModelError"), which would match "language".
    static func failureCategory(for error: any Error) -> EventLedger.FailureCategory {
        let localized = (error as? LocalizedError)?.errorDescription ?? ""
        let desc = (String(describing: error) + " " + localized).lowercased()
        if desc.contains("guardrail") || desc.contains("safety") || desc.contains("unsafe")
            || desc.contains("refus") {
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
