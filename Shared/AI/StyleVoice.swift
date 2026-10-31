import Foundation

/// Which styles the Worker gives their own voice in 痛罵 / 發洩 (cloud
/// private drafts). Mirrors `cloud-worker/src/style_voice.js` STYLE_VOICES:
/// Pro styles only (owner decision), and 京片兒 only in Simplified Chinese.
/// On-device private drafts ignore the style (`PromptBuilder.systemPrompt`),
/// so this is a cloud-only fact.
///
/// The paywall says "the Pro style you pick" sets the voice of 痛罵/發洩 on
/// every device (A2, 1.8.0); the per-style hint under the style row uses this
/// so it never claims a voice the Worker doesn't have.
enum StyleVoice {
    /// Styles whose Worker voice exists only for some content buckets.
    static let voiceBuckets: [String: Set<AppLanguage>] = [
        "bjing_taunt": [.simplifiedChinese],
    ]

    static func hasCloudVoice(_ style: StylePreset, locale: Locale) -> Bool {
        guard style.tier == .pro else { return false }
        guard let only = voiceBuckets[style.id] else { return true }
        return only.contains(AppLanguage.contentBucket(for: locale))
    }
}
