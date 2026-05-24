import Foundation

/// Orchestrates a single backend over a set of scenarios on a fixed
/// (intensity, locale) cell. Future expansion (W2 day 2): cross-product
/// over modes/intensities/locales for Tier B baseline.
struct RunConfig {
    let scenarios: [Scenario]
    let backends: [any Backend]
    let intensity: String
    let locale: String
    /// Override style — if nil, use each scenario's defaultStyleId.
    let styleOverride: String?
}

enum Runner {
    static func run(_ cfg: RunConfig) async -> [CellResult] {
        var cells: [CellResult] = []
        for sc in cfg.scenarios {
            guard let sit = sc.prompt[cfg.locale] else {
                continue  // scenario doesn't carry this locale
            }
            let style = cfg.styleOverride ?? sc.defaultStyleId
            // Build the per-call worker payload (the WorkerBackend
            // reuses this as its "userPrompt" parameter).
            let payload: [String: Any] = [
                "situation": sit,
                "styleName": style,
                "intensity": cfg.intensity,
                "locale": cfg.locale,
                "deviceId": "eval-runner-\(Int(Date().timeIntervalSince1970))-\(sc.id.prefix(15))"
            ]
            guard let body = try? JSONSerialization.data(withJSONObject: payload),
                  let bodyStr = String(data: body, encoding: .utf8) else {
                continue
            }
            for backend in cfg.backends {
                let res = await backend.call(systemPrompt: "", userPrompt: bodyStr)
                let checks = res.ok
                    ? DeterministicChecks.run(text: res.text, locale: cfg.locale,
                                              intensity: cfg.intensity)
                    : nil
                cells.append(CellResult(
                    scenarioId: sc.id, style: style,
                    intensity: cfg.intensity, locale: cfg.locale,
                    backendName: backend.name,
                    modelReported: res.modelReported,
                    providerReported: res.providerReported,
                    ok: res.ok, latencyMs: res.latencyMs,
                    text: res.ok ? res.text : nil,
                    errorKind: res.errorKind, errorDetail: res.errorDetail,
                    checks: checks
                ))
                // Polite delay between requests so we don't trip rate
                // limits during a batch.
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
        return cells
    }
}
