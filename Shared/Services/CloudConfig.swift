import Foundation

/// Cloud Vent / Feral configuration. The endpoint is the Cloudflare
/// Worker URL owned by the developer; OpenRouter API keys live as a
/// Wrangler secret on the Worker, never in the iOS binary.
///
/// Replace `ventEndpointString` after running `npx wrangler deploy` —
/// the deploy step prints your `https://roastmate-vent.<subdomain>.workers.dev`
/// URL, paste it here verbatim, then ship.
enum CloudConfig {
    /// Deployed Worker URL (no trailing slash on the host). The path
    /// `/v1/vent` is appended automatically. Swap to a different
    /// subdomain if the Worker ever moves; the iOS app needs no other
    /// changes since the request/response contract is stable.
    private static let ventEndpointString = "https://roastmate-vent.yyyyy-yeyuhe.workers.dev"

    /// Resolved URL the client posts to.
    static let ventEndpoint: URL = URL(string: "\(ventEndpointString)/v1/vent")!

    /// True once the developer has replaced the placeholder host with a
    /// real Worker URL. The `RoastEngine` falls back to fully-local
    /// Foundation Models when this is false, regardless of the user's
    /// setting, so a fresh-clone or pre-deploy build still works.
    static var isConfigured: Bool {
        guard let host = ventEndpoint.host else { return false }
        // Block both the original placeholder host and any future
        // example domains so a misconfigured fork can't accidentally
        // proxy through the wrong endpoint.
        return !host.contains("example.workers.dev")
    }

    /// Network timeout — DeepSeek V3 via OpenRouter typically responds
    /// in 2–6 seconds; 25s leaves slack for cold path + edge variability
    /// without dragging the UI loading state forever.
    static let requestTimeout: TimeInterval = 25
}
