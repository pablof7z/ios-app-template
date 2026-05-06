import SwiftUI

// MARK: - Overdue Section

extension HomeView {

    // MARK: Predicates

    /// Returns `true` when overdue grouping is active in the current sort mode.
    /// Only shown in the two sort modes where temporal ordering is meaningful.
    var showOverdueSection: Bool {
        guard !isSearching, !isEditing, currentTodayFilter == .all else { return false }
        return currentSort == .dateAddedDesc || currentSort == .dueDateAsc
    }

    /// Items that have a past due date (day-granular) and pass all active filters.
    var overdueItems: [Item] {
        guard showOverdueSection else { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        return filteredActiveItems.filter { item in
            guard let due = item.dueDate else { return false }
            return Calendar.current.startOfDay(for: due) < today
        }
    }

    /// Active items that are NOT overdue — the main items list content when grouping is active.
    var nonOverdueItems: [Item] {
        guard showOverdueSection else { return filteredActiveItems }
        let today = Calendar.current.startOfDay(for: Date())
        return filteredActiveItems.filter { item in
            guard let due = item.dueDate else { return true }
            return Calendar.current.startOfDay(for: due) >= today
        }
    }

    // MARK: - Overdue Section View

    @ViewBuilder
    var overdueSection: some View {
        if !overdueItems.isEmpty {
            Section {
                ForEach(overdueItems) { item in
                    itemRow(for: item)
                        .listRowBackground(Color.red.opacity(0.06))
                }
            } header: {
                overdueSectionHeader
            }
        }
    }

    private var overdueSectionHeader: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
            Text("Overdue")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .foregroundStyle(.red)
            Text("(\(overdueItems.count))")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.red.opacity(0.7))
        }
    }
}
