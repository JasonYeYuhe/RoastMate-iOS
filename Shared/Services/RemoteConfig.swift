import Foundation
import os.log

/// Remote kill-switch / feature-flag values, fetched as a tiny static JSON
/// on launch. The single lever the developer has to disable a feature or
/// force on-device generation WITHOUT shipping a new build through Apple
/// review (days of latency). Highest-ROI item from the 2026-05-29 health
/// audit (`docs/HEALTH_AUDIT_2026-05-29.md` §4).
///
/// PRIVACY + SAFETY CONTRACT (do not weaken — see audit §4):
///   1. RESTRICT-only. A flag can only ever turn a capability OFF. It can
///      NEVER cause user text to reach the cloud without the existing
///      5.1.2(i) consent grant — `cloudAllowed(consentAllowsCloud:)` ANDs
///      the flags with the consent bool, so `false` consent is always
///      `false` regardless of flags. The consent gate stays the source of
///      truth; this can only subtract.
///   2. The fetch sends ZERO user data — a plain GET of a static file, no
///      query params, no identifiers, no telemetry counters in the URL.
///      Preserves the privacy moat (consistent with the cloud-vent posture
///      of only sending consented vent text).
///   3. Fail-open. Any fetch/decode failure keeps the last good value (or
///      baked-in all-enabled defaults on a fresh offline launch) so the
///      app never bricks itself offline. A kill requires a SUCCESSFUL
///      fetch of an explicit `false` — you can only kill when reachable.
struct RemoteConfigValues: Sendable, Codable, Equatable {
    /// Schema version of the fetched payload (advisory; v1 = 1).
    var configVersion: Int
    /// `false` → hide the Echoes tile + block `EchoesEngine.generate`.
    var echoesEnabled: Bool
    /// `false` (the baked DEFAULT) → hide the 虚拟舍友群 entry + block
    /// roommate-scene generation. Ships DARK: the feature is enabled by
    /// flipping this baked default to `true` in the real-device-eval-gated
    /// release; the remote config then serves only as its post-launch
    /// kill-switch. Always gated together with `echoesEnabled` —
    /// see `roommateGroupAllowed`.
    var roommateGroupEnabled: Bool
    /// `true` → force ALL generation on-device (disables the rewrite
    /// cloud-vent path AND any Echoes-feral cloud), regardless of user
    /// consent. The "cloud is misbehaving / costing too much" lever.
    var forceLocalOnly: Bool
    /// `false` → disable just the rewrite Vent/Feral cloud path.
    var ventCloudEnabled: Bool
    /// Soft "please update" floor — advisory only in v1 (never hard-blocks).
    var minSupportedBuild: Int

    /// Baked-in safe defaults. Everything enabled EXCEPT the roommate group,
    /// which ships dark (unvalidated, stricter parse contract than classic
    /// Echoes — enable only after its real-device eval passes). Used on a
    /// fresh first launch with no cache + no network: a privacy-first app
    /// must work fully offline and cannot hard-depend on a network fetch.
    static let safeDefault = RemoteConfigValues(
        configVersion: 1,
        echoesEnabled: true,
        forceLocalOnly: false,
        ventCloudEnabled: true,
        minSupportedBuild: 0,
        roommateGroupEnabled: false
    )

    enum CodingKeys: String, CodingKey {
        case configVersion       = "config_version"
        case echoesEnabled       = "echoes_enabled"
        case roommateGroupEnabled = "roommate_group_enabled"
        case forceLocalOnly      = "force_local_only"
        case ventCloudEnabled    = "vent_cloud_enabled"
        case minSupportedBuild   = "min_supported_build"
    }

    /// `roommateGroupEnabled` is the LAST parameter with a `false` default so
    /// existing 5-arg call sites keep compiling and a config that never
    /// mentions the roommate group keeps it dark.
    init(configVersion: Int, echoesEnabled: Bool, forceLocalOnly: Bool,
         ventCloudEnabled: Bool, minSupportedBuild: Int,
         roommateGroupEnabled: Bool = false) {
        self.configVersion = configVersion
        self.echoesEnabled = echoesEnabled
        self.roommateGroupEnabled = roommateGroupEnabled
        self.forceLocalOnly = forceLocalOnly
        self.ventCloudEnabled = ventCloudEnabled
        self.minSupportedBuild = minSupportedBuild
    }

    /// Decoder for the PERSISTED CACHE (always written in full via `persist`)
    /// and a forward-compat safety net: every key is optional and falls back
    /// to the SAFE default when absent, so a future-added key never breaks
    /// decoding an older cache blob. `roommateGroupEnabled` falls back to its
    /// dark (`false`) baked default — an old cache that predates the feature
    /// keeps it off.
    ///
    /// NOTE: the LIVE wire payload does NOT use this defaulting path — it
    /// decodes into `RemoteConfigPatch` and MERGES only the present keys over
    /// `current` (see `RemoteConfig.apply`). So an omitted key keeps its prior
    /// value and can never accidentally re-enable a killed feature by omission
    /// (Codex review 2026-05-29).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = RemoteConfigValues.safeDefault
        configVersion        = try c.decodeIfPresent(Int.self,  forKey: .configVersion)        ?? d.configVersion
        echoesEnabled        = try c.decodeIfPresent(Bool.self, forKey: .echoesEnabled)        ?? d.echoesEnabled
        roommateGroupEnabled = try c.decodeIfPresent(Bool.self, forKey: .roommateGroupEnabled) ?? d.roommateGroupEnabled
        forceLocalOnly       = try c.decodeIfPresent(Bool.self, forKey: .forceLocalOnly)       ?? d.forceLocalOnly
        ventCloudEnabled     = try c.decodeIfPresent(Bool.self, forKey: .ventCloudEnabled)     ?? d.ventCloudEnabled
        minSupportedBuild    = try c.decodeIfPresent(Int.self,  forKey: .minSupportedBuild)    ?? d.minSupportedBuild
    }

    // MARK: - The RESTRICT-only combinator (load-bearing safety logic)

    /// Whether a cloud generation is permitted, given the existing consent
    /// gate's decision. This is an AND: the kill-switch can only SUBTRACT
    /// from the consent grant, never add to it.
    ///
    /// Invariant (unit-tested): `cloudAllowed(consentAllowsCloud: false)`
    /// is `false` for EVERY flag combination. No remote value can route
    /// user text to the cloud without a prior explicit 5.1.2(i) grant.
    func cloudAllowed(consentAllowsCloud: Bool) -> Bool {
        consentAllowsCloud && ventCloudEnabled && !forceLocalOnly
    }

    /// Whether the 虚拟舍友群 scene may run: its own flag AND the Echoes
    /// master switch. Killing Echoes also kills the roommate group.
    var roommateGroupAllowed: Bool {
        roommateGroupEnabled && echoesEnabled
    }

    /// True if this config disables anything relative to the all-enabled
    /// baseline — drives the `remote_config_kill_applied` telemetry bump so
    /// an A′ export confirms a kill actually reached the device. Note:
    /// `roommateGroupEnabled` is intentionally EXCLUDED — it is dark by
    /// default, so its `false` is the baseline, not a kill.
    var isRestrictive: Bool {
        !echoesEnabled || forceLocalOnly || !ventCloudEnabled
    }

    /// Merge a wire patch over self: each PRESENT key overrides; each ABSENT
    /// key keeps self's value. This makes the kill-switch
    /// change-by-explicit-presence — a partial or hand-edited payload can
    /// only alter the flags it actually names, and can never silently revert
    /// an omitted flag to a default (so it cannot accidentally re-enable a
    /// killed feature by omission). Codex review 2026-05-29.
    func merging(_ patch: RemoteConfigPatch) -> RemoteConfigValues {
        RemoteConfigValues(
            configVersion:        patch.configVersion        ?? configVersion,
            echoesEnabled:        patch.echoesEnabled        ?? echoesEnabled,
            forceLocalOnly:       patch.forceLocalOnly       ?? forceLocalOnly,
            ventCloudEnabled:     patch.ventCloudEnabled     ?? ventCloudEnabled,
            minSupportedBuild:    patch.minSupportedBuild    ?? minSupportedBuild,
            roommateGroupEnabled: patch.roommateGroupEnabled ?? roommateGroupEnabled
        )
    }
}

/// Wire-format patch: every field optional, decoded from the fetched JSON.
/// `RemoteConfigValues.merging(_:)` applies only the keys actually present,
/// leaving any omitted key at its prior value (see `RemoteConfig.apply`).
struct RemoteConfigPatch: Decodable, Sendable {
    var configVersion: Int?
    var echoesEnabled: Bool?
    var roommateGroupEnabled: Bool?
    var forceLocalOnly: Bool?
    var ventCloudEnabled: Bool?
    var minSupportedBuild: Int?

    enum CodingKeys: String, CodingKey {
        case configVersion       = "config_version"
        case echoesEnabled       = "echoes_enabled"
        case roommateGroupEnabled = "roommate_group_enabled"
        case forceLocalOnly      = "force_local_only"
        case ventCloudEnabled    = "vent_cloud_enabled"
        case minSupportedBuild   = "min_supported_build"
    }
}

// MARK: - App-Group cache (lock-free, cross-actor readable)

extension RemoteConfigValues {
    /// App-Group UserDefaults shared across the app + extensions — the same
    /// suite `EventLedger` uses. The cache survives offline launches so a
    /// kill applied yesterday is still in force today with no network.
    static var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: "group.yyh.roastmate.app") ?? .standard
    }

    static let cacheKey = "remoteconfig.cached_v1"

    /// Last good config, or `nil` if none cached yet.
    static func loadCached(from defaults: UserDefaults) -> RemoteConfigValues? {
        guard let data = defaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(RemoteConfigValues.self, from: data)
    }

    /// Last good config, or the baked-in all-enabled default. Safe to call
    /// from ANY actor (plain UserDefaults read) — `EchoesEngine` uses this
    /// to read `echoesEnabled` without hopping to the main actor.
    static func cached(from defaults: UserDefaults = appGroupDefaults) -> RemoteConfigValues {
        loadCached(from: defaults) ?? .safeDefault
    }

    static func persist(_ values: RemoteConfigValues, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: cacheKey)
    }
}

// MARK: - The live owner

/// Owns the live `current` config for SwiftUI (observable) + the launch
/// refresh. Reads stay on the main actor; the lock-free
/// `RemoteConfigValues.cached()` snapshot serves non-main readers (the
/// `EchoesEngine` actor). Mirrors `EventLedger`'s injectable-dependency
/// shape: inject `UserDefaults` + `URLSession` for tests.
@MainActor
@Observable
final class RemoteConfig {
    static let shared = RemoteConfig()

    /// Served at the Pages-repo root (same static site as privacy.html /
    /// terms.html / research.html). A static file = editable by committing
    /// one line; no Worker code needed.
    static let defaultEndpoint = URL(string: "https://jasonyeyuhe.github.io/RoastMate/roastmate-config.json")!

    private(set) var current: RemoteConfigValues

    private let defaults: UserDefaults
    private let session: URLSession
    private let endpoint: URL
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "RemoteConfig")

    init(defaults: UserDefaults = RemoteConfigValues.appGroupDefaults,
         session: URLSession = RemoteConfig.makeSession(),
         endpoint: URL = RemoteConfig.defaultEndpoint) {
        self.defaults = defaults
        self.session = session
        self.endpoint = endpoint
        // Load the last good config so a kill survives an offline launch;
        // fall back to baked-in all-enabled defaults on a fresh install.
        self.current = RemoteConfigValues.loadCached(from: defaults) ?? .safeDefault
    }

    /// Ephemeral session: no persistent cookies, no credential store, no
    /// URLCache. Belt-and-suspenders with the per-request hardening in
    /// `refresh()` so the config GET carries zero identifying state.
    static func makeSession() -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.httpCookieStorage = nil
        cfg.httpShouldSetCookies = false
        cfg.urlCache = nil
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: cfg)
    }

    /// Fire-and-forget on launch. Plain GET of a static file — sends NO
    /// user data, no query params, no identifying headers. On ANY failure
    /// (offline, non-2xx, malformed) keeps the last value (fail-open).
    func refresh() async {
        var req = URLRequest(url: endpoint,
                             cachePolicy: .reloadIgnoringLocalCacheData,
                             timeoutInterval: 10)
        req.httpMethod = "GET"
        req.httpShouldHandleCookies = false
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                logger.notice("RemoteConfig: non-2xx response; keeping cached config.")
                return
            }
            apply(fetchedData: data)
        } catch {
            // Offline / DNS / timeout — keep the last value. A privacy-first
            // app must never brick itself on a failed config fetch.
            logger.notice("RemoteConfig: fetch failed (\(error.localizedDescription, privacy: .public)); keeping cached config.")
        }
    }

    /// Decode a wire patch → MERGE over `current` → publish + persist +
    /// telemetry. Separated from the network so it's unit-testable with raw
    /// `Data`. On decode failure keeps the last value (fail-open).
    func apply(fetchedData: Data) {
        guard let patch = try? JSONDecoder().decode(RemoteConfigPatch.self, from: fetchedData) else {
            logger.notice("RemoteConfig: decode failed; keeping cached config.")
            return
        }
        // Merge present keys over `current`; an omitted key keeps its prior
        // (possibly killed) value, so a partial payload can never accidentally
        // re-enable a killed feature (Codex review 2026-05-29).
        let merged = current.merging(patch)
        current = merged
        RemoteConfigValues.persist(merged, to: defaults)
        if merged.isRestrictive {
            // A kill is in force on this device — record it (opt-in gated) so
            // an A′ export confirms the kill reached users.
            EventLedger.shared.recordRemoteConfigKillApplied()
        }
    }
}
