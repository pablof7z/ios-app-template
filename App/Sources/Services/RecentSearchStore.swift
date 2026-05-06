import Foundation
import Observation

// MARK: - Constants

private enum RecentSearchConstants {
    /// Maximum number of recent searches to retain.
    static let maxCount = 5
    /// UserDefaults key for the persisted recent-searches list.
    static let storageKey = "home.recentSearches"
}

// MARK: - RecentSearchStore

/// Persists the last `maxCount` unique search terms the user has submitted
/// in the HomeView search bar. Newest queries appear first.
///
/// The `searches` property is `@Observable` so any SwiftUI view that reads it
/// will automatically re-render when entries are added, removed, or cleared.
/// Mutations write-through to `UserDefaults` for persistence across launches.
@MainActor
@Observable
final class RecentSearchStore {

    static let shared = RecentSearchStore()

    /// In-memory list of recent searches, newest first. Observed by SwiftUI.
    private(set) var searches: [String]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.searches = defaults.stringArray(forKey: RecentSearchConstants.storageKey) ?? []
    }

    /// Records `query` as the most-recent search.
    ///
    /// Trims whitespace, ignores blank strings, deduplicates (case-insensitive
    /// match removes the older copy), and caps the list at `maxCount`.
    func record(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var updated = searches
        // Remove any existing entry with the same text (case-insensitive) so
        // the new copy lands at the front rather than creating a duplicate.
        updated.removeAll { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }
        updated.insert(trimmed, at: 0)
        if updated.count > RecentSearchConstants.maxCount {
            updated = Array(updated.prefix(RecentSearchConstants.maxCount))
        }
        searches = updated
        defaults.set(searches, forKey: RecentSearchConstants.storageKey)
    }

    /// Removes a single entry from the recent-searches list.
    func remove(_ query: String) {
        searches.removeAll { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
        defaults.set(searches, forKey: RecentSearchConstants.storageKey)
    }

    /// Clears the entire recent-searches history.
    func clearAll() {
        searches = []
        defaults.removeObject(forKey: RecentSearchConstants.storageKey)
    }
}
