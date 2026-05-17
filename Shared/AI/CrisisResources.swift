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
/// Last reviewed 2026-05-17.
enum CrisisResources {

    /// The always-present international directory (routes by the user's
    /// country). Shown as the primary call-to-action in the view.
    static let directoryURL = URL(string: "https://findahelpline.com")!

    static func regionalResources(for locale: Locale) -> [CrisisResource] {
        let lang = locale.language.languageCode?.identifier ?? "en"
        let script = locale.language.script?.identifier
        let region = locale.region?.identifier

        switch lang {
        case "zh":
            if script == "Hant" || region == "HK" || region == "TW" || region == "MO" {
                return [
                    CrisisResource(id: "hk-sbhk", name: "香港撒瑪利亞防止自殺會",
                                   detail: "2389 2222", url: URL(string: "tel:23892222")),
                    CrisisResource(id: "hk-sw", name: "香港社會福利署熱線",
                                   detail: "2343 2255", url: URL(string: "tel:23432255")),
                    CrisisResource(id: "tw-1925", name: "台灣・安心專線",
                                   detail: "1925", url: URL(string: "tel:1925")),
                    CrisisResource(id: "tw-1995", name: "台灣・生命線",
                                   detail: "1995", url: URL(string: "tel:1995"))
                ]
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
}
