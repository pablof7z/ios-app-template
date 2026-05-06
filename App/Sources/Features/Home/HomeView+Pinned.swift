import SwiftUI

// MARK: - Pinned (Priority) Section

extension HomeView {

    // MARK: Predicates

    /// Returns `true` when the pinned-items grouping should be active.
    ///
    /// Pinning is deliberately narrow in scope:
    /// - Only when the default sort (Newest First) is selected — manual priority
    ///   overriding any other sort mode would confuse expectations.
    /// - Suppressed while the overdue section is showing — the two sections would
    ///   fight for the same items (a priority item can also be overdue).
    /// - Suppressed while searching or in edit mode, matching the overdue rule.
    var showPinnedSection: Bool {
        guard !isSearching, !isEditing else { return false }
        guard !showOverdueSection else { return false }
        return currentSort == .dateAddedDesc && !pinnedItems.isEmpty
    }

    /// Priority items that pass all active filters, shown in the Pinned section.
    var pinnedItems: [Item] {
        guard currentSort == .dateAddedDesc, !isSearching, !isEditing else { return [] }
        return filteredActiveItems.filter(\.isPriority)
    }

    /// Non-priority items to display below the Pinned section when pinning is active.
    var nonPinnedItems: [Item] {
        guard showPinnedSection else { return filteredActiveItems }
        return filteredActiveItems.filter { !$0.isPriority }
    }

    // MARK: - Pinned Section View

    @ViewBuilder
    var pinnedSection: some View {
        if !pinnedItems.isEmpty {
            Section {
                ForEach(pinnedItems) { item in
                    itemRow(for: item)
                        .listRowBackground(Color.yellow.opacity(0.06))
                }
            } header: {
                pinnedSectionHeader
            }
        }
    }

    private var pinnedSectionHeader: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text("Pinned")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("(\(pinnedItems.count))")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
