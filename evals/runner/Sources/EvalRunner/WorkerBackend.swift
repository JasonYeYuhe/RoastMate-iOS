import Foundation

/// Calls the deployed RoastMate vent worker. The worker handles routing
/// (Groq primary → OpenRouter GLM Air fallback) and applies the same
/// prompt-construction logic the iOS app uses. For backend comparison
/// runs, an optional `modelOverride` forces the worker to bypass Groq
/// and use the named OpenRouter model (allowlist-gated server-side).
///
/// The Backend protocol is generic over (system, user) prompt strings,
/// but this worker endpoint constructs prompts server-side from
/// (situation, intensity, locale, styleName). We pass the situation
/// through `systemPrompt` parameter and parse `(intensity, locale,
/// styleName)` from the user prompt JSON tag we append in Runner.
/// This is a wart introduced because the worker has its own prompt
/// builder; we'll fix it in B3 day 2 by exposing a `/v1/raw` endpoint
/// that takes literal system+user strings.
struct WorkerBackend: Backend {
    let endpoint: URL
    let modelOverride: String?

    var name: String {
        if let m = modelOverride { return "worker:openrouter-override:\(m)" }
        return "worker:default-route"
    }

    init(endpoint: URL = URL(string: "https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent")!,
         modelOverride: String? = nil) {
        self.endpoint = endpoint
        self.modelOverride = modelOverride
    }

    func call(systemPrompt: String, userPrompt: String) async -> BackendResult {
        // userPrompt is JSON of {intensity, locale, styleName, situation,
        // deviceId} — Runner constructs this packet. systemPrompt is unused
        // by this backend (the worker rebuilds it server-side).
        _ = systemPrompt
        let start = Date()
        guard let body = userPrompt.data(using: .utf8) else {
            return .init(ok: false, text: "", latencyMs: 0, modelReported: nil,
                         providerReported: nil, errorKind: "encode_fail",
                         errorDetail: "userPrompt not utf-8")
        }
        // Inject model override into the body if set
        var bodyData = body
        if let m = modelOverride,
           var dict = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
            dict["model"] = m
            if let reencoded = try? JSONSerialization.data(withJSONObject: dict) {
                bodyData = reencoded
            }
        }
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Mozilla/5.0 RoastMate-eval/0.1", forHTTPHeaderField: "User-Agent")
        req.httpBody = bodyData
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            guard let http = response as? HTTPURLResponse else {
                return .init(ok: false, text: "", latencyMs: ms, modelReported: nil,
                             providerReported: nil, errorKind: "no_http",
                             errorDetail: nil)
            }
            if http.statusCode != 200 {
                let detail = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
                return .init(ok: false, text: "", latencyMs: ms, modelReported: nil,
                             providerReported: nil,
                             errorKind: "http_\(http.statusCode)",
                             errorDetail: String(detail))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let text = json["text"] as? String, !text.isEmpty else {
                return .init(ok: false, text: "", latencyMs: ms, modelReported: nil,
                             providerReported: nil, errorKind: "empty_text",
                             errorDetail: String(data: data, encoding: .utf8) ?? "")
            }
            return .init(ok: true, text: text, latencyMs: ms,
                         modelReported: json["model"] as? String,
                         providerReported: json["provider"] as? String,
                         errorKind: nil, errorDetail: nil)
        } catch {
            let ms = Int(Date().timeIntervalSince(start) * 1000)
            return .init(ok: false, text: "", latencyMs: ms, modelReported: nil,
                         providerReported: nil, errorKind: "transport",
                         errorDetail: error.localizedDescription)
        }
    }
}

/// Placeholder for the on-device Apple Foundation Models path. Fully
/// wired in B3 day 2 — requires `#if canImport(FoundationModels)` +
/// macOS 26 / iOS 26 SDK + entitlements that a CLI target normally
/// can't get. Workaround: invoke from an XCTest bundle inside the
/// main app target. Tracking issue left here so the protocol is
/// complete and Runner can dispatch in a unified way.
struct AppleFMBackend: Backend {
    var name: String { "apple-fm:on-device" }

    func call(systemPrompt: String, userPrompt: String) async -> BackendResult {
        _ = systemPrompt; _ = userPrompt
        return .init(ok: false, text: "", latencyMs: 0,
                     modelReported: nil, providerReported: nil,
                     errorKind: "not_implemented",
                     errorDetail: "Apple FM backend stub — wire in B3 day 2 via XCTest host")
    }
}
