import SwiftUI

struct HomeActivityFeed: View {
    let entries: [AgentActivityEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Text("Recent activity")
                    .font(AppTheme.Typography.headline)
                Spacer()
                if !entries.isEmpty {
                    Text("\(entries.count)")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .glassEffect(.regular, in: .capsule)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xs)

            if entries.isEmpty {
                emptyState
            } else {
                GlassEffectContainer(spacing: AppTheme.Spacing.sm) {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            ActivityRow(entry: entry)
                            if index < entries.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                                    .opacity(0.4)
                            }
                        }
                    }
                    .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse, options: .repeating)
            Text("No agent activity yet")
                .font(AppTheme.Typography.headline)
                .foregroundStyle(.primary)
            Text("Once the agent makes changes on your behalf, they'll show up here with quick undo.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppTheme.Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
        .padding(.horizontal, AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }
}

// MARK: - Activity row

private struct ActivityRow: View {
    let entry: AgentActivityEntry

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: entry.kind.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(entry.undone ? AnyShapeStyle(.tertiary) : AnyShapeStyle(tintColor))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(entry.undone ? .secondary : .primary)
                    .strikethrough(entry.undone, color: .secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(relativeTimestamp(entry.timestamp))
                    .font(AppTheme.Typography.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }

            Spacer(minLength: 0)

            if entry.undone {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
                    .accessibilityLabel("Undone")
            }
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var tintColor: Color { entry.kind.tint }

    private func relativeTimestamp(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 5 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86_400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86_400))d ago"
    }
}
