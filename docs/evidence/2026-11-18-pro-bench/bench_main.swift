import Foundation
import NaturalLanguage

// 1.9.0 Pro-quality bench (plan DEV_PLAN_PRO_QUALITY_2026-11 §2, Q0).
// Compiled together with a `Shared/` tree — the v1.8.0-ios29 tag's (control) or
// the branch HEAD's (candidate) — into a minimal .app (build.sh), so the
// PRODUCTION RoastEngine runs with the real AppleFMBackend, StylePresets and
// ForbiddenTerms. Nothing here re-implements an engine step; it only calls the
// engine and records what a user would see. One JSON line per call on stdout.
//
// Modes:
//   sendable <inputs.json> [--locale L] [--shard i/n] [--styles a,b] [--set key]
//   sim      [--locale L] [--setups file.json]
//   rewrite  <inputs.json> [--runs N]
//   judge    <set.json>          (RewriteThreatScreen, then the shipped judge prompt)
//   safety   <safety_set.json> [--runs N]

let args = Array(CommandLine.arguments.dropFirst())
func opt(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}
func emit(_ obj: [String: Any]) {
    let data = try! JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys, .withoutEscapingSlashes])
    print(String(data: data, encoding: .utf8)!)
    fflush(stdout)
}
func ms(since t0: Date) -> Int { Int(Date().timeIntervalSince(t0) * 1000) }
func loadJSON(_ path: String) -> [String: Any] {
    try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path))) as! [String: Any]
}
func log(_ s: String) { FileHandle.standardError.write((s + "\n").data(using: .utf8)!) }

/// English tokens with NLTagger lexical class + lemma (score.py's "no verb" and
/// "grounded" rules). NLTagger has no lexical classes for zh/ja (measured
/// 11-18: every token comes back OtherWord), so those get no tags.
func enTags(_ text: String) -> [[String]] {
    let t = NLTagger(tagSchemes: [.lexicalClass, .lemma])
    t.string = text
    t.setLanguage(.english, range: text.startIndex..<text.endIndex)
    var out: [[String]] = []
    t.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass,
                    options: [.omitWhitespace, .omitPunctuation]) { tag, r in
        let lemma = t.tag(at: r.lowerBound, unit: .word, scheme: .lemma).0?.rawValue ?? String(text[r]).lowercased()
        out.append([String(text[r]), tag?.rawValue ?? "", lemma.lowercased()])
        return true
    }
    return out
}
func tagsIfEnglish(_ locale: String, _ texts: [String]) -> [[[String]]] {
    locale.hasPrefix("en") ? texts.map(enTags) : []
}

@MainActor var catalog: StyleCatalog { StyleCatalog.shared }

func header(_ mode: String) {
    let os = ProcessInfo.processInfo.operatingSystemVersionString
    emit(["header": mode, "os": os, "onDevice": RoastEngine.isOnDeviceModelAvailable,
          "started": ISO8601DateFormatter().string(from: Date())])
}

// MARK: - sendable (Q1)

@MainActor func runSendable() async {
    let inputs = loadJSON(args[1])
    let setKey = opt("--set") ?? "sendable"
    let sets = inputs[setKey] as! [String: [[String: String]]]
    let styleGroups = inputs["styles"] as! [String: [String]]
    var styles = styleGroups["free"]! + styleGroups["pro"]!
    if let only = opt("--styles") { styles = only.split(separator: ",").map(String.init) }
    let intensities = (inputs["intensities"] as! [String]).compactMap(Intensity.init(rawValue:))
    var shard = (0, 1)
    if let s = opt("--shard") {
        let p = s.split(separator: "/").compactMap { Int($0) }
        shard = (p[0], p[1])
    }
    let locales = opt("--locale").map { [$0] } ?? ["zh_TW", "en_US", "ja_JP"]
    header("sendable")
    var index = 0
    for loc in locales {
        guard let sits = sets[loc] else { continue }
        for sit in sits {
            for intensity in intensities {
                for sid in styles {
                    defer { index += 1 }
                    guard index % shard.1 == shard.0 else { continue }
                    guard let style = catalog.style(id: sid) else { log("no style \(sid)"); continue }
                    let text = sit["text"]!
                    let t0 = Date()
                    var provenance = "threw", texts: [String] = [], errText = ""
                    do {
                        let out = try await RoastEngine.shared.generateDetailed(
                            situation: text, style: style, locale: Locale(identifier: loc),
                            variantCount: 3, intensity: intensity)
                        provenance = "\(out.provenance)"; texts = out.texts
                    } catch { errText = "\(error)" }
                    emit(["mode": "sendable", "set": setKey, "locale": loc, "sit": sit["id"]!, "situation": text,
                          "intensity": intensity.rawValue, "style": sid, "provenance": provenance,
                          "texts": texts, "error": errText, "ms": ms(since: t0),
                          "tags": tagsIfEnglish(loc, texts), "sit_tags": loc.hasPrefix("en") ? enTags(text) : []])
                }
            }
        }
    }
}

// MARK: - sim (Q4) — A4's set, verbatim

let simZH: [(String, String, [String])] = [
    ("raise", "我要跟主管談加薪。我已經兩年沒調薪,工作量多了一倍,他每次都說公司今年很困難。",
     ["我理解公司困難,但我的工作量多了一倍,這是事實。", "那請你告訴我,具體要達到什麼標準才能調薪?"]),
    ("trash", "室友一直不倒垃圾,我想跟她說清楚以後要輪流。她每次都說她很忙。",
     ["大家都很忙,但垃圾是我們兩個人製造的。", "那我們排個表,一人一週,可以嗎?"]),
    ("mom", "我媽一直催我結婚,說我都三十歲了還不急,我想跟她講清楚這是我的人生。",
     ["媽,我知道你擔心我,但結婚不是比賽。", "我會自己決定什麼時候結婚,請你尊重我。"]),
]
let simEN: [(String, String, [String])] = [
    ("raise", "I want to ask my manager for a raise. No raise in two years, my workload doubled, and he always says budgets are tight this year.",
     ["I understand budgets are tight, but my workload has doubled. That's a fact.", "Then tell me exactly what I need to hit to get a raise."]),
    ("trash", "My roommate never takes out the trash. I want to agree on a rotation. She always says she's too busy.",
     ["We're both busy, but we both make the trash.", "So let's do a schedule, one week each. Deal?"]),
    ("mom", "My mom keeps pressuring me to get married because I'm 30. I want to tell her it's my life.",
     ["Mom, I know you worry, but marriage isn't a race.", "I'll decide when I get married. Please respect that."]),
]
let simJA: [(String, String, [String])] = [
    ("raise", "上司に昇給を頼みたい。二年間据え置きで仕事量は倍になったのに、毎回「今年は厳しい」と言われる。",
     ["厳しいのは分かりますが、私の仕事量は倍になっています。これは事実です。", "では、昇給には具体的に何を達成すればいいか教えてください。"]),
    ("trash", "ルームメイトが全然ゴミを出さない。当番制にしたい。彼女はいつも忙しいと言う。",
     ["二人とも忙しいけど、ゴミは二人で出してるよね。", "じゃあ週ごとの当番表を作ろう。いい？"]),
    ("mom", "母が三十歳なんだから早く結婚しろとうるさい。私の人生だとはっきり伝えたい。",
     ["お母さん、心配なのは分かるけど、結婚は競争じゃない。", "いつ結婚するかは自分で決める。尊重してほしい。"]),
]

@MainActor func runSim() async {
    var sets: [(String, [(String, String, [String])])] = [("zh_TW", simZH), ("en_US", simEN), ("ja_JP", simJA)]
    if let file = opt("--setups") {
        // Unseen setups: {"zh_TW": [{"id","setup","replies":[..]}], ...}
        let j = loadJSON(file)
        sets = ["zh_TW", "en_US", "ja_JP"].compactMap { loc in
            guard let arr = j[loc] as? [[String: Any]] else { return nil }
            return (loc, arr.map { ($0["id"] as! String, $0["setup"] as! String, $0["replies"] as! [String]) })
        }
    }
    let only = opt("--locale")
    header("sim")
    for (loc, set) in sets where only == nil || only == loc {
        for (scenario, setup, replies) in set {
            let persona = await RoastEngine.shared.opponentPersona(setup: setup)
            for sid in ["cold_violence", "savage_no_filter"] {
                guard let style = catalog.style(id: sid) else { continue }
                var transcript: [ArgumentLine] = []
                for turn in 0...replies.count {
                    if turn > 0 { transcript.append(ArgumentLine(speaker: .user, text: replies[turn - 1])) }
                    let t0 = Date()
                    var result = "threw", text = ""
                    do {
                        switch try await RoastEngine.shared.opponentTurn(
                            setup: setup, transcript: transcript, style: style,
                            locale: Locale(identifier: loc), persona: persona) {
                        case .line(let s): result = "line"; text = s
                            transcript.append(ArgumentLine(speaker: .opponent, text: s))
                        case .notGenerated: result = "notGenerated"
                        case .unavailable: result = "unavailable"
                        }
                    } catch { text = "\(error)" }
                    emit(["mode": "sim", "locale": loc, "scenario": scenario, "setup": setup, "style": sid,
                          "turn": turn, "user_last": turn > 0 ? replies[turn - 1] : "",
                          "persona": persona ?? "", "result": result, "text": text, "ms": ms(since: t0)])
                }
            }
        }
    }
}

// MARK: - rewrite (Q5 owner + curated rate)

@MainActor func runRewrite() async {
    let inputs = loadJSON(args[1])
    let items = (inputs["rewrite"] as! [String: Any])["items"] as! [[String: Any]]
    let runs = Int(opt("--runs") ?? "1") ?? 1
    let style = catalog.style(id: "high_eq")!
    header("rewrite")
    for item in items {
        // r01/r02 are the owner gate's 11-08 cases: at least 5 runs each.
        let n = (item["id"] as! String == "r01" || item["id"] as! String == "r02") ? max(runs, 5) : runs
        for run in 0..<n {
            let t0 = Date()
            var provenance = "threw", text = ""
            do {
                let r = try await RoastEngine.shared.rewriteAsSendableDetailed(
                    ventDraft: item["draft"] as! String, originalSituation: item["situation"] as! String,
                    style: style, locale: Locale(identifier: item["locale"] as! String))
                provenance = "\(r.provenance)"; text = r.text
            } catch { text = "\(error)" }
            emit(["mode": "rewrite", "id": item["id"]!, "locale": item["locale"]!, "run": run,
                  "provenance": provenance, "text": text, "wrong_owner": item["wrong_owner"] ?? [],
                  "ms": ms(since: t0)])
        }
    }
}

// MARK: - judge (Q5): RewriteThreatScreen, then the shipped one-word judge

@MainActor func runJudge() async {
    let set = loadJSON(args[1])
    let messages = set["messages"] as! [[String: Any]]
    guard let fm = FMBackendFactory.make(), fm.isAvailable else { log("no FM"); return }
    // Harness-only: JUDGE_PROMPT_FILE swaps the judge text for a tuning run.
    // Gate runs never set it, so they use the build's RoastEngine.threatJudgeInstructions.
    let judgeText = ProcessInfo.processInfo.environment["JUDGE_PROMPT_FILE"]
        .map { try! String(contentsOfFile: $0, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) }
        ?? RoastEngine.threatJudgeInstructions
    header("judge")
    for m in messages {
        let text = m["text"] as! String
        let phrase = RewriteThreatScreen.containsThreat(text)
        var verdict = ""
        let t0 = Date()
        if !phrase {
            do {
                verdict = try await fm.respondFresh(
                    instructions: judgeText, to: text,
                    temperature: 0, maxTokens: 4, guardrails: .permissiveContentTransformations)
            } catch { verdict = "ERR" }
        }
        let blocked = phrase || !RoastEngine.threatJudgeSaysSafe(verdict)
        emit(["mode": "judge", "id": m["id"]!, "label": m["label"]!, "locale": m["locale"] ?? "?",
              "veiled": m["veiled"] ?? false, "phrase": phrase, "verdict": verdict, "blocked": blocked,
              "text": text, "ms": ms(since: t0)])
    }
}

// MARK: - safety (§2 "safety e2e"): the safety set's situations and simulator
// cases through the production engine, as the app calls it.

@MainActor func runSafety() async {
    let set = loadJSON(args[1])
    let runs = Int(opt("--runs") ?? "2") ?? 2
    let style = catalog.style(id: "savage_no_filter")!
    header("safety")
    for run in 0..<runs {
        for s in set["situations"] as! [[String: Any]] {
            let text = s["text"] as! String
            let loc = s["locale"] as! String
            let intensity = Intensity(rawValue: s["intensity"] as! String) ?? .savage
            let crisis = SafetyFilter.crisisSignal(text)
            var provenance = "", texts: [String] = [], errText = ""
            let t0 = Date()
            if crisis == .hard {
                provenance = "crisis_hard"   // the app shows crisis resources and generates nothing
            } else {
                do {
                    let out = try await RoastEngine.shared.generateDetailed(
                        situation: text, style: style, locale: Locale(identifier: loc),
                        variantCount: 3, intensity: intensity)
                    provenance = "\(out.provenance)"; texts = out.texts
                } catch { provenance = "rejected"; errText = "\(error)" }
            }
            emit(["mode": "safety", "run": run, "id": s["id"]!, "category": s["category"]!, "locale": loc,
                  "expect": s["expect"]!, "crisis": "\(crisis)", "provenance": provenance, "texts": texts,
                  "error": errText, "ms": ms(since: t0)])
        }
        for c in set["simulator"] as? [[String: Any]] ?? [] {
            let loc = c["locale"] as! String
            guard let st = catalog.style(id: c["style"] as! String) else { continue }
            let setup = c["setup"] as! String
            let persona = await RoastEngine.shared.opponentPersona(setup: setup)
            var transcript: [ArgumentLine] = []
            let replies = c["replies"] as! [String]
            for turn in 0...replies.count {
                if turn > 0 { transcript.append(ArgumentLine(speaker: .user, text: replies[turn - 1])) }
                var result = "threw", text = ""
                do {
                    switch try await RoastEngine.shared.opponentTurn(
                        setup: setup, transcript: transcript, style: st, locale: Locale(identifier: loc), persona: persona) {
                    case .line(let s): result = "line"; text = s
                        transcript.append(ArgumentLine(speaker: .opponent, text: s))
                    case .notGenerated: result = "notGenerated"
                    case .unavailable: result = "unavailable"
                    }
                } catch { result = "rejected"; text = "\(error)" }
                emit(["mode": "safety_sim", "run": run, "id": c["id"]!, "locale": loc, "turn": turn,
                      "expect": c["expect"] ?? [], "result": result, "text": text])
            }
        }
    }
}

@main struct Bench {
    @MainActor static func main() async {
        log("onDeviceAvailable: \(RoastEngine.isOnDeviceModelAvailable)")
        switch args.first ?? "" {
        case "sendable": await runSendable()
        case "sim": await runSim()
        case "rewrite": await runRewrite()
        case "judge": await runJudge()
        case "safety": await runSafety()
        default: log("usage: bench sendable|sim|rewrite|judge|safety …")
        }
    }
}
