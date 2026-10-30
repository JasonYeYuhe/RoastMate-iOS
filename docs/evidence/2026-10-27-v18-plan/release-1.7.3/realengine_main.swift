import Foundation

// Calls the PRODUCTION RoastEngine (Shared/, real AppleFMBackend) on this Mac.
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
    }
}
