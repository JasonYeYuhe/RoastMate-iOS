import Foundation

/// One measured cell (scenario × locale × intensity), plus its classification.
/// Encodable-only: the harness only ever writes these out (`CheckResult`, copied
/// verbatim from the worker harness, is Encodable-only), never reads them back.
struct CellRecord: Encodable, Sendable {
    let scenarioId: String
    let category: String
    let styleId: String
    let styleDisplayName: String
    let intensity: String
    let locale: String

    /// "success" | "guardrail" | "other"
    let outcome: String
    let otherCaseName: String?
    let errorRaw: String?
    let errorLocalized: String?

    let text: String?
    let latencyMs: Int
    let attempts: Int

    // Transparency: how big the real production prompt was for this cell.
    let systemPromptChars: Int
    let userPromptChars: Int

    // Success-only quality signals (nil / false when not a success).
    let softRefusalFlag: Bool
    let checks: CheckResult?
}

struct LocaleAgg {
    var total = 0
    var success = 0
    var guardrail = 0
    var other = 0
    var softRefusalsAmongSuccess = 0
    var otherCases: [String: Int] = [:]

    /// Hard refusal rate = guardrail / (guardrail + success). Operational
    /// errors are excluded from the denominator (they are neither a refusal nor
    /// a usable generation).
    var hardRefusalRate: Double {
        let denom = guardrail + success
        return denom == 0 ? 0 : Double(guardrail) / Double(denom)
    }
    /// The production-style OVER-COUNT: everything that is not a clean success
    /// is treated as a refusal (mirrors `failureCategory`'s default-to-guardrail
    /// bucket). Reported only to quantify the gap the methodology trap warned of.
    var overcountRefusalRate: Double {
        total == 0 ? 0 : Double(guardrail + other) / Double(total)
    }
}

enum FMReport {
    static func aggregate(_ cells: [CellRecord]) -> [String: LocaleAgg] {
        var byLocale: [String: LocaleAgg] = [:]
        for c in cells {
            var a = byLocale[c.locale] ?? LocaleAgg()
            a.total += 1
            switch c.outcome {
            case "success":
                a.success += 1
                if c.softRefusalFlag { a.softRefusalsAmongSuccess += 1 }
            case "guardrail":
                a.guardrail += 1
            default:
                a.other += 1
                if let cn = c.otherCaseName { a.otherCases[cn, default: 0] += 1 }
            }
            byLocale[c.locale] = a
        }
        return byLocale
    }

    static func writeJSON(_ cells: [CellRecord], meta: [String: String], to url: URL) throws {
        struct Out: Encodable { let meta: [String: String]; let cells: [CellRecord] }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try enc.encode(Out(meta: meta, cells: cells)).write(to: url)
    }

    static func writeMarkdown(_ cells: [CellRecord], meta: [String: String],
                              localeOrder: [String], to url: URL) throws {
        let agg = aggregate(cells)
        var s = "# Apple Foundation Models — vent/feral guardrail refusal run\n\n"
        for (k, v) in meta.sorted(by: { $0.key < $1.key }) {
            s += "**\(k):** \(v)  \n"
        }
        s += "\n## Refusal rate by locale (TRUE guardrail vs. over-count)\n\n"
        s += "| locale | n | success | guardrail (TRUE refusal) | other-err | **hard refusal rate** | over-count rate | soft-refusal (of success) |\n"
        s += "|---|---|---|---|---|---|---|---|\n"
        for loc in localeOrder {
            guard let a = agg[loc] else { continue }
            s += "| \(loc) | \(a.total) | \(a.success) | \(a.guardrail) | \(a.other) | "
            s += "**\(pct(a.hardRefusalRate))** | \(pct(a.overcountRefusalRate)) | \(a.softRefusalsAmongSuccess) |\n"
        }
        // Overall
        let all = cells.count
        let g = cells.filter { $0.outcome == "guardrail" }.count
        let ok = cells.filter { $0.outcome == "success" }.count
        let ot = cells.filter { $0.outcome == "other" }.count
        let hard = (g + ok) == 0 ? 0 : Double(g) / Double(g + ok)
        s += "| **ALL** | \(all) | \(ok) | \(g) | \(ot) | **\(pct(hard))** | \(pct(all == 0 ? 0 : Double(g + ot)/Double(all))) | — |\n"

        // Other-error breakdown
        let otherCells = cells.filter { $0.outcome == "other" }
        if !otherCells.isEmpty {
            var cases: [String: Int] = [:]
            for c in otherCells { cases[c.otherCaseName ?? "?", default: 0] += 1 }
            s += "\n## Operational (non-refusal) errors — EXCLUDED from refusal rate\n\n"
            for (k, v) in cases.sorted(by: { $0.value > $1.value }) {
                s += "- `\(k)` × \(v)\n"
            }
        }

        // Verbatim guardrail errors (what a refusal looks like)
        let refusals = cells.filter { $0.outcome == "guardrail" }
        s += "\n## Guardrail refusals — verbatim error text (n=\(refusals.count))\n\n"
        if refusals.isEmpty {
            s += "_No guardrail refusals were thrown across the whole matrix._\n"
        } else {
            s += "| scenario | intensity | locale | localized error | raw |\n|---|---|---|---|---|\n"
            for c in refusals {
                s += "| \(c.scenarioId) | \(c.intensity) | \(c.locale) | \(c.errorLocalized ?? "") | `\(oneLine(c.errorRaw ?? ""))` |\n"
            }
        }

        // Per-cell detail
        s += "\n## Per-cell detail\n\n"
        for c in cells {
            s += "### `\(c.scenarioId)` / \(c.intensity) / \(c.locale) → **\(c.outcome.uppercased())**\n\n"
            s += "- style: `\(c.styleId)` (\(c.styleDisplayName)), latency \(c.latencyMs)ms, attempts \(c.attempts)\n"
            s += "- prompt size: system \(c.systemPromptChars) chars, user \(c.userPromptChars) chars\n"
            switch c.outcome {
            case "success":
                if let ch = c.checks {
                    s += "- chars \(ch.charCount), language \(ch.languageMatch ? "✓" : "✗"), "
                    s += "strong-words \(ch.ventStrongWordCount), polite-open \(ch.politeSarcasmOpen ? "⚠︎yes" : "no"), "
                    s += "safety-flags \(ch.safetyFlags.isEmpty ? "none" : ch.safetyFlags.joined(separator: ","))\n"
                }
                s += "- soft-refusal sniff: \(c.softRefusalFlag ? "⚠︎ LOOKS LIKE A REFUSAL/DEFLECTION" : "no")\n\n"
                s += "> \(oneLine(c.text ?? ""))\n\n"
            case "guardrail":
                s += "- localized: **\(c.errorLocalized ?? "")**\n"
                s += "- raw: `\(oneLine(c.errorRaw ?? ""))`\n\n"
            default:
                s += "- caseName: `\(c.otherCaseName ?? "?")`\n"
                s += "- localized: \(c.errorLocalized ?? "")\n"
                s += "- raw: `\(oneLine(c.errorRaw ?? ""))`\n\n"
            }
        }
        try s.data(using: .utf8)!.write(to: url)
    }

    static func pct(_ x: Double) -> String { String(format: "%.1f%%", x * 100) }
    static func oneLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ⏎ ").replacingOccurrences(of: "|", with: "/")
    }
}
