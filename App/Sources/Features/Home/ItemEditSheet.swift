import SwiftUI

// Layout constants live in ItemSheetLayout (HomeViewModels.swift) and are
// shared with ItemComposeSheet to keep icon sizes and reminder defaults in sync.

struct ItemEditSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let item: Item
    var sourceID: UUID? = nil
    var namespace: Namespace.ID? = nil

    @State private var title: String = ""
    @State private var details: String = ""
    @State private var isPriority: Bool = false
    @State private var recurrence: Recurrence = .none
    @State private var dueDateEnabled: Bool = false
    @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var reminderEnabled: Bool = false
    @State private var reminderDate: Date = Date().addingTimeInterval(ItemSheetLayout.defaultReminderOffset)
    @State private var notificationDenied: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                editor
            }
            .navigationTitle("Edit item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: item.shareText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share item")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .applyZoomTransition(sourceID: sourceID, namespace: namespace)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            title = item.title
            details = item.details
            isPriority = item.isPriority
            recurrence = item.recurrence
            dueDateEnabled = item.dueDate != nil
            dueDate = item.dueDate ?? Calendar.current.startOfDay(for: Date())
            reminderEnabled = item.reminderAt != nil
            reminderDate = item.reminderAt ?? Date().addingTimeInterval(ItemSheetLayout.defaultReminderOffset)
            isFocused = true
        }
    }

    // MARK: - Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            titleField
            detailsField
            priorityRow
            recurrenceRow
            dueDateRow
            reminderRow
            if notificationDenied {
                deniedBanner
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .animation(AppTheme.Animation.spring, value: dueDateEnabled)
        .animation(AppTheme.Animation.spring, value: reminderEnabled)
        .animation(AppTheme.Animation.spring, value: notificationDenied)
    }

    private var titleField: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: ItemSheetLayout.checkmarkSize, weight: .regular))
                .foregroundStyle(.green)
            TextField("What needs doing?", text: $title)
                .font(AppTheme.Typography.body)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit { Task { await save() } }
        }
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }

    private var detailsField: some View {
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

    private var priorityRow: some View {
        Toggle(isOn: $isPriority) {
            Label("Priority", systemImage: isPriority ? "star.fill" : "star")
                .font(AppTheme.Typography.body)
                .foregroundStyle(isPriority ? .yellow : .secondary)
        }
        .tint(.yellow)
        .padding(AppTheme.Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: AppTheme.Corner.lg))
    }

    private var recurrenceRow: some View {
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

    private var dueDateRow: some View {
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

    private var reminderRow: some View {
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

    private var deniedBanner: some View {
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

    // MARK: - Logic

    private var canSave: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let titleChanged = trimmed != item.title
        let detailsChanged = details != item.details
        let priorityChanged = isPriority != item.isPriority
        let recurrenceChanged = recurrence != item.recurrence
        let dueDateChanged = dueDateEnabled != (item.dueDate != nil)
            || (dueDateEnabled && !Calendar.current.isDate(dueDate, inSameDayAs: item.dueDate ?? .distantPast))
        let reminderChanged = reminderEnabled != (item.reminderAt != nil)
            || (reminderEnabled && reminderDate != item.reminderAt)
        return titleChanged || detailsChanged || priorityChanged || recurrenceChanged || dueDateChanged || reminderChanged
    }

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var updated = item
        updated.title = trimmed
        updated.details = details
        updated.isPriority = isPriority
        updated.recurrence = recurrence

        // Handle due date
        updated.dueDate = dueDateEnabled ? Calendar.current.startOfDay(for: dueDate) : nil

        // Handle reminder transitions
        let hadReminder = item.reminderAt != nil
        if reminderEnabled {
            let scheduled = await NotificationService.scheduleReminder(
                for: item.id,
                title: trimmed,
                at: reminderDate
            )
            if scheduled {
                updated.reminderAt = reminderDate
            } else {
                notificationDenied = true
                Haptics.warning()
                return
            }
        } else if hadReminder {
            // Reminder was turned off — cancel the pending notification
            NotificationService.cancel(for: item.id)
            updated.reminderAt = nil
        }

        store.updateItem(updated)
        Haptics.success()
        dismiss()
    }

    // MARK: - Background

    private var background: LinearGradient {
        AppTheme.Gradients.itemSheetBackground
    }
}

// MARK: - Zoom Transition Helper

private extension View {
    @ViewBuilder
    func applyZoomTransition(sourceID: UUID?, namespace: Namespace.ID?) -> some View {
        if let sourceID, let namespace {
            self.navigationTransition(.zoom(sourceID: sourceID, in: namespace))
        } else {
            self
        }
    }
}
