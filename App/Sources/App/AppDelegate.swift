import UIKit

// MARK: - App Delegate

/// Handles UIKit lifecycle events that pure SwiftUI cannot receive,
/// specifically app-icon quick-action (home-screen shortcut) selection.
///
/// Wired in via `@UIApplicationDelegateAdaptor` in `AppMain`.
final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Shortcut type constants

    private enum ShortcutType {
        /// Matches the type defined in Info.plist for the "Add Item" quick action.
        static let addItem = "add-item"
        /// Matches the type defined in Info.plist for the "View Overdue" quick action.
        static let viewOverdue = "view-overdue"
    }

    // MARK: - Pending shortcut

    /// Shortcut selected while the app was not running (cold-launch path).
    /// `RootView` reads this on `.onAppear` and clears it after routing.
    var pendingShortcutURL: URL?

    // MARK: - UIApplicationDelegate

    /// Called when the user selects a quick action while the app is in the background.
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = handle(shortcutItem)
        completionHandler(handled)
    }

    // MARK: - Private

    /// Converts a shortcut item into a deep-link URL and posts it via NotificationCenter
    /// so `RootView` can route without a direct reference to the delegate.
    /// Returns `true` if the shortcut type was recognised.
    @discardableResult
    private func handle(_ item: UIApplicationShortcutItem) -> Bool {
        let suffix = item.type.components(separatedBy: ".").last ?? ""
        let urlString: String
        switch suffix {
        case ShortcutType.addItem:    urlString = "apptemplate://new-item"
        case ShortcutType.viewOverdue: urlString = "apptemplate://overdue"
        default: return false
        }
        guard let url = URL(string: urlString) else { return false }
        NotificationCenter.default.post(
            name: AppDelegate.shortcutURLNotification,
            object: url
        )
        return true
    }
}

// MARK: - Notification name

extension AppDelegate {
    /// Posted when a quick-action URL is ready to route.
    static let shortcutURLNotification = Notification.Name("AppDelegate.shortcutURL")
}
