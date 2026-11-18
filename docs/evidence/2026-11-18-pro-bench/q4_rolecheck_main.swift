import Foundation

// Q4 experiment: can the on-device model tell a turn that argues the USER's side?
// Reads the 11-19 blind labels (labels/q4_dev1) and the two sim runs, asks a
// one-word check per turn, prints agreement with the read. Not a gate tool.
// Usage: rolecheck <bench dir> <prompt.txt>

@main struct RoleCheck {
    @MainActor static func main() async {
        let dir = CommandLine.arguments[1]
        let instructions = try! String(contentsOfFile: CommandLine.arguments[2], encoding: .utf8)
        func json(_ p: String) -> Any { try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: p))) }
        let key = json("\(dir)/labels/q4_dev1/key.json") as! [String: [String: Any]]
        let labels = json("\(dir)/labels/q4_dev1/labels.json") as! [String: String]
        var turns: [String: [String: Any]] = [:]
        for run in ["control180_sim", "cand1_sim"] {
            let lines = try! String(contentsOfFile: "\(dir)/runs/\(run).jsonl", encoding: .utf8).split(separator: "\n")
            for l in lines {
                let r = try! JSONSerialization.jsonObject(with: Data(l.utf8)) as! [String: Any]
                guard r["header"] == nil else { continue }
                turns["\(run)|\(r["locale"]!)|\(r["scenario"]!)|\(r["style"]!)|\(r["turn"]!)"] = r
            }
        }
        guard let fm = FMBackendFactory.make() else { return }
        var tp = 0, fn = 0, fp = 0, tn = 0
        for (id, k) in key.sorted(by: { $0.key < $1.key }) {
            guard let lab = labels[id], lab != "NG" else { continue }
            let r = turns["\(k["run"]!)|\(k["locale"]!)|\(k["scenario"]!)|\(k["style"]!)|\(k["turn"]!)"]!
            let input = "Setup the user wrote: \(r["setup"]!)\nWho the other person is: \(r["persona"]!)\nThe user just said: \(r["user_last"] as? String ?? "")\nThe other person's line: \(r["text"]!)"
            let verdict = (try? await fm.respondFresh(instructions: instructions, to: input, temperature: 0, maxTokens: 4,
                                                      guardrails: .permissiveContentTransformations)) ?? "ERR"
            let says = verdict.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)).uppercased()
            let bad = lab != "OPP"
            let flagged = says.hasPrefix("USER")
            switch (bad, flagged) {
            case (true, true): tp += 1
            case (true, false): fn += 1
            case (false, true): fp += 1
            case (false, false): tn += 1
            }
            print("\(lab)\t\(says)\t\(k["locale"]!) \(k["scenario"]!)\t\((r["text"] as! String).prefix(60))")
        }
        print("USER/AMB caught \(tp)/\(tp + fn); OPP wrongly flagged \(fp)/\(fp + tn)")
    }
}
