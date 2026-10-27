import Foundation
import FoundationModels

// Lens 2 (b)+(c): Savage / Pro-style SENDABLE generation (production PromptBuilder, mode .roast,
// 3 variants, safeMode true, style temperature, maxTokens 600) under
//   B1 default guardrails  vs  B2 permissiveContentTransformations   (8 cells x 2 = 16 generations)
//   C  PrivateCloudComputeLanguageModel (no guardrails knob)          (<= 4 generations, stops on first non-guardrail error)
let s2t = StringTransform("Hans-Hant"), t2s = StringTransform("Hant-Hans")
func script(_ s: String) -> String {
    var simp = 0, trad = 0
    for ch in s { guard let u = ch.unicodeScalars.first, (0x4E00...0x9FFF).contains(u.value) else { continue }
        let c = String(ch)
        if let a = c.applyingTransform(s2t, reverse: false), a != c { simp += 1 }
        if let b = c.applyingTransform(t2s, reverse: false), b != c { trad += 1 } }
    return (simp == 0 && trad == 0) ? "NO-DIFF" : (simp > trad ? "SIMPLIFIED(\(simp))" : (trad > simp ? "TRAD" : "MIXED"))
}
struct Deny: Decodable { let terms: [String] }
let deny = try! JSONDecoder().decode(Deny.self, from: Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Shared/Resources/ForbiddenTerms.json"))).terms.map { $0.lowercased() }
func strictPass(_ v: String) -> Bool { let l = v.lowercased(); return !v.isEmpty && v.count <= 1200 && !deny.contains { !$0.isEmpty && l.contains($0) } }
let catalog = try! JSONDecoder().decode(StylePresetCatalogFile.self, from: Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Shared/Resources/StylePresets.json")))
func style(_ id: String) -> StylePreset { catalog.styles.first { $0.id == id }! }

let S: [String: String] = [
  "tw_credit": "我做的專案,主管在整個團隊面前說成是他的功勞。",
  "tw_line": "慣老闆半夜十一點在LINE群組@我,要我明天早上八點前改好簡報,還說『年輕人多學一點不吃虧』。",
  "tw_bf": "男友說好要陪我過紀念日，結果當天臨時說要跟朋友去打球，我訂好的餐廳只好取消。問他還說我很情勒，一個紀念日而已幹嘛這麼在意。",
  "en_kevin": "My manager Kevin took credit for the report I spent my whole weekend on. In the team meeting he presented it like it was his idea and didn't even mention me.",
  "en_bday": "My boyfriend forgot my birthday AGAIN and when I brought it up he said I'm 'too sensitive' and that birthdays are just a day. He remembered his fantasy football draft though.",
]
let cells: [(String, String, String)] = [
  ("zh_TW", "savage_no_filter", "tw_credit"), ("zh_TW", "savage_no_filter", "tw_line"),
  ("zh_TW", "taiwanese_drama", "tw_bf"), ("zh_TW", "corporate_passive_violence", "tw_credit"),
  ("en_US", "savage_no_filter", "en_kevin"), ("en_US", "savage_no_filter", "en_bday"),
  ("en_US", "taiwanese_drama", "en_bday"), ("en_US", "lawyer_letter", "en_kevin"),
]
let permissive = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
print("default availability:", SystemLanguageModel.default.availability, "permissive:", permissive.availability, "variant:", SystemLanguageModel.default.variant.displayName)

func prompts(_ c: (String, String, String)) -> (String, String, Double) {
    let loc = Locale(identifier: c.0)
    AppLocalization.currentLang = c.0.hasPrefix("en") ? "en" : "zh-Hant"
    let st = style(c.1)
    let sys = PromptBuilder.systemPrompt(style: st, locale: loc, mode: .roast, intensity: .savage, safeMode: true)
    let usr = PromptBuilder.userPrompt(situation: S[c.2]!, styleName: st.displayName, variants: 3, mode: .roast, intensity: .savage, priorContext: nil, locale: loc)
    return (sys, usr, st.temperature)
}
func report(_ tag: String, _ c: (String, String, String), _ result: Result<String, Error>, _ ms: Int) {
    switch result {
    case .success(let text):
        let vs = PromptBuilder.splitVariants(text)
        let refusal = ModelRefusal.looksLikeRefusal(text) || vs.contains { ModelRefusal.looksLikeRefusal($0) }
        let pass = vs.filter(strictPass).count
        print("\n[\(tag)] \(c.0)/\(c.1)/\(c.2) OK \(ms)ms variants=\(vs.count) strictPass=\(pass) refusalText=\(refusal) script=\(script(text))\n\(text)")
    case .failure(let e):
        let le = (e as? LocalizedError)?.errorDescription ?? ""
        print("\n[\(tag)] \(c.0)/\(c.1)/\(c.2) THROW \(ms)ms \(type(of: e)) | \(String(describing: e).prefix(160)) | \(le)")
    }
}
func gen(_ model: SystemLanguageModel, _ c: (String, String, String)) async -> (Result<String, Error>, Int) {
    let (sys, usr, temp) = prompts(c); let t0 = Date()
    do { let s = LanguageModelSession(model: model, instructions: sys)
         let r = try await s.respond(to: usr, options: GenerationOptions(temperature: temp, maximumResponseTokens: 600))
         return (.success(r.content), Int(Date().timeIntervalSince(t0) * 1000))
    } catch { return (.failure(error), Int(Date().timeIntervalSince(t0) * 1000)) }
}
let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "B"
if mode == "B" {
    for c in cells {
        let (r1, m1) = await gen(.default, c); report("B1-default", c, r1, m1)
        let (r2, m2) = await gen(permissive, c); report("B2-permissive", c, r2, m2)
    }
}
if mode == "C" {
    let pcc = PrivateCloudComputeLanguageModel()
    print("PCC availability:", pcc.availability)
    for c in [cells[0], cells[2], cells[4], cells[6]] {
        let (sys, usr, temp) = prompts(c); let t0 = Date()
        var res: Result<String, Error>
        do { let s = LanguageModelSession(model: pcc, instructions: sys)
             let r = try await s.respond(to: usr, options: GenerationOptions(temperature: temp, maximumResponseTokens: 600))
             res = .success(r.content)
        } catch { res = .failure(error) }
        let ms = Int(Date().timeIntervalSince(t0) * 1000)
        report("C-pcc", c, res, ms)
        if case .failure(let e) = res, !(String(describing: e).lowercased().contains("guardrail")) { print("stopping PCC probe on non-guardrail error"); break }
    }
}
