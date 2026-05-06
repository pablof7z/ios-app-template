import SwiftUI

// MARK: - Productivity Stats View

/// Shows a summary of item-completion activity: totals, streak, and source breakdown.
/// Data is derived entirely from `AppStateStore` — no schema changes required.
/// Sub-components (`HeroStatCard`, `LabeledStatRow`, `SourceBreakdownRow`, `CompletionStats`)
/// live in `ProductivityStatsComponents.swift`.
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
            streakHeroSection
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

    // MARK: - Streak hero

    private var streakHeroSection: some View {
        Section {
            StreakHeroCard(
                currentStreak: stats.currentStreak,
                longestStreak: stats.longestStreak
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(
                top: AppTheme.Spacing.xs,
                leading: AppTheme.Spacing.md,
                bottom: AppTheme.Spacing.xs,
                trailing: AppTheme.Spacing.md
            ))
        } header: {
            Text("Streak")
        } footer: {
            Text("A streak counts consecutive calendar days where you completed at least one item.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
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
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }
}
