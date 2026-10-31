import Foundation

// A4 gate: the PRODUCTION `RoastEngine.opponentTurn` (Shared/, real
// AppleFMBackend) on lens 1's 36-turn set (zh_TW + en, same setups and user
// replies as harness/audit/probe/main.swift), plus a ja set for the refusal
// gate. Each turn feeds the real transcript so far, as the view model does.
// Output: one JSON line per turn on stdout.

struct Rec: Encodable {
    let locale, style, scenario: String
    let turn: Int
    let result: String   // line | notGenerated | unavailable | threw
    let text: String
    let ms: Int
}

let zh: [(String, String, [String])] = [
    ("raise", "我要跟主管談加薪。我已經兩年沒調薪,工作量多了一倍,他每次都說公司今年很困難。",
     ["我理解公司困難,但我的工作量多了一倍,這是事實。", "那請你告訴我,具體要達到什麼標準才能調薪?"]),
    ("trash", "室友一直不倒垃圾,我想跟她說清楚以後要輪流。她每次都說她很忙。",
     ["大家都很忙,但垃圾是我們兩個人製造的。", "那我們排個表,一人一週,可以嗎?"]),
    ("mom", "我媽一直催我結婚,說我都三十歲了還不急,我想跟她講清楚這是我的人生。",
     ["媽,我知道你擔心我,但結婚不是比賽。", "我會自己決定什麼時候結婚,請你尊重我。"]),
]
let en: [(String, String, [String])] = [
    ("raise", "I want to ask my manager for a raise. No raise in two years, my workload doubled, and he always says budgets are tight this year.",
     ["I understand budgets are tight, but my workload has doubled. That's a fact.", "Then tell me exactly what I need to hit to get a raise."]),
    ("trash", "My roommate never takes out the trash. I want to agree on a rotation. She always says she's too busy.",
     ["We're both busy, but we both make the trash.", "So let's do a schedule, one week each. Deal?"]),
    ("mom", "My mom keeps pressuring me to get married because I'm 30. I want to tell her it's my life.",
     ["Mom, I know you worry, but marriage isn't a race.", "I'll decide when I get married. Please respect that."]),
]
// Not lens 1's: written for this gate (refusals per locale), same three shapes.
let ja: [(String, String, [String])] = [
    ("raise", "上司に昇給を頼みたい。二年間据え置きで仕事量は倍になったのに、毎回「今年は厳しい」と言われる。",
     ["厳しいのは分かりますが、私の仕事量は倍になっています。これは事実です。", "では、昇給には具体的に何を達成すればいいか教えてください。"]),
    ("trash", "ルームメイトが全然ゴミを出さない。当番制にしたい。彼女はいつも忙しいと言う。",
     ["二人とも忙しいけど、ゴミは二人で出してるよね。", "じゃあ週ごとの当番表を作ろう。いい？"]),
    ("mom", "母が三十歳なんだから早く結婚しろとうるさい。私の人生だとはっきり伝えたい。",
     ["お母さん、心配なのは分かるけど、結婚は競争じゃない。", "いつ結婚するかは自分で決める。尊重してほしい。"]),
]

@main struct Main {
    static func main() async {
        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        FileHandle.standardError.write("onDeviceAvailable: \(RoastEngine.isOnDeviceModelAvailable)\n".data(using: .utf8)!)
        let args = CommandLine.arguments.dropFirst()
        let noPersona = args.contains("--no-persona")   // round 1 = the prompt without the persona call
        let only = args.first { !$0.hasPrefix("--") }
        for (loc, set) in [("zh_TW", zh), ("en_US", en), ("ja_JP", ja)] where only == nil || only == loc {
            for (scenario, setup, replies) in set {
                let persona = noPersona ? nil : await RoastEngine.shared.opponentPersona(setup: setup)
                FileHandle.standardError.write("[\(loc) \(scenario)] persona: \(persona ?? "nil")\n".data(using: .utf8)!)
                for sid in ["cold_violence", "savage_no_filter"] {
                    guard let style = StyleCatalog.shared.style(id: sid) else { continue }
                    var transcript: [ArgumentLine] = []
                    for turn in 0...replies.count {
                        if turn > 0 { transcript.append(ArgumentLine(speaker: .user, text: replies[turn - 1])) }
                        let t0 = Date()
                        var result = "threw", text = ""
                        do {
                            switch try await RoastEngine.shared.opponentTurn(
                                setup: setup, transcript: transcript, style: style, locale: Locale(identifier: loc),
                                persona: persona) {
                            case .line(let s): result = "line"; text = s
                                transcript.append(ArgumentLine(speaker: .opponent, text: s))
                            case .notGenerated: result = "notGenerated"
                            case .unavailable: result = "unavailable"
                            }
                        } catch { text = "\(error)" }
                        let rec = Rec(locale: loc, style: sid, scenario: scenario, turn: turn, result: result,
                                      text: text, ms: Int(Date().timeIntervalSince(t0) * 1000))
                        print(String(data: try! enc.encode(rec), encoding: .utf8)!)
                        fflush(stdout)
                    }
                }
            }
        }
    }
}
