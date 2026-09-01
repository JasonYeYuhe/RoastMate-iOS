import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// apple-fm-guardrail — measures Apple on-device Foundation Models' guardrail
// REFUSAL rate on RoastMate's real vent/feral prompts, per locale.
//
// Faithfulness: the system + user prompts are produced by a byte-verbatim copy
// of the production `PromptBuilder` (SHA-verified) driven by the real
// `StylePresets.json` catalog and the real per-locale style display names. The
// ONLY thing swapped out is the on-device model call itself (which production
// routes through `AppleFMBackend`).
//
// Methodology: a refusal is counted ONLY on a real `.guardrailViolation` throw.
// Operational errors are bucketed separately and never counted as refusals.

struct Args {
    var scenariosPath = "evals/scenarios/base.json"
    var allScenarios = false
    var catalogPath = "Shared/Resources/StylePresets.json"
    var locales = ["zh-Hans", "zh-Hant", "ja", "en"]
    var intensities = ["vent", "feral"]
    var limit: Int? = nil
    var label: String? = nil
    var outDir = "evals/runs"
    var maxTokens = 600
    var dumpPrompt = false   // print the real (system,user) prompt per cell and skip the FM call
    var guardrails = "default"   // "default" | "permissive" (permissiveContentTransformations)
}

func parseArgs() -> Args {
    var a = Args()
    let argv = CommandLine.arguments
    var i = 1
    while i < argv.count {
        switch argv[i] {
        case "--scenarios":  i += 1; a.scenariosPath = argv[i]
        case "--all-scenarios": a.allScenarios = true
        case "--catalog":    i += 1; a.catalogPath = argv[i]
        case "--locale":     i += 1; a.locales = argv[i].split(separator: ",").map(String.init)
        case "--intensity":  i += 1; a.intensities = argv[i].split(separator: ",").map(String.init)
        case "--limit":      i += 1; a.limit = Int(argv[i])
        case "--label":      i += 1; a.label = argv[i]
        case "--out":        i += 1; a.outDir = argv[i]
        case "--max-tokens": i += 1; a.maxTokens = Int(argv[i]) ?? 600
        case "--dump-prompt": a.dumpPrompt = true
        case "--guardrails": i += 1; a.guardrails = argv[i]   // default | permissive
        case "--help", "-h":
            print("apple-fm-guardrail [--scenarios P|--all-scenarios] [--locale a,b] [--intensity vent,feral] [--limit N] [--label NAME] [--out DIR] [--max-tokens N]")
            exit(0)
        default:
            FileHandle.standardError.write("unknown arg \(argv[i])\n".data(using: .utf8)!)
            exit(2)
        }
        i += 1
    }
    return a
}

func loadCatalog(_ path: String) throws -> [String: StylePreset] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let file = try JSONDecoder().decode(StylePresetCatalogFile.self, from: data)
    return Dictionary(uniqueKeysWithValues: file.styles.map { ($0.id, $0) })
}

func loadScenarios(_ a: Args) throws -> [Scenario] {
    if a.allScenarios {
        let base = URL(fileURLWithPath: a.scenariosPath).deletingLastPathComponent()
        var all: [Scenario] = []
        for name in ["base.json", "additions-en.json", "additions-ja.json", "additions-sports.json"] {
            let f = base.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: f.path) {
                all.append(contentsOf: try ScenarioLoader.load(path: f))
            }
        }
        return all
    }
    return try ScenarioLoader.load(path: URL(fileURLWithPath: a.scenariosPath))
}

@main
struct Main {
    static func main() async {
        let a = parseArgs()

        // --dump-prompt: emit the exact production (system,user) prompt per cell
        // as JSON and exit. No model call, so no availability gate. Used to build
        // faithful isolation probes and a report appendix.
        if a.dumpPrompt {
            guard let catalog = try? loadCatalog(a.catalogPath),
                  var scns = try? loadScenarios(a) else {
                FileHandle.standardError.write("dump: failed to load inputs\n".data(using: .utf8)!); exit(1)
            }
            if let lim = a.limit { scns = Array(scns.prefix(lim)) }
            for locale in a.locales {
                AppLocalization.currentLocale = locale
                let loc = Locale(identifier: locale)
                for intensityRaw in a.intensities {
                    guard let intensity = Intensity(rawValue: intensityRaw) else { continue }
                    for sc in scns {
                        guard let situation = sc.prompt[locale], let style = catalog[sc.defaultStyleId] else { continue }
                        let system = PromptBuilder.systemPrompt(style: style, locale: loc, mode: .roast, intensity: intensity, safeMode: true)
                        let user = PromptBuilder.userPrompt(situation: situation, styleName: style.displayName, variants: 1, mode: .roast, intensity: intensity, priorContext: nil, locale: loc)
                        let obj: [String: String] = ["locale": locale, "intensity": intensityRaw, "scenario": sc.id, "style": style.id, "system": system, "user": user]
                        if let d = try? JSONSerialization.data(withJSONObject: obj), let s = String(data: d, encoding: .utf8) {
                            print(s)
                        }
                    }
                }
            }
            return
        }

        #if !canImport(FoundationModels)
        FileHandle.standardError.write("FATAL: SDK has no FoundationModels — cannot run.\n".data(using: .utf8)!)
        exit(10)
        #else
        guard #available(macOS 26.0, *) else {
            FileHandle.standardError.write("FATAL: runtime macOS < 26 — FoundationModels unavailable. NOT fabricating results.\n".data(using: .utf8)!)
            exit(10)
        }
        // Hard availability gate. The whole experiment is void on the simulator
        // or an AI-off Mac; we refuse to emit numbers rather than fake them.
        guard AppleOnDeviceBackend.isAvailable else {
            let reason = AppleOnDeviceBackend.availabilityDescription()
            FileHandle.standardError.write("FATAL: SystemLanguageModel not available: \(reason)\n".data(using: .utf8)!)
            FileHandle.standardError.write("Requires: Apple-Intelligence-capable Mac, AI enabled, model downloaded, signed in.\n".data(using: .utf8)!)
            exit(11)
        }
        print("Apple Intelligence on-device model: AVAILABLE (\(AppleOnDeviceBackend.availabilityDescription()))")

        let catalog: [String: StylePreset]
        let scenarios: [Scenario]
        do {
            catalog = try loadCatalog(a.catalogPath)
            var scn = try loadScenarios(a)
            if let lim = a.limit { scn = Array(scn.prefix(lim)) }
            scenarios = scn
        } catch {
            FileHandle.standardError.write("FATAL loading inputs: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
        print("loaded \(scenarios.count) scenarios, \(catalog.count) styles")
        let plannedCells = scenarios.count * a.locales.count * a.intensities.count
        print("plan: \(plannedCells) cells = \(scenarios.count) scenario × \(a.locales.count) locale × \(a.intensities.count) intensity")
        print("locales=\(a.locales) intensities=\(a.intensities) maxTokens=\(a.maxTokens) guardrails=\(a.guardrails)")

        // Durable JSONL sink so a long run survives a crash.
        let ts = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        let suffix = a.label ?? "applefm-\(ts.prefix(15))"
        let dir = URL(fileURLWithPath: a.outDir).appendingPathComponent("run-\(suffix)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let jsonlURL = dir.appendingPathComponent("cells.jsonl")
        FileManager.default.createFile(atPath: jsonlURL.path, contents: nil)
        let jsonl = try? FileHandle(forWritingTo: jsonlURL)

        var records: [CellRecord] = []
        let started = Date()
        var done = 0

        for locale in a.locales {
            AppLocalization.currentLocale = locale
            let loc = Locale(identifier: locale)
            for intensityRaw in a.intensities {
                guard let intensity = Intensity(rawValue: intensityRaw) else {
                    FileHandle.standardError.write("skip unknown intensity \(intensityRaw)\n".data(using: .utf8)!)
                    continue
                }
                for sc in scenarios {
                    done += 1
                    guard let situation = sc.prompt[locale] else { continue }
                    guard let style = catalog[sc.defaultStyleId] else {
                        FileHandle.standardError.write("skip: no style \(sc.defaultStyleId)\n".data(using: .utf8)!)
                        continue
                    }
                    // Build the REAL production prompts.
                    let instructions = PromptBuilder.systemPrompt(
                        style: style, locale: loc, mode: .roast,
                        intensity: intensity, safeMode: true)
                    let user = PromptBuilder.userPrompt(
                        situation: situation, styleName: style.displayName,
                        variants: 1, mode: .roast, intensity: intensity,
                        priorContext: nil, locale: loc)
                    let temperature = intensity.isPrivateDraft
                        ? min(style.temperature + 0.1, 1.0) : style.temperature

                    let backend = AppleOnDeviceBackend(temperature: temperature, maxTokens: a.maxTokens,
                                                       permissiveGuardrails: a.guardrails == "permissive")
                    let outcome = await backend.generate(instructions: instructions, prompt: user)

                    let rec = makeRecord(sc: sc, style: style, intensity: intensityRaw,
                                         locale: locale, sysChars: instructions.count,
                                         userChars: user.count, outcome: outcome)
                    records.append(rec)
                    if let line = try? JSONEncoder().encode(rec),
                       var d = String(data: line, encoding: .utf8) {
                        d += "\n"; jsonl?.write(d.data(using: .utf8)!)
                    }
                    let tag: String
                    switch outcome {
                    case .guardrail: tag = "GUARDRAIL-REFUSAL"
                    case .success(let t, _, _): tag = "ok(\(t.count)c\(rec.softRefusalFlag ? ",soft?" : ""))"
                    case .otherError(let cn, _, _, _, _): tag = "other:\(cn)"
                    }
                    print(String(format: "[%3d/%3d] %-16@ %-6@ %-8@ %5dms  %@",
                                 done, plannedCells, sc.id as NSString,
                                 intensityRaw as NSString, locale as NSString,
                                 rec.latencyMs, tag as NSString))
                }
            }
        }
        try? jsonl?.close()
        let elapsed = Int(Date().timeIntervalSince(started))

        // Outputs
        var meta: [String: String] = [
            "generated": ISO8601DateFormatter().string(from: Date()),
            "device": "Apple M1 Pro / macOS on-device Foundation Models",
            "availability": AppleOnDeviceBackend.availabilityDescription(),
            "cells": "\(records.count)",
            "elapsed_s": "\(elapsed)",
            "prompt_source": "verbatim Shared/AI/PromptBuilder.swift (SHA-matched) + real StylePresets.json",
            "locales": a.locales.joined(separator: ","),
            "intensities": a.intensities.joined(separator: ","),
            "max_tokens": "\(a.maxTokens)",
            "guardrails": a.guardrails,
        ]
        meta["scenarios"] = a.allScenarios ? "base+additions" : a.scenariosPath

        let jsonURL = dir.appendingPathComponent("results.json")
        let mdURL = dir.appendingPathComponent("report.md")
        try? FMReport.writeJSON(records, meta: meta, to: jsonURL)
        try? FMReport.writeMarkdown(records, meta: meta, localeOrder: a.locales, to: mdURL)

        // Console summary
        let agg = FMReport.aggregate(records)
        print("\n==== SUMMARY (ran \(records.count) cells in \(elapsed)s) ====")
        print("locale    n  success  guardrail  other  hardRefusalRate")
        for loc in a.locales {
            guard let v = agg[loc] else { continue }
            print(String(format: "%-8@  %3d  %7d  %9d  %5d  %@",
                         loc as NSString, v.total, v.success, v.guardrail, v.other,
                         FMReport.pct(v.hardRefusalRate) as NSString))
        }
        print("wrote \(jsonURL.path)")
        print("wrote \(mdURL.path)")
        print("wrote \(jsonlURL.path)")
        #endif
    }

    static func makeRecord(sc: Scenario, style: StylePreset, intensity: String,
                           locale: String, sysChars: Int, userChars: Int,
                           outcome: FMOutcome) -> CellRecord {
        switch outcome {
        case .success(let text, let ms, let attempts):
            let checks = DeterministicChecks.run(text: text, locale: locale, intensity: intensity)
            return CellRecord(scenarioId: sc.id, category: sc.category, styleId: style.id,
                              styleDisplayName: style.displayName, intensity: intensity,
                              locale: locale, outcome: "success", otherCaseName: nil,
                              errorRaw: nil, errorLocalized: nil, text: text,
                              latencyMs: ms, attempts: attempts, systemPromptChars: sysChars,
                              userPromptChars: userChars,
                              softRefusalFlag: SoftRefusal.looksLikeRefusal(text), checks: checks)
        case .guardrail(let raw, let localized, let ms, let attempts):
            return CellRecord(scenarioId: sc.id, category: sc.category, styleId: style.id,
                              styleDisplayName: style.displayName, intensity: intensity,
                              locale: locale, outcome: "guardrail", otherCaseName: nil,
                              errorRaw: raw, errorLocalized: localized, text: nil,
                              latencyMs: ms, attempts: attempts, systemPromptChars: sysChars,
                              userPromptChars: userChars, softRefusalFlag: false, checks: nil)
        case .otherError(let cn, let raw, let localized, let ms, let attempts):
            return CellRecord(scenarioId: sc.id, category: sc.category, styleId: style.id,
                              styleDisplayName: style.displayName, intensity: intensity,
                              locale: locale, outcome: "other", otherCaseName: cn,
                              errorRaw: raw, errorLocalized: localized, text: nil,
                              latencyMs: ms, attempts: attempts, systemPromptChars: sysChars,
                              userPromptChars: userChars, softRefusalFlag: false, checks: nil)
        }
    }
}
