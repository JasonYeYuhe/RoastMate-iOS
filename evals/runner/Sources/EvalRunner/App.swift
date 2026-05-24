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
    }

    static let usage = """
    eval-runner — RoastMate Tier-A/B harness (B3 day 2)

    USAGE:
      eval-runner [--scenarios PATH] [--locale BCP47,…] [--intensity vent,feral,…]
                  [--style STYLE_ID] [--model OR_MODEL_ID]… [--no-default]
                  [--out DIR] [--label NAME]

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
        let args = parseArgs()
        do {
            let scenarios = try ScenarioLoader.load(path: args.scenariosPath)
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
            print("locales=\(args.locales) intensities=\(args.intensities)")
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
        } catch {
            FileHandle.standardError.write("ERROR: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }
}
