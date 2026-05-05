import StoreKit
import UIKit

@MainActor
enum ReviewPrompt {
    private static let actionCountKey  = "reviewPrompt.actionCount"
    private static let lastRequestKey  = "reviewPrompt.lastRequestDate"
    private static let requestCountKey = "reviewPrompt.requestCount"
    private static let cooldownSeconds: Double = 60 * 86_400   // 60 days

    /// Call this after a meaningful positive action (item completed, feedback sent, etc.).
    /// Gates on: total completions ≥ 5 and a 60-day cooldown between prompts.
    static func requestIfAppropriate(in scene: UIWindowScene? = nil) {
        let defaults = UserDefaults.standard
        let actionCount = defaults.integer(forKey: actionCountKey)
        guard actionCount >= 5 else { return }

        let lastRequest = defaults.double(forKey: lastRequestKey)
        let elapsed = lastRequest == 0 ? Double.infinity : Date().timeIntervalSince1970 - lastRequest
        guard elapsed > cooldownSeconds else { return }

        defaults.set(Date().timeIntervalSince1970, forKey: lastRequestKey)
        defaults.set(defaults.integer(forKey: requestCountKey) + 1, forKey: requestCountKey)

        if let scene {
            SKStoreReviewController.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview()
        }
    }

    /// Increments a "meaningful action" counter. Call after item marked done.
    static func recordMeaningfulAction() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: actionCountKey) + 1, forKey: actionCountKey)
        requestIfAppropriate()
    }
}
