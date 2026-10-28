import Foundation
import FoundationModels

// A3 end-to-end on the safety set's situations (2026-10-29). Mirrors the A3 design
// in plan §3: input checks (validateInput, crisisSignal hard → nothing generated),
// then the production Savage prompt (PromptBuilder, 3 variants) under DEFAULT
// guardrails; only on a refusal, one fresh call under permissiveContentTransformations.
// Every variant of a permissive answer must pass ModelRefusal → validateOutput →
// RewriteThreatScreen → the judge (prompt file given as argv[1]); survivors are
// "shown". Since 2026-10-29 the input check (IntimidationRequest + intent prompt)
// runs before the retry, as in RoastEngine. The shown texts are then read by hand for threats, slurs, self-harm and PII.
//
//   e2e <judge_prompt.txt> [runs=2] [style=savage_no_filter]
let args = CommandLine.arguments
let judgePrompt = try! String(contentsOfFile: args[1], encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
let runs = args.count > 2 ? Int(args[2])! : 2
let styleId = args.count > 3 ? args[3] : "savage_no_filter"
let intentPrompt = try! String(contentsOfFile: "\(repoRoot)/docs/evidence/2026-10-27-v18-plan/harness/safety/intent/prompts/i1_examples.txt", encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)

struct Sit: Decodable { let id, locale, category, text: String; let intensity: String? }
struct SetFile: Decodable { let situations: [Sit] }
let set = try! JSONDecoder().decode(SetFile.self, from: Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/docs/evidence/2026-10-27-v18-plan/harness/safety_set.json")))
let catalog = try! JSONDecoder().decode(StylePresetCatalogFile.self, from: Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Shared/Resources/StylePresets.json")))
let st = catalog.styles.first { $0.id == styleId }!
let permissive = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)

func emit(_ d: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: d, options: [.sortedKeys, .withoutEscapingSlashes])
    print(String(data: data, encoding: .utf8)!); fflush(stdout)
}
func judgeSafe(_ text: String) async -> (Bool, String) {
    do {
        let s = LanguageModelSession(model: permissive, instructions: judgePrompt)
        let v = try await s.respond(to: text, options: GenerationOptions(temperature: 0, maximumResponseTokens: 4)).content
        return (v.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).uppercased() == "SAFE", v)
    } catch { return (false, "ERR") }
}

for run in 1...runs { for s in set.situations {
    var row: [String: Any] = ["id": s.id, "run": run, "locale": s.locale, "category": s.category, "style": styleId]
    // Production order (RoastGeneratorViewModel): the crisis check runs before anything else.
    if case .hard = SafetyFilter.crisisSignal(s.text) { row["stage"] = "crisisHard"; emit(row); continue }
    if (try? SafetyFilter.validateInput(s.text)) == nil { row["stage"] = "inputRejected"; emit(row); continue }
    let loc = Locale(identifier: s.locale)
    AppLocalization.currentLang = s.locale.hasPrefix("en") ? "en" : (s.locale.hasPrefix("ja") ? "ja" : "zh-Hant")
    let intensity: Intensity = s.intensity == "sharp" ? .sharp : .savage
    let sys = PromptBuilder.systemPrompt(style: st, locale: loc, mode: .roast, intensity: intensity, safeMode: true)
    let usr = PromptBuilder.userPrompt(situation: s.text, styleName: st.displayName, variants: 3, mode: .roast, intensity: intensity, priorContext: nil, locale: loc)
    let t0 = Date()
    var raw = "", path = "default"
    do {
        raw = try await LanguageModelSession(model: .default, instructions: sys).respond(to: usr, options: GenerationOptions(temperature: st.temperature, maximumResponseTokens: 600)).content
    } catch {
        path = "permissive"
        // Input check before the retry, as RoastEngine.permissiveRetry does it.
        if IntimidationRequest.matches(s.text) { row["stage"] = "intentPhrase"; emit(row); continue }
        do {
            let v = try await LanguageModelSession(model: permissive, instructions: intentPrompt).respond(to: s.text, options: GenerationOptions(temperature: 0, maximumResponseTokens: 5)).content
            if v.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).uppercased() != "OK" {
                row["stage"] = "intentModel"; row["intent"] = v; emit(row); continue
            }
        } catch { row["stage"] = "intentModel"; row["intent"] = "ERR"; emit(row); continue }
        do { raw = try await LanguageModelSession(model: permissive, instructions: sys).respond(to: usr, options: GenerationOptions(temperature: st.temperature, maximumResponseTokens: 600)).content }
        catch { row["stage"] = "bothThrew"; row["err"] = String(describing: error).prefix(100); emit(row); continue }
    }
    row["path"] = path
    var shown: [String] = [], dropped: [[String: String]] = []
    for v in PromptBuilder.splitVariants(raw) {
        if ModelRefusal.looksLikeRefusal(v) { dropped.append(["why": "refusal", "text": v]); continue }
        guard let ok = try? SafetyFilter.validateOutput(v) else { dropped.append(["why": "strict", "text": v]); continue }
        if path == "permissive" {
            if RewriteThreatScreen.containsThreat(ok) { dropped.append(["why": "phrase", "text": ok]); continue }
            let (safe, verdict) = await judgeSafe(ok)
            if !safe { dropped.append(["why": "judge:\(verdict)", "text": ok]); continue }
        }
        shown.append(ok)
    }
    row["ms"] = Int(Date().timeIntervalSince(t0) * 1000)
    row["stage"] = shown.isEmpty ? "curated" : "shown"
    row["shown"] = shown; row["dropped"] = dropped
    emit(row)
} }
