import Foundation
import os.log

/// Errors specific to the Cloud Vent path. `RoastEngine` catches these
/// and falls back to local Foundation Models output so a network blip
/// never blocks a vent.
enum CloudVentError: Error, LocalizedError {
    case notConfigured
    case disabledBySettings
    case rateLimited(remaining: Int)
    case http(status: Int, body: String?)
    case decode
    case empty
    case transport(Error)
    /// v2 (Track M): the /v1/auth session token was rejected (expired/invalid).
    /// The caller drops the cached token and retries on the free/legacy path.
    case tokenInvalid

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "cloud.error.not_configured")
        case .disabledBySettings:
            return String(localized: "cloud.error.disabled")
        case .rateLimited:
            return String(localized: "cloud.error.rate_limited")
        case .http, .decode, .empty, .transport, .tokenInvalid:
            return String(localized: "cloud.error.unavailable")
        }
    }
}

/// Protocol so the engine can swap in a fake in unit tests.
protocol CloudVentService: Sendable {
    /// `authToken` (Track M v2): a /v1/auth session token that upgrades the
    /// request to the authenticated Pro lane. Nil → the tokenless free/legacy
    /// path (build-17 behavior).
    func generate(_ req: CloudVentRequest, authToken: String?) async throws -> CloudVentResponse
}

extension CloudVentService {
    /// Back-compat convenience for the tokenless (free/legacy) path.
    func generate(_ req: CloudVentRequest) async throws -> CloudVentResponse {
        try await generate(req, authToken: nil)
    }
}

struct CloudVentRequest: Encodable, Sendable {
    let situation: String
    let styleName: String?
    let intensity: String     // private: "vent"/"feral"; sendable (mode=roast): "calm"/"sharp"/"savage"
    let locale: String
    let deviceId: String
    /// nil / "vent" → the 1–3-sentence private draft; "roommate" → the
    /// 虚拟舍友群 8–10-line group-chat transcript (Echoes vNext, Option A);
    /// "roast" → the sendable modes (calm/sharp/savage) as `variantCount`
    /// numbered variants. Synthesized `encodeIfPresent` omits it when nil, so
    /// existing vent call sites are unchanged on the wire.
    let mode: String?
    /// Stable style identifier (e.g. "high_eq") — lets the Worker render the
    /// matching style register AND lets the drift test prove both prompt sets
    /// reference the same catalog entry. Omitted when nil (vent path).
    let styleId: String?
    /// Number of sendable variants to request (mode=roast only; Worker clamps
    /// 1–5). Omitted when nil — vent/roommate always collapse to one body.
    let variantCount: Int?

    init(situation: String, styleName: String?, intensity: String,
         locale: String, deviceId: String, mode: String? = nil,
         styleId: String? = nil, variantCount: Int? = nil) {
        self.situation = situation
        self.styleName = styleName
        self.intensity = intensity
        self.locale = locale
        self.deviceId = deviceId
        self.mode = mode
        self.styleId = styleId
        self.variantCount = variantCount
    }
}

struct CloudVentResponse: Decodable, Sendable {
    let text: String
    let model: String?
    let remaining: Int?
}

/// HTTPS client for the Cloud Vent Worker.
/// - Stateless: a single instance is safe to share.
/// - URLSession is injectable so tests can mock the network without
///   actually hitting the wire.
final class CloudVentClient: CloudVentService, @unchecked Sendable {
    static let shared = CloudVentClient()

    private let session: URLSession
    private let endpoint: URL
    private let logger = Logger(subsystem: "yyh.roastmate.app", category: "CloudVent")

    init(session: URLSession = .shared, endpoint: URL = CloudConfig.ventEndpoint) {
        self.session = session
        self.endpoint = endpoint
    }

    func generate(_ req: CloudVentRequest, authToken: String?) async throws -> CloudVentResponse {
        guard CloudConfig.isConfigured else {
            throw CloudVentError.notConfigured
        }
        var request = URLRequest(url: endpoint, timeoutInterval: CloudConfig.requestTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("RoastMate-iOS", forHTTPHeaderField: "User-Agent")
        if let authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        do {
            request.httpBody = try JSONEncoder().encode(req)
        } catch {
            throw CloudVentError.transport(error)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.warning("CloudVent transport error: \(error.localizedDescription, privacy: .public)")
            throw CloudVentError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CloudVentError.http(status: -1, body: nil)
        }
        if http.statusCode == 401 {
            // v2 lane: the session token was rejected. Signal the caller to drop
            // it and retry on the free/legacy path — never surfaced to the user.
            throw CloudVentError.tokenInvalid
        }
        if http.statusCode == 429 {
            let parsed = try? JSONDecoder().decode([String: AnyCodable].self, from: data)
            let remaining = (parsed?["remaining"]?.value as? Int) ?? 0
            throw CloudVentError.rateLimited(remaining: remaining)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)
            throw CloudVentError.http(status: http.statusCode, body: body?.prefix(200).description)
        }

        let decoded: CloudVentResponse
        do {
            decoded = try JSONDecoder().decode(CloudVentResponse.self, from: data)
        } catch {
            throw CloudVentError.decode
        }
        let trimmed = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CloudVentError.empty
        }
        return CloudVentResponse(text: trimmed, model: decoded.model, remaining: decoded.remaining)
    }
}

/// Minimal Codable shim so we can read the `remaining` int from a 429
/// without writing a dedicated error envelope type.
private struct AnyCodable: Decodable {
    let value: Any
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let i = try? c.decode(Int.self) { value = i; return }
        if let d = try? c.decode(Double.self) { value = d; return }
        if let s = try? c.decode(String.self) { value = s; return }
        if let b = try? c.decode(Bool.self) { value = b; return }
        value = NSNull()
    }
}
