import Foundation

/// One row in the result table — single (backend, scenario, locale,
/// intensity, style) cell.
struct CellResult: Sendable, Encodable {
    let scenarioId: String
    let style: String
    let intensity: String
    let locale: String
    let backendName: String
    let modelReported: String?
    let providerReported: String?
    let ok: Bool
    let latencyMs: Int
    let text: String?
    let errorKind: String?
    let errorDetail: String?
    let checks: CheckResult?
}

enum ReportWriter {
    /// JSON dump for diffability across runs.
    static func writeJSON(_ cells: [CellResult], to path: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try enc.encode(cells)
        try data.write(to: path)
    }

    /// Markdown report — what YE reads + rates against.
    static func writeMarkdown(_ cells: [CellResult], to path: URL,
                              header: String) throws {
        var s = "# \(header)\n\n"
        s += "**Generated:** \(ISO8601DateFormatter().string(from: Date()))\n\n"
        s += "**Cells:** \(cells.count) | "
        let okCount = cells.filter(\.ok).count
        s += "**Successful:** \(okCount)/\(cells.count)\n\n"
        s += "## Results\n\n"
        s += "| scenario | style | intensity | locale | backend | lat | strong | flags | text |\n"
        s += "|---|---|---|---|---|---|---|---|---|\n"
        for c in cells {
            let text = c.text?.replacingOccurrences(of: "|", with: "\\|")
                .replacingOccurrences(of: "\n", with: " ") ?? "—"
            let strong = c.checks?.ventStrongWordCount.description ?? "—"
            let flags = c.checks?.safetyFlags.joined(separator: ",") ?? ""
            let lat = c.ok ? "\(c.latencyMs)ms" : "FAIL"
            s += "| \(c.scenarioId) | \(c.style) | \(c.intensity) | \(c.locale) | \(c.backendName) | \(lat) | \(strong) | \(flags) | \(text) |\n"
        }
        s += "\n## Detail per cell\n\n"
        for c in cells {
            s += "### `\(c.scenarioId)` / \(c.intensity) / \(c.locale) → \(c.backendName)\n\n"
            if c.ok, let t = c.text {
                s += "> \(t)\n\n"
                if let chk = c.checks {
                    s += "- latency: **\(c.latencyMs)ms**\n"
                    s += "- chars: \(chk.charCount), language: \(chk.languageMatch ? "✓" : "✗")\n"
                    s += "- length in range: \(chk.lengthInRange ? "✓" : "✗")\n"
                    s += "- vent strong-word count: **\(chk.ventStrongWordCount)**\n"
                    s += "- polite-sarcasm open: \(chk.politeSarcasmOpen ? "⚠️ yes" : "✓ no")\n"
                    if !chk.safetyFlags.isEmpty {
                        s += "- safety flags: \(chk.safetyFlags.joined(separator: ", "))\n"
                    }
                }
            } else {
                s += "**FAIL** — `\(c.errorKind ?? "?")` — \(c.errorDetail ?? "")\n"
            }
            s += "\n"
        }
        try s.write(to: path, atomically: true, encoding: .utf8)
    }
}
