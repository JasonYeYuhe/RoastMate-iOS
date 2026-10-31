import Foundation

/// B5 (1.8.0): one labelled 痛罵 preview for free users. After a free user's
/// first Vent the Worker actually wrote, the app offers once per iCloud
/// account the same situation as a Feral draft in a Pro voice. It is a
/// preview exception to "credits never unlock a capability", not credits: no
/// credit is spent, nothing is saved as a session, and it is never offered
/// again (`UserSettings.proPreviewOfferedAt`, CloudKit-synced).
///
/// The Worker accepts Feral with a Pro `styleId` on the free lane and applies
/// the style's voice there (`cloud-worker/src/index.js` has no lane check on
/// intensity; `styleVoice` checks only the style), so this needs no Worker
/// change. About $0.00013 per preview.
enum ProPreview {

    /// Offer only after a Vent the cloud wrote (only cloud drafts carry the
    /// Pro voice), only to free users, and only once.
    static func shouldOffer(isPro: Bool, intensity: Intensity, servedByCloud: Bool,
                            offeredAt: Date?) -> Bool {
        !isPro && intensity == .vent && servedByCloud && offeredAt == nil
    }

    /// 台劇腔 for Chinese (the Worker's hant voice is the Taiwan one), 冷處理
    /// elsewhere, where a Taiwanese-drama monologue reads as a novelty.
    static func styleId(for locale: Locale) -> String {
        switch AppLanguage.contentBucket(for: locale) {
        case .traditionalChinese, .simplifiedChinese: return "taiwanese_drama"
        default: return "cold_violence"
        }
    }
}
