import UIKit
import UserNotifications

@MainActor
enum BadgeManager {
    private static let center = UNUserNotificationCenter.current()

    /// Updates the app icon badge to reflect the number of pending items.
    /// Requests notification permission if needed (badge requires it on iOS).
    static func sync(pendingCount: Int) async {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            try? await center.requestAuthorization(options: [.badge])
        }
        try? await center.setBadgeCount(pendingCount)
    }

    /// Clears the badge (sets to 0).
    static func clear() async {
        try? await center.setBadgeCount(0)
    }
}
