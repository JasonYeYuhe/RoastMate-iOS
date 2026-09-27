import XCTest
@testable import RoastMate

/// Guards the Traditional-Chinese routing for the locale identifiers real
/// devices actually send.
///
/// Measured 2026-09-26 on an iOS 18.5 simulator set up as a real phone:
/// language zh-Hant-TW → `Locale.current.identifier == "zh_TW"`, and
/// zh-Hant-HK → `"zh_HK"`. There is NO "Hant" in either identifier — iOS drops
/// the script subtag when it is the region's default. Every
/// `identifier.contains("Hant")` check therefore told Taiwan and Hong Kong
/// users to reply in Simplified. These cases use exactly those identifiers.
final class TraditionalLocaleTests: XCTestCase {
    private let traditional = ["zh_TW", "zh_HK", "zh_MO", "zh-Hant", "zh-Hant_TW"]
    private let simplified = ["zh_CN", "zh_SG", "zh-Hans", "zh-Hans_HK"]

    private let style = StylePreset(
        id: "test",
        displayKey: "test.name",
        blurbKey: "test.blurb",
        icon: "star",
        tier: .free,
        temperature: 0.8,
        tags: [],
        systemPreamble: "Be witty.",
        examples: [.init(situation: "S1", response: "R1")],
        localesSupported: nil
    )

    func testUserLanguageReminderFollowsTheRealDeviceIdentifier() {
        for id in traditional {
            XCTAssertEqual(PromptBuilder.userLanguageReminder(for: Locale(identifier: id)),
                           "請以繁體中文回覆。", "\(id) must be told to reply in Traditional")
        }
        for id in simplified {
            XCTAssertEqual(PromptBuilder.userLanguageReminder(for: Locale(identifier: id)),
                           "请用简体中文回复。", "\(id) must be told to reply in Simplified")
        }
    }

    /// The system prompt carries two more directives (the language hint and the
    /// enforcement line). A prompt that says 繁體 in one place and 简体 in
    /// another is the failure mode, so assert on both presence and absence.
    func testSystemPromptNeverMixesScriptsForTaiwanAndHongKong() {
        for id in ["zh_TW", "zh_HK", "zh_TW@calendar=roc"] {
            for intensity: Intensity in [.calm, .sharp, .vent, .feral] {
                let p = PromptBuilder.systemPrompt(style: style,
                                                   locale: Locale(identifier: id),
                                                   intensity: intensity)
                XCTAssertTrue(p.contains("繁體中文"), "\(id)/\(intensity): no Traditional directive")
                XCTAssertFalse(p.contains("简体中文"), "\(id)/\(intensity): Simplified directive leaked in")
                // The vent calibration's GOOD line is the sentence the model
                // copies most closely; a Simplified one here bleeds into output.
                // (网吧 appears only in the Simplified calibration. The shared
                // multilingual rule text above it still quotes a Simplified
                // example — measured harmless on the cloud path, 0/16 bleed.)
                XCTAssertFalse(p.contains("网吧"), "\(id)/\(intensity): Simplified calibration example")
            }
        }
        for intensity: Intensity in [.vent, .feral] {
            let tw = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "zh_TW"), intensity: intensity)
            XCTAssertTrue(tw.contains("網咖"), "zh_TW \(intensity) should carry the Traditional calibration")
            let cn = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "zh_CN"), intensity: intensity)
            XCTAssertTrue(cn.contains("网吧"), "zh_CN \(intensity) keeps the Simplified calibration")
        }
        let cn = PromptBuilder.systemPrompt(style: style, locale: Locale(identifier: "zh_CN"))
        XCTAssertTrue(cn.contains("简体中文"))
        XCTAssertFalse(cn.contains("繁體中文"))
    }

    /// The home screen's scenario chips — the first Chinese text a Taiwan
    /// user reads.
    func testScenarioAndSampleTextPickTheTraditionalVariant() throws {
        let json = Data(#"""
        {"id":"t","category":"boss","prompt":{"zh-Hans":"简","zh-Hant":"繁","en":"en"},
         "defaultStyleId":"high_eq","defaultIntensity":"sharp"}
        """#.utf8)
        let scenario = try JSONDecoder().decode(Scenario.self, from: json)
        let sampleJSON = Data(#"""
        {"id":"s","situation":{"zh-Hans":"简","zh-Hant":"繁","en":"en"},
         "styleId":"high_eq","responseLocale":"en","response":"r"}
        """#.utf8)
        let sample = try JSONDecoder().decode(SampleRoast.self, from: sampleJSON)
        for id in traditional {
            XCTAssertEqual(scenario.prompt(for: Locale(identifier: id)), "繁", "scenario \(id)")
            XCTAssertEqual(sample.situation(for: Locale(identifier: id)), "繁", "sample \(id)")
        }
        for id in simplified {
            XCTAssertEqual(scenario.prompt(for: Locale(identifier: id)), "简", "scenario \(id)")
            XCTAssertEqual(sample.situation(for: Locale(identifier: id)), "简", "sample \(id)")
        }
    }
}
