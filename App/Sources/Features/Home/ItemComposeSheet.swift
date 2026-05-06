import SwiftUI

// Layout constants live in ItemLayout (HomeViewModels.swift) and are
// shared with ItemEditSheet, ItemRow, and CompletedItemRow to keep icon sizes
// and reminder defaults consistent across all item surfaces.

struct ItemComposeSheet: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var initialTitle: String = ""

    @State private var title: String = ""
    @State private var details: String = ""
    @State private var isPriority: Bool = false
    @State private var recurrence: Recurrence = .none
    @State private var colorLabel: ItemColor? = nil
    @State private var dueDateEnabled: Bool = false
    @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var reminderDate: Date = Date().addingTimeInterval(ItemLayout.defaultReminderOffset)
    @State private var reminderEnabled: Bool = false
    @State private var notificationDenied: Bool = false
    @FocusState private var isFocused: Bool
    @State private var showTemplatePicker: Bool = false

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
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showTemplatePicker = true
                    } label: {
                        Label("Templates", systemImage: "doc.badge.plus")
                    }
                    .accessibilityLabel("Choose a template")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .buttonStyle(.glassProminent)
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                ItemTemplatePicker { template in
                    applyTemplate(template)
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
            ItemTitleField(title: $title, isFocused: $isFocused) { Task { await save() } }
            ItemDetailsField(details: $details)
            ItemPriorityRow(isPriority: $isPriority)
            ItemColorPickerRow(selection: $colorLabel)
            ItemRecurrenceRow(recurrence: $recurrence)
            ItemDueDateRow(dueDateEnabled: $dueDateEnabled, dueDate: $dueDate)
            ItemReminderRow(reminderEnabled: $reminderEnabled, reminderDate: $reminderDate)
            if notificationDenied {
                ItemNotificationDeniedBanner()
            }
            Spacer(minLength: 0)
        }
        .padding(AppTheme.Spacing.md)
        .animation(AppTheme.Animation.spring, value: dueDateEnabled)
        .animation(AppTheme.Animation.spring, value: reminderEnabled)
        .animation(AppTheme.Animation.spring, value: notificationDenied)
    }

    // MARK: - Logic

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Applies all fields from a template, overwriting any previously typed values.
    /// Reminder state is intentionally not templated — a time-sensitive field
    /// should always be set deliberately by the user.
    private func applyTemplate(_ template: ItemTemplate) {
        withAnimation(AppTheme.Animation.spring) {
            title = template.title
            details = template.details
            isPriority = template.isPriority
            colorLabel = template.colorLabel
            recurrence = template.recurrence
        }
        Haptics.success()
    }

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var item = store.addItem(title: trimmed, source: .manual)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        if isPriority || !trimmedDetails.isEmpty || recurrence != .none || dueDateEnabled || colorLabel != nil {
            item.isPriority = isPriority
            item.details = trimmedDetails
            item.recurrence = recurrence
            item.dueDate = dueDateEnabled ? Calendar.current.startOfDay(for: dueDate) : nil
            item.colorLabel = colorLabel
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
