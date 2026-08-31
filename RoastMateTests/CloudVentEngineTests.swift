import XCTest
@testable import RoastMate

/// Validates that RoastEngine routes vent / feral through the cloud
/// client when configured + opted in, and falls back to the local path
/// gracefully on any failure. The local path itself isn't asserted here
/// — these tests only care about the routing decision.
final class CloudVentEngineTests: XCTestCase {
    func testCloudClientReceivesCorrectFieldsForVent() async throws {
        // CloudConfig.isConfigured is now true (real Worker URL), so vent
        // intensity should reach the cloud client with the expected
        // request fields.
        let recorder = RecordingCloudVentService(returning: "卧槽,凌晨两点你打什么破游戏。")
        _ = try? await RoastEngine.shared.generate(
            situation: "我室友每天凌晨两点打游戏。",
            style: testStyle,
            locale: Locale(identifier: "zh-Hans"),
            variantCount: 1,
            intensity: .vent,
            cloudVentEnabled: true,
            cloudClient: recorder
        )
        XCTAssertEqual(recorder.calls.count, 1,
                       "Vent intensity with cloud enabled + configured endpoint must route through the cloud client.")
        let req = try XCTUnwrap(recorder.calls.first)
        XCTAssertEqual(req.intensity, "vent")
        XCTAssertEqual(req.locale, "zh-Hans")
        XCTAssertEqual(req.situation, "我室友每天凌晨两点打游戏。")
        XCTAssertFalse(req.deviceId.isEmpty,
                       "Each request must carry the per-install device UUID for rate limiting.")
    }

    // MARK: - Track M v2: Pro-token wiring

    func testProTokenRidesOnCloudRequest() async throws {
        let recorder = RecordingCloudVentService(returning: "卧槽,真离谱。")
        _ = try? await RoastEngine.shared.generate(
            situation: "室友半夜打游戏。", style: testStyle,
            locale: Locale(identifier: "zh-Hans"), variantCount: 1, intensity: .vent,
            cloudVentEnabled: true, cloudClient: recorder, auth: StubAuth(token: "pro-tok"))
        XCTAssertEqual(recorder.tokens, ["pro-tok"],
                       "A verified-Pro session token must ride on the cloud request (v2 lane).")
    }

    func testTokenlessWhenNotPro() async throws {
        let recorder = RecordingCloudVentService(returning: "卧槽。")
        _ = try? await RoastEngine.shared.generate(
            situation: "室友半夜打游戏。", style: testStyle,
            locale: Locale(identifier: "zh-Hans"), variantCount: 1, intensity: .vent,
            cloudVentEnabled: true, cloudClient: recorder, auth: StubAuth(token: nil))
        XCTAssertEqual(recorder.tokens, [nil],
                       "Non-Pro (no token) uses the tokenless free/legacy lane.")
    }

    func testToken401RetriesTokenlessAndNeverBlocks() async throws {
        let rejecting = TokenRejectingCloudVentService()
        let result = try await RoastEngine.shared.generate(
            situation: "室友半夜打游戏。", style: testStyle,
            locale: Locale(identifier: "zh-Hans"), variantCount: 1, intensity: .vent,
            cloudVentEnabled: true, cloudClient: rejecting, auth: StubAuth(token: "stale-tok"))
        XCTAssertEqual(rejecting.tokens, ["stale-tok", nil],
                       "A 401 drops the token and retries once on the free lane — never blocks the vent.")
        XCTAssertEqual(result, ["free-lane-ok"])
    }

    func testSendableRoutesToCloudWhenEnabled() async throws {
        // Increment 4 (iOS 18 no-FM): the ViewModel resolves cloud consent for
        // sendable modes too, so the engine routes sharp/calm/savage through
        // mode="roast" — carrying the stable styleId + the requested variant
        // count. (Pre-increment-4 this stayed local; the "stays local"
        // guarantee now lives in the consent gate, not the engine.)
        let recorder = RecordingCloudVentService(returning: "1. 你天天抢功,脸是真大。\n2. 方案我熬出来的,名字凭什么是你的。")
        let result = try await RoastEngine.shared.generate(
            situation: "同事抢我方案邀功。",
            style: testStyle,
            locale: Locale(identifier: "zh-Hans"),
            variantCount: 2,
            intensity: .sharp,
            cloudVentEnabled: true,
            cloudClient: recorder
        )
        XCTAssertEqual(recorder.calls.count, 1,
                       "Sendable + cloud enabled must route through the cloud client (iOS 18 no-FM path).")
        let req = try XCTUnwrap(recorder.calls.first)
        XCTAssertEqual(req.mode, "roast", "Sendable cloud must use mode=roast, not the vent path.")
        XCTAssertEqual(req.intensity, "sharp")
        XCTAssertEqual(req.styleId, "test", "Worker needs the stable styleId for the style register + drift test.")
        XCTAssertEqual(req.variantCount, 2, "The requested variant count must reach the Worker.")
        XCTAssertEqual(result.count, 2,
                       "Both numbered cloud variants should split + pass the strict validator.")
    }

    func testSendableStaysLocalWhenCloudDisabled() async throws {
        // 5.1.2(i) guarantee: a surface that does NOT resolve consent
        // (cloudVentEnabled defaults false — Share / Watch / App Intents) must
        // NEVER send sendable text to the network.
        let recorder = RecordingCloudVentService(returning: "ignored")
        _ = try? await RoastEngine.shared.generate(
            situation: "X",
            style: testStyle,
            locale: Locale(identifier: "en_US"),
            variantCount: 3,
            intensity: .sharp,
            cloudVentEnabled: false,
            cloudClient: recorder
        )
        XCTAssertEqual(recorder.calls.count, 0,
                       "Sendable with cloud NOT enabled must never reach the network.")
    }

    func testCloudClientNotCalledWhenUserDisabledIt() async throws {
        let recorder = RecordingCloudVentService(returning: "ignored")
        _ = try? await RoastEngine.shared.generate(
            situation: "X",
            style: testStyle,
            locale: Locale(identifier: "en_US"),
            variantCount: 1,
            intensity: .vent,
            cloudVentEnabled: false,
            cloudClient: recorder
        )
        XCTAssertEqual(recorder.calls.count, 0,
                       "User opt-out (cloudVentEnabled=false) must prevent any cloud call.")
    }

    func testCloudOutputThatTripsSafetyFilterIsNotReturnedRaw() async throws {
        // Regression guard for the `(try? …) ?? cloudText` bug: if the
        // cloud model emits hard-rail content (self-harm directed at the
        // other party), the engine must NOT hand that raw text back. It
        // discards it and falls through to the local path, so the result
        // is anything EXCEPT the dangerous string.
        let dangerous = "这种人真想让他去死。"
        let recorder = RecordingCloudVentService(returning: dangerous)
        let result = try await RoastEngine.shared.generate(
            situation: "我室友每天凌晨两点打游戏。",
            style: testStyle,
            locale: Locale(identifier: "zh-Hans"),
            variantCount: 1,
            intensity: .vent,
            cloudVentEnabled: true,
            cloudClient: recorder
        )
        XCTAssertEqual(recorder.calls.count, 1, "Cloud should have been attempted.")
        XCTAssertFalse(result.contains(dangerous),
                       "Cloud output that fails the vent safety filter must never be returned to the user; engine should fall back to the local path instead.")
    }

    private var testStyle: StylePreset {
        StylePreset(
            id: "test",
            displayKey: "test.name",
            blurbKey: "test.blurb",
            icon: "star",
            tier: .free,
            temperature: 0.8,
            tags: [],
            systemPreamble: "Be witty.",
            examples: [],
            localesSupported: nil
        )
    }
}

/// Fake `CloudVentService` that records every call without touching the
/// network. Lets us verify the engine's routing decisions deterministically.
final class RecordingCloudVentService: CloudVentService, @unchecked Sendable {
    private(set) var calls: [CloudVentRequest] = []
    private(set) var tokens: [String?] = []
    private let stubbedText: String

    init(returning text: String) {
        self.stubbedText = text
    }

    func generate(_ req: CloudVentRequest, authToken: String?) async throws -> CloudVentResponse {
        calls.append(req)
        tokens.append(authToken)
        return CloudVentResponse(text: stubbedText, model: "fake-model", remaining: 99)
    }
}

/// Stub Pro-auth provider (Track M v2). Returns a fixed token (or nil for
/// non-Pro); `invalidate()` is a no-op — the engine's 401 retry explicitly sends
/// no token, so the stub never needs to change what it returns.
struct StubAuth: CloudAuthProviding {
    let token: String?
    func proSessionToken() async -> String? { token }
    func invalidate() async {}
}

/// Fake cloud service that rejects any tokened request (401 → .tokenInvalid) and
/// succeeds only on the tokenless retry. Verifies the engine's degrade path.
final class TokenRejectingCloudVentService: CloudVentService, @unchecked Sendable {
    private(set) var tokens: [String?] = []
    func generate(_ req: CloudVentRequest, authToken: String?) async throws -> CloudVentResponse {
        tokens.append(authToken)
        if authToken != nil { throw CloudVentError.tokenInvalid }
        return CloudVentResponse(text: "free-lane-ok", model: "m", remaining: 5)
    }
}
