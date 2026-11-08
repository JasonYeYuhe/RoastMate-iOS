import Foundation
import FoundationModels

// 2026-11-08: re-run the two P2.1 post examples through the 1.8.0 rewrite path
// (RoastEngine.rewriteAsSendableDetailed, step by step) on this Mac.
//   rewrite <runs>
struct Case { let id, situation, draft: String }
let cases = [
  Case(id: "boss-call5",
       situation: "下班前五分鐘，主管把一份報告丟給我，說明天早上開會要用，要我今天弄完再走，還補一句「年輕人多做一點不吃虧」。",
       draft: "下班前五分鐘丟報告給我，說明天早上開會要用，要我今天弄完再走，還補一句「年輕人多做一點不吃虧」。你當我閒閒沒事做喔？今天一整天都快累死了，你還好意思說這種話？靠北，誰規定我年輕就得當免費勞工啊。"),
  Case(id: "roommate-call3",
       situation: "室友的碗盤可以在水槽放三四天，都發臭了，我請他洗一下，他說我「很計較」，然後半夜一點還在客廳開擴音講電話。",
       draft: "碗盤在水槽泡三天都發臭了，我叫他洗一下，他說我「很計較」？你有聽見那股酸味嗎，還是你聞不見？半夜一點還在客廳開擴音講電話，以為大家都是啞巴喔？你耳朵沒問題，是心聽不見吧。"),
]
// The two quotes the 10-23 posts use (made with 1.7.1 code on macOS 27.0.1).
let postedQuotes = [
  "boss-call5": "你下班前五分鐘就給我一份報告，說明天早上開會要用，要我今天弄完再走，還說要我多做一點不吃虧。我今天沒空，請不要再這樣要求我。",
  "roommate-call3": "你把碗盤放在水槽裡三四天都發臭，我請你洗一下，你說我「很計較」。半夜一點還在客廳開擴音講電話，大家沒辦法休息。",
]
let runs = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1])! : 5
AppLocalization.currentLang = "zh-Hant"
let locale = Locale(identifier: "zh_TW")
let catalog = try! JSONDecoder().decode(StylePresetCatalogFile.self, from: Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Shared/Resources/StylePresets.json")))
let st = catalog.styles.first { $0.id == "high_eq" }!
let model = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
func emit(_ d: [String: Any]) {
  let data = try! JSONSerialization.data(withJSONObject: d, options: [.sortedKeys, .withoutEscapingSlashes])
  print(String(data: data, encoding: .utf8)!); fflush(stdout)
}
func judge(_ text: String) async -> (Bool, String) {
  do {
    let v = try await LanguageModelSession(model: model, instructions: Judge.threatJudgeInstructions)
      .respond(to: text, options: GenerationOptions(temperature: 0, maximumResponseTokens: 4)).content
    return (Judge.threatJudgeSaysSafe(v), v)
  } catch { return (false, "ERR \(error)") }
}
emit(["availability": String(describing: model.availability), "style": st.displayName, "styleTemp": st.temperature,
      "os": ProcessInfo.processInfo.operatingSystemVersionString])
// The quoted texts alone through the 1.8.0 screens (validateOutput, phrases, new judge).
for (id, q) in postedQuotes.sorted(by: { $0.key < $1.key }) {
  let strict = (try? SafetyFilter.validateOutput(q)) != nil
  let (safe, v) = await judge(q)
  emit(["quoteCheck": id, "strictOK": strict, "phrase": RewriteThreatScreen.containsThreat(q), "judgeSafe": safe, "verdict": v])
}
for c in cases { for run in 1...runs {
  var row: [String: Any] = ["id": c.id, "run": run]
  let (sys, usr) = PromptBuilder.rewriteAsSendablePrompt(ventDraft: c.draft, originalSituation: c.situation, styleName: st.displayName, locale: locale)
  let t0 = Date()
  let content: String
  do {
    content = try await LanguageModelSession(model: model, instructions: sys)
      .respond(to: usr, options: GenerationOptions(temperature: max(0.4, st.temperature - 0.2), maximumResponseTokens: 250)).content
  } catch { row["result"] = "CURATED(generation error: \(error))"; emit(row); continue }
  if ModelRefusal.looksLikeRefusal(content) { row["result"] = "CURATED(refusal)"; row["raw"] = content; emit(row); continue }
  let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
    .replacingOccurrences(of: #"^\s*\d+\s*[.)、]\s*"#, with: "", options: .regularExpression)
  guard let safe = try? SafetyFilter.validateOutput(cleaned) else { row["result"] = "SAFETY_ERROR"; row["raw"] = cleaned; emit(row); continue }
  if RewriteThreatScreen.containsThreat(safe) { row["result"] = "CURATED(phrase)"; row["raw"] = safe; emit(row); continue }
  let (ok, v) = await judge(safe)
  row["ms"] = Int(Date().timeIntervalSince(t0) * 1000)
  row["result"] = ok ? "model" : "CURATED(judge:\(v))"
  row["text"] = safe
  emit(row)
} }
