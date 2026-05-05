import Foundation

@MainActor
enum DeepLinkHandler {
    enum Link {
        case settings
        case feedback
        case newItem(title: String?)
    }

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
