import Foundation

/// One backend = one way to get a generation result for a (system, user) pair.
/// Implementations: WorkerBackend (proxies through our deployed Cloudflare
/// worker, so quota/auth/routing logic stays in one place), AppleFMBackend
/// (uses local Foundation Models — gated to macOS 26+ at runtime; stubbed
/// for now until B3 day 2 wires it).
protocol Backend: Sendable {
    /// A human-readable identifier — used in report rows and JSON keys.
    /// Examples: "worker:groq:qwen3-32b" (the default route), "worker:openrouter-override:z-ai/glm-4.5-air:free", "apple-fm".
    var name: String { get }

    func call(systemPrompt: String, userPrompt: String) async -> BackendResult
}

struct BackendResult: Sendable {
    /// "OK" means we got non-empty text back.
    var ok: Bool
    var text: String
    var latencyMs: Int
    var modelReported: String?
    var providerReported: String?
    var errorKind: String?
    var errorDetail: String?
}
