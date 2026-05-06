import SwiftUI
import UserNotifications
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate", category: "NotificationSettingsView")

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

// MARK: - Layout constants

private enum Layout {
    /// Identifier prefix used by NotificationService to namespace reminder requests.
    static let reminderIDPrefix = "reminder:"
    /// Side length of the icon tile shown in each reminder row.
    static let iconTileSize: CGFloat = 29
    /// Corner radius of the icon tile shown in each reminder row.
    static let iconTileCorner: CGFloat = 7
    /// Point size of the bell icon inside the tile.
    static let iconSize: CGFloat = 14
    /// Horizontal spacing between the icon tile and the text in a reminder row.
    static let rowSpacing: CGFloat = 12
    /// Vertical spacing between the title and subtitle text.
    static let textSpacing: CGFloat = 2
    /// Minimum width of the trailing spacer in a reminder row.
    static let trailingSpacerMin: CGFloat = 4
}

struct NotificationSettingsView: View {
    @Environment(AppStateStore.self) private var store
    @Environment(\.openURL) private var openURL

    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var pendingReminders: [PendingReminder] = []
    @State private var isLoading = true

    /// Reminders grouped by relative-date bucket (Today / Tomorrow / This Week / Later).
    private var groupedReminders: [(bucket: ReminderDateBucket, reminders: [PendingReminder])] {
        let now = Date()
        let calendar = Calendar.current
        var dict: [ReminderDateBucket: [PendingReminder]] = [:]
        for reminder in pendingReminders {
            let key = ReminderDateBucket.bucket(for: reminder.fireDate, now: now, calendar: calendar)
            dict[key, default: []].append(reminder)
        }
        return ReminderDateBucket.allCases.compactMap { bucket in
            guard let reminders = dict[bucket], !reminders.isEmpty else { return nil }
            return (bucket, reminders)
        }
    }

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
                    subtitle: "Grant access so the app can deliver reminders"
                )
                AsyncButton {
                    await requestPermission()
                } label: {
                    SettingsRow(
                        icon: "bell.badge",
                        tint: .orange,
                        title: "Request Permission"
                    )
                }
                .foregroundStyle(.primary)
            @unknown default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var remindersSection: some View {
        if isLoading {
            Section("Scheduled Reminders") {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } else if pendingReminders.isEmpty {
            Section("Scheduled Reminders") {
                ContentUnavailableView {
                    Label("No pending reminders", systemImage: "bell.slash")
                } description: {
                    Text("Set a reminder when adding or editing an item.")
                }
                .listRowBackground(Color.clear)
            }
        } else {
            ForEach(groupedReminders, id: \.bucket) { group in
                Section(group.bucket.rawValue) {
                    ForEach(group.reminders) { reminder in
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
            }
            Section {
            } footer: {
                Text("\(pendingReminders.count) reminder\(pendingReminders.count == 1 ? "" : "s") pending · Swipe left to cancel.")
            }
        }
    }

    // MARK: - Row

    private func reminderRow(_ reminder: PendingReminder) -> some View {
        HStack(spacing: Layout.rowSpacing) {
            ZStack {
                RoundedRectangle(cornerRadius: Layout.iconTileCorner, style: .continuous)
                    .fill(Color.orange)
                    .frame(width: Layout.iconTileSize, height: Layout.iconTileSize)
                Image(systemName: "bell.fill")
                    .font(.system(size: Layout.iconSize, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: Layout.textSpacing) {
                Text(reminder.title)
                    .font(AppTheme.Typography.body)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(reminder.fireDate.formatted(date: .abbreviated, time: .shortened))
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: Layout.trailingSpacerMin)
            if reminder.fireDate > Date() {
                Text(reminder.fireDate, style: .relative)
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.vertical, AppTheme.Spacing.xs)
    }

    // MARK: - Data

    private func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            authStatus = granted ? .authorized : .denied
            Haptics.selection()
        } catch {
            logger.error("requestAuthorization failed: \(error, privacy: .public)")
        }
        await reload()
    }

    private func reload() async {
        isLoading = true
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let requests = await center.pendingNotificationRequests()

        authStatus = settings.authorizationStatus

        let items = store.state.items

        pendingReminders = requests
            .filter { $0.identifier.hasPrefix(Layout.reminderIDPrefix) }
            .compactMap { request -> PendingReminder? in
                guard
                    let trigger = request.trigger as? UNCalendarNotificationTrigger,
                    let fireDate = trigger.nextTriggerDate()
                else { return nil }

                let uuidString = String(request.identifier.dropFirst(Layout.reminderIDPrefix.count))
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

