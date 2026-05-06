import SwiftUI

// Layout constants live in ItemLayout (HomeViewModels.swift) and are
// shared with ItemComposeSheet, ItemRow, and CompletedItemRow to keep icon sizes
// and reminder defaults consistent across all item surfaces.

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
    @State private var colorLabel: ItemColor? = nil
    @State private var dueDateEnabled: Bool = false
    @State private var dueDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var reminderEnabled: Bool = false
    @State private var reminderDate: Date = Date().addingTimeInterval(ItemLayout.defaultReminderOffset)
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
                        .keyboardShortcut(.cancelAction)
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
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .applyZoomTransition(sourceID: sourceID, namespace: namespace)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .userActivity(HandoffActivityType.editItem) { activity in
            // Donate a Handoff activity so the user can continue editing
            // this item on another nearby device (iPad, Mac, etc.).
            activity.title = item.title
            activity.isEligibleForHandoff = true
            activity.userInfo = [
                HandoffUserInfoKey.itemID: item.id.uuidString,
                HandoffUserInfoKey.itemTitle: item.title,
            ]
        }
        .onAppear {
            title = item.title
            details = item.details
            isPriority = item.isPriority
            recurrence = item.recurrence
            colorLabel = item.colorLabel
            dueDateEnabled = item.dueDate != nil
            dueDate = item.dueDate ?? Calendar.current.startOfDay(for: Date())
            reminderEnabled = item.reminderAt != nil
            reminderDate = item.reminderAt ?? Date().addingTimeInterval(ItemLayout.defaultReminderOffset)
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
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let titleChanged = trimmed != item.title
        let detailsChanged = details != item.details
        let priorityChanged = isPriority != item.isPriority
        let recurrenceChanged = recurrence != item.recurrence
        let colorLabelChanged = colorLabel != item.colorLabel
        let dueDateChanged = dueDateEnabled != (item.dueDate != nil)
            || (dueDateEnabled && !Calendar.current.isDate(dueDate, inSameDayAs: item.dueDate ?? .distantPast))
        let reminderChanged = reminderEnabled != (item.reminderAt != nil)
            || (reminderEnabled && reminderDate != item.reminderAt)
        return titleChanged || detailsChanged || priorityChanged || recurrenceChanged
            || colorLabelChanged || dueDateChanged || reminderChanged
    }

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var updated = item
        updated.title = trimmed
        updated.details = details
        updated.isPriority = isPriority
        updated.recurrence = recurrence
        updated.colorLabel = colorLabel

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

// MARK: - Zoom transition helper
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
