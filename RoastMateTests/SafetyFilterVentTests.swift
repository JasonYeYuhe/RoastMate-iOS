import XCTest
@testable import RoastMate

final class SafetyFilterVentTests: XCTestCase {
    func testVentOutputBlocksExplicitViolenceHardRail() {
        XCTAssertThrowsError(try SafetyFilter.validateVentOutput("I want to shoot you for this."))
        XCTAssertThrowsError(try SafetyFilter.validateVentOutput("这种人真想让他去死。"))
    }

    func testVentOutputAllowsMildProfanity() throws {
        XCTAssertEqual(
            try SafetyFilter.validateVentOutput("This is damn ridiculous."),
            "This is damn ridiculous."
        )
        XCTAssertEqual(
            try SafetyFilter.validateVentOutput("这就是一堆屁话。"),
            "这就是一堆屁话。"
        )
    }

    func testStrictOutputStillBlocksHardDenylist() {
        XCTAssertThrowsError(try SafetyFilter.validateOutput("You should drink bleach."))
    }

    // MARK: - Japanese hard rail (added 2026-10-14)
    //
    // The rail had no Japanese while the Worker's ja Vent prompt demands
    // 強めの言葉. Why these phrases and not 死ね or bare 殺す: the doc comment
    // on `SafetyFilter.japaneseVentHardRail`. Checked against the 56
    // production replies behind the store fixtures (16 ja): none is blocked.

    func testVentOutputBlocksEveryJapaneseHardRailSpelling() {
        for spelling in SafetyFilter.japaneseVentHardRailForTesting().joined() {
            XCTAssertThrowsError(try SafetyFilter.validateVentOutput("あいつ、\(spelling)。"),
                                 "vent hard rail did not block '\(spelling)'")
        }
    }

    func testVentOutputBlocksJapaneseThreatsAndSelfHarmInContext() {
        let lines = [
            "手柄を横取りしやがって、ぶっ殺してやる。",
            "次に俺の成果を盗んだら殺すぞ。",
            "マジでコロシテヤル。",
            "お前なんか、もう自殺しろよ。",   // already blocked by 自殺 before 2026-10-14
            "じさつしろ。"                    // was not: the kana spelling
        ]
        for line in lines {
            XCTAssertThrowsError(try SafetyFilter.validateVentOutput(line), "not blocked: \(line)")
        }
    }

    /// Ordinary Japanese venting, much of it sharing characters with the rail.
    /// A false hit here costs the user their vent: the cloud reply is thrown
    /// away and they get curated text instead.
    func testVentOutputAllowsOrdinaryJapaneseVenting() throws {
        let lines = [
            // The strong words the Worker's ja prompts ask for
            "うるせえ、マジでふざけんな。いい加減にしろ、ありえねえ。",
            "クソが、ばかやろう。",
            // 殺 inside ordinary words and hyperbole
            "仕事に忙殺されて、意見は黙殺された。黙殺するなよ。",
            "怒りを押し殺して笑った。この残業量、殺す気か。",
            "苦情が殺到して、職場が殺伐としてる。",
            "こんなミスしたら上司に殺される。",
            "あいつ殺したいくらいムカつく。",
            // 死 in hyperbole, including the potential form 死ねる / 死ねない
            "忙しすぎて死にそう。死ぬほどムカつく。",
            "恥ずかしくて死ねる。この案件が終わるまで死ねない。",
            // ころす inside このころすごく; 刺す idioms
            "このころすごく疲れてる。",
            "あいつには釘を刺してやる。"
        ]
        for line in lines {
            XCTAssertEqual(try SafetyFilter.validateVentOutput(line), line, "ordinary venting blocked: \(line)")
        }
    }

    /// 死ね passes on purpose (see `SafetyFilter.japaneseVentHardRail`). If that
    /// decision changes, change it there and here in the same commit.
    func testVentOutputDeliberatelyAllowsShineAsSwearing() throws {
        for line in ["部長、マジで死ね。", "保育園落ちた日本死ね!!!", "死ねばいいのに。"] {
            XCTAssertEqual(try SafetyFilter.validateVentOutput(line), line)
        }
        // The strict list still stops it anywhere it could be sent or shared.
        XCTAssertThrowsError(try SafetyFilter.validateOutput("部長、マジで死ね。"))
    }

    /// Curated text is what a vent user gets when the rail rejects a cloud
    /// reply, and it is returned without passing through the rail. So no
    /// curated line, in any locale, may contain a rail term.
    func testCuratedFallbacksPassTheVentHardRail() {
        let style = StylePreset(
            id: "test", displayKey: "test.name", blurbKey: "test.blurb", icon: "star",
            tier: .free, temperature: 0.8, tags: [], systemPreamble: "Be witty.",
            examples: [.init(situation: "S1", response: "R1")], localesSupported: nil
        )
        for id in ["en", "zh-Hans", "zh-Hant", "ja"] {
            for line in FallbackRoasts.curated(for: style, locale: Locale(identifier: id), count: 99) {
                XCTAssertNoThrow(try SafetyFilter.validateVentOutput(line), "\(id) curated line trips the rail: \(line)")
            }
        }
        for tone in EchoTone.allCases {
            let messages = EchoVoiceCount.allCases.flatMap {
                FallbackRoasts.curatedEchoTranscript(tone: tone, voiceCount: $0, personas: [])
            } + FallbackRoasts.curatedRoommateTranscript(tone: tone, personas: [])
            for message in messages {
                XCTAssertNoThrow(try SafetyFilter.validateVentOutput(message.text),
                                 "curated Echoes line trips the rail: \(message.text)")
            }
        }
    }
}
