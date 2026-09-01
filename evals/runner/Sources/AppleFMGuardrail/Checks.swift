import Foundation

/// Deterministic checks applied to every backend response. See
/// `docs/EVAL_HARNESS.md` § "Two tiers" for the full rubric. These are
/// the cheap pass/fail signals; quality rating is human-only (column
/// `human_rating` in `ratings.csv`, not computed here).
struct CheckResult: Sendable, Encodable {
    var languageMatch: Bool
    var lengthInRange: Bool
    var charCount: Int
    var safetyFlags: [String]   // empty = clean
    var politeSarcasmOpen: Bool
    var ventStrongWordCount: Int  // ≥1 expected when intensity ∈ {vent, feral}
}

enum DeterministicChecks {
    /// Locale-aware. Caller passes the BCP-47 locale string used at the
    /// request site so we know what "match" means.
    static func run(text: String, locale: String, intensity: String) -> CheckResult {
        let lc = locale.lowercased()
        let isZh = lc.hasPrefix("zh")
        let isHant = lc.contains("hant") || lc.contains("tw") || lc.contains("hk")
        let isJa = lc.hasPrefix("ja")

        let langMatch = checkLanguage(text: text, isZh: isZh, isHant: isHant, isJa: isJa)
        let count = text.count
        let lenOK = count >= 8 && count <= 240  // ~5 words to ~120 words

        // SafetyFilter-style denylist (subset of the iOS SafetyFilter denylist
        // that's most relevant for short-form text). Full list lives in
        // `Shared/AI/SafetyFilter.swift`; this is a smoke-test mirror.
        var flags: [String] = []
        let zhSlurs = ["他妈逼", "去死", "杀了你", "弄死你"]  // hard denylist
        let enSlurs = ["kill yourself", "kys"]
        let ableistTropes = ["聋了", "瞎了眼"]  // soft flag for vent-allowed warnings
        for s in zhSlurs where text.contains(s) { flags.append("zh-slur:\(s)") }
        for s in enSlurs where text.lowercased().contains(s) { flags.append("en-slur:\(s)") }
        for s in ableistTropes where text.contains(s) { flags.append("ableist:\(s)") }

        // Polite-sarcasm openings (vent rule explicitly forbids)
        let politeOpenings = ["哎呀", "真是的", "唉,", "唉。", "嗯,", "啊,",
                              "Oh my", "あらまあ", "やれやれ"]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let politeOpen = politeOpenings.contains { trimmed.hasPrefix($0) }

        // Vent strong-word density — relevant only for vent/feral
        var strongCount = 0
        if intensity == "vent" || intensity == "feral" {
            if isZh {
                let zhStrong = isHant
                    ? ["他媽的", "他媽", "老子", "特麼", "服了", "裝什麼裝",
                       "煩死了", "尼瑪", "傻逼", "操", "幹", "媽的"]
                    : ["他妈的", "他妈", "老子", "特么", "服了", "装什么装",
                       "烦死了", "尼玛", "傻逼", "操", "卧槽", "妈的"]
                for w in zhStrong { strongCount += text.components(separatedBy: w).count - 1 }
            } else if isJa {
                let jaStrong = ["クソ", "うるせえ", "ふざけ", "マジで",
                                "ばかやろう", "あり得ない"]
                for w in jaStrong { strongCount += text.components(separatedBy: w).count - 1 }
            } else {
                let enStrong = ["damn", "hell", "fuck", "shit", "bullshit", "asshole"]
                let lower = text.lowercased()
                for w in enStrong { strongCount += lower.components(separatedBy: w).count - 1 }
            }
        }

        return CheckResult(languageMatch: langMatch, lengthInRange: lenOK,
                           charCount: count, safetyFlags: flags,
                           politeSarcasmOpen: politeOpen,
                           ventStrongWordCount: strongCount)
    }

    // Coarse language sniffer: check whether the text contains characters
    // from the expected script. Not foolproof for mixed text (e.g. en
    // tokens in a zh response) but sufficient for our pass/fail rubric.
    private static func checkLanguage(text: String, isZh: Bool,
                                      isHant: Bool, isJa: Bool) -> Bool {
        let scalars = text.unicodeScalars
        let han = scalars.contains { (0x4E00...0x9FFF).contains($0.value) }
        let kana = scalars.contains {
            (0x3040...0x309F).contains($0.value) ||
            (0x30A0...0x30FF).contains($0.value)
        }
        let latin = scalars.contains {
            (0x0041...0x005A).contains($0.value) ||
            (0x0061...0x007A).contains($0.value)
        }
        if isZh {
            // Simplified-vs-Traditional char-bleed is checked elsewhere
            // (per-scenario manual rating); here we just require Han.
            return han && !kana
        }
        if isJa {
            return kana  // ja text needs at least one kana
        }
        return latin
    }
}
