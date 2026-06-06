import Foundation
import os.log

/// Loads the bundled persona catalog JSON for the current locale and
/// hands the engine the right slice. Catalog files live under
/// `Shared/Resources/echoes-personas-<locale>.json`. v1 ships zh-Hans
/// only; the lookup falls back to zh-Hans for other locales until the
/// locale-additive en / zh-Hant / ja catalogs land.
///
/// Two slices per file:
///   - `personas`         : the classic 1–2 voice pool (shuffled per call).
///   - `roommatePersonas` : the FIXED 3-voice 虚拟舍友群 trio (护短 / 毒舌 /
///                          清醒), returned in stable order — NEVER shuffled,
///                          because the roommate prompt + parser bind A/B/C
///                          to specific roles and the bridge must come from
///                          清醒 (C).
///
/// All persona content is static + version-controlled — there is NO
/// learning of which persona the user prefers, and no CloudKit sync of
/// any persona-selection state. Privacy posture from v2 plan §5.
enum EchoesPersonaCatalog {
    private static let logger = Logger(subsystem: "yyh.roastmate.app", category: "EchoesPersonaCatalog")

    private struct PersonaFile: Decodable {
        let version: Int
        let locale: String
        let personas: [EchoSpec]
        let roommatePersonas: [EchoSpec]?
    }

    /// Scene-aware persona selection. Classic returns a fresh shuffle
    /// capped at `voiceCount`; roommate returns the fixed trio in stable
    /// order (`voiceCount` is always `.three` there).
    static func selectPersonas(
        locale: Locale,
        voiceCount: EchoVoiceCount,
        scene: EchoScene = .classic
    ) -> [EchoSpec] {
        if scene == .roommateGroup {
            return roommateTrio(for: locale)
        }
        let all = loadCatalog(for: locale)
        guard !all.isEmpty else {
            logger.error("Persona catalog empty for locale \(locale.identifier, privacy: .public). Using hardcoded fallback.")
            return Self.hardcodedFallback(voiceCount: voiceCount)
        }
        let pool = all.shuffled()
        let needed = min(voiceCount.rawValue, pool.count)
        return Array(pool.prefix(needed))
    }

    /// The fixed 3-voice roommate trio in STABLE order (护短 / 毒舌 / 清醒
    /// → indices A/B/C). Never shuffled.
    static func roommateTrio(for locale: Locale) -> [EchoSpec] {
        let loaded = loadFile(for: locale)?.roommatePersonas ?? []
        guard loaded.count >= 3 else {
            logger.error("Roommate persona trio missing/short for \(locale.identifier, privacy: .public). Using hardcoded trio.")
            return Self.hardcodedRoommateTrio()
        }
        return Array(loaded.prefix(3))
    }

    /// Direct catalog access for tests / debug (classic pool).
    static func loadCatalog(for locale: Locale) -> [EchoSpec] {
        loadFile(for: locale)?.personas ?? []
    }

    private static func loadFile(for locale: Locale) -> PersonaFile? {
        let candidates = candidateBundleNames(for: locale)
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let parsed = try? JSONDecoder().decode(PersonaFile.self, from: data) {
                return parsed
            }
        }
        return nil
    }

    private static func candidateBundleNames(for locale: Locale) -> [String] {
        // Order: exact tag, language code, then v1 ship locale.
        let id = locale.identifier
        let lang = locale.language.languageCode?.identifier
        var out: [String] = []
        // Special-case the zh script tags so en-XX / ja don't accidentally
        // fall through to zh-Hans on a hopeful-match.
        if id.lowercased().contains("hans") || id == "zh-Hans" {
            out.append("echoes-personas-zh-Hans")
        } else if id.lowercased().contains("hant") || id == "zh-Hant" {
            out.append("echoes-personas-zh-Hant")
        } else if lang == "ja" {
            out.append("echoes-personas-ja")
        } else if lang == "en" {
            out.append("echoes-personas-en")
        }
        // Final fallback — v1 always ships zh-Hans, so it always exists.
        if !out.contains("echoes-personas-zh-Hans") {
            out.append("echoes-personas-zh-Hans")
        }
        return out
    }

    /// Last-resort static personas if the bundled JSON is missing (classic).
    /// Same shape as the JSON so the rest of the engine can't tell the
    /// difference. Kept minimal so v1 ships SOMETHING even in a build where
    /// the JSON didn't get copied to the bundle.
    private static func hardcodedFallback(voiceCount: EchoVoiceCount) -> [EchoSpec] {
        let all: [EchoSpec] = [
            EchoSpec(
                id: "fallback-a",
                handle: "回声·甲",
                archetype: "毒舌共情型",
                colorHex: "#FF9500",
                promptFragment: "你是「回声·甲」，毒舌但站对方那一边。说话像微信群里那个最会替朋友出气的损友——一两句就把对方的情绪接住，然后帮 ta 把那口气骂出来。不超过 45 个字。"
            ),
            EchoSpec(
                id: "fallback-b",
                handle: "回声·乙",
                archetype: "理性兜底型",
                colorHex: "#64D2FF",
                promptFragment: "你是「回声·乙」，理性但同样站对方一边。说话克制、句子短。最后一段帮朋友把怒气落地到下一步具体动作上。不超过 45 个字。"
            )
        ]
        return Array(all.prefix(voiceCount.rawValue))
    }

    /// Last-resort static roommate trio if the JSON `roommatePersonas` is
    /// missing — keeps the 3-voice scene shippable even in a build where
    /// the catalog didn't copy. Same shape + stable 护短/毒舌/清醒 order.
    private static func hardcodedRoommateTrio() -> [EchoSpec] {
        [
            EchoSpec(id: "roommate-defender", handle: "护短室友", archetype: "护短型", colorHex: "#FF9F0A",
                     promptFragment: "你是「护短室友」，第一时间无条件站用户这边，不质疑、不讲道理。一句话先把委屈接住。不超过 30 个字。不要承诺关系、不要煽动报复。"),
            EchoSpec(id: "roommate-savage", handle: "毒舌室友", archetype: "毒舌型", colorHex: "#FF375F",
                     promptFragment: "你是「毒舌室友」，火力担当，专挑对方行为的荒谬处开炮、负责笑点。短句有梗。不超过 30 个字。不许人身攻击、歧视词、威胁或拿真名羞辱。"),
            EchoSpec(id: "roommate-clearheaded", handle: "清醒室友", archetype: "清醒型", colorHex: "#64D2FF",
                     promptFragment: "你是「清醒室友」，接住前面的梗后收尾，不灌鸡汤、不当心理咨询师。先把怒气落到「别替他背锅」，最后一句给出 Bridge——把这事变成能发的话。不超过 30 个字。")
        ]
    }
}
