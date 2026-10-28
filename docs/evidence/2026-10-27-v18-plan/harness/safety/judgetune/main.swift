import Foundation
import FoundationModels

// Threat-judge tuning runner (2026-10-29, A3). Runs candidate judge prompts on
// a slice of messages and prints a per-message line plus a summary.
//
//   judgetune <slice> <prompt.txt> [<prompt2.txt> ...]
//     slice: dev  = harness/safety/judge_dev.json (tuning)
//            odd  = safety_set.json messages with an odd number (tuning)
//            even = safety_set.json messages with an even number (report only)
//            all  = the whole safety set
//            file:<path> = any {"messages": [...]} file (e.g. real generated outputs)
//   Several prompts = several judges; a message passes only if every judge
//   answers a plain SAFE (one call each, permissive, temperature 0, maxTokens 4).
//   RewriteThreatScreen runs first, as in production; PHRASES=0 turns it off.
//
// Compile: swiftc -O -o $OUT/judgetune judgetune/main.swift Stubs.swift
//          $R/Shared/AI/RewriteThreatScreen.swift   (Stubs.swift from harness/safety/)

struct Msg: Decodable { let id, locale, label, text: String; let veiled: Bool?; let kind: String? }
struct Msgs: Decodable { let messages: [Msg] }

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: judgetune <dev|odd|even|all> <prompt.txt>..."); exit(1) }
let slice = args[1]
let prompts = args.dropFirst(2).map { try! String(contentsOfFile: $0, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) }
let env = ProcessInfo.processInfo.environment
let usePhrases = env["PHRASES"] != "0"
// MAXTOK: token budget per judge call (production: 4). PARSE=last reads the
// last word of a longer answer (for prompts that quote before deciding).
let maxTok = Int(env["MAXTOK"] ?? "") ?? 4
let parseLast = env["PARSE"] == "last"
func word(_ v: String) -> String {
    let w = parseLast ? (v.components(separatedBy: .whitespacesAndNewlines).last { !$0.isEmpty } ?? "") : v
    return w.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters).union(.symbols)).uppercased()
}
let base = "\(repoRoot)/docs/evidence/2026-10-27-v18-plan/harness"

func load(_ p: String) -> [Msg] { try! JSONDecoder().decode(Msgs.self, from: Data(contentsOf: URL(fileURLWithPath: p))).messages }
func number(_ id: String) -> Int { Int(id.filter(\.isNumber)) ?? 0 }
let messages: [Msg] = switch slice {
case "dev": load("\(base)/safety/judge_dev.json")
case "odd": load("\(base)/safety_set.json").filter { number($0.id) % 2 == 1 }
case "even": load("\(base)/safety_set.json").filter { number($0.id) % 2 == 0 }
case let f where f.hasPrefix("file:"): load(String(f.dropFirst(5)))
default: load("\(base)/safety_set.json")
}

// GUARD=default runs the judge under Apple's default guardrails; a guardrail
// throw then counts as "not SAFE", as production treats any error.
let model = env["GUARD"] == "default"
    ? SystemLanguageModel(useCase: .general, guardrails: .default)
    : SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
var caught = 0, threats = 0, flagged = 0, legit = 0, veiledCaught = 0, veiled = 0
var times: [Int] = []
for m in messages {
    let phrase = usePhrases && RewriteThreatScreen.containsThreat(m.text)
    var verdicts: [String] = []
    if !phrase {
        for p in prompts {
            let t0 = Date()
            do {
                let s = LanguageModelSession(model: model, instructions: p)
                verdicts.append(try await s.respond(to: m.text, options: GenerationOptions(temperature: 0, maximumResponseTokens: maxTok)).content)
            } catch { verdicts.append(String(describing: error).contains("unsafe") || String(describing: error).contains("guardrail") ? "GUARDRAIL" : "ERR") }
            times.append(Int(Date().timeIntervalSince(t0) * 1000))
            if word(verdicts.last!) != "SAFE" { break }  // production stops at the first non-SAFE
        }
    }
    let blocked = phrase || verdicts.contains { word($0) != "SAFE" }
    let isThreat = m.label == "threat"
    let wrong = isThreat != blocked
    if isThreat { threats += 1; if blocked { caught += 1 }; if m.veiled == true { veiled += 1; if blocked { veiledCaught += 1 } } }
    else { legit += 1; if blocked { flagged += 1 } }
    print("\(wrong ? "✗" : " ") \(m.id) \(m.label) \(m.locale)\(m.veiled == true ? " veiled" : "") \(phrase ? "PHRASE" : verdicts.map { $0.replacingOccurrences(of: "\n", with: " ") }.joined(separator: "/")) | \(m.text)")
    fflush(stdout)
}
times.sort()
let median = times.isEmpty ? 0 : times[times.count / 2]
print("SUMMARY slice=\(slice) judges=\(prompts.count) threats caught \(caught)/\(threats) (veiled \(veiledCaught)/\(veiled)); legit blocked \(flagged)/\(legit); median judge call \(median) ms")
