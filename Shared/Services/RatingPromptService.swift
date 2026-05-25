import Foundation
#if os(iOS) && !APP_EXTENSION
import UIKit
import StoreKit
#elseif os(macOS) && !APP_EXTENSION
import AppKit
import StoreKit
#endif

/// ε1 (Phase 3, 2026-07): in-app App Store rating prompt.
///
/// Trigger contract — the prompt fires on the FIRST of:
///   • a successful Share-Sheet open from the share card, OR
///   • the third successful generation in the same app session.
///
/// CRITICAL: `notifySuccessful*()` must NOT be called after a refusal,
/// a safety filter drop, a network error, or any other non-success path.
/// Calling on failure trains Apple's prompt-rate signal against us and
/// annoys users who are already mid-bad-experience.
///
/// Throttling: Apple StoreKit enforces a global 3-per-365-days server-side
/// limit; we also enforce at-most-one prompt per app session so a heavy
/// user doesn't see two prompts in the same launch.
public final class RatingPromptService: @unchecked Sendable {
    public static let shared = RatingPromptService()

    private let requestReviewHook: @Sendable () -> Void
    private let queue = DispatchQueue(label: "yyh.roastmate.rating.prompt")
    private var hasPromptedThisSession = false
    private var successfulGenerationsThisSession = 0

    public convenience init() {
        self.init(requestReviewHook: Self.defaultRequestReview)
    }

    init(requestReviewHook: @escaping @Sendable () -> Void) {
        self.requestReviewHook = requestReviewHook
    }

    /// Resets per-session counters. Called from `RoastMateApp.bootstrap()`
    /// on cold launch so the 3-generations gate starts fresh.
    public func resetSession() {
        queue.sync {
            hasPromptedThisSession = false
            successfulGenerationsThisSession = 0
        }
    }

    /// Call from the SUCCESS path of any generation (cloud or on-device).
    /// Never call on safety filter drops, refusals, or errors.
    public func notifySuccessfulGeneration() {
        let shouldPrompt: Bool = queue.sync {
            successfulGenerationsThisSession += 1
            guard !hasPromptedThisSession else { return false }
            return successfulGenerationsThisSession >= 3
        }
        if shouldPrompt { fireReviewRequest() }
    }

    /// Call from the SUCCESS path of share (Share Sheet opened, not
    /// dismissed). Never call on share-sheet dismiss/cancel.
    public func notifySuccessfulShare() {
        let shouldPrompt: Bool = queue.sync {
            guard !hasPromptedThisSession else { return false }
            return true
        }
        if shouldPrompt { fireReviewRequest() }
    }

    var debugGenerationCount: Int {
        queue.sync { successfulGenerationsThisSession }
    }

    var debugDidPromptThisSession: Bool {
        queue.sync { hasPromptedThisSession }
    }

    private func fireReviewRequest() {
        queue.sync { hasPromptedThisSession = true }
        requestReviewHook()
    }

    @Sendable private static func defaultRequestReview() {
        #if os(iOS) && !APP_EXTENSION
        DispatchQueue.main.async {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                AppStore.requestReview(in: scene)
            }
        }
        #elseif os(macOS) && !APP_EXTENSION
        DispatchQueue.main.async {
            if let controller = NSApplication.shared.keyWindow?.contentViewController
                ?? NSApplication.shared.mainWindow?.contentViewController {
                AppStore.requestReview(in: controller)
            }
        }
        #endif
        // watchOS, iOS/macOS app extensions: no-op (extensions never
        // present an App Store review prompt; UIApplication.shared is
        // unavailable there anyway).
    }
}
