import Foundation
import UserNotifications

/// Schedules and cancels local reminder notifications for Items.
///
/// Permissions are requested lazily — only when a user actually sets a
/// reminder — so the app never bothers users who don't use this feature.
///
/// Notification identifiers are namespaced as "reminder:<item-uuid>" so
/// cancellation is exact and never touches unrelated system notifications.
@MainActor
enum NotificationService {

    // MARK: - Identifier

    private static func identifier(for itemID: UUID) -> String {
        "reminder:\(itemID.uuidString)"
    }

    // MARK: - Authorization

    /// Requests authorization for alerts, sounds, and badges.
    /// Returns `true` if permission was granted (or already granted).
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    // MARK: - Schedule

    /// Schedules a reminder notification for an item at the given date.
    ///
    /// Automatically cancels any existing notification for the same item
    /// before scheduling a new one, so calling this on edit is idempotent.
    ///
    /// - Returns: `false` if notification permission was denied.
    @discardableResult
    static func scheduleReminder(for itemID: UUID, title: String, at date: Date) async -> Bool {
        guard date > Date() else { return false }

        let granted = await requestAuthorization()
        guard granted else { return false }

        // Cancel any previous reminder for this item before scheduling.
        cancel(for: itemID)

        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        content.body = title.isEmpty ? "You have a task due." : title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier(for: itemID),
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Cancel

    /// Cancels a pending reminder for the given item, if any.
    static func cancel(for itemID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: itemID)])
    }

    // MARK: - Batch cancel

    /// Cancels pending reminders for multiple items. Useful during clearAllData.
    static func cancelAll(for itemIDs: [UUID]) {
        let ids = itemIDs.map { identifier(for: $0) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
