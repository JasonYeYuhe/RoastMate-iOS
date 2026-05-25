import Foundation

@main
struct App {
    struct CLIArgs {
        var scenariosPath: URL =
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("evals/scenarios/base.json")
        var locales: [String] = ["zh-Hans"]
        var intensities: [String] = ["vent"]
        var styleOverride: String?
        var models: [String] = []
        var includeDefault: Bool = true
        var outDir: URL = URL(fileURLWithPath: "evals/runs")
        var label: String?  // optional run label for the output dir name
        var tierA: Bool = false  // α4 — preflight smoke preset, strict exit
    }

    static let usage = """
    eval-runner — RoastMate Tier-A/B harness (B3 day 2)

    USAGE:
      eval-runner [--scenarios PATH] [--locale BCP47,…] [--intensity vent,feral,…]
                  [--style STYLE_ID] [--model OR_MODEL_ID]… [--no-default]
                  [--out DIR] [--label NAME] [--tier-a]

    DEFAULTS:
      --scenarios   evals/scenarios/base.json
      --locale      zh-Hans              (comma-separate for multi: "zh-Hans,ja,en")
      --intensity   vent                 (comma-separate: "vent,feral")
      --out         evals/runs/<timestamp>/

    EXAMPLES:
      # default route, 8 base scenarios on zh-Hans vent
      eval-runner

      # B4 baseline: 8 scenarios × 2 intensities × 4 locales = 64 cells
      eval-runner --locale zh-Hans,zh-Hant,ja,en --intensity vent,feral \\
          --label baseline-build-8

      # cross-test default + GLM Air on zh-Hant vent
      eval-runner --locale zh-Hant --model z-ai/glm-4.5-air:free

      # α4 preflight smoke (1 scenario × vent+feral × 4 locales = 8 cells,
      # ≤2 min, exits non-zero on any cell failure). When /v1/sharp lands
      # in α2 (W3), this expands to include sharp+calm = 16 cells.
      eval-runner --tier-a
    """

    static func parseArgs() -> CLIArgs {
        var a = CLIArgs()
        var i = 1
        let argv = CommandLine.arguments
        while i < argv.count {
            let k = argv[i]
            switch k {
            case "--scenarios": i += 1; a.scenariosPath = URL(fileURLWithPath: argv[i])
            case "--locale":    i += 1; a.locales = argv[i].split(separator: ",").map(String.init)
            case "--intensity": i += 1; a.intensities = argv[i].split(separator: ",").map(String.init)
            case "--style":     i += 1; a.styleOverride = argv[i]
            case "--model":     i += 1; a.models.append(argv[i])
            case "--no-default": a.includeDefault = false
            case "--out":       i += 1; a.outDir = URL(fileURLWithPath: argv[i])
            case "--label":     i += 1; a.label = argv[i]
            case "--tier-a":    a.tierA = true
            case "--help", "-h": print(usage); exit(0)
            default:
                FileHandle.standardError.write("Unknown arg: \(k)\n".data(using: .utf8)!)
                print(usage); exit(2)
            }
            i += 1
        }
        return a
    }

    static func main() async {
        var args = parseArgs()
        // α4: Tier A is a fixed preset — first scenario × vent+feral × 4
        // locales = 8 cells today (expands to 16 when α2 ships /v1/sharp).
        // Caller can still override --label/--out for output location.
        if args.tierA {
            args.intensities = ["vent", "feral"]
            args.locales = ["zh-Hans", "zh-Hant", "ja", "en"]
            if args.label == nil {
                let ts = ISO8601DateFormatter().string(from: Date())
                    .replacingOccurrences(of: ":", with: "")
                    .replacingOccurrences(of: "-", with: "")
                args.label = "tier-a-\(ts.prefix(15))"
            }
            args.models = []
            args.includeDefault = true
        }
        do {
            var scenarios = try ScenarioLoader.load(path: args.scenariosPath)
            if args.tierA {
                // Pick exactly one representative — keeps the smoke under
                // 2 min when sleep budget is 5-8s/cell. base.json's first
                // scenario is the "noisy roommate" archetype across all
                // 4 locales — good coverage for the language-match check.
                scenarios = Array(scenarios.prefix(1))
            }
            print("loaded \(scenarios.count) scenarios from \(args.scenariosPath.path)")

            var backends: [any Backend] = []
            if args.includeDefault {
                backends.append(WorkerBackend(modelOverride: nil))
            }
            for m in args.models {
                backends.append(WorkerBackend(modelOverride: m))
            }
            if backends.isEmpty {
                FileHandle.standardError.write(
                    "no backends configured — pass --model or omit --no-default\n"
                        .data(using: .utf8)!)
                exit(2)
            }
            print("backends: \(backends.map(\.name).joined(separator: ", "))")
            print("locales=\(args.locales) intensities=\(args.intensities)\(args.tierA ? " [Tier A — strict exit]" : "")")
            let totalCells = scenarios.count * backends.count *
                             args.locales.count * args.intensities.count
            print("planning \(totalCells) cells "
                  + "(\(scenarios.count) scenarios × \(backends.count) backend × "
                  + "\(args.locales.count) locale × \(args.intensities.count) intensity)")

            let started = Date()
            var allCells: [CellResult] = []
            for locale in args.locales {
                for intensity in args.intensities {
                    print("--- locale=\(locale) intensity=\(intensity) ---")
                    let cfg = RunConfig(
                        scenarios: scenarios, backends: backends,
                        intensity: intensity, locale: locale,
                        styleOverride: args.styleOverride
                    )
                    let subset = await Runner.run(cfg)
                    let okHere = subset.filter(\.ok).count
                    print("  \(okHere)/\(subset.count) ok")
                    allCells.append(contentsOf: subset)
                }
            }
            let elapsed = Int(Date().timeIntervalSince(started))
            print("ran \(allCells.count) cells in \(elapsed)s")

            // Write output
            let ts = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
            let suffix = args.label ?? String(ts.prefix(15))
            let dir = args.outDir.appendingPathComponent("run-\(suffix)")
            try FileManager.default.createDirectory(at: dir,
                                                     withIntermediateDirectories: true)
            let jsonPath = dir.appendingPathComponent("results.json")
            let mdPath = dir.appendingPathComponent("report.md")
            try ReportWriter.writeJSON(allCells, to: jsonPath)
            let header = "Eval run — locales=\(args.locales.joined(separator: ",")) intensities=\(args.intensities.joined(separator: ","))"
            try ReportWriter.writeMarkdown(allCells, to: mdPath, header: header)
            print("wrote \(jsonPath.path)")
            print("wrote \(mdPath.path)")

            let ok = allCells.filter(\.ok).count
            print("PASS \(ok)/\(allCells.count)")
            // α4 strict gating — Tier A is preflight; any cell failure
            // (backend error OR deterministic-check fail) blocks the
            // archive. Tier B stays advisory (exit 0) so baseline runs
            // can complete even with transient flakes. Strong-word
            // count regressions (vs baseline) are checked by
            // scripts/eval-rerun.sh — not by this gate.
            if args.tierA {
                let badCells = allCells.filter { !Self.tierAPassed($0) }
                if !badCells.isEmpty {
                    FileHandle.standardError.write(
                        "Tier A: \(badCells.count) cell(s) failed — archive blocked.\n"
                            .data(using: .utf8)!)
                    for c in badCells {
                        let reason = Self.tierAFailureReason(c)
                        FileHandle.standardError.write(
                            "  - \(c.scenarioId)/\(c.intensity)/\(c.locale): \(reason)\n"
                                .data(using: .utf8)!)
                    }
                    exit(3)
                }
            }
        } catch {
            FileHandle.standardError.write("ERROR: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }

    /// α4 Tier-A pass gate. A cell passes iff the backend returned a
    /// response AND the deterministic checks (language, length, safety)
    /// were clean. Strong-word density and polite-open are informational
    /// — baseline comparison handles those regressions.
    static func tierAPassed(_ c: CellResult) -> Bool {
        guard c.ok, let ch = c.checks else { return false }
        return ch.languageMatch && ch.lengthInRange && ch.safetyFlags.isEmpty
    }

    static func tierAFailureReason(_ c: CellResult) -> String {
        if !c.ok { return "backend error (\(c.errorKind ?? "?"))" }
        guard let ch = c.checks else { return "no checks emitted" }
        var reasons: [String] = []
        if !ch.languageMatch { reasons.append("language mismatch") }
        if !ch.lengthInRange { reasons.append("length \(ch.charCount) out of [8, 240]") }
        if !ch.safetyFlags.isEmpty { reasons.append("safety: \(ch.safetyFlags.joined(separator: ","))") }
        return reasons.isEmpty ? "unknown" : reasons.joined(separator: "; ")
    }
}
