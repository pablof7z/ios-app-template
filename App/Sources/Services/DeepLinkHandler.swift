import Foundation

/// Parses `apptemplate://` deep-links into typed ``Link`` values.
///
/// All work is pure URL parsing with no shared state, so no actor isolation is required.
enum DeepLinkHandler {
    /// The set of deep-link destinations recognised by the app.
    enum Link {
        /// Opens the Settings screen.
        case settings
        /// Opens the Feedback sheet.
        case feedback
        /// Creates a new item, optionally pre-filling its title from the query string.
        case newItem(title: String?)
    }

    /// Converts a URL into a ``Link``, or returns `nil` if the URL is not a recognised deep-link.
    static func resolve(_ url: URL) -> Link? {
        guard url.scheme == "apptemplate" else { return nil }
        switch url.host {
        case "settings": return .settings
        case "feedback": return .feedback
        case "new-item":
            let title = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "title" })?.value
            return .newItem(title: title)
        default: return nil
        }
    }
}
