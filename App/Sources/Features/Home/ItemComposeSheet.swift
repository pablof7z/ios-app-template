import SwiftUI

// MARK: - Layout constants

private enum ComposeDefaults {
    /// Default offset applied to the current time when the reminder picker first appears.
    static let reminderOffset: TimeInterval = 3_600
}

struct ItemComposeSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""

    @State private var title: String = ""
    @State private var isPriority: Bool = false
    @State private var reminderDate: Date = Date().addingTimeInterval(ComposeDefaults.reminderOffset)
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
        .presentationDetents([.height(reminderEnabled ? 360 : 260), .medium])
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
            priorityRow
            reminderRow
            if notificationDenied {
                deniedBanner
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .animation(AppTheme.Animation.spring, value: reminderEnabled)
        .animation(AppTheme.Animation.spring, value: notificationDenied)
    }

    private var titleField: some View {
        HStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .regular))
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
        if isPriority {
            item.isPriority = true
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
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color.green.opacity(0.05),
                Color.teal.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
