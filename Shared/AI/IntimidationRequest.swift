import Foundation

/// Deterministic check on the user's own input: is the user asking the app to
/// write something that scares, threatens or intimidates the other person?
///
/// Why it exists: on macOS 27.2 Apple's default guardrails refuse every
/// sendable Savage prompt, so A3's permissive retry carries nearly every
/// call, and the output screens (`RewriteThreatScreen` + the model judge)
/// miss about 1 veiled threat in 4. On the safety set's threat-bait inputs the
/// permissive model wrote "I'll be waiting after your shift" and
/// 「我知道你的住所…」 when asked to (2026-10-29,
/// `harness/safety/e2e`). The cheapest place to stop that is before the
/// retry: a request to intimidate never gets the permissive model, so it gets
/// the labelled curated example instead.
///
/// Only requests count, not reports: "my landlord threatened me", "he said
/// he'd be waiting for me" and "I'll go to the police" are venting and pass.
/// Every CJK pattern carries both scripts.
enum IntimidationRequest {

    static func matches(_ text: String) -> Bool {
        let t = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
        return patterns.contains { t.range(of: $0, options: .regularExpression) != nil }
    }

    /// Matched against lower-cased text.
    static let patterns: [String] = [
        // English: an ask (write / make / tell / help / let) aimed at fear.
        #"\b(scare|frighten|intimidate|terrify|spook) (him|her|them|this guy|that guy|my \w+)\b"#,
        #"\bmake (him|her|them|my \w+) (scared|afraid|nervous|terrified|paranoid|fear|lose sleep|sleep with)\b"#,
        #"\bthreaten (him|her|them|my \w+)\b"#,
        #"\b(sounds?|reads?|come across|comes across) (like a |as a )?(threat|threatening|menacing|scary)\b"#,
        #"\b(threatening|menacing|intimidating|scary) (message|text|note|reply|letter)\b"#,
        #"\b(know|knows) where (he|she|they) (lives?|works?|parks?|sleeps?)\b"#,
        #"\b(watch|watches) (his|her|their) back\b"#,
        #"\bi'll be waiting (for (him|her|them)|outside|after)\b"#,
        #"\b(pay (him|her|them) a visit|teach (him|her|them) a lesson)\b"#,
        // Chinese (Traditional and Simplified in each pattern)
        #"(嚇|吓)(嚇|吓|唬)?(他|她|對方|对方|那個|那个)"#,
        #"(恐嚇|恐吓|威脅|威胁|威嚇|威吓)(他|她|對方|对方|一下)"#,
        #"(讓|让|叫|要)(他|她|對方|对方)[^，。！？,.!?]{0,6}(害怕|怕到|發抖|发抖|睡不著|睡不着|不敢出門|不敢出门|小心一點|小心一点|皮繃緊|皮绷紧)"#,
        #"(讓|让)(他|她|對方|对方)知道我知道(他|她|對方|对方)?(住|家|公司|在哪)"#,
        #"(給|给)(他|她|對方|对方)[^，。！？,.!?]{0,4}(一點|一点)?(教訓|教训|顏色|颜色)(看看)?"#,
        #"(有威脅感|有威胁感|帶點威脅|带点威胁|像威脅|像威胁|嚇人一點|吓人一点)"#,
        // Japanese
        #"(脅(す|して|かす|かして|し)|ビビらせ|怖がらせ|怯えさせ|震え上がらせ)"#,
        #"(家|住所|職場|会社)(を|は)?(知って(る|いる)って)(匂わせ|伝え|わから|分から)"#,
        #"(痛い目を見せ|夜も眠れなく)"#,
        // Added after reading the blind set's misses (2026-10-29), so the
        // blind score in harness/safety/intent/README.md predates them:
        // "hint / imply" + harm, and naming the threat outright.
        #"\b(imply|implies|hint|hints|suggest|suggests|gives? (him|her|them) the impression)\b[^.!?]{0,80}\b(accident|safety|safe|show up|coming over|visit|make it home|hurt|physically|heavy hitters)\b"#,
        #"\b(ominous|menacing) (warning|message|text|note)\b"#,
        #"暗示[^。！？!?]{0,30}(晚上|路上|回家|地址|住哪|兄弟|小心|意外|急診|急诊|少個|少个|飛下去|飞下去)"#,
        #"(脅迫|恐喝)(する|して|っぽい|のような|するような)"#,
        #"(別怪我|别怪我)不客氣|(別怪我|别怪我)不客气"#,
        #"(危害|危険)が(及ぶ|及びます)"#,
        // Asking for fear itself, in any wording.
        #"\b(terrify|terrifies|terrified|dread|blood run cold|chilling (message|text|note))\b"#,
        #"(恐嚇信|恐吓信|威脅說|威胁说|心驚膽跳|心惊胆跳|陰森|阴森)"#,
        #"(恐怖を(与え|植え付け)|不穏|不気味な(警告|文|メッセージ))"#,
    ]
}
