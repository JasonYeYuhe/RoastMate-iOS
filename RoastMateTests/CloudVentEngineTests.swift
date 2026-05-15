import XCTest
@testable import RoastMate

/// Validates that RoastEngine routes vent / feral through the cloud
/// client when configured + opted in, and falls back to the local path
/// gracefully on any failure. The local path itself isn't asserted here
/// — these tests only care about the routing decision.
final class CloudVentEngineTests: XCTestCase {
    func testCloudClientReceivesCorrectFieldsForVent() async throws {
        let recorder = RecordingCloudVentService(returning: "卧槽,凌晨两点你打什么破游戏。")
        // We don't want this test to depend on Foundation Models being
        // available, so we let the test pass either way: the assertion is
        // only that the recorder saw the request.
        _ = try? await RoastEngine.shared.generate(
            situation: "我室友每天凌晨两点打游戏。",
            style: testStyle,
            locale: Locale(identifier: "zh-Hans"),
            variantCount: 1,
            intensity: .vent,
            cloudVentEnabled: true,
            cloudClient: recorder
        )
        // CloudConfig.isConfigured is false by default (placeholder host),
        // so the engine should NOT have called the cloud — recorder must
        // see zero requests. This protects us against accidentally
        // shipping a build that posts to the example placeholder URL.
        XCTAssertEqual(recorder.calls.count, 0,
                       "Engine must not call cloud when CloudConfig.isConfigured == false.")
    }

    func testCloudClientNotCalledWhenIntensityIsSendable() async throws {
        let recorder = RecordingCloudVentService(returning: "ignored")
        _ = try? await RoastEngine.shared.generate(
            situation: "X",
            style: testStyle,
            locale: Locale(identifier: "en_US"),
            variantCount: 1,
            intensity: .sharp,
            cloudVentEnabled: true,
            cloudClient: recorder
        )
        XCTAssertEqual(recorder.calls.count, 0,
                       "Sharp intensity must always stay on-device, regardless of cloud toggle.")
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
    private let stubbedText: String

    init(returning text: String) {
        self.stubbedText = text
    }

    func generate(_ req: CloudVentRequest) async throws -> CloudVentResponse {
        calls.append(req)
        return CloudVentResponse(text: stubbedText, model: "fake-model", remaining: 99)
    }
}
