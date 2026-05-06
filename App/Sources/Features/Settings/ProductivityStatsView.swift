import SwiftUI

// MARK: - Productivity Stats View

/// Shows a summary of item-completion activity: totals, streak, and source breakdown.
/// Data is derived entirely from `AppStateStore` — no schema changes required.
struct ProductivityStatsView: View {
    @Environment(AppStateStore.self) private var store

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            if stats.totalCompleted == 0 {
                emptyState
            } else {
                statsList
            }
        }
        .navigationTitle("Productivity")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Computed stats

    private var stats: CompletionStats {
        CompletionStats(items: store.state.items)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: AppTheme.Spacing.xs) {
                Text("No completions yet")
                    .font(AppTheme.Typography.title)
                Text("Complete items on the Home tab to see your progress here.")
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main list

    private var statsList: some View {
        List {
            heroSection
            weekSection
            streakSection
            sourceSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Hero (all-time)

    private var heroSection: some View {
        Section {
            HeroStatCard(
                value: stats.totalCompleted,
                label: "items completed",
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: AppTheme.Spacing.xs,
                leading: AppTheme.Spacing.md,
                bottom: AppTheme.Spacing.xs,
                trailing: AppTheme.Spacing.md
            ))
        }
    }

    // MARK: - This-week breakdown

    private var weekSection: some View {
        Section("This Week") {
            LabeledStatRow(
                icon: "sun.max.fill",
                tint: .orange,
                label: "Completed Today",
                value: "\(stats.completedToday)"
            )
            LabeledStatRow(
                icon: "calendar.badge.checkmark",
                tint: .blue,
                label: "Completed This Week",
                value: "\(stats.completedThisWeek)"
            )
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        Section {
            LabeledStatRow(
                icon: "flame.fill",
                tint: streakTint,
                label: "Current Streak",
                value: streakLabel(stats.currentStreak)
            )
            LabeledStatRow(
                icon: "trophy.fill",
                tint: .yellow,
                label: "Longest Streak",
                value: streakLabel(stats.longestStreak)
            )
        } header: {
            Text("Streak")
        } footer: {
            Text("A streak counts consecutive calendar days where you completed at least one item.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var streakTint: Color {
        switch stats.currentStreak {
        case 0:       return .secondary
        case 1...2:   return .orange
        case 3...6:   return .orange
        default:      return .red
        }
    }

    private func streakLabel(_ days: Int) -> String {
        days == 1 ? "1 day" : "\(days) days"
    }

    // MARK: - Source breakdown

    private var sourceSection: some View {
        Section {
            SourceBreakdownRow(label: "Manual", count: stats.bySource.manual, total: stats.totalCompleted, tint: .teal)
            SourceBreakdownRow(label: "Agent",  count: stats.bySource.agent,  total: stats.totalCompleted, tint: .purple)
            SourceBreakdownRow(label: "Voice",  count: stats.bySource.voice,  total: stats.totalCompleted, tint: .pink)
        } header: {
            Text("By Source")
        } footer: {
            Text("Items created manually, by the AI agent, or via voice input.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - HeroStatCard

private struct HeroStatCard: View {

    private enum Layout {
        static let iconSize: CGFloat = 44
        static let valueFontSize: CGFloat = 56
        static let borderOpacity: Double = 0.15
        static let borderLineWidth: CGFloat = 1
    }

    let value: Int
    let label: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: Layout.iconSize, weight: .semibold))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.system(size: Layout.valueFontSize, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Text(label)
                    .font(AppTheme.Typography.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous))
        .appShadow(AppTheme.Shadow.card)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                    .strokeBorder(tint.opacity(Layout.borderOpacity), lineWidth: Layout.borderLineWidth)
            )
    }
}

// MARK: - LabeledStatRow

private struct LabeledStatRow: View {

    private enum Layout {
        static let iconBadgeSize: CGFloat = 29
        static let iconCorner: CGFloat = 7
        static let iconFontSize: CGFloat = 14
    }

    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.iconCorner, style: .continuous)
                    .fill(tint)
                    .frame(width: Layout.iconBadgeSize, height: Layout.iconBadgeSize)
                Image(systemName: icon)
                    .font(.system(size: Layout.iconFontSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)

            Text(label)
                .font(AppTheme.Typography.body)

            Spacer(minLength: AppTheme.Spacing.xs)

            Text(value)
                .font(AppTheme.Typography.body)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - SourceBreakdownRow

private struct SourceBreakdownRow: View {

    private enum Layout {
        static let barMaxWidth: CGFloat = 80
        static let barHeight: CGFloat = 6
        static let barMinFraction: CGFloat = 0.02
    }

    let label: String
    let count: Int
    let total: Int
    let tint: Color

    private var fraction: CGFloat {
        guard total > 0, count > 0 else { return 0 }
        return max(CGFloat(count) / CGFloat(total), Layout.barMinFraction)
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text(label)
                .font(AppTheme.Typography.body)
                .frame(minWidth: 60, alignment: .leading)

            GeometryReader { geo in
                let maxW = min(geo.size.width, Layout.barMaxWidth)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(tint.opacity(0.15))
                        .frame(height: Layout.barHeight)
                    Capsule()
                        .fill(tint)
                        .frame(width: fraction * maxW, height: Layout.barHeight)
                }
            }
            .frame(height: Layout.barHeight)

            Spacer(minLength: 0)

            Text("\(count)")
                .font(AppTheme.Typography.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(count) items")
    }
}

// MARK: - CompletionStats

/// Pure value type computed from `[Item]` — no side effects.
private struct CompletionStats {

    let totalCompleted: Int
    let completedToday: Int
    let completedThisWeek: Int
    let currentStreak: Int
    let longestStreak: Int
    let bySource: SourceCounts

    struct SourceCounts {
        let manual: Int
        let agent: Int
        let voice: Int
    }

    init(items: [Item]) {
        let done = items.filter { !$0.deleted && $0.status == .done }
        totalCompleted = done.count

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let weekStart: Date = {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            return cal.date(from: comps) ?? todayStart
        }()

        completedToday  = done.filter { $0.updatedAt >= todayStart }.count
        completedThisWeek = done.filter { $0.updatedAt >= weekStart }.count

        bySource = SourceCounts(
            manual: done.filter { $0.source == .manual }.count,
            agent:  done.filter { $0.source == .agent }.count,
            voice:  done.filter { $0.source == .voice }.count
        )

        // Build set of unique days that had at least one completion.
        let days: Set<String> = Set(done.map { item in
            let d = cal.startOfDay(for: item.updatedAt)
            return "\(cal.component(.year, from: d))-\(cal.component(.dayOfYear, from: d))"
        })

        // Sort unique completion days descending.
        let sortedDays = done
            .map { cal.startOfDay(for: $0.updatedAt) }
            .uniqued()
            .sorted(by: >)

        // Current streak: count consecutive days from the most-recent completion day.
        var current = 0
        if let mostRecent = sortedDays.first {
            var cursor = mostRecent
            for day in sortedDays {
                if cal.isDate(cursor, inSameDayAs: day) {
                    current += 1
                    cursor = cal.date(byAdding: .day, value: -1, to: cursor) ?? cursor
                } else {
                    break
                }
            }
        }
        currentStreak = current

        // Longest streak: walk the sorted unique days finding the longest run.
        var longest = 0
        var run = 0
        var prev: Date?
        for day in sortedDays.sorted() {
            if let p = prev, let expected = cal.date(byAdding: .day, value: 1, to: p), cal.isDate(expected, inSameDayAs: day) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
            prev = day
        }
        longestStreak = longest

        _ = days // suppress unused warning; used above for uniqueness check via sortedDays
    }
}

// MARK: - Array helper

private extension Array where Element == Date {
    /// Returns unique dates by calendar day, preserving order.
    func uniqued() -> [Date] {
        var seen = Set<String>()
        let cal = Calendar.current
        return filter { date in
            let d = cal.startOfDay(for: date)
            let key = "\(cal.component(.year, from: d))-\(cal.component(.dayOfYear, from: d))"
            return seen.insert(key).inserted
        }
    }
}
