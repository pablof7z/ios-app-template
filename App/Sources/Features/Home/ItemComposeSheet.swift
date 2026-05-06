import SwiftUI

// Layout constants live in ItemSheetLayout (HomeViewModels.swift) and are
// shared with ItemEditSheet to keep icon sizes and reminder defaults in sync.

struct ItemComposeSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""

    @State private var title: String = ""
    @State private var details: String = ""
    @State private var isPriority: Bool = false
    @State private var recurrence: Recurrence = .none
    @State private var dueDateEnabled: Bool = false
    @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var reminderDate: Date = Date().addingTimeInterval(ItemSheetLayout.defaultReminderOffset)
    @State private var reminderEnabled: Bool = false
    @State private var notificationDenied: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                background.ignoresSafeArea()
                editor
            }
            .navigationTitle("New item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if !initialTitle.isEmpty { title = initialTitle }
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
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var item = store.addItem(title: trimmed, source: .manual)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if isPriority || !trimmedDetails.isEmpty || recurrence != .none || dueDateEnabled {
            item.isPriority = isPriority
            item.details = trimmedDetails
            item.recurrence = recurrence
            item.dueDate = dueDateEnabled ? Calendar.current.startOfDay(for: dueDate) : nil
            store.updateItem(item)
        }

        if reminderEnabled {
            let scheduled = await NotificationService.scheduleReminder(
                for: item.id,
                title: trimmed,
                at: reminderDate
            )
            if scheduled {
                item.reminderAt = reminderDate
                store.updateItem(item)
            } else {
                notificationDenied = true
                Haptics.warning()
                return
            }
        }

        Haptics.success()
        dismiss()
    }

    // MARK: - Background

    private var background: LinearGradient {
        AppTheme.Gradients.itemSheetBackground
    }
}
