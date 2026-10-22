import Foundation

/// Deterministic check for threat phrasing in a finished "make it sendable"
/// rewrite, run before the default-guardrail screen in
/// `RoastEngine.rewriteAsSendableDetailed`.
///
/// Why it exists: the rewrite runs under `permissiveContentTransformations`
/// (see `FMGuardrails`), and the default-guardrail echo screen that follows it
/// caught only 4 of 7 threat sentences on macOS 27.0.1 (2026-10-22,
/// scratchpad `churn/fmperm/after/screen_run.txt`). It let these three
/// through, and the strict denylist (`ForbiddenTerms.json`) has no term for
/// any of them:
///   "If you do that again, you'll regret it. I know where you live."
///   「今晚我會拿球棒在你車旁邊等你，看你還敢不敢。」
///   「今夜バットを持ってあなたの車の横で待っています。」
///
/// Why here and not in `ForbiddenTerms.json`: that list also gates user INPUT,
/// so "my ex texted me 'I know where you live'" would be refused before the
/// user could vent about being threatened. This screen only reads text the
/// app is about to offer as a message to send.
///
/// A hit fails toward the labelled curated example, never toward an error, so
/// a false positive costs one rewrite and a miss is still behind the prompt's
/// "leave any threat out" rule and the guardrail screen. Each pattern is a
/// whole threat-shaped phrase, not a bare word: 拿刀 alone is inside 「你拿刀
/// 切完菜都不洗」, a real complaint about dishes, so the Chinese weapon and
/// damage patterns need the speaker (我) in front. Every CJK pattern carries
/// both scripts.
enum RewriteThreatScreen {

    static func containsThreat(_ text: String) -> Bool {
        let t = text.lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
        return patterns.contains { t.range(of: $0, options: .regularExpression) != nil }
    }

    /// Matched against lower-cased text.
    static let patterns: [String] = [
        // English
        #"\bi know where you (live|work|sleep|park)\b"#,
        #"\b(with|holding|bring|bringing|grab|grabbing) (a|my) (baseball )?(bat|knife|gun|crowbar|hammer|machete)\b"#,
        #"\b(smash|slash|key|torch|burn|wreck|trash) your (car|windshield|windows?|tires|tyres|house|place|door)\b"#,
        #"\b(break|smash) your (face|legs?|arms?|teeth|neck|fingers|hands?|nose)\b"#,
        #"\byou('ll| will) regret (it|this)\b"#,
        #"\byou('ll| will) (find out|see) what happens\b"#,
        #"\b(watch your back|sleep with one eye open)\b"#,
        #"\bi('ll| will)? ?(be )?wait(ing)? (for you )?(by|near|outside|at) your (car|house|home|door|place|apartment)\b"#,
        #"\b(i know|i've seen) (where )?your (kids|children|family)\b"#,
        // Chinese (Traditional and Simplified in each pattern)
        #"我知道你(住|家)(在)?(哪|那)"#,
        #"我[^，。！？,.!?]{0,4}(拿|帶|带|提|抄)(著|着|上|起)?(球棒|棒球棍|球棍|刀子|菜刀|刀|棍子|鐵棍|铁棍|鐵管|铁管|槍|枪)"#,
        #"我[^，。！？,.!?]{0,4}(砸爛|砸烂|砸|刮花|燒|烧|毀|毁)(了|掉)?你(的)?(車|车|家|房子|門|门)"#,
        #"你(會|会)(後悔|后悔)(的)?([。！!，,]|$)"#,
        #"(讓|让)你好看"#,
        #"打(斷|断)你的"#,
        #"我[^，。！？,.!?]{0,4}揍你"#,
        #"(走著瞧|走着瞧|等著瞧|等着瞧)"#,
        #"((晚上|夜裡|夜里)走路|走夜路)(小心|注意)"#,
        #"在你(家|車|车)(旁邊|旁边|門口|门口|樓下|楼下|外面)等你"#,
        // Japanese
        #"(家|住所|住んでる(とこ|ところ|場所)|住んでいる(ところ|場所))(を|は|も)?(知って|わかって|分かって)(る|いる|います|んだ)"#,
        #"(バット|金属バット|鉄パイプ|ナイフ|刃物)を?(持って|もって)"#,
        #"(バット|金属バット|鉄パイプ)で"#,
        #"痛い目に(あわせ|遭わせ|合わせ|あわす|遭わす)"#,
        #"(ぶん|ぶっ)(殴|なぐ)"#,
        #"(殴|なぐ)(る|って)(ぞ|からな|やる)"#,
        #"(覚えてろ|覚えとけ|おぼえてろ|おぼえとけ)"#,
        #"夜道(には|に|は)?(気をつけ|気を付け)"#,
        #"後悔(させてやる|することになる)"#,
    ]
}
