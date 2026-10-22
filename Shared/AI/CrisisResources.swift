import Foundation

/// One crisis support line. `name` is a proper-noun organisation name
/// (intentionally NOT localized); `detail` is the dial string; `url` is a
/// `tel:` (or web) link.
struct CrisisResource: Identifiable, Sendable, Equatable {
    let id: String
    let name: String
    let detail: String
    let url: URL?

    init(id: String, name: String, detail: String, url: URL?) {
        self.id = id
        self.name = name
        self.detail = detail
        self.url = url
    }
}

/// Region/language-aware crisis lines for the Chinese-language-first
/// (HK / TW / SG / JP / diaspora) audience. The `CrisisSupportView`
/// always *also* shows a prominent international-directory link and an
/// emergency-services reminder, so this screen stays useful no matter
/// where a diaspora user actually is — these curated numbers are a
/// convenience layer, not the only path.
///
/// NOTE: helpline numbers can change — verify these periodically.
/// Last reviewed 2026-10-22 (Taiwan lines); HK / CN / JP / default lines
/// last reviewed 2026-05-17.
///
/// Taiwan sources (2026-10-22):
/// - 1925 安心專線 — Ministry of Health and Welfare, 24 h, free, the only
///   number since 2019-12-20: https://mohw.gov.tw/cp-16-50587-1.html
/// - 1995 生命線 (各縣市生命線, 全國通用) and 1980 張老師 — National Health
///   Insurance Administration (MOHW) "諮詢服務資源一覽表", 2025-06-05:
///   https://www.nhi.gov.tw/ch/dl-80349-bf7f66d1a35241cd9e3b8038f197aea5-1.pdf
///   Operators: https://www.life1995.org.tw/ and https://www.1980.org.tw/
///   ("1980輔導專線"). Only 1925 is stated as 24 h in these sources ("24
///   小時服務專線"); neither the list nor the operator pages state hours for
///   1995 or 1980 (re-checked 2026-10-22). Order: the government 24 h line,
///   then 生命線, then 張老師.
enum CrisisResources {

    /// The always-present international directory (routes by the user's
    /// country). Shown as the primary call-to-action in the view.
    static let directoryURL = URL(string: "https://findahelpline.com")!

    /// - Parameter deviceRegion: the device's region, used when `locale`
    ///   carries none. The in-app language picker produces a bare
    ///   `zh-Hant` locale, which would otherwise hide that the user is in
    ///   Taiwan. Injectable for tests.
    static func regionalResources(
        for locale: Locale,
        deviceRegion: String? = Locale.current.region?.identifier
    ) -> [CrisisResource] {
        let lang = locale.language.languageCode?.identifier ?? "en"
        let script = locale.language.script?.identifier
        let region = locale.region?.identifier ?? deviceRegion

        // Taiwan lines for anyone in Taiwan, whatever the app language. Until
        // 1.7.1 a Taiwan phone saw two Hong Kong numbers first, and their
        // 8-digit local `tel:` strings do not reach Hong Kong from Taiwan.
        if region == "TW" {
            return taiwanLines
        }

        switch lang {
        case "zh":
            if script == "Hant" || region == "HK" || region == "MO" {
                return hongKongLines + taiwanLines
            }
            // Simplified / mainland-language diaspora: the directory + local
            // emergency services (rendered by the view) are the main path;
            // include one long-standing Chinese-language line as backup.
            return [
                CrisisResource(id: "cn-bjcrisis", name: "北京心理危机研究与干预中心",
                               detail: "010-82951332", url: URL(string: "tel:01082951332")),
                CrisisResource(id: "cn-hope24", name: "希望24热线",
                               detail: "400-161-9995", url: URL(string: "tel:4001619995"))
            ]
        case "ja":
            return [
                CrisisResource(id: "jp-yorisoi", name: "よりそいホットライン",
                               detail: "0120-279-338", url: URL(string: "tel:0120279338")),
                CrisisResource(id: "jp-inochi", name: "日本いのちの電話",
                               detail: "0570-783-556", url: URL(string: "tel:0570783556"))
            ]
        default:
            return [
                CrisisResource(id: "us-988", name: "988 Suicide & Crisis Lifeline (US)",
                               detail: "988", url: URL(string: "tel:988")),
                CrisisResource(id: "sg-sos", name: "Samaritans of Singapore (SOS)",
                               detail: "1767", url: URL(string: "tel:1767")),
                CrisisResource(id: "intl-text", name: "Crisis Text Line",
                               detail: "text HOME to 741741", url: nil)
            ]
        }
    }

    /// The MOHW 24 h line first. Sources in the type's doc comment.
    private static let taiwanLines: [CrisisResource] = [
        CrisisResource(id: "tw-1925", name: "台灣・安心專線",
                       detail: "1925", url: URL(string: "tel:1925")),
        CrisisResource(id: "tw-1995", name: "台灣・生命線",
                       detail: "1995", url: URL(string: "tel:1995")),
        CrisisResource(id: "tw-1980", name: "台灣・張老師",
                       detail: "1980", url: URL(string: "tel:1980"))
    ]

    private static let hongKongLines: [CrisisResource] = [
        CrisisResource(id: "hk-sbhk", name: "香港撒瑪利亞防止自殺會",
                       detail: "2389 2222", url: URL(string: "tel:23892222")),
        CrisisResource(id: "hk-sw", name: "香港社會福利署熱線",
                       detail: "2343 2255", url: URL(string: "tel:23432255"))
    ]
}
