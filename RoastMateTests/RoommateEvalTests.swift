import XCTest
import Foundation
@testable import RoastMate
#if canImport(FoundationModels)
import FoundationModels
#endif

/// 虚拟舍友群 (roommate group, Echoes vNext) quality gate.
///
/// Two tiers:
///   1. `test_curatedRoommateFallback_satisfiesContract` — SIM-RUNNABLE.
///      Pure structural check that the curated fallback always satisfies the
///      strict roommate parser contract (so a parse failure degrades to a
///      well-formed transcript, never a malformed one).
///   2. `test_roommateGroup_realDeviceParseFallbackRate` — DEVICE-ONLY.
///      Runs the real on-device 3B model over 20 zh-Hans grievances and
///      measures the parse-fallback RATE — the gating unknown for whether
///      the roommate group is good enough to ship. SKIPS on the simulator
///      (no Apple Intelligence → always fallback, which tells you nothing).
///      Run on a physical iPhone with Apple Intelligence ON:
///        xcodebuild test -project RoastMate.xcodeproj -scheme RoastMate \
///          -destination 'platform=iOS,name=<your iPhone>' \
///          -only-testing:RoastMateTests/RoommateEvalTests/test_roommateGroup_realDeviceParseFallbackRate
///      Enable < 15% (already done — the baked default IS true since c37d393) /
///      hard-kill ≥ 35% (set `roommate_group_enabled:false` in the served JSON) (the stricter 8–10-msg contract makes this the real
///      risk vs classic Echoes). See docs/ROOMMATE_REALDEVICE_EVAL.md.
final class RoommateEvalTests: XCTestCase {

    private let zh = Locale(identifier: "zh-Hans")

    // MARK: - Sim-runnable: the fallback always satisfies the strict contract

    func test_curatedRoommateFallback_satisfiesContract() {
        let personas = EchoesPersonaCatalog.roommateTrio(for: zh)
        XCTAssertEqual(personas.count, 3, "Roommate trio must load three personas.")
        for tone in [EchoTone.casual, .feral] {
            let msgs = FallbackRoasts.curatedRoommateTranscript(tone: tone, personas: personas)
            XCTAssertEqual(msgs.count, 8, "Curated roommate transcript is 8 messages.")
            XCTAssertEqual(msgs.first?.role, .validate, "Opens on validate.")
            XCTAssertEqual(msgs.last?.role, .bridge, "Ends on the single bridge.")
            XCTAssertEqual(msgs.filter { $0.role == .bridge }.count, 1, "Exactly one bridge.")
            XCTAssertTrue(msgs.contains { $0.role == .deescalate }, "Has a deescalate (reframe).")
            for idx in 0...2 {
                XCTAssertGreaterThanOrEqual(msgs.filter { $0.echoIndex == idx }.count, 2,
                                            "Each voice (A/B/C) speaks ≥2× — voice \(idx).")
            }
            XCTAssertEqual(msgs.last?.bridgeIntensity, tone.bridgeIntensity,
                           "Bridge carries the tone-derived intensity.")
            // Every line within the 80-char roommate hard cap.
            XCTAssertTrue(msgs.allSatisfy { $0.text.count <= 80 }, "All lines ≤ 80 chars.")
        }
    }

    // MARK: - Device-only: real on-device parse-fallback rate

    func test_roommateGroup_realDeviceParseFallbackRate() async throws {
        #if canImport(FoundationModels)
        // The test target now deploys to iOS 18, but Foundation Models symbols
        // are iOS-26-only — gate them at runtime so this compiles for the
        // lowered target (skips on anything below 26, same as it skips the sim).
        guard #available(iOS 26.0, macOS 26.0, *) else {
            throw XCTSkip("Foundation Models requires iOS 26 / macOS 26.")
        }
        try XCTSkipUnless(
            SystemLanguageModel.default.availability == .available,
            "Foundation Models unavailable (simulator / Apple Intelligence off). " +
            "Run on a physical iPhone with Apple Intelligence ON — the sim only " +
            "ever serves curated fallback, which would read as 100% fallback."
        )
        // Opt-in: the regular suite SKIPS this ~4-minute on-device eval. Run it
        // explicitly with `TEST_RUNNER_ROOMMATE_EVAL=1` (optionally
        // `TEST_RUNNER_ROOMMATE_EVAL_N=6` to sample fewer scenarios while tuning).
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["ROOMMATE_EVAL"] == "1",
                          "Set TEST_RUNNER_ROOMMATE_EVAL=1 to run the on-device roommate parse-fallback eval.")
        let sampleN = Int(env["ROOMMATE_EVAL_N"] ?? "") ?? Self.scenarios.count
        let scenarios = Array(Self.scenarios.prefix(max(1, sampleN)))

        let personas = EchoesPersonaCatalog.roommateTrio(for: zh)
        var fallbacks = 0
        var log: [String] = []

        for (i, sc) in scenarios.enumerated() {
            let prompt = EchoesPromptBuilder.systemPrompt(
                tone: sc.tone, voiceCount: .three, personas: personas, locale: zh, scene: .roommateGroup)
            let user = EchoesPromptBuilder.userPrompt(situation: sc.situation, scene: .roommateGroup)
            let session = LanguageModelSession(instructions: prompt)
            do {
                let resp = try await session.respond(
                    to: user,
                    options: GenerationOptions(temperature: sc.tone == .feral ? 0.95 : 0.85,
                                               maximumResponseTokens: 800))
                if let parsed = EchoesParser.parse(resp.content, scene: .roommateGroup) {
                    log.append("#\(i + 1) [\(sc.tone)] PARSED(\(parsed.count) msgs)\n\(resp.content)\n")
                } else {
                    fallbacks += 1
                    log.append("#\(i + 1) [\(sc.tone)] FALLBACK ✗ (parse)\n\(resp.content)\n")
                }
            } catch {
                // A thrown generation error (notably Apple's FM
                // guardrailViolation) IS a fallback in production — the engine
                // catches it and serves the curated transcript. Count it so the
                // rate reflects what users actually experience.
                fallbacks += 1
                log.append("#\(i + 1) [\(sc.tone)] FALLBACK ✗ (error: \(error))\n")
            }
        }

        let n = scenarios.count
        let rate = Double(fallbacks) / Double(n)
        print("\n===== 虚拟舍友群 PARSE-FALLBACK EVAL =====")
        print(log.joined(separator: "\n"))
        print(String(format: "fallback = %d/%d = %.0f%%   (enable < 15%%  /  kill ≥ 35%%)",
                     fallbacks, n, rate * 100))
        print("=========================================\n")

        XCTAssertLessThan(rate, 0.35,
                          "Roommate parse-fallback \(Int(rate * 100))% ≥ 35% kill threshold — " +
                          "do NOT enable; tune the prompt or drop the feature.")
        #else
        throw XCTSkip("FoundationModels not available in this build configuration.")
        #endif
    }

    // MARK: - Scenarios

    struct Scenario { let tone: EchoTone; let situation: String }

    /// 20 zh-Hans grievances spanning the roommate-group fantasy (relatable
    /// young-adult conflicts). The first 10 mirror the classic Echoes eval
    /// for comparability; the next 10 are roommate-flavoured.
    static let scenarios: [Scenario] = [
        .init(tone: .casual, situation: "室友半夜两点还在外放打游戏，说了三次都当耳旁风，今天又来。"),
        .init(tone: .casual, situation: "同事把我做完的方案直接署上他自己的名字交给老板，一句话都没跟我说。"),
        .init(tone: .casual, situation: "朋友又一次临时放我鸽子，我都到餐厅了他才发消息说来不了。"),
        .init(tone: .casual, situation: "点的外卖洒了一半，客服只肯赔三块钱优惠券，还说是我自己不会拿。"),
        .init(tone: .casual, situation: "妈又开始拿我和别人家孩子比，说我这个年纪还没买房就是没出息。"),
        .init(tone: .feral,  situation: "房东退押金扣东扣西，合同里根本没写的费用也硬塞进来，微信还不回。"),
        .init(tone: .feral,  situation: "组里那个人整个学期啥都没干，汇报的时候全程他在讲，功劳全揽过去。"),
        .init(tone: .feral,  situation: "网店发来的是货不对板的劣质货，要退货反被拉黑，还倒打一耙说我碰瓷。"),
        .init(tone: .feral,  situation: "相亲对象全程低头玩手机，临走还点评我条件也就这样别太挑。"),
        .init(tone: .feral,  situation: "加班到十一点把活赶完，领导第二天当着全组说年轻人就该多奉献。"),
        .init(tone: .casual, situation: "室友每次用完厨房都不收拾，油锅放一礼拜，还说我太计较。"),
        .init(tone: .casual, situation: "借给同学的充电宝两个月没还，问一次他就已读不回一次。"),
        .init(tone: .casual, situation: "群里发了重要通知没人理，结果出了事第一个来甩锅的就是他们。"),
        .init(tone: .casual, situation: "健身房私教一直推销课程，说不要还阴阳我没毅力练不出来。"),
        .init(tone: .casual, situation: "快递放代收点也不通知，丢了反过来怪我没及时去取。"),
        .init(tone: .feral,  situation: "前任借钱时叫得比谁都亲，分手后立刻翻脸说那是我自愿给的。"),
        .init(tone: .feral,  situation: "甲方改了八版需求一分钱不加，验收又说没达到他想要的感觉。"),
        .init(tone: .feral,  situation: "亲戚群里被长辈公开数落工资低，还说读那么多书有什么用。"),
        .init(tone: .feral,  situation: "合租的人偷用我的东西被抓包，不道歉还反咬一口说我小气。"),
        .init(tone: .feral,  situation: "公司画饼半年说好的晋升，临了换成空降的关系户，理由是我还需要历练。"),
    ]
}
