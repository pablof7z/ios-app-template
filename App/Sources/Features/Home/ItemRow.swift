import SwiftUI

// MARK: - Item Row

struct ItemRow: View {
    let item: Item

    private enum Layout {
        /// Point size of the checkmark circle icon.
        static let checkmarkSize: CGFloat = 22
    }

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: Layout.checkmarkSize, weight: .regular))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                Text(item.title)
                    .font(AppTheme.Typography.body)
                    .lineLimit(2)
                if let reminder = item.reminderAt {
                    let rel = ReminderLabel.from(reminder)
                    Label(rel.text, systemImage: "bell.fill")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(rel.color)
                }
            }
            Spacer(minLength: 0)
            sourceIcon
        }
        .padding(.vertical, AppTheme.Spacing.xs)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if item.isPriority {
            Image(systemName: "star.fill")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.yellow)
        }
        switch item.source {
        case .agent:
            Image(systemName: "sparkle")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .voice:
            Image(systemName: "mic.fill")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
        case .manual:
            EmptyView()
        }
    }
}

// MARK: - Reminder Label

struct ReminderLabel {
    let text: String
    let color: Color

    static func from(_ date: Date) -> ReminderLabel {
        let cal = Calendar.current
        let now = Date()
        let timeStr = date.formatted(date: .omitted, time: .shortened)

        if date < now {
            if cal.isDateInToday(date) {
                return ReminderLabel(text: "Today, \(timeStr)", color: .red)
            } else if cal.isDateInYesterday(date) {
                return ReminderLabel(text: "Yesterday, \(timeStr)", color: .red)
            } else {
                return ReminderLabel(text: "Overdue · \(date.formatted(date: .abbreviated, time: .shortened))", color: .red)
            }
        } else if cal.isDateInToday(date) {
            return ReminderLabel(text: "Today, \(timeStr)", color: .orange)
        } else if cal.isDateInTomorrow(date) {
            return ReminderLabel(text: "Tomorrow, \(timeStr)", color: .orange)
        } else if let days = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: cal.startOfDay(for: date)).day,
                  days <= 6 {
            let weekday = date.formatted(.dateTime.weekday(.wide))
            return ReminderLabel(text: "\(weekday), \(timeStr)", color: .secondary)
        } else {
            return ReminderLabel(text: date.formatted(date: .abbreviated, time: .shortened), color: .secondary)
        }
    }
}
