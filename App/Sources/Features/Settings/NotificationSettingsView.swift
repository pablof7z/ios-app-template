import SwiftUI
import UserNotifications

// MARK: - NotificationSettingsView
//
// Settings → Notifications. Shows the current authorization status and the
// full list of pending reminder notifications. Users can cancel individual
// reminders with a swipe or tap "Open Settings" when permission is denied.
//
// Data is loaded async from UNUserNotificationCenter; only requests whose
// identifiers start with the "reminder:" prefix (managed by NotificationService)
// are shown. Each request is matched to its live Item so we can show the
// item title rather than the raw notification body.

struct NotificationSettingsView: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingReminders: [PendingReminder] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            List {
                permissionSection
                if authStatus != .denied {
                    remindersSection
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    // MARK: - Sections

    @ViewBuilder
    private var permissionSection: some View {
        Section("Status") {
            switch authStatus {
            case .authorized, .provisional, .ephemeral:
                SettingsRow(
                    icon: "bell.badge.fill",
                    tint: .green,
                    title: "Reminders allowed",
                    subtitle: "You'll be notified when items are due"
                )
            case .denied:
                SettingsRow(
                    icon: "bell.slash.fill",
                    tint: .red,
                    title: "Notifications blocked",
                    subtitle: "Enable in iOS Settings to receive reminders"
                )
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    SettingsRow(
                        icon: "gear",
                        tint: .blue,
                        title: "Open Settings"
                    )
                }
                .foregroundStyle(.primary)
            case .notDetermined:
                SettingsRow(
                    icon: "bell",
                    tint: .secondary,
                    title: "Not yet requested",
                    subtitle: "Permission is asked when you set a reminder"
                )
            @unknown default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section {
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if pendingReminders.isEmpty {
                ContentUnavailableView {
                    Label("No pending reminders", systemImage: "bell.slash")
                } description: {
                    Text("Set a reminder when adding or editing an item.")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(pendingReminders) { reminder in
                    reminderRow(reminder)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                cancel(reminder)
                            } label: {
                                Label("Cancel", systemImage: "bell.slash")
                            }
                        }
                }
            }
        } header: {
            Text("Scheduled Reminders")
        } footer: {
            if !isLoading && !pendingReminders.isEmpty {
                Text("\(pendingReminders.count) reminder\(pendingReminders.count == 1 ? "" : "s") pending · Swipe left to cancel.")
            }
        }
    }

    // MARK: - Row

    private func reminderRow(_ reminder: PendingReminder) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.orange)
                    .frame(width: 29, height: 29)
                Image(systemName: "bell.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(reminder.fireDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            if reminder.fireDate > Date() {
                Text(reminder.fireDate, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Data

    private func reload() async {
        isLoading = true
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let requests = await center.pendingNotificationRequests()

        authStatus = settings.authorizationStatus

        let reminderPrefix = "reminder:"
        let items = store.state.items

        pendingReminders = requests
            .filter { $0.identifier.hasPrefix(reminderPrefix) }
            .compactMap { request -> PendingReminder? in
                guard
                    let trigger = request.trigger as? UNCalendarNotificationTrigger,
                    let fireDate = trigger.nextTriggerDate()
                else { return nil }

                let uuidString = String(request.identifier.dropFirst(reminderPrefix.count))
                let title: String
                if let uuid = UUID(uuidString: uuidString),
                   let item = items.first(where: { $0.id == uuid }) {
                    title = item.title
                } else {
                    // Fall back to the notification body if the item was deleted.
                    title = request.content.body
                }
                return PendingReminder(
                    id: request.identifier,
                    itemID: UUID(uuidString: uuidString),
                    title: title,
                    fireDate: fireDate
                )
            }
            .sorted { $0.fireDate < $1.fireDate }

        isLoading = false
    }

    private func cancel(_ reminder: PendingReminder) {
        if let itemID = reminder.itemID {
            NotificationService.cancel(for: itemID)
            // Clear the stored reminder date from the item so the edit sheet
            // doesn't show a stale picker value.
            store.clearReminderDate(for: itemID)
        } else {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [reminder.id])
        }
        withAnimation {
            pendingReminders.removeAll { $0.id == reminder.id }
        }
        Haptics.selection()
    }
}

// MARK: - PendingReminder

private struct PendingReminder: Identifiable {
    let id: String
    let itemID: UUID?
    let title: String
    let fireDate: Date
}
