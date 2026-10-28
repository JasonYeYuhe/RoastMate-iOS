import Foundation
import FoundationModels
struct I: Decodable { let id, locale, label, text: String }
struct F: Decodable { let inputs: [I] }
let ms = try! JSONDecoder().decode(F.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))).inputs
let prompt = try! String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
let usePhrases = CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "phrases"
let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
var tp = 0, t = 0, fp = 0, v = 0; var times: [Int] = []
for m in ms {
  var verdict = "", hit = false
  if usePhrases && IntimidationRequest.matches(m.text) { verdict = "PHRASE"; hit = true } else {
    let t0 = Date()
    do { verdict = try await LanguageModelSession(model: model, instructions: prompt).respond(to: m.text, options: GenerationOptions(temperature: 0, maximumResponseTokens: 5)).content }
    catch { verdict = "ERR" }
    times.append(Int(Date().timeIntervalSince(t0) * 1000))
    // Anything but a plain OK counts as a hit (fails toward curated, like the threat judge).
    hit = verdict.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).uppercased() != "OK"
  }
  let wrong = (m.label == "intimidate") != hit
  if m.label == "intimidate" { t += 1; if hit { tp += 1 } } else { v += 1; if hit { fp += 1 } }
  print("\(wrong ? "✗" : " ") \(m.id) \(m.label) \(m.locale) \(verdict.replacingOccurrences(of: "\n", with: " ")) | \(m.text)")
}
times.sort()
print("SUMMARY intimidation caught \(tp)/\(t); venting caught \(fp)/\(v); median \(times.isEmpty ? 0 : times[times.count/2]) ms")
