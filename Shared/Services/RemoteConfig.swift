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
    /// `true` (the baked DEFAULT, post-2026-06-06 cloud eval @ 10% fallback) →
    /// the 虚拟舍友群 entry is visible + the roommate scene generates via the
    /// cloud Worker. The remote `roommate_group_enabled:false` is the
    /// production kill-switch (if the live parse-fallback ever spikes). Always
    /// gated together with `echoesEnabled` — see `roommateGroupAllowed`.
    var roommateGroupEnabled: Bool
    /// `true` → force ALL generation on-device (disables the rewrite
    /// cloud-vent path AND any Echoes-feral cloud), regardless of user
    /// consent. The "cloud is misbehaving / costing too much" lever.
    var forceLocalOnly: Bool
    /// `false` → disable just the rewrite Vent/Feral cloud path.
    var ventCloudEnabled: Bool
    /// `true` → allow the SENDABLE modes (calm/sharp/savage) to use the cloud
    /// Worker when the device has NO on-device model (iOS 18 / AI off).
    /// **DARK by default** (`false`): v1.2.0 ships with the code present but the
    /// path off, so we can flip it on remotely after the zh-Hans quality eval —
    /// no Apple cycle (the increment-8 DARK→eval→flip model). RESTRICT-only: it
    /// still ANDs the 5.1.2(i) consent grant via `cloudSendableAllowed`.
    var cloudSendableEnabled: Bool
    /// OPTIONAL per-locale narrowing for the sendable cloud path, as content
    /// bucket codes ("zh-Hans", "zh-Hant", "ja", "en").
    ///
    /// `nil` (the key absent) means "all locales", so existing configs behave
    /// exactly as before. RESTRICT-only like every other remote flag: this can
    /// only NARROW `cloudSendableEnabled`, never widen it, and it cannot route
    /// anything to cloud on its own.
    ///
    /// Why this exists: the Track 0.2 eval cleared zh-Hans (48/48), ja (24/24)
    /// and en (24/24) but not zh-Hant (20/24, below the 85% gate — simplified
    /// character bleed). With a single global boolean the only options were
    /// "block all four" or "ship known-degraded output to zh-Hant readers".
    /// This makes the third option — enable the locales that passed — possible.
    /// WHICH locales to enable stays a product decision; this is only the
    /// mechanism.
    var cloudSendableLocales: [String]?
    /// `true` → the share card may carry its GROWTH layer: the QR code, the
    /// "search RoastMate" badge, and the campaign-tagged link.
    ///
    /// Scope note, because this differs from what the v1.4 plan assumed. The
    /// plan said to ship "the Comeback Card" dark. It was written believing the
    /// card was unshipped — it is not: a card has been live since v1.0.5, and
    /// v1.3.1 made it sendable-only and immutable. Gating the whole card would
    /// therefore REMOVE a shipped, now-safe feature from users.
    ///
    /// So this flag gates the growth layer only — the parts that turn a private
    /// nicety into an acquisition surface, and therefore into a traffic surge.
    /// That preserves the plan's actual intent (no viral floodgate before the
    /// dam is proven) with no user-visible regression. DARK by default.
    var shareCardEnabled: Bool
    /// A.1: gates the setup-chip picker in the composer. SEPARATE from
    /// `shareCardEnabled` on purpose — that one gates the QR growth badge, and
    /// flipping both at once makes the signal unreadable.
    var shareCardSetupEnabled: Bool
    /// Soft "please update" floor — advisory only in v1 (never hard-blocks).
    var minSupportedBuild: Int

    /// Baked-in safe defaults: everything enabled (the roommate group too, now
    /// that its cloud path validated at 10% parse-fallback — the remote
    /// kill-switch is the safety net). Used on a fresh first launch with no
    /// cache + no network: a privacy-first app must work fully offline and
    /// cannot hard-depend on a network fetch.
    static let safeDefault = RemoteConfigValues(
        configVersion: 1,
        echoesEnabled: true,
        forceLocalOnly: false,
        ventCloudEnabled: true,
        minSupportedBuild: 0,
        roommateGroupEnabled: true,
        cloudSendableEnabled: false, // DARK: flipped on remotely after the eval
        cloudSendableLocales: nil,   // nil = all locales (back-compat)
        shareCardEnabled: false,     // DARK: flipped after the §2 quantitative gate
        shareCardSetupEnabled: false // DARK: A.1 setup chips, flip after a device look
    )

    enum CodingKeys: String, CodingKey {
        case configVersion       = "config_version"
        case echoesEnabled       = "echoes_enabled"
        case roommateGroupEnabled = "roommate_group_enabled"
        case forceLocalOnly      = "force_local_only"
        case ventCloudEnabled    = "vent_cloud_enabled"
        case cloudSendableEnabled = "cloud_sendable_enabled"
        case cloudSendableLocales = "cloud_sendable_locales"
        case shareCardEnabled    = "share_card_enabled"
        case shareCardSetupEnabled = "share_card_setup_enabled"
        case minSupportedBuild   = "min_supported_build"
    }

    /// `roommateGroupEnabled` / `cloudSendableEnabled` are the LAST parameters
    /// (defaults = the shipped state, the latter DARK) so existing call sites
    /// keep compiling.
    init(configVersion: Int, echoesEnabled: Bool, forceLocalOnly: Bool,
         ventCloudEnabled: Bool, minSupportedBuild: Int,
         roommateGroupEnabled: Bool = true,
         cloudSendableEnabled: Bool = false,
         cloudSendableLocales: [String]? = nil,
         shareCardEnabled: Bool = false,
         shareCardSetupEnabled: Bool = false) {
        self.configVersion = configVersion
        self.echoesEnabled = echoesEnabled
        self.roommateGroupEnabled = roommateGroupEnabled
        self.forceLocalOnly = forceLocalOnly
        self.ventCloudEnabled = ventCloudEnabled
        self.cloudSendableEnabled = cloudSendableEnabled
        self.cloudSendableLocales = cloudSendableLocales
        self.shareCardEnabled = shareCardEnabled
        self.shareCardSetupEnabled = shareCardSetupEnabled
        self.minSupportedBuild = minSupportedBuild
    }

    /// Decoder for the PERSISTED CACHE (always written in full via `persist`)
    /// and a forward-compat safety net: every key is optional and falls back
    /// to the SAFE default when absent, so a future-added key never breaks
    /// decoding an older cache blob. `roommateGroupEnabled` falls back to its
    /// baked default, which is `true` (flipped by c37d393 when the feature went
    /// live) — an old cache that predates the key therefore reads the feature as
    /// ENABLED, matching a fresh install. This comment previously said the
    /// default was dark/`false`; it had been wrong since that flip.
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
        cloudSendableEnabled = try c.decodeIfPresent(Bool.self, forKey: .cloudSendableEnabled) ?? d.cloudSendableEnabled
        shareCardEnabled     = try c.decodeIfPresent(Bool.self, forKey: .shareCardEnabled)     ?? d.shareCardEnabled
        shareCardSetupEnabled = try c.decodeIfPresent(Bool.self, forKey: .shareCardSetupEnabled) ?? d.shareCardSetupEnabled
        cloudSendableLocales = try c.decodeIfPresent([String].self, forKey: .cloudSendableLocales)
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

    /// Sendable-mode (calm/sharp/savage) cloud permission — the analogue of
    /// `cloudAllowed` for the iOS-18 no-FM path. Same RESTRICT-only invariant:
    /// `cloudSendableAllowed(consentAllowsCloud: false)` is `false` for every
    /// flag combination, so no remote value routes sendable text to the cloud
    /// without a prior explicit 5.1.2(i) grant. DARK until `cloudSendableEnabled`.
    func cloudSendableAllowed(consentAllowsCloud: Bool) -> Bool {
        consentAllowsCloud && cloudSendableEnabled && !forceLocalOnly
    }

    /// Locale-aware form. Adds the optional per-locale narrowing on top of the
    /// global switch; an absent/empty list means every locale, so this is
    /// identical to the call above for existing configs.
    func cloudSendableAllowed(consentAllowsCloud: Bool, locale: Locale) -> Bool {
        guard cloudSendableAllowed(consentAllowsCloud: consentAllowsCloud) else { return false }
        guard let allowed = cloudSendableLocales, !allowed.isEmpty else { return true }
        return allowed.contains(AppLanguage.contentBucket(for: locale).rawValue)
    }

    /// Whether the 虚拟舍友群 scene may run: its own flag AND the Echoes
    /// master switch. Killing Echoes also kills the roommate group.
    var roommateGroupAllowed: Bool {
        roommateGroupEnabled && echoesEnabled
    }

    /// True if this config disables anything relative to its BAKED DEFAULT —
    /// drives the `remote_config_kill_applied` telemetry bump so an A′ export
    /// confirms a kill actually reached the device.
    ///
    /// `roommateGroupEnabled` was excluded here on the premise that it was dark
    /// by default, so its `false` was the baseline rather than a kill. Commit
    /// c37d393 falsified that premise when it flipped the baked default to
    /// `true`, and the exclusion was not revisited — so a roommate-group kill
    /// fired NO telemetry and an export could not confirm the kill had landed.
    /// Fixed 2026-09-06.
    ///
    /// The comparison is against `safeDefault` rather than a hardcoded
    /// all-enabled baseline, so this cannot go stale the same way again: flip a
    /// default and this follows automatically. `cloudSendableEnabled` and
    /// `shareCardEnabled` genuinely ARE dark by default, so their `false` is
    /// correctly not a kill — but that now falls out of the comparison instead
    /// of being asserted by a comment that can rot.
    var isRestrictive: Bool {
        let d = RemoteConfigValues.safeDefault
        return (d.echoesEnabled && !echoesEnabled)
            || (d.ventCloudEnabled && !ventCloudEnabled)
            || (d.roommateGroupEnabled && !roommateGroupEnabled)
            || (d.cloudSendableEnabled && !cloudSendableEnabled)
            || (d.shareCardEnabled && !shareCardEnabled)
            || (d.shareCardSetupEnabled && !shareCardSetupEnabled)
            || (!d.forceLocalOnly && forceLocalOnly)
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
            roommateGroupEnabled: patch.roommateGroupEnabled ?? roommateGroupEnabled,
            cloudSendableEnabled: patch.cloudSendableEnabled ?? cloudSendableEnabled,
            cloudSendableLocales: patch.cloudSendableLocales ?? cloudSendableLocales,
            shareCardEnabled: patch.shareCardEnabled ?? shareCardEnabled,
            shareCardSetupEnabled: patch.shareCardSetupEnabled ?? shareCardSetupEnabled
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
    var cloudSendableEnabled: Bool?
    /// OPTIONAL per-locale narrowing for the sendable cloud path, as content
    /// bucket codes ("zh-Hans", "zh-Hant", "ja", "en").
    ///
    /// `nil` (the key absent) means "all locales", so existing configs behave
    /// exactly as before. RESTRICT-only like every other remote flag: this can
    /// only NARROW `cloudSendableEnabled`, never widen it, and it cannot route
    /// anything to cloud on its own.
    ///
    /// Why this exists: the Track 0.2 eval cleared zh-Hans (48/48), ja (24/24)
    /// and en (24/24) but not zh-Hant (20/24, below the 85% gate — simplified
    /// character bleed). With a single global boolean the only options were
    /// "block all four" or "ship known-degraded output to zh-Hant readers".
    /// This makes the third option — enable the locales that passed — possible.
    /// WHICH locales to enable stays a product decision; this is only the
    /// mechanism.
    var cloudSendableLocales: [String]?
    var shareCardEnabled: Bool?
    var shareCardSetupEnabled: Bool?
    var minSupportedBuild: Int?

    enum CodingKeys: String, CodingKey {
        case configVersion       = "config_version"
        case echoesEnabled       = "echoes_enabled"
        case roommateGroupEnabled = "roommate_group_enabled"
        case forceLocalOnly      = "force_local_only"
        case ventCloudEnabled    = "vent_cloud_enabled"
        case cloudSendableEnabled = "cloud_sendable_enabled"
        case cloudSendableLocales = "cloud_sendable_locales"
        case shareCardEnabled    = "share_card_enabled"
        case shareCardSetupEnabled = "share_card_setup_enabled"
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
