import XCTest
@testable import RoastMate

/// Track M M.1 (v1.3): the Pro-auth token client (`CloudAuthClient`) and the
/// `CloudVentClient` v2 token plumbing. Reuses `StubURLProtocol` (defined in
/// RemoteConfigTests) to stub /v1/auth + /v1/vent without touching the network.
///
/// The load-bearing invariant: auth is BEST-EFFORT — any failure yields nil so
/// the caller falls back to the tokenless free/legacy path; a broken auth path
/// never blocks a vent.
@MainActor
final class CloudAuthTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        StubURLProtocol.reset()
    }
    override func tearDown() async throws {
        StubURLProtocol.reset()
        try await super.tearDown()
    }

    private func ok200(token: String, expiresInSec: TimeInterval = 3600) -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        return { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let expMs = (Date().timeIntervalSince1970 + expiresInSec) * 1000
            return (resp, Data("{\"token\":\"\(token)\",\"expiresAt\":\(expMs)}".utf8))
        }
    }
    private func status(_ code: Int, _ body: String = "{}") -> (URLRequest) throws -> (HTTPURLResponse, Data) {
        return { req in
            (HTTPURLResponse(url: req.url!, statusCode: code, httpVersion: nil, headerFields: nil)!, Data(body.utf8))
        }
    }

    // MARK: - CloudAuthClient

    func test_noProJWS_returnsNil_withoutHittingNetwork() async {
        // responder WOULD return a token if the network were reached...
        StubURLProtocol.responder = ok200(token: "should-not-be-used")
        let auth = CloudAuthClient(session: StubURLProtocol.makeSession(),
                                   endpoint: CloudConfig.authEndpoint,
                                   jwsProvider: { nil })
        let token = await auth.proSessionToken()
        XCTAssertNil(token, "no Pro JWS → nil, and the /v1/auth call is never made")
    }

    func test_success_returnsToken_andCachesAcrossCalls() async {
        StubURLProtocol.responder = ok200(token: "tok-A")
        let auth = CloudAuthClient(session: StubURLProtocol.makeSession(),
                                   endpoint: CloudConfig.authEndpoint,
                                   jwsProvider: { "fake-pro-jws" })
        let t1 = await auth.proSessionToken()
        XCTAssertEqual(t1, "tok-A")
        // Change the responder; a cached token must NOT re-fetch.
        StubURLProtocol.responder = ok200(token: "tok-B")
        let t2 = await auth.proSessionToken()
        XCTAssertEqual(t2, "tok-A", "second call served from cache, not a fresh fetch")
    }

    func test_invalidate_forcesRefetch() async {
        StubURLProtocol.responder = ok200(token: "tok-A")
        let auth = CloudAuthClient(session: StubURLProtocol.makeSession(),
                                   endpoint: CloudConfig.authEndpoint,
                                   jwsProvider: { "jws" })
        _ = await auth.proSessionToken()
        await auth.invalidate()
        StubURLProtocol.responder = ok200(token: "tok-B")
        let t2 = await auth.proSessionToken()
        XCTAssertEqual(t2, "tok-B", "after invalidate, a new token is fetched")
    }

    func test_non2xx_returnsNil() async {
        StubURLProtocol.responder = status(401, "{\"error\":\"verification_failed\"}")
        let auth = CloudAuthClient(session: StubURLProtocol.makeSession(),
                                   endpoint: CloudConfig.authEndpoint,
                                   jwsProvider: { "jws" })
        let token = await auth.proSessionToken()
        XCTAssertNil(token)
    }

    func test_emptyTokenInResponse_returnsNil() async {
        StubURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("{\"token\":\"\",\"expiresAt\":123}".utf8))
        }
        let auth = CloudAuthClient(session: StubURLProtocol.makeSession(),
                                   endpoint: CloudConfig.authEndpoint,
                                   jwsProvider: { "jws" })
        let token = await auth.proSessionToken()
        XCTAssertNil(token)
    }

    // MARK: - CloudVentClient v2 token plumbing

    func test_ventClient_setsBearerHeader_whenTokenProvided() async throws {
        StubURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("{\"text\":\"roast\",\"model\":\"m\",\"remaining\":5}".utf8))
        }
        let client = CloudVentClient(session: StubURLProtocol.makeSession())
        let req = CloudVentRequest(situation: "s", styleName: nil, intensity: "vent", locale: "en", deviceId: "device-123456")
        _ = try await client.generate(req, authToken: "tok-xyz")
        XCTAssertEqual(StubURLProtocol.captured?.value(forHTTPHeaderField: "Authorization"), "Bearer tok-xyz")
    }

    func test_ventClient_noAuthHeader_onTokenlessPath() async throws {
        StubURLProtocol.responder = { req in
            (HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
             Data("{\"text\":\"roast\",\"model\":\"m\",\"remaining\":5}".utf8))
        }
        let client = CloudVentClient(session: StubURLProtocol.makeSession())
        let req = CloudVentRequest(situation: "s", styleName: nil, intensity: "vent", locale: "en", deviceId: "device-123456")
        _ = try await client.generate(req)  // back-compat extension → authToken nil
        XCTAssertNil(StubURLProtocol.captured?.value(forHTTPHeaderField: "Authorization"))
    }

    func test_ventClient_401_throwsTokenInvalid() async {
        StubURLProtocol.responder = status(401, "{\"error\":\"token_invalid\"}")
        let client = CloudVentClient(session: StubURLProtocol.makeSession())
        let req = CloudVentRequest(situation: "s", styleName: nil, intensity: "vent", locale: "en", deviceId: "device-123456")
        do {
            _ = try await client.generate(req, authToken: "tok")
            XCTFail("expected CloudVentError.tokenInvalid")
        } catch CloudVentError.tokenInvalid {
            // expected
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }
}
