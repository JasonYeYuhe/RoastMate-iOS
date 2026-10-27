import Foundation
import FoundationModels

let s2t = StringTransform("Hans-Hant"), t2s = StringTransform("Hant-Hans")
let twOK: Set<Character> = Set("台里后干只面着周游系才群托志表了布借吃床")
func script(_ s: String) -> String {
    var simp = "", trad = 0
    for ch in s { guard let u = ch.unicodeScalars.first, (0x4E00...0x9FFF).contains(u.value) else { continue }
        let c = String(ch)
        if let a = c.applyingTransform(s2t, reverse: false), a != c, !twOK.contains(ch) { simp.append(ch) }
        if let b = c.applyingTransform(t2s, reverse: false), b != c { trad += 1 } }
    return "simpOnly=\(simp.count)[\(simp)] tradOnly=\(trad)"
}
struct PF: Decodable { let personas: [EchoSpec] }
let pf = try! JSONDecoder().decode(PF.self, from: Data(contentsOf: URL(fileURLWithPath: "\(repoRoot)/Shared/Resources/echoes-personas-zh-Hans.json")))
let personas = Array(pf.personas.prefix(2))
let tw = Locale(identifier: "zh_TW")
print("availability:", SystemLanguageModel.default.availability)

// Variant H = a minimal zh-Hant adaptation an engineer might try first: same contract,
// prompt converted to Traditional + Taiwan register line. (NOT production.)
func hantVariant(_ p: String, feral: Bool) -> String {
    var q = p.replacingOccurrences(of: "in mandarin Chinese (zh-Hans)", with: "in Traditional Chinese as written in Taiwan (zh-Hant, 繁體中文). Every character must be Traditional")
    q = q.replacingOccurrences(of: "Cursing OK in mandarin Internet vent style (狗东西 / 神经病 / 操 — but no slurs, no violence threats). Match how friends actually rant in private WeChat / 朋友圈 DMs.",
                               with: "Cursing OK in Taiwanese style (靠北 / 白目 / 機車 / 北七 — but no slurs, no violence threats). Match how friends actually rant in a private LINE group.")
    return q.applyingTransform(s2t, reverse: false) ?? q
}
let sits = [
 ("roommate", "室友每天半夜兩點還開外放打電動，我講了好幾次，他只回「你戴耳塞就好了啊」，還在群組說我很難相處。"),
 ("boss", "慣老闆晚上十一點在 LINE 群組 @我，要我明天早上八點前改好簡報，還說「年輕人多學一點不吃虧」。"),
 ("money", "朋友跟我借了五千塊說下個月還，三個月了都已讀不回，IG 限動還在發出國玩的照片。"),
 ("family", "我媽在家族 LINE 群組把我的體重講給所有親戚聽，還說「女生要有點自覺」。"),
]

var tally: [String: [String: Int]] = [:]
let hansSits = [
 ("roommate-hans", "室友每天凌晨一两点开外放刷短视频，笑得整层楼都听得见。我跟她说了好几次，她说“你戴耳塞不就行了”。"),
 ("credit-hans", "同事把我做的方案署上自己名字交给老板，还在群里@我说谢谢配合。"),
]
let mundane = [("mundane", "同事借了我的订书机一直没还。")]
func one(_ key: String, _ sid: String, _ sys: String, _ usr: String, _ temp: Double, _ g: SystemLanguageModel) async {
    var t = tally[key] ?? [:]; t["n", default: 0] += 1
    let t0 = Date()
    do {
        let s = LanguageModelSession(model: g, instructions: sys)
        let r = try await s.respond(to: usr, options: GenerationOptions(temperature: temp, maximumResponseTokens: 600))
        let parsed = EchoesParser.parse(r.content, scene: .classic)
        t[parsed == nil ? "parseFail" : "parseOK", default: 0] += 1
        let sc = script(r.content)
        if !sc.hasPrefix("simpOnly=0") { t["anySimplified", default: 0] += 1 }
        print("\n[\(key) \(sid)] OK \(Int(Date().timeIntervalSince(t0)*1000))ms parse=\(parsed == nil ? "FAIL->curated" : "ok(\(parsed!.count))") \(sc)\n\(r.content)")
    } catch {
        t["throw", default: 0] += 1
        print("\n[\(key) \(sid)] THROW \(Int(Date().timeIntervalSince(t0)*1000))ms \(String(describing: error).prefix(120)) -> curated")
    }
    tally[key] = t
}
let cn = Locale(identifier: "zh_CN")
let perm = SystemLanguageModel(useCase: .general, guardrails: .permissiveContentTransformations)
// A: what a zh-Hans payer gets today (production prompt, default guardrails, Simplified input)
for tone in [EchoTone.casual, .feral] { for (sid, text) in hansSits + mundane {
    await one("A-prod-default-zhHans/\(tone.rawValue)", sid,
      EchoesPromptBuilder.systemPrompt(tone: tone, voiceCount: .two, personas: personas, locale: cn, scene: .classic),
      EchoesPromptBuilder.userPrompt(situation: text, scene: .classic), tone == .feral ? 0.95 : 0.85, .default) } }
// B: production prompt + permissive guardrails, Taiwan input
for tone in [EchoTone.casual, .feral] { for (sid, text) in sits {
    await one("B-prod-permissive-TWinput/\(tone.rawValue)", sid,
      EchoesPromptBuilder.systemPrompt(tone: tone, voiceCount: .two, personas: personas, locale: tw, scene: .classic),
      EchoesPromptBuilder.userPrompt(situation: text, scene: .classic), tone == .feral ? 0.95 : 0.85, perm) } }
// C: zh-Hant-adapted prompt + permissive guardrails
for tone in [EchoTone.casual, .feral] { for (sid, text) in sits.prefix(2) {
    let sys = hantVariant(EchoesPromptBuilder.systemPrompt(tone: tone, voiceCount: .two, personas: personas, locale: tw, scene: .classic), feral: tone == .feral)
    let u0 = EchoesPromptBuilder.userPrompt(situation: text, scene: .classic)
    await one("C-hant-permissive/\(tone.rawValue)", sid, sys, u0.applyingTransform(s2t, reverse: false) ?? u0, tone == .feral ? 0.95 : 0.85, perm) } }
print("\nTALLY")
for (k, v) in tally.sorted(by: { $0.key < $1.key }) { print(k, v.sorted(by: { $0.key < $1.key }).map { "\($0.key)=\($0.value)" }.joined(separator: " ")) }
