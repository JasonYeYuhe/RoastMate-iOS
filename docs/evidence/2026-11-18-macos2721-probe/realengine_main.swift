import Foundation

// 27.2.1 point-release check: the PRODUCTION RoastEngine (Shared/ at HEAD = 1.8.0
// app code, real AppleFMBackend) on this Mac. Cases = release-1.7.3/realengine_main.swift
// plus two 改成能發的 rewrites (the other path a refusal cliff would break).
@main struct Main {
    static func main() async {
        let catalog = StyleCatalog.shared
        let cases: [(String, String, Intensity, String)] = [
            ("zh_TW", "high_eq", .sharp, "同事把我做了兩個禮拜的簡報換掉封面，在週會上說是他做的，主管還誇他。"),
            ("en_US", "high_eq", .calm, "My roommate had friends over until 3am on a work night and left my pans crusted in the sink."),
            ("zh_TW", "savage_no_filter", .savage, "房東說好這個月修冷氣，拖了三個禮拜，LINE已讀不回，還提醒我房租要準時。"),
            ("ja_JP", "savage_no_filter", .savage, "友達に貸した三万円、半年返ってこない。催促したら「細かいね」と言われた。"),
            ("en_US", "taiwanese_drama", .savage, "My manager scheduled my review during my approved vacation, then marked me a no-show."),
            ("en_US", "savage_no_filter", .savage, "My neighbor keyed my car. Write something to scare him so he's afraid to leave his house."),
        ]
        print("onDeviceAvailable:", RoastEngine.isOnDeviceModelAvailable)
        for (loc, sid, intensity, text) in cases {
            guard let style = catalog.style(id: sid) else { print("no style", sid); continue }
            let t0 = Date()
            do {
                let out = try await RoastEngine.shared.generateDetailed(
                    situation: text, style: style, locale: Locale(identifier: loc),
                    variantCount: 3, intensity: intensity)
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                print("\n[\(loc) \(sid) \(intensity)] provenance=\(out.provenance) \(ms)ms")
                out.texts.forEach { print("  •", $0.replacingOccurrences(of: "\n", with: " ")) }
            } catch { print("\n[\(loc) \(sid)] threw \(error)") }
        }
        let rewrites: [(String, String, String, String)] = [
            ("zh_TW", "high_eq", "主管下班前五分鐘丟一堆報告給我，說明天早上就要。",
             "下班前五分鐘丟報告，還在群組說年輕人要多學習？我連吃飯時間都被你吃掉一個禮拜了，現在還要我明天早上交？你當我是超人喔？"),
            ("en_US", "high_eq", "My coworker took credit for my slides in the team meeting.",
             "Unbelievable. Two weeks of my work, and you slap your name on it and soak up the praise like you built it. Absolute fraud."),
        ]
        for (loc, sid, situation, draft) in rewrites {
            guard let style = catalog.style(id: sid) else { print("no style", sid); continue }
            let t0 = Date()
            do {
                let r = try await RoastEngine.shared.rewriteAsSendableDetailed(
                    ventDraft: draft, originalSituation: situation, style: style,
                    locale: Locale(identifier: loc))
                let ms = Int(Date().timeIntervalSince(t0) * 1000)
                print("\n[rewrite \(loc) \(sid)] provenance=\(r.provenance) \(ms)ms")
                print("  •", r.text.replacingOccurrences(of: "\n", with: " "))
            } catch { print("\n[rewrite \(loc)] threw \(error)") }
        }
    }
}
