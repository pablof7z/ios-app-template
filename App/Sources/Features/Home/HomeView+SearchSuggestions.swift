import SwiftUI

// MARK: - Search suggestion constants

private enum SearchSuggestionLayout {
    /// SF Symbol for the recent-search clock icon (available iOS 17+).
    static let clockIcon = "clock.arrow.circlepath"
}

// MARK: - HomeView search suggestions

extension HomeView {

    // MARK: - Suggestion list

    /// Content provided to `.searchSuggestions { }`.
    /// SwiftUI shows this automatically while the search field is presented.
    /// Reading `recentSearches.searches` (the `@Observable` store) means
    /// SwiftUI re-renders whenever entries are added, removed, or cleared.
    @ViewBuilder
    var searchSuggestions: some View {
        let recents = recentSearches.searches
        if !recents.isEmpty {
            Section {
                ForEach(recents, id: \.self) { term in
                    searchSuggestionRow(for: term)
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    Button {
                        recentSearches.clearAll()
                        Haptics.light()
                    } label: {
                        Text("Clear")
                            .font(AppTheme.Typography.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Individual suggestion row

    private func searchSuggestionRow(for term: String) -> some View {
        Label(term, systemImage: SearchSuggestionLayout.clockIcon)
            .foregroundStyle(.secondary)
            // `.searchCompletion` wires the tap → fill `searchText` behaviour.
            .searchCompletion(term)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    recentSearches.remove(term)
                    Haptics.light()
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
    }

    // MARK: - Record on submit

    /// Call via `.onSubmit(of: .search)` to persist the current query.
    func recordSearch() {
        recentSearches.record(searchText)
    }
}
