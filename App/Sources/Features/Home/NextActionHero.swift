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

    // MARK: - Layout constants

    private enum Layout {
        /// Letter-spacing applied to the "NEXT" eyebrow label.
        static let eyebrowTracking: CGFloat = 1.6
        /// Opacity of the multi-item chevron icon beside the "NEXT" label.
        static let chevronOpacity: Double = 0.7
        /// Maximum number of lines allowed for the item title.
        static let titleLineLimit: Int = 3
        /// Opacity of the accent-color border around the card.
        static let borderOpacity: Double = 0.18
        /// Width of the accent-color border stroke.
        static let borderLineWidth: CGFloat = 1
    }

    // MARK: - Accessibility

    /// Combined label read by VoiceOver — appends the reminder time when one exists
    /// because `.accessibilityLabel` overrides child element labels.
    private var accessibilityLabel: String {
        var parts = ["Next action: \(item.title)"]
        if item.isPriority { parts.append("Priority") }
        if let reminder = item.reminderAt {
            parts.append("Reminder: \(ReminderLabel.from(reminder).text)")
        }
        return parts.joined(separator: ". ")
    }

    var body: some View {
        Button(action: onTap) {
            card
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: item.id, in: namespace)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double-tap to edit")
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
                .tracking(Layout.eyebrowTracking)
                .foregroundStyle(Color.accentColor)
            if itemCount > 1 {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor.opacity(Layout.chevronOpacity))
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
            .lineLimit(Layout.titleLineLimit)
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
                    .strokeBorder(Color.accentColor.opacity(Layout.borderOpacity), lineWidth: Layout.borderLineWidth)
            )
    }
}
