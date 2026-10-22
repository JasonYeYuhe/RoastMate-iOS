import Foundation
import FoundationModels

let s2t = StringTransform("Hans-Hant"), t2s = StringTransform("Hant-Hans")
func script(_ s: String) -> String {
    var simp = 0, trad = 0
    for ch in s { guard let u = ch.unicodeScalars.first, (0x4E00...0x9FFF).contains(u.value) else { continue }
        let c = String(ch)
        if let a = c.applyingTransform(s2t, reverse: false), a != c { simp += 1 }
        if let b = c.applyingTransform(t2s, reverse: false), b != c { trad += 1 } }
    let v = (simp == 0 && trad == 0) ? "NO-DIFF" : (simp > trad ? "SIMPLIFIED" : (trad > simp ? "TRADITIONAL" : "MIXED"))
    return "\(v) simpOnly=\(simp) tradOnly=\(trad)"
}
// Production AppleFMBackend.failureCategory logic (AppleFMBackend.swift:81-96), copied for the mapping check.
func prodCategory(_ desc0: String) -> String {
    let desc = desc0.lowercased()
    if desc.contains("guardrail") || desc.contains("safety") { return "guardrail" }
    if desc.contains("context") || desc.contains("token") { return "quota" }
    if desc.contains("asset") || desc.contains("unavailable") || desc.contains("language") || desc.contains("locale") { return "modelAssetMissing" }
    return "guardrail"
}

let model = SystemLanguageModel.default
print("availability:", model.availability)
print("supportedLanguages:", model.supportedLanguages.map { $0.minimalIdentifier + "(" + ($0.script?.identifier ?? "-") + "," + ($0.region?.identifier ?? "-") + ")" }.sorted())
for id in ["en_US", "zh_TW", "zh-Hant_TW", "zh-Hant", "zh_HK", "zh-Hans_CN", "zh_CN", "ja_JP", "ru_RU", "th_TH"] {
    print("supportsLocale(\(id)):", model.supportsLocale(Locale(identifier: id)))
}
let synthetic = LanguageModelSession.GenerationError.unsupportedLanguageOrLocale(.init(debugDescription: "probe"))
print("String(describing: unsupportedLanguageOrLocale) =", String(describing: synthetic))
print("  -> production failureCategory would be:", prodCategory(String(describing: synthetic)), "(either way RoastEngine returns curated)")

let catalogData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/jason/Documents/RoastMate/Shared/Resources/StylePresets.json"))
let catalog = try! JSONDecoder().decode(StylePresetCatalogFile.self, from: catalogData)
func style(_ id: String) -> StylePreset { catalog.styles.first { $0.id == id }! }

func run(_ instructions: String, _ prompt: String, temp: Double, maxTokens: Int) async -> String {
    let t0 = Date()
    do {
        let s = LanguageModelSession(instructions: instructions)
        let r = try await s.respond(to: prompt, options: GenerationOptions(temperature: temp, maximumResponseTokens: maxTokens))
        return "OK \(Int(Date().timeIntervalSince(t0)*1000))ms | \(script(r.content)) | \(r.content.replacingOccurrences(of: "\n", with: " ⏎ "))"
    } catch let e as LanguageModelSession.GenerationError {
        return "THROW GenerationError: \(String(describing: e).prefix(160)) -> prodCategory=\(prodCategory(String(describing: e))) -> app shows CURATED"
    } catch { return "THROW other: \(error)" }
}

let args = CommandLine.arguments
let tw = Locale(identifier: args.count > 1 ? args[1] : "zh_TW")
AppLocalization.currentLang = "zh-Hant"
print("\nlocale under test:", tw.identifier, "bucket:", AppLanguage.contentBucket(for: tw))
let scenarios: [(String, String)] = [
    ("boss_credit", "我做的專案,主管在整個團隊面前說成是他的功勞。"),
    ("tw_line_boss", "慣老闆半夜十一點在LINE群組@我,要我明天早上八點前改好簡報,還說『年輕人多學一點不吃虧』。"),
]
let cells: [(String, Intensity)] = [
    ("savage_no_filter", .savage), ("taiwanese_drama", .savage), ("corporate_passive_violence", .savage),
    ("high_eq", .sharp), ("taiwanese_drama", .calm),
]
for (sid, text) in scenarios {
    for (styleId, intensity) in cells {
        let st = style(styleId)
        let sys = PromptBuilder.systemPrompt(style: st, locale: tw, mode: .roast, intensity: intensity, safeMode: true)
        let usr = PromptBuilder.userPrompt(situation: text, styleName: st.displayName, variants: 3, mode: .roast, intensity: intensity, priorContext: nil, locale: tw)
        let r = await run(sys, usr, temp: st.temperature, maxTokens: 600)
        print("\n[\(sid) \(styleId)/\(intensity.rawValue) exPrimed=\(PromptBuilder.examplesForPrompt(style: st, locale: tw).count)] \(r)")
    }
}
// Rewrite-as-sendable fed with REAL production Worker drafts (worker_probe.jsonl, 2026-10-22)
struct Draft: Decodable { let locale: String; let intensity: String; let scenarioId: String; let text: String }
let wlines = (try? String(contentsOfFile: "../worker_probe.jsonl", encoding: .utf8))?.split(separator: "\n") ?? []
let situations: [String: String] = [
  "硬核回擊": "慣老闆半夜十一點在LINE群組@我,要我明天早上八點前改好簡報,還說『年輕人多學一點不吃虧』。",
  "台劇腔": "室友的碗可以放好幾天,還說我『太計較』。",
  "職場冷暴力": "我做的專案,主管在整個團隊面前說成是他的功勞。",
  "高 EQ": "前任突然傳來一句『在嗎』,好像什麼都沒發生過。",
  "陰陽怪氣": "有人把我的私訊截圖發到群組,故意讓我難堪。",
  "Savage": "My boss pinged me at 11pm on Slack to redo the deck by 8am and said 'young people should learn more'.",
]
let styleFor: [String: String] = ["硬核回擊": "savage_no_filter", "台劇腔": "taiwanese_drama", "職場冷暴力": "corporate_passive_violence", "高 EQ": "high_eq", "陰陽怪氣": "passive_aggressive", "Savage": "savage_no_filter"]
for l in wlines {
    guard let d = try? JSONDecoder().decode(Draft.self, from: Data(l.utf8)), !d.text.isEmpty else { continue }
    let loc = Locale(identifier: d.locale)
    AppLocalization.currentLang = d.locale.hasPrefix("en") ? "en" : "zh-Hant"
    let st = style(styleFor[d.scenarioId] ?? "high_eq")
    let (sys, usr) = PromptBuilder.rewriteAsSendablePrompt(ventDraft: d.text, originalSituation: situations[d.scenarioId] ?? "", styleName: st.displayName, locale: loc)
    let r = await run(sys, usr, temp: max(0.4, st.temperature - 0.2), maxTokens: 250)
    print("\n[rewrite of real \(d.intensity) draft, \(d.locale), \(st.id)] \(r)")
}
AppLocalization.currentLang = "zh-Hant"
// Unsupported-language control: what the framework does with a language outside the supported set.
let ru = await run("You are a helpful assistant. You MUST respond in Russian.", "Напиши одно вежливое предложение начальнику.", temp: 0.7, maxTokens: 100)
print("\n[control ru] \(ru)")
