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
    /// Count of strong/profane words. The EXPECTATION flips by intensity:
    /// vent/feral want ≥1 (catharsis), sendable wants exactly 0 — a sendable
    /// reply with profanity in it is not sendable. Populated for every
    /// intensity as of the 0.2 sendable eval; previously vent/feral only, and
    /// the computation is unchanged for those, so old runs stay comparable.
    var ventStrongWordCount: Int
    /// mode:"roast" returns N numbered variants in one payload; the client
    /// splits them. 1 for the vent path (single draft).
    var variantsParsed: Int = 1
    /// Count of SIMPLIFIED-only characters found in zh-Hant output (0 for
    /// every other locale). Non-zero means script bleed — the model answered a
    /// Traditional request in Simplified, which reads as broken to a zh-Hant
    /// user even though every other check passes.
    var simplifiedBleed: Int = 0
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

        // Strong-word density. Counted for ALL intensities now: vent/feral
        // want it high, sendable wants it at zero.
        var strongCount = 0
        do {
            if isZh {
                let zhStrong = isHant
                    ? ["他媽的", "他媽", "老子", "特麼", "服了", "裝什麼裝",
                       "煩死了", "尼瑪", "傻逼", "操", "幹", "媽的"]
                    : ["他妈的", "他妈", "老子", "特么", "服了", "装什么装",
                       "烦死了", "尼玛", "傻逼", "操", "卧槽", "妈的"]
                for w in zhStrong {
                    strongCount += (w == "操" || w == "干" || w == "幹")
                        ? countProfaneCoarseVerb(w, in: text)
                        : text.components(separatedBy: w).count - 1
                }
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
                           ventStrongWordCount: strongCount,
                           variantsParsed: Self.countVariants(text),
                           simplifiedBleed: isHant ? Self.countSimplifiedBleed(text) : 0)
    }

    /// Single-character coarse verbs (操 / 干) are profane ONLY in specific
    /// constructions. In ordinary use they are extremely common and neutral.
    ///
    /// This matches the PROFANE constructions explicitly rather than trying to
    /// exclude benign ones, because the benign set is unbounded and defeats
    /// adjacency rules: 操心 can be split by an infix (少操这份闲心), and 干
    /// appears mid-idiom (一干二净). Both slipped past a denylist on 2026-09-03
    /// and produced false sendable-bar failures.
    ///
    /// Profane: the verb followed by a person-object (操你 / 干他 / 操蛋), or
    /// standing alone as an exclamation bounded by punctuation.
    static func countProfaneCoarseVerb(_ w: String, in text: String) -> Int {
        let objects = "你您他她它我们妈娘丫蛋逼"
        let patterns = [
            "\(w)[\(objects)]",
            // Standalone exclamation: not adjacent to any other Han character.
            "(?<![\\u4e00-\\u9fa5])\(w)(?![\\u4e00-\\u9fa5])"
        ]
        var n = 0
        for pat in patterns {
            guard let re = try? NSRegularExpression(pattern: pat) else { continue }
            n += re.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
        }
        return n
    }

    /// Characters that exist ONLY in Simplified Chinese. Finding any of these
    /// in zh-Hant output means the model produced the wrong script.
    ///
    /// `checkLanguage` cannot catch this — it only asks "is this Han?", and
    /// Simplified text passes that trivially. The file previously deferred
    /// simplified/traditional bleed to "per-scenario manual rating", which
    /// meant it was not actually being measured. It is the single biggest
    /// zh-Hant risk, so it is measured here now.
    ///
    /// Deliberately EXCLUDES characters that are valid in both scripts with
    /// different meanings — 里 (a unit; 裡 is "inside") and 后 (empress; 後 is
    /// "after") both appear legitimately in Traditional text and would be
    /// false positives.
    static let simplifiedOnly: Set<Character> = Set(
        "们说时这个会学电车门问关实认应发无与从众优传伤体让过还进边远连运达选适该详语请论谁讲谢识证议记计讨许设访词试话谈调变组织经给结统绝续维线练级约红纸细终编华亲义习书买卖东长马鸟鱼龙点热爱样现单双头难题类显图团园国圆声处备复够势医卫压厂厅历县参"
    )

    static func countSimplifiedBleed(_ text: String) -> Int {
        text.reduce(0) { $0 + (simplifiedOnly.contains($1) ? 1 : 0) }
    }

    /// Mirrors the client's numbered-variant split ("1. …\n\n2. …").
    /// A sendable response that does not parse into the requested number of
    /// variants is a contract failure, not a style opinion.
    static func countVariants(_ text: String) -> Int {
        let re = try? NSRegularExpression(pattern: "(?m)^\\s*\\d+[.、)]\\s+")
        let n = re?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)) ?? 0
        return max(1, n)
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
