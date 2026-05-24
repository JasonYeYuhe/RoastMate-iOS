import Foundation

@main
struct App {
    struct CLIArgs {
        var scenariosPath: URL =
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("evals/scenarios/base.json")
        var locale: String = "zh-Hans"
        var intensity: String = "vent"
        var styleOverride: String?
        var models: [String] = []
        var includeDefault: Bool = true
        var outDir: URL = URL(fileURLWithPath: "evals/runs")
    }

    static let usage = """
    eval-runner — RoastMate Tier-A/B harness scaffold (B3 day 1)

    USAGE:
      eval-runner [--scenarios PATH] [--locale BCP47] [--intensity vent|feral|sharp|calm]
                  [--style STYLE_ID] [--model OR_MODEL_ID]... [--no-default] [--out DIR]

    DEFAULTS:
      --scenarios   evals/scenarios/base.json
      --locale      zh-Hans
      --intensity   vent
      --out         evals/runs/<timestamp>/

    EXAMPLES:
      swift run eval-runner
      swift run eval-runner --locale zh-Hant \\
          --model z-ai/glm-4.5-air:free \\
          --model minimax/minimax-m2.5:free
      swift run eval-runner --no-default --model deepseek/deepseek-v4-flash:free
    """

    static func parseArgs() -> CLIArgs {
        var a = CLIArgs()
        var i = 1
        let argv = CommandLine.arguments
        while i < argv.count {
            let k = argv[i]
            switch k {
            case "--scenarios": i += 1; a.scenariosPath = URL(fileURLWithPath: argv[i])
            case "--locale":    i += 1; a.locale = argv[i]
            case "--intensity": i += 1; a.intensity = argv[i]
            case "--style":     i += 1; a.styleOverride = argv[i]
            case "--model":     i += 1; a.models.append(argv[i])
            case "--no-default": a.includeDefault = false
            case "--out":       i += 1; a.outDir = URL(fileURLWithPath: argv[i])
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
            print("locale=\(args.locale) intensity=\(args.intensity)")

            let cfg = RunConfig(
                scenarios: scenarios, backends: backends,
                intensity: args.intensity, locale: args.locale,
                styleOverride: args.styleOverride
            )
            let started = Date()
            let cells = await Runner.run(cfg)
            let elapsed = Int(Date().timeIntervalSince(started))
            print("ran \(cells.count) cells in \(elapsed)s")

            // Write output
            let ts = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "")
                .replacingOccurrences(of: "-", with: "")
            let dir = args.outDir.appendingPathComponent("run-\(ts.prefix(15))")
            try FileManager.default.createDirectory(at: dir,
                                                     withIntermediateDirectories: true)
            let jsonPath = dir.appendingPathComponent("results.json")
            let mdPath = dir.appendingPathComponent("report.md")
            try ReportWriter.writeJSON(cells, to: jsonPath)
            try ReportWriter.writeMarkdown(
                cells, to: mdPath,
                header: "Eval run — \(args.locale)/\(args.intensity)"
            )
            print("wrote \(jsonPath.path)")
            print("wrote \(mdPath.path)")

            let ok = cells.filter(\.ok).count
            print("PASS \(ok)/\(cells.count)")
        } catch {
            FileHandle.standardError.write("ERROR: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }
}
