import SwiftUI

// MARK: - Today Filter UI

extension HomeView {

    // MARK: Chip

    /// Pill-shaped toggle chip shown in the leading toolbar. Tapping switches between
    /// "All" and "Today" (items due or reminding today).
    var todayFilterChip: some View {
        let isActive = currentTodayFilter == .today
        return Button {
            todayFilterRaw = isActive ? TodayFilter.all.rawValue : TodayFilter.today.rawValue
        } label: {
            Label("Today", systemImage: "sun.max")
                .font(AppTheme.Typography.caption.weight(.semibold))
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(
                    isActive
                        ? Color.orange.opacity(0.15)
                        : Color.secondary.opacity(0.1),
                    in: Capsule()
                )
                .foregroundStyle(isActive ? Color.orange : Color.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isActive
                ? "Showing Today items — tap to show All"
                : "Filter to Today items"
        )
        .animation(AppTheme.Animation.spring, value: isActive)
    }

    // MARK: Empty state

    /// Shown inside the list when the Today filter is active but no items match.
    var todayEmptyState: some View {
        ContentUnavailableView(
            "Nothing due today",
            systemImage: "sun.max",
            description: Text("No items are due or reminding today.")
        )
    }
}
