import Foundation
import FoundationModels

// Lens-1 audit probe (2026-10-27). Compiles production PromptBuilder.swift, Intensity.swift,
// StylePreset.swift, SafetyFilter.swift and ModelRefusal.swift, and replays exactly what
// RoastEngine.generateDetailed does on an Apple-Intelligence device (default guardrails,
// fresh session per sendable call, keepSession for the Argument Simulator), then applies
// the same post-processing (splitVariants -> strict validateOutput -> prefix(3)).
// Output: one JSON object per call on stdout.

let s2t = StringTransform("Hans-Hant"), t2s = StringTransform("Hant-Hans")
let twOK = Set("台里后干只面着周游系才群托志表了布借")
func simplifiedChars(_ s: String) -> String {
    var out = ""
    for ch in s {
        guard let u = ch.unicodeScalars.first, (0x4E00...0x9FFF).contains(u.value) else { continue }
        let c = String(ch)
        if let a = c.applyingTransform(s2t, reverse: false), a != c, !twOK.contains(ch) { out += c }
    }
    return out
}

let catalogData = try! Data(contentsOf: URL(fileURLWithPath: "/Users/jason/Documents/RoastMate/Shared/Resources/StylePresets.json"))
let catalog = try! JSONDecoder().decode(StylePresetCatalogFile.self, from: catalogData)
func style(_ id: String) -> StylePreset { catalog.styles.first { $0.id == id }! }

struct Rec: Encodable {
    var part: String
    var locale: String
    var style: String
    var intensity: String
    var scenario: String
    var turn: Int
    var status: String          // ok | throw
    var errorType: String
    var errorDesc: String
    var latencyMs: Int
    var raw: String
    var parsedVariants: [String]
    var keptVariants: [String]  // what the user sees (after strict filter, prefix 3)
    var droppedBySafety: Int
    var textRefusals: Int       // kept variants that ModelRefusal flags (not screened in generate path)
    var appShows: String        // model | curated
    var simplifiedChars: String
    var examplesPrimed: Int
    var input: String
}

func emit(_ r: Rec) {
    let enc = JSONEncoder()
    enc.outputFormatting = [.withoutEscapingSlashes]
    let d = try! enc.encode(r)
    print(String(data: d, encoding: .utf8)!)
    fflush(stdout)
}

func langFor(_ loc: String) -> String {
    if loc.hasPrefix("en") { return "en" }
    if loc.hasPrefix("ja") { return "ja" }
    if loc == "zh_CN" || loc.contains("Hans") { return "zh-Hans" }
    return "zh-Hant"
}

/// One sendable generation, as RoastEngine.generateDetailed does it on-device.
func sendable(part: String, loc: String, styleId: String, intensity: Intensity, scenario: String, situation: String) async {
    AppLocalization.currentLang = langFor(loc)
    let locale = Locale(identifier: loc)
    let st = style(styleId)
    let sys = PromptBuilder.systemPrompt(style: st, locale: locale, mode: .roast, intensity: intensity, safeMode: true)
    let usr = PromptBuilder.userPrompt(situation: situation, styleName: st.displayName, variants: 3, mode: .roast, intensity: intensity, priorContext: nil, locale: locale)
    var r = Rec(part: part, locale: loc, style: styleId, intensity: intensity.rawValue, scenario: scenario, turn: 0,
                status: "ok", errorType: "", errorDesc: "", latencyMs: 0, raw: "", parsedVariants: [], keptVariants: [],
                droppedBySafety: 0, textRefusals: 0, appShows: "model", simplifiedChars: "",
                examplesPrimed: PromptBuilder.examplesForPrompt(style: st, locale: locale).count, input: situation)
    let t0 = Date()
    do {
        let s = LanguageModelSession(instructions: sys)
        let resp = try await s.respond(to: usr, options: GenerationOptions(temperature: st.temperature, maximumResponseTokens: 600))
        r.latencyMs = Int(Date().timeIntervalSince(t0) * 1000)
        r.raw = resp.content
        let split = PromptBuilder.splitVariants(resp.content)
        r.parsedVariants = split
        var kept: [String] = []
        for c in split {
            if let safe = try? SafetyFilter.validateOutput(c) { kept.append(safe) } else { r.droppedBySafety += 1 }
        }
        kept = Array(kept.prefix(3))
        r.keptVariants = kept
        r.textRefusals = kept.filter { ModelRefusal.looksLikeRefusal($0) }.count
        r.appShows = kept.isEmpty ? "curated" : "model"
        r.simplifiedChars = loc == "zh_TW" ? simplifiedChars(kept.joined()) : ""
    } catch {
        r.latencyMs = Int(Date().timeIntervalSince(t0) * 1000)
        r.status = "throw"
        r.errorType = String(reflecting: type(of: error))
        r.errorDesc = String(String(describing: error).prefix(200))
        r.appShows = "curated"
    }
    emit(r)
}

/// The Argument Simulator, as ArgumentSimulatorViewModel + RoastEngine do it:
/// one session per (style, locale, argument, sharp), keepSession: true, variantCount 1.
func argument(loc: String, styleId: String, scenario: String, setup: String, replies: [String]) async {
    AppLocalization.currentLang = langFor(loc)
    let locale = Locale(identifier: loc)
    let st = style(styleId)
    let sys = PromptBuilder.systemPrompt(style: st, locale: locale, mode: .argument, intensity: .sharp, safeMode: true)
    let session = LanguageModelSession(instructions: sys)
    var inputs: [String] = []
    inputs.append("""
    I want to rehearse the following argument:

    \(setup)

    Play the OTHER side. Give the first thing the other person would say to me in this argument. Keep it under 80 words. Stay in character. One reply only — no commentary, no quotation marks.
    """)
    for reply in replies {
        inputs.append("""
        The other person (me) just said: "\(reply)"

        Continue playing the OTHER side. Reply to my last line, in character, in the same style. Keep it under 80 words. One reply only — no commentary, no quotation marks.
        """)
    }
    for (turn, input) in inputs.enumerated() {
        let usr = PromptBuilder.userPrompt(situation: input, styleName: st.displayName, variants: 1, mode: .argument, intensity: .sharp, priorContext: nil, locale: locale)
        var r = Rec(part: "argument", locale: loc, style: styleId, intensity: "sharp", scenario: scenario, turn: turn,
                    status: "ok", errorType: "", errorDesc: "", latencyMs: 0, raw: "", parsedVariants: [], keptVariants: [],
                    droppedBySafety: 0, textRefusals: 0, appShows: "model", simplifiedChars: "",
                    examplesPrimed: PromptBuilder.examplesForPrompt(style: st, locale: locale).count,
                    input: turn == 0 ? setup : replies[turn - 1])
        let t0 = Date()
        do {
            let resp = try await session.respond(to: usr, options: GenerationOptions(temperature: st.temperature, maximumResponseTokens: 600))
            r.latencyMs = Int(Date().timeIntervalSince(t0) * 1000)
            r.raw = resp.content
            let split = PromptBuilder.splitVariants(resp.content)
            r.parsedVariants = split
            var kept: [String] = []
            for c in split { if let safe = try? SafetyFilter.validateOutput(c) { kept.append(safe) } else { r.droppedBySafety += 1 } }
            kept = Array(kept.prefix(1))
            r.keptVariants = kept
            r.textRefusals = kept.filter { ModelRefusal.looksLikeRefusal($0) }.count
            r.appShows = kept.isEmpty ? "curated" : "model"
            r.simplifiedChars = loc == "zh_TW" ? simplifiedChars(kept.joined()) : ""
        } catch {
            r.latencyMs = Int(Date().timeIntervalSince(t0) * 1000)
            r.status = "throw"
            r.errorType = String(reflecting: type(of: error))
            r.errorDesc = String(String(describing: error).prefix(200))
            r.appShows = "curated"
        }
        emit(r)
    }
}

let zhTW: [(String, String)] = [
    ("credit", "我做的專案,主管在整個團隊面前說成是他的功勞。"),
    ("line_boss", "慣老闆半夜十一點在LINE群組@我,要我明天早上八點前改好簡報,還說『年輕人多學一點不吃虧』。"),
    ("dishes", "室友的碗可以放好幾天,還說我『太計較』。"),
    ("loan", "朋友借了我五千塊說下個月還,已經半年了,每次問都說最近手頭緊,結果IG天天在吃大餐。"),
]
let enUS: [(String, String)] = [
    ("credit", "My manager presented my project as his own work in front of the whole team."),
    ("line_boss", "My boss pinged me at 11pm on Slack to redo the deck by 8am and said 'young people should learn more'."),
    ("dishes", "My roommate leaves dishes in the sink for days and says I'm 'too uptight'."),
    ("loan", "A friend borrowed $200 saying he'd pay me back next month. It's been six months, he says he's broke, but posts fancy dinners on Instagram every day."),
]
let jaJP: [(String, String)] = [
    ("credit", "私が作った企画を、上司がチーム全員の前で自分の手柄みたいに発表した。"),
    ("dishes", "ルームメイトが洗い物を何日も放置して、注意したら「細かすぎ」って言われた。"),
]
let zhCN: [(String, String)] = [
    ("credit", "我做的项目,领导在全组面前说成是他的功劳。"),
    ("dishes", "室友的碗能放好几天,还说我『太计较』。"),
]

let model = SystemLanguageModel.default
FileHandle.standardError.write("availability: \(model.availability)\n".data(using: .utf8)!)
let which = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "all"

let proStyles = ["savage_no_filter", "taiwanese_drama", "corporate_passive_violence", "cold_violence"]

if which == "all" || which == "savage" {
    for (loc, sits) in [("zh_TW", zhTW), ("en_US", enUS)] {
        for (sid, text) in sits {
            for st in proStyles {
                await sendable(part: "savage", loc: loc, styleId: st, intensity: .savage, scenario: sid, situation: text)
            }
        }
    }
    for (loc, sits) in [("ja_JP", jaJP), ("zh_CN", zhCN)] {
        for (sid, text) in sits {
            for st in ["savage_no_filter", "taiwanese_drama"] {
                await sendable(part: "savage", loc: loc, styleId: st, intensity: .savage, scenario: sid, situation: text)
            }
        }
    }
}
if which == "all" || which == "sharp" {
    for (sid, text) in zhTW {
        for st in ["taiwanese_drama", "argument_killshot"] {
            await sendable(part: "sharp_pro", loc: "zh_TW", styleId: st, intensity: .sharp, scenario: sid, situation: text)
        }
    }
    for (sid, text) in enUS.prefix(2) {
        for st in ["taiwanese_drama", "argument_killshot"] {
            await sendable(part: "sharp_pro", loc: "en_US", styleId: st, intensity: .sharp, scenario: sid, situation: text)
        }
    }
}
if which == "all" || which == "argument" {
    let zhSetups: [(String, String, [String])] = [
        ("raise", "我要跟主管談加薪。我已經兩年沒調薪,工作量多了一倍,他每次都說公司今年很困難。",
         ["我理解公司困難,但我的工作量多了一倍,這是事實。", "那請你告訴我,具體要達到什麼標準才能調薪?"]),
        ("trash", "室友一直不倒垃圾,我想跟她說清楚以後要輪流。她每次都說她很忙。",
         ["大家都很忙,但垃圾是我們兩個人製造的。", "那我們排個表,一人一週,可以嗎?"]),
        ("mom", "我媽一直催我結婚,說我都三十歲了還不急,我想跟她講清楚這是我的人生。",
         ["媽,我知道你擔心我,但結婚不是比賽。", "我會自己決定什麼時候結婚,請你尊重我。"]),
    ]
    let enSetups: [(String, String, [String])] = [
        ("raise", "I want to ask my manager for a raise. No raise in two years, my workload doubled, and he always says budgets are tight this year.",
         ["I understand budgets are tight, but my workload has doubled. That's a fact.", "Then tell me exactly what I need to hit to get a raise."]),
        ("trash", "My roommate never takes out the trash. I want to agree on a rotation. She always says she's too busy.",
         ["We're both busy, but we both make the trash.", "So let's do a schedule, one week each. Deal?"]),
        ("mom", "My mom keeps pressuring me to get married because I'm 30. I want to tell her it's my life.",
         ["Mom, I know you worry, but marriage isn't a race.", "I'll decide when I get married. Please respect that."]),
    ]
    for (loc, setups) in [("zh_TW", zhSetups), ("en_US", enSetups)] {
        for (sid, setup, replies) in setups {
            for st in ["cold_violence", "savage_no_filter"] {
                await argument(loc: loc, styleId: st, scenario: sid, setup: setup, replies: replies)
            }
        }
    }
}
FileHandle.standardError.write("done\n".data(using: .utf8)!)
