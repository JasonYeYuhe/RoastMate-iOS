import Foundation
import os.log

/// Loads the bundled persona catalog JSON for the current locale and
/// hands the engine the right slice. Catalog files live under
/// `Shared/Resources/echoes-personas-<locale>.json`. v1 ships zh-Hans
/// only; the lookup falls back to zh-Hans for other locales until v0.2
/// adds en / zh-Hant / ja catalogs.
///
/// All persona content is static + version-controlled — there is NO
/// learning of which persona the user prefers, and no CloudKit sync
/// of any persona-selection state. Privacy posture from v2 plan §5.
enum EchoesPersonaCatalog {
    private static let logger = Logger(subsystem: "yyh.roastmate.app", category: "EchoesPersonaCatalog")

    private struct PersonaFile: Decodable {
        let version: Int
        let locale: String
        let personas: [EchoSpec]
    }

    /// Returns a fresh per-call shuffle of the catalog, capped at
    /// `voiceCount`. Calling twice in a row may yield different ordering;
    /// that is intentional — same setup should not always pick the
    /// same Echo first.
    static func selectPersonas(
        locale: Locale,
        voiceCount: EchoVoiceCount
    ) -> [EchoSpec] {
        let all = loadCatalog(for: locale)
        guard !all.isEmpty else {
            logger.error("Persona catalog empty for locale \(locale.identifier, privacy: .public). Using hardcoded fallback.")
            return Self.hardcodedFallback(voiceCount: voiceCount)
        }
        let pool = all.shuffled()
        let needed = min(voiceCount.rawValue, pool.count)
        return Array(pool.prefix(needed))
    }

    /// Direct catalog access for tests / debug.
    static func loadCatalog(for locale: Locale) -> [EchoSpec] {
        let candidates = candidateBundleNames(for: locale)
        for name in candidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let parsed = try? JSONDecoder().decode(PersonaFile.self, from: data) {
                return parsed.personas
            }
        }
        return []
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

    /// Last-resort static personas if the bundled JSON is missing. Same
    /// shape as the JSON file so the rest of the engine can't tell the
    /// difference. Kept minimal so v1 ships SOMETHING even in a build
    /// where the JSON didn't get copied to the bundle.
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
}
