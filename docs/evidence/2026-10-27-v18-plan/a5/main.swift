import Foundation

// A5 gate: lens 1's on-device probe (40 Savage + 12 Sharp-Pro calls, same
// situations and styles as harness/audit/probe/main.swift), but through the
// PRODUCTION RoastEngine.generateDetailed (3 versions, A3's refusal retry and
// screens included), so it measures what the user sees. One JSON line per call.

struct Rec: Encodable {
    let part, locale, style, intensity, scenario, provenance: String
    let texts: [String]
    let ms: Int
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

@MainActor func run(_ part: String, _ loc: String, _ sid: String, _ intensity: Intensity, _ scenario: String, _ text: String) async {
    guard let style = StyleCatalog.shared.style(id: sid) else { return }
    let t0 = Date()
    var provenance = "threw", texts: [String] = []
    do {
        let out = try await RoastEngine.shared.generateDetailed(
            situation: text, style: style, locale: Locale(identifier: loc), variantCount: 3, intensity: intensity)
        provenance = "\(out.provenance)"; texts = out.texts
    } catch { texts = ["\(error)"] }
    let rec = Rec(part: part, locale: loc, style: sid, intensity: "\(intensity)", scenario: scenario,
                  provenance: provenance, texts: texts, ms: Int(Date().timeIntervalSince(t0) * 1000))
    print(String(data: try! JSONEncoder().encode(rec), encoding: .utf8)!)
    fflush(stdout)
}

@main struct Main {
    static func main() async {
        FileHandle.standardError.write("onDeviceAvailable: \(RoastEngine.isOnDeviceModelAvailable)\n".data(using: .utf8)!)
        let which = CommandLine.arguments.dropFirst().first ?? "all"
        let proStyles = ["savage_no_filter", "taiwanese_drama", "corporate_passive_violence", "cold_violence"]
        if which == "all" || which == "savage" {
            for (loc, sits) in [("zh_TW", zhTW), ("en_US", enUS)] {
                for (sid, text) in sits { for st in proStyles { await run("savage", loc, st, .savage, sid, text) } }
            }
            for (loc, sits) in [("ja_JP", jaJP), ("zh_CN", zhCN)] {
                for (sid, text) in sits { for st in ["savage_no_filter", "taiwanese_drama"] { await run("savage", loc, st, .savage, sid, text) } }
            }
        }
        if which == "all" || which == "sharp" {
            for (sid, text) in zhTW { for st in ["taiwanese_drama", "argument_killshot"] { await run("sharp_pro", "zh_TW", st, .sharp, sid, text) } }
            for (sid, text) in enUS.prefix(2) { for st in ["taiwanese_drama", "argument_killshot"] { await run("sharp_pro", "en_US", st, .sharp, sid, text) } }
        }
    }
}
