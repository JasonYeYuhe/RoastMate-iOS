import Foundation

/// Deterministic check on the user's own input: is the user asking the app to
/// attack the other person's identity (race, nationality, religion,
/// orientation, gender, disability) or to use slurs?
///
/// Why it exists: same reason as `IntimidationRequest`. With the permissive
/// retry carrying nearly every call on macOS 27.2, the model refused the
/// zh-Hant and en slur-bait inputs itself, but answered the ja one
/// (「中国人の同僚…差別用語で思いっきり罵って」) with 「笑えるほど浅黒い」, a
/// skin-colour jab no denylist term covers (2026-10-29, `harness/safety/e2e`).
/// A request like that never gets the permissive model.
///
/// Only requests count: "my landlord said racist things to me" and "help me
/// tell HR he called me a slur" are venting and pass.
enum SlurRequest {

    static func matches(_ text: String) -> Bool {
        let t = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
        return patterns.contains { t.range(of: $0, options: .regularExpression) != nil }
    }

    /// Matched against lower-cased text.
    static let patterns: [String] = [
        // English: an ask aimed at identity, or naming slurs as the tool.
        #"\b(use|using|throw|throwing|include|add|with|give me|hit (him|her|them) with|call (him|her|them)) [^.!?]{0,40}\b(slurs?|racist|racial|ethnic|homophobic|transphobic|ableist|sexist) ?(words?|names?|terms?|insults?|jokes?|slurs?)?\b"#,
        #"\b(every|worst|best|nastiest) [^.!?]{0,20}\bslurs?\b"#,
        #"\b(insult|mock|make fun of|attack|roast|trash|rip on) (his|her|their) (race|ethnicity|religion|accent|country|nationality|skin( color| colour)?|disability|sexuality|gender|culture|people)\b"#,
        #"\b(mock|make fun of|insult|roast|attack) (him|her|them) for being (gay|lesbian|trans|disabled|black|asian|mexican|muslim|jewish|indian|chinese|a woman|fat|autistic)\b"#,
        #"\b(stereotypes?) (about|of) (his|her|their)\b"#,
        // Chinese (Traditional and Simplified in each pattern)
        #"(用|拿|給他|给他|給她|给她|罵他|骂他|罵她|骂她)[^，。！？,.!?]{0,15}(歧視|歧视)(的)?(字眼|用語|用语|詞|词|字|話|话|稱呼|称呼)"#,
        #"(種族|种族|地域|性別|性别)(歧視|歧视)(字眼|用語|用语|的詞|的词|的字)"#,
        #"(嘲笑|取笑|笑|罵|骂|酸|攻擊|攻击)(他|她|對方|对方)(的)?[^，。！？,.!?]{0,6}(口音|膚色|肤色|國籍|国籍|宗教|性向|種族|种族|殘障|残障|身障|出身)"#,
        // Japanese
        #"差別(用語|語|的な(言葉|表現|ネタ|呼び方))"#,
        #"(国籍|人種|出身|宗教|障害|性的指向|訛り|肌の色)を(バカに|馬鹿に|ネタに|いじ|笑|からか|けな)"#,
    ]
}
