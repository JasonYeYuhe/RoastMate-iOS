import XCTest
@testable import RoastMate

/// Remote kill-switch (`RemoteConfig` / `RemoteConfigValues`), the highest-
/// ROI item from the 2026-05-29 health audit §4. The marquee invariant:
/// the switch can only ever RESTRICT — it can force a feature off or force
/// on-device, but it can NEVER route user text to the cloud without the
/// existing 5.1.2(i) consent grant. Plus: forward-compatible decode
/// (missing keys = safe ENABLED defaults), fail-open on bad data (keep the
/// last value), and offline-safe baked defaults.
@MainActor
final class RemoteConfigTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    // Async setUp/tearDown so the overrides inherit the class's @MainActor
    // isolation and can touch the isolated fixture properties (the sync
    // variants are nonisolated under Swift 6 strict concurrency).
    override func setUp() async throws {
        try await super.setUp()
        // Isolated per-test UserDefaults suite — no contamination across
        // tests or with the real app's App-Group store.
        suiteName = "remoteconfig-test-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try await super.tearDown()
    }

    // MARK: - Decode

    func test_decodeValidJSON_allFields() throws {
        let json = Data("""
        {
          "config_version": 1,
          "echoes_enabled": false,
          "force_local_only": true,
          "vent_cloud_enabled": false,
          "min_supported_build": 14
        }
        """.utf8)
        let v = try JSONDecoder().decode(RemoteConfigValues.self, from: json)
        XCTAssertEqual(v.configVersion, 1)
        XCTAssertFalse(v.echoesEnabled)
        XCTAssertTrue(v.forceLocalOnly)
        XCTAssertFalse(v.ventCloudEnabled)
        XCTAssertEqual(v.minSupportedBuild, 14)
    }

    func test_decodeMissingKeys_useSafeEnabledDefaults() throws {
        // This is the CACHE / forward-compat decoder (RemoteConfigValues).
        // Missing keys fall back to enabled so an older cache blob still
        // decodes when a future version adds a key. (The LIVE wire path does
        // NOT default — it merges a RemoteConfigPatch; see the merge tests.)
        let json = Data(#"{ "echoes_enabled": false }"#.utf8)
        let v = try JSONDecoder().decode(RemoteConfigValues.self, from: json)
        XCTAssertFalse(v.echoesEnabled, "Explicit false is honored.")
        XCTAssertTrue(v.ventCloudEnabled, "Missing key → safe (enabled) default.")
        XCTAssertFalse(v.forceLocalOnly, "Missing key → safe (not-forced) default.")
        XCTAssertEqual(v.configVersion, RemoteConfigValues.safeDefault.configVersion)
        XCTAssertEqual(v.minSupportedBuild, 0)
    }

    func test_decodeEmptyObject_equalsSafeDefault() throws {
        let v = try JSONDecoder().decode(RemoteConfigValues.self, from: Data("{}".utf8))
        XCTAssertEqual(v, .safeDefault, "An empty config is the all-enabled baseline.")
    }

    func test_unknownKeysIgnored_forwardCompatible() throws {
        // A future server-added key must not break an old client's decode.
        let json = Data(#"{ "echoes_enabled": true, "future_flag_v2": "whatever" }"#.utf8)
        let v = try JSONDecoder().decode(RemoteConfigValues.self, from: json)
        XCTAssertTrue(v.echoesEnabled)
    }

    // MARK: - apply(): publish + persist, fail-open

    func test_applyValidConfig_updatesCurrentAndPersists() {
        let rc = RemoteConfig(defaults: defaults)
        XCTAssertEqual(rc.current, .safeDefault, "Fresh (no cache) starts at the all-enabled default.")
        let killJSON = Data(#"{ "config_version": 1, "echoes_enabled": false, "force_local_only": true, "vent_cloud_enabled": false, "min_supported_build": 0 }"#.utf8)
        rc.apply(fetchedData: killJSON)
        XCTAssertFalse(rc.current.echoesEnabled)
        XCTAssertTrue(rc.current.forceLocalOnly)
        // Persisted to the injected defaults so the kill survives a relaunch.
        XCTAssertEqual(RemoteConfigValues.loadCached(from: defaults), rc.current)
    }

    func test_applyMalformedData_keepsLastValue() {
        let rc = RemoteConfig(defaults: defaults)
        // First apply a known-good restrictive config.
        rc.apply(fetchedData: Data(#"{ "echoes_enabled": false }"#.utf8))
        let before = rc.current
        XCTAssertFalse(before.echoesEnabled)
        // Then a garbage payload — must be ignored, last value retained.
        rc.apply(fetchedData: Data("not json {{{".utf8))
        XCTAssertEqual(rc.current, before, "Malformed fetch must keep the last good config (fail-open).")
    }

    func test_initLoadsCachedConfig_killSurvivesRelaunch() {
        // Simulate a prior launch that cached a kill.
        let killed = RemoteConfigValues(configVersion: 1, echoesEnabled: false,
                                        forceLocalOnly: false, ventCloudEnabled: true,
                                        minSupportedBuild: 0)
        RemoteConfigValues.persist(killed, to: defaults)
        // A new launch (new instance, same defaults) must read the kill,
        // not reset to all-enabled.
        let rc = RemoteConfig(defaults: defaults)
        XCTAssertFalse(rc.current.echoesEnabled,
                       "A kill cached yesterday must still be in force after an offline relaunch.")
    }

    // MARK: - apply() MERGE semantics — no accidental un-kill (Codex review 2026-05-29)

    func test_applyPartialPatch_keepsPriorKilledValue_doesNotReEnable() {
        let rc = RemoteConfig(defaults: defaults)
        // Day 1: kill Echoes (full config, all keys present).
        rc.apply(fetchedData: Data(#"{ "config_version":1, "echoes_enabled":false, "force_local_only":false, "vent_cloud_enabled":true, "min_supported_build":0 }"#.utf8))
        XCTAssertFalse(rc.current.echoesEnabled)
        // Day 2: a PARTIAL payload that adds a force-local kill but OMITS
        // echoes_enabled. Merge must keep Echoes killed (NOT revert it to the
        // enabled default) — the switch may only change keys it explicitly
        // names. This is the RESTRICT-only-by-presence guarantee.
        rc.apply(fetchedData: Data(#"{ "force_local_only": true }"#.utf8))
        XCTAssertFalse(rc.current.echoesEnabled,
                       "An omitted key must keep its prior killed value, never re-enable by omission.")
        XCTAssertTrue(rc.current.forceLocalOnly, "The present key applies.")
        XCTAssertTrue(rc.current.ventCloudEnabled, "An untouched key keeps its prior value.")
        // Persisted merge survives relaunch too.
        XCTAssertEqual(RemoteConfigValues.loadCached(from: defaults), rc.current)
    }

    func test_applyExplicitTrue_reEnablesAKilledFeature() {
        let rc = RemoteConfig(defaults: defaults)
        rc.apply(fetchedData: Data(#"{ "echoes_enabled": false }"#.utf8))
        XCTAssertFalse(rc.current.echoesEnabled)
        // Re-enabling requires an EXPLICIT true — deliberate, never by omission.
        rc.apply(fetchedData: Data(#"{ "echoes_enabled": true }"#.utf8))
        XCTAssertTrue(rc.current.echoesEnabled)
    }

    func test_applyEmptyObject_isNoOpMerge() {
        let rc = RemoteConfig(defaults: defaults)
        rc.apply(fetchedData: Data(#"{ "echoes_enabled": false, "vent_cloud_enabled": false }"#.utf8))
        let before = rc.current
        rc.apply(fetchedData: Data("{}".utf8))
        XCTAssertEqual(rc.current, before, "An empty patch is a no-op merge — every prior value is kept.")
    }

    // MARK: - First launch: offline-safe baked defaults

    func test_firstLaunchNoCacheNoNetwork_everythingEnabled() {
        // No cache key in a fresh suite → baked-in safe default, all on.
        let cfg = RemoteConfigValues.cached(from: defaults)
        XCTAssertEqual(cfg, .safeDefault)
        XCTAssertTrue(cfg.echoesEnabled)
        XCTAssertTrue(cfg.ventCloudEnabled)
        XCTAssertFalse(cfg.forceLocalOnly)
    }

    // MARK: - The RESTRICT-only invariant (marquee 5.1.2(i) safety)

    func test_restrictOnly_consentDeniedNeverClouds_regardlessOfFlags() {
        // For EVERY flag combination, a denied/notAsked consent (false) must
        // never be upgraded to a cloud call. This is the core 5.1.2(i)
        // guarantee: the switch subtracts, it never adds.
        for vent in [true, false] {
            for forceLocal in [true, false] {
                let v = RemoteConfigValues(configVersion: 1, echoesEnabled: true,
                                           forceLocalOnly: forceLocal,
                                           ventCloudEnabled: vent, minSupportedBuild: 0)
                XCTAssertFalse(v.cloudAllowed(consentAllowsCloud: false),
                               "consentAllowsCloud:false must yield cloud-OFF for vent=\(vent) forceLocal=\(forceLocal).")
            }
        }
    }

    func test_killSubtractsCloud_evenWhenConsentGranted() {
        // vent_cloud_enabled:false → no cloud even with consent.
        let ventOff = RemoteConfigValues(configVersion: 1, echoesEnabled: true,
                                         forceLocalOnly: false, ventCloudEnabled: false,
                                         minSupportedBuild: 0)
        XCTAssertFalse(ventOff.cloudAllowed(consentAllowsCloud: true))
        // force_local_only:true → no cloud even with consent + vent enabled.
        let forced = RemoteConfigValues(configVersion: 1, echoesEnabled: true,
                                        forceLocalOnly: true, ventCloudEnabled: true,
                                        minSupportedBuild: 0)
        XCTAssertFalse(forced.cloudAllowed(consentAllowsCloud: true))
    }

    func test_cloudAllowed_onlyWhenConsentAndFlagsAllOpen() {
        XCTAssertTrue(RemoteConfigValues.safeDefault.cloudAllowed(consentAllowsCloud: true),
                      "Consent granted + all-enabled baseline → cloud permitted.")
    }

    // MARK: - cloud_sendable_enabled (DARK-by-default, iOS 18 no-FM path)

    func test_cloudSendable_darkByDefault() {
        XCTAssertFalse(RemoteConfigValues.safeDefault.cloudSendableEnabled,
                       "Sendable-cloud must ship DARK — flipped on remotely only after the eval.")
        XCTAssertFalse(RemoteConfigValues.safeDefault.cloudSendableAllowed(consentAllowsCloud: true),
                       "Even with consent, the baked default keeps sendable cloud OFF.")
    }

    func test_cloudSendableAllowed_restrictOnly_consentDeniedNeverClouds() {
        // RESTRICT-only invariant for the sendable path: no flag combination
        // routes sendable text to the cloud without a prior 5.1.2(i) grant.
        let on = RemoteConfigValues(configVersion: 1, echoesEnabled: true, forceLocalOnly: false,
                                    ventCloudEnabled: true, minSupportedBuild: 0,
                                    roommateGroupEnabled: true, cloudSendableEnabled: true)
        XCTAssertFalse(on.cloudSendableAllowed(consentAllowsCloud: false),
                       "consent=false must be false regardless of the flag.")
        XCTAssertTrue(on.cloudSendableAllowed(consentAllowsCloud: true),
                      "flag on + consent → sendable cloud permitted.")
        // force_local_only subtracts even when the sendable flag is on.
        let forced = RemoteConfigValues(configVersion: 1, echoesEnabled: true, forceLocalOnly: true,
                                        ventCloudEnabled: true, minSupportedBuild: 0,
                                        roommateGroupEnabled: true, cloudSendableEnabled: true)
        XCTAssertFalse(forced.cloudSendableAllowed(consentAllowsCloud: true),
                       "force_local_only must kill the sendable cloud path too.")
    }

    func test_cloudSendable_remoteFlipOn_viaPatch() {
        // The flip that ships post-eval: a patch that names only
        // cloud_sendable_enabled:true must enable it without touching others.
        let flipped = RemoteConfigValues.safeDefault.merging(
            try! JSONDecoder().decode(RemoteConfigPatch.self,
                                      from: Data(#"{ "cloud_sendable_enabled": true }"#.utf8)))
        XCTAssertTrue(flipped.cloudSendableEnabled)
        XCTAssertTrue(flipped.ventCloudEnabled, "Omitted keys keep their prior value.")
    }

    // MARK: - isRestrictive (telemetry trigger)

    func test_isRestrictive_trueWhenAnythingDisabled() {
        XCTAssertFalse(RemoteConfigValues.safeDefault.isRestrictive,
                       "The all-enabled baseline is not restrictive.")
        XCTAssertTrue(RemoteConfigValues(configVersion: 1, echoesEnabled: false, forceLocalOnly: false,
                                         ventCloudEnabled: true, minSupportedBuild: 0).isRestrictive)
        XCTAssertTrue(RemoteConfigValues(configVersion: 1, echoesEnabled: true, forceLocalOnly: true,
                                         ventCloudEnabled: true, minSupportedBuild: 0).isRestrictive)
        XCTAssertTrue(RemoteConfigValues(configVersion: 1, echoesEnabled: true, forceLocalOnly: false,
                                         ventCloudEnabled: false, minSupportedBuild: 0).isRestrictive)
    }

    // MARK: - 虚拟舍友群 dark-by-default flag

    func test_roommateGroup_enabledByDefaultAfterEval() {
        // The cloud path (Option A) validated at 10% parse-fallback (2026-06-06),
        // so the roommate group now ships ENABLED; the remote
        // `roommate_group_enabled:false` is the production kill-switch.
        XCTAssertTrue(RemoteConfigValues.safeDefault.roommateGroupEnabled)
        XCTAssertTrue(RemoteConfigValues.safeDefault.roommateGroupAllowed,
                      "Enabled + echoes on → allowed.")
        // The all-enabled baseline is still not restrictive.
        XCTAssertFalse(RemoteConfigValues.safeDefault.isRestrictive)
    }

    func test_roommateGroupAllowed_requiresBothFlags() {
        let onWithEchoes = RemoteConfigValues(configVersion: 1, echoesEnabled: true, forceLocalOnly: false,
                                              ventCloudEnabled: true, minSupportedBuild: 0,
                                              roommateGroupEnabled: true)
        XCTAssertTrue(onWithEchoes.roommateGroupAllowed)
        let echoesKilled = RemoteConfigValues(configVersion: 1, echoesEnabled: false, forceLocalOnly: false,
                                              ventCloudEnabled: true, minSupportedBuild: 0,
                                              roommateGroupEnabled: true)
        XCTAssertFalse(echoesKilled.roommateGroupAllowed,
                       "Killing echoes must also kill the roommate group (AND gate).")
    }

    func test_roommateGroup_remoteKill_notReEnabledByOmission() {
        let rc = RemoteConfig(defaults: defaults)
        XCTAssertTrue(rc.current.roommateGroupAllowed, "Fresh = enabled (post-eval default).")
        // Remote KILL — the production safety net if the live parse-fallback spikes.
        rc.apply(fetchedData: Data(#"{ "roommate_group_enabled": false }"#.utf8))
        XCTAssertFalse(rc.current.roommateGroupAllowed, "Explicit false kills it.")
        // A later partial patch that omits it must keep it KILLED (merge semantics) —
        // an omitted key can never re-enable a killed feature.
        rc.apply(fetchedData: Data(#"{ "vent_cloud_enabled": false }"#.utf8))
        XCTAssertFalse(rc.current.roommateGroupEnabled,
                       "An omitted key keeps its prior (killed) value — no re-enable by omission.")
    }

    // MARK: - refresh(): request shape + network failure (Codex review 2026-05-29)

    func test_refresh_requestIsBareGET_noQueryNoCookies() async {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { req in
            let resp = HTTPURLResponse(url: req.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{ "echoes_enabled": false }"#.utf8))
        }
        let rc = RemoteConfig(defaults: defaults,
                              session: StubURLProtocol.makeSession(),
                              endpoint: URL(string: "https://example.invalid/roastmate-config.json")!)
        await rc.refresh()
        let captured = StubURLProtocol.captured
        XCTAssertEqual(captured?.httpMethod, "GET", "Config fetch must be a GET.")
        XCTAssertNil(captured?.url?.query, "Privacy: the config GET must carry no query parameters.")
        XCTAssertNil(captured?.httpBody, "A GET must send no body.")
        XCTAssertNil(captured?.value(forHTTPHeaderField: "Cookie"),
                     "Privacy: no Cookie header (ephemeral session, cookies disabled).")
        XCTAssertNil(captured?.value(forHTTPHeaderField: "Authorization"),
                     "Privacy: no Authorization / identifying header.")
        XCTAssertFalse(rc.current.echoesEnabled, "A successfully-fetched false applies.")
    }

    func test_refresh_non2xx_keepsCurrent() async {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { req in
            // Server error WITH a would-be-restrictive body — must be ignored.
            let resp = HTTPURLResponse(url: req.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!
            return (resp, Data(#"{ "echoes_enabled": false }"#.utf8))
        }
        let rc = RemoteConfig(defaults: defaults,
                              session: StubURLProtocol.makeSession(),
                              endpoint: URL(string: "https://example.invalid/c.json")!)
        await rc.refresh()
        XCTAssertEqual(rc.current, .safeDefault,
                       "A non-2xx response must not apply its body — keep current (fail-open).")
    }

    func test_refresh_transportError_keepsCurrent() async {
        StubURLProtocol.reset()
        StubURLProtocol.responder = { _ in throw URLError(.notConnectedToInternet) }
        let rc = RemoteConfig(defaults: defaults,
                              session: StubURLProtocol.makeSession(),
                              endpoint: URL(string: "https://example.invalid/c.json")!)
        await rc.refresh()
        XCTAssertEqual(rc.current, .safeDefault,
                       "Offline / transport error must keep current (fail-open, never brick).")
    }
}

/// Minimal `URLProtocol` stub so `refresh()` can be exercised offline.
/// Captures the outbound request (to assert the privacy-critical request
/// shape) and returns a scripted response or throws a transport error.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var responder: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    nonisolated(unsafe) static var captured: URLRequest?

    static func reset() { responder = nil; captured = nil }

    static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: cfg)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        StubURLProtocol.captured = request
        guard let responder = StubURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (resp, data) = try responder(request)
            client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
