import SwiftUI

/// A prominent hero card surfacing the first active item as "Next."
/// Inspired by the win-the-day TodayPagerView nextActionHero pattern.
///
/// Visibility rules:
/// - Hidden when there are no active items to show.
/// - Hidden while the user is searching (search has its own focus model).
/// - Only renders when `item` is non-nil (caller guards this).
struct NextActionHero: View {
    let item: Item
    let itemCount: Int
    let namespace: Namespace.ID
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            card
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: item.id, in: namespace)
        .accessibilityLabel("Next action: \(item.title). Double-tap to edit.")
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            eyebrow
            titleText
            if let reminder = item.reminderAt {
                reminderBadge(reminder)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppTheme.Spacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous))
        .appShadow(AppTheme.Shadow.card)
    }

    private var eyebrow: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            Text("NEXT")
                .font(.caption2.weight(.bold))
                .tracking(1.6)
                .foregroundStyle(Color.accentColor)
            if itemCount > 1 {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }
            Spacer(minLength: 0)
            if item.isPriority {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private var titleText: some View {
        Text(item.title)
            .font(AppTheme.Typography.title)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reminderBadge(_ date: Date) -> some View {
        let rel = ReminderLabel.from(date)
        return Label(rel.text, systemImage: "bell.fill")
            .font(AppTheme.Typography.caption)
            .foregroundStyle(rel.color)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Corner.lg, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
            )
    }
}
