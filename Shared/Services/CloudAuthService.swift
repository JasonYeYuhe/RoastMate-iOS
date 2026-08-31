import Foundation
import os.log

/// Track M M.1 (v1.3): exchanges the active Pro subscription's Apple-signed JWS
/// for a short-lived Worker session token (POST /v1/auth) and caches it until it
/// nears expiry. That token is what upgrades a vent request to the authenticated
/// "Pro lane" on the Worker.
///
/// Everything here is BEST-EFFORT: any failure (not Pro, network error, non-2xx,
/// decode error, unconfigured endpoint) returns nil, and the caller falls back to
/// the tokenless free/legacy path. A broken auth path must never block a vent.
protocol CloudAuthProviding: Sendable {
    /// A valid Pro session token, or nil if the user isn't verified-Pro or auth
    /// failed. Cached — only hits the network when there is no live token.
    func proSessionToken() async -> String?
    /// Drop any cached token (call after the vent endpoint returns 401 so the
    /// next request re-authenticates).
    func invalidate() async
}

/// Yields the current Pro JWS (nil if not Pro). Injected so the actor doesn't
/// hard-depend on StoreService and so tests can supply their own.
typealias ProJWSProvider = @Sendable () async -> String?

actor CloudAuthClient: CloudAuthProviding {
    static let shared = CloudAuthClient()

    private struct CachedToken { let token: String; let expiresAt: Date }

    private let session: URLSession
    private let endpoint: URL
    private let jwsProvider: ProJWSProvider
    /// Refresh this far before the real expiry so an in-flight request never
    /// carries a just-expired token.
    private let expirySkew: TimeInterval = 60
    private var cached: CachedToken?
    private var inFlight: Task<String?, Never>?
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "CloudAuth")

    init(session: URLSession = .shared,
         endpoint: URL = CloudConfig.authEndpoint,
         jwsProvider: @escaping ProJWSProvider = { await StoreService.shared.currentProTransactionJWS() }) {
        self.session = session
        self.endpoint = endpoint
        self.jwsProvider = jwsProvider
    }

    func proSessionToken() async -> String? {
        if let c = cached, c.expiresAt.timeIntervalSinceNow > expirySkew {
            return c.token
        }
        // Coalesce concurrent callers onto a single network fetch.
        if let inFlight { return await inFlight.value }
        let task = Task<String?, Never> { await self.fetch() }
        inFlight = task
        let result = await task.value
        inFlight = nil
        return result
    }

    func invalidate() {
        cached = nil
    }

    private func fetch() async -> String? {
        guard CloudConfig.isConfigured else { return nil }
        guard let jws = await jwsProvider(), !jws.isEmpty else { return nil }

        var request = URLRequest(url: endpoint, timeoutInterval: CloudConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("RoastMate-iOS", forHTTPHeaderField: "User-Agent")
        guard let body = try? JSONEncoder().encode(["jws": jws]) else { return nil }
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard !decoded.token.isEmpty, decoded.expiresAt > 0 else { return nil }
            // Worker returns `expiresAt` as a ms-epoch value.
            cached = CachedToken(token: decoded.token,
                                 expiresAt: Date(timeIntervalSince1970: decoded.expiresAt / 1000))
            return decoded.token
        } catch {
            logger.warning("CloudAuth fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private struct AuthResponse: Decodable {
        let token: String
        let expiresAt: Double  // ms epoch
    }
}
