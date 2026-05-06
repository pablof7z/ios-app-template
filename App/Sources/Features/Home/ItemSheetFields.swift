import SwiftUI

// MARK: - Shared field-row views for ItemComposeSheet and ItemEditSheet
//
// These views are identical in both sheets. Extracting them here means
// field-level changes only need to be made in one place.

// MARK: - Title field

/// The leading-checkmark + text-field row used at the top of both sheets.
struct ItemTitleField: View {
    @Binding var title: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: ItemSheetLayout.checkmarkSize, weight: .regular))
                .foregroundStyle(.green)
            TextField("What needs doing?", text: $title)
                .font(AppTheme.Typography.body)
                .focused(isFocused)
                .submitLabel(.done)
                .onSubmit(onSubmit)
        }
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }
}

// MARK: - Details field

/// The multiline details text-field row.
struct ItemDetailsField: View {
    @Binding var details: String

    var body: some View {
        HStack(alignment: .top, spacing: AppTheme.Spacing.md) {
            Image(systemName: "text.alignleft")
                .font(.system(size: ItemSheetLayout.rowIconSize, weight: .regular))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            TextField(
                "Add details…",
                text: $details,
                axis: .vertical
            )
            .font(AppTheme.Typography.callout)
            .foregroundStyle(.primary)
            .lineLimit(3...8)
            .accessibilityLabel("Item details")
        }
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }
}

// MARK: - Priority row

/// A toggle row for marking an item as priority / starred.
struct ItemPriorityRow: View {
    @Binding var isPriority: Bool

    var body: some View {
        Toggle(isOn: $isPriority) {
            Label("Priority", systemImage: isPriority ? "star.fill" : "star")
                .font(AppTheme.Typography.body)
                .foregroundStyle(isPriority ? .yellow : .secondary)
        }
        .tint(.yellow)
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }
}

// MARK: - Recurrence row

/// A picker row for choosing item recurrence (None / Daily / Weekly / Monthly).
struct ItemRecurrenceRow: View {
    @Binding var recurrence: Recurrence

    var body: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: Recurrence.daily.systemImage)
                .font(.system(size: ItemSheetLayout.rowIconSize, weight: .regular))
                .foregroundStyle(recurrence != .none ? Color.teal : .secondary)
            Picker("Repeats", selection: $recurrence) {
                ForEach(Recurrence.allCases, id: \.self) { period in
                    Text(period.label).tag(period)
                }
            }
            .pickerStyle(.menu)
            .font(AppTheme.Typography.body)
            .tint(recurrence != .none ? Color.teal : .secondary)
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }
}

// MARK: - Due date row

/// Toggle + inline DatePicker for an optional due date.
struct ItemDueDateRow: View {
    @Binding var dueDateEnabled: Bool
    @Binding var dueDate: Date

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Toggle(isOn: $dueDateEnabled) {
                Label("Due date", systemImage: "calendar")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(dueDateEnabled ? .pink : .secondary)
            }
            .tint(.pink)
            .padding(AppTheme.Spacing.md)
            .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))

            if dueDateEnabled {
                DatePicker(
                    "Due date",
                    selection: $dueDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Reminder row

/// Toggle + inline DatePicker for an optional reminder notification.
struct ItemReminderRow: View {
    @Binding var reminderEnabled: Bool
    @Binding var reminderDate: Date

    var body: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Toggle(isOn: $reminderEnabled) {
                Label("Remind me", systemImage: "bell.fill")
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(reminderEnabled ? .orange : .secondary)
            }
            .tint(.orange)
            .padding(AppTheme.Spacing.md)
            .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))

            if reminderEnabled {
                DatePicker(
                    "Reminder time",
                    selection: $reminderDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(AppTheme.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Notifications-denied banner

/// Inline warning shown when the user tries to set a reminder but notifications
/// are disabled at the system level.
struct ItemNotificationDeniedBanner: View {
    var body: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.orange)
            Text("Notifications are disabled. Enable them in Settings to receive reminders.")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular.tint(.orange.opacity(0.08)), in: .rect(cornerRadius: AppTheme.Corner.md))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
