import Foundation
import Observation
import os.log

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "AppTemplate", category: "AppStateStore")

/// Single source of truth. All mutations route through here so the `didSet`
/// observer can persist automatically. UI and agent both call the same methods.
@MainActor
@Observable
final class AppStateStore {

    var state: AppState {
        didSet {
            Persistence.save(state)
            SpotlightIndexer.reindex(state: state)
            Task { await BadgeManager.sync(pendingCount: self.activeItems.count) }
            // Push the current settings to iCloud KV store. The sync service
            // internally no-ops if an inbound merge is already in progress.
            iCloudSettingsSync.shared.push(state.settings)
        }
    }

    /// Retained observer token for iCloud external-change notifications.
    private var iCloudObserver: NSObjectProtocol?

    init() {
        var loadedState: AppState
        do {
            loadedState = try Persistence.load()
        } catch {
            logger.error("Persistence.load failed: \(error, privacy: .public) — starting with empty state")
            loadedState = AppState()
        }
        Self.migrateLegacyOpenRouterSecretIfNeeded(in: &loadedState)
        // Start iCloud KV sync before assigning state so that the first
        // push (triggered by the `didSet` below) reflects the merged values.
        iCloudSettingsSync.shared.start(mergingInto: &loadedState.settings)
        self.state = loadedState
        // Seed Spotlight with whatever was persisted before this launch — the
        // index can be wiped out independently of our app data (device reset,
        // reinstall, user clearing system search).
        SpotlightIndexer.reindex(state: loadedState)
        // Observe external iCloud changes so settings stay in sync while the
        // app is running on multiple devices simultaneously.
        iCloudObserver = NotificationCenter.default.addObserver(
            forName: iCloudSettingsSync.settingsDidChangeExternallyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applyExternalSettingsChange()
            }
        }
    }

    /// Pulls the latest iCloud values into `state.settings`.
    /// Called when `iCloudSettingsSync` reports an external change.
    private func applyExternalSettingsChange() {
        let sync = iCloudSettingsSync.shared
        sync.isApplyingRemoteChange = true
        defer { sync.isApplyingRemoteChange = false }
        var updated = state.settings
        sync.merge(from: NSUbiquitousKeyValueStore.default, into: &updated)
        guard updated != state.settings else { return }
        logger.info("iCloudSettingsSync: applying remote settings update")
        // Assign directly (bypassing updateSettings) to avoid a redundant push.
        state.settings = updated
    }

    private static func migrateLegacyOpenRouterSecretIfNeeded(in state: inout AppState) {
        let legacyKey = state.settings.legacyOpenRouterAPIKey?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !legacyKey.isEmpty else {
            state.settings.legacyOpenRouterAPIKey = nil
            return
        }

        do {
            try OpenRouterCredentialStore.saveAPIKey(legacyKey)
            state.settings.markOpenRouterManual()
        } catch {
            logger.error("Failed to migrate legacy OpenRouter key to keychain: \(error, privacy: .public)")
            state.settings.clearOpenRouterCredential()
        }
        Persistence.save(state)
    }

    // MARK: - Items

    @discardableResult
    func addItem(title: String, source: ItemSource = .manual, friendID: UUID? = nil, friendName: String? = nil) -> Item {
        var item = Item(title: title, source: source)
        item.requestedByFriendID = friendID
        item.requestedByDisplayName = friendName
        state.items.append(item)
        return item
    }

    func setItemStatus(_ id: UUID, status: ItemStatus) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        let completed = state.items[idx]
        state.items[idx].status = status
        state.items[idx].updatedAt = Date()
        // When an item is completed or dropped, cancel any pending reminder.
        if status != .pending {
            NotificationService.cancel(for: id)
            state.items[idx].reminderAt = nil
        }
        if status == .done {
            // Fire smart review prompts at streak milestones and total-completion thresholds.
            let stats = CompletionStats(items: state.items)
            ReviewPrompt.recordItemCompleted(totalCompletions: stats.totalCompleted)
            ReviewPrompt.recordStreakMilestone(stats.currentStreak)
            // Roll forward recurring items: insert a new pending copy advanced by one period.
            spawnRecurringItem(from: completed)
        }
    }

    /// If `original` has a non-`.none` recurrence, creates a new pending Item
    /// with all fields copied and the reminder date (if any) advanced by one period.
    private func spawnRecurringItem(from original: Item) {
        guard original.recurrence != .none else { return }
        var next = Item(title: original.title, source: original.source)
        next.details = original.details
        next.isPriority = original.isPriority
        next.recurrence = original.recurrence
        next.colorLabel = original.colorLabel
        next.requestedByFriendID = original.requestedByFriendID
        next.requestedByDisplayName = original.requestedByDisplayName
        if let base = original.reminderAt,
           let advanced = original.recurrence.nextDate(after: base) {
            next.reminderAt = advanced
            // Schedule the notification asynchronously; ignore permission denials silently
            // since the user already granted permission when they first set the reminder.
            Task {
                await NotificationService.scheduleReminder(
                    for: next.id,
                    title: next.title,
                    at: advanced
                )
            }
        }
        // Advance the due date by the same period so the recurred copy inherits the deadline.
        if let base = original.dueDate,
           let advanced = original.recurrence.nextDate(after: base) {
            next.dueDate = Calendar.current.startOfDay(for: advanced)
        }
        state.items.append(next)
    }

    func itemStatus(_ id: UUID) -> ItemStatus? {
        state.items.first { $0.id == id }?.status
    }

    func restoreItem(_ id: UUID) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].deleted = false
        state.items[idx].updatedAt = Date()
    }

    func updateItem(_ item: Item) {
        guard let idx = state.items.firstIndex(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.updatedAt = Date()
        state.items[idx] = updated
    }

    func deleteItem(_ id: UUID) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].deleted = true
        NotificationService.cancel(for: id)
    }

    /// Persists a new manual ordering for the items currently visible in the
    /// drag-enabled "main" section.
    ///
    /// `visibleIDs` must be the ordered IDs of the items shown in the draggable
    /// `ForEach` *after* the move has been applied locally. All other IDs that
    /// already exist in `manualItemOrder` but are not in `visibleIDs` (e.g. items
    /// currently filtered out) are preserved at their relative positions so that
    /// switching filters doesn't reset the ordering of hidden items.
    func reorderItems(visibleIDs: [UUID]) {
        // Build a set for O(1) membership tests.
        let visibleSet = Set(visibleIDs)
        // Preserve relative order of any IDs not currently in the visible slice.
        let preserved = state.manualItemOrder.filter { !visibleSet.contains($0) }
        state.manualItemOrder = visibleIDs + preserved
    }

    /// Clears the stored reminder date on an item without changing its status.
    /// Call this after cancelling a pending notification outside the normal edit flow.
    func clearReminderDate(for id: UUID) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].reminderAt = nil
        state.items[idx].updatedAt = Date()
    }

    func toggleItemPriority(_ id: UUID) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].isPriority.toggle()
        state.items[idx].updatedAt = Date()
    }

    /// Sets the color label on an item, or clears it when `color` is `nil`.
    /// Triggers the same persist / Spotlight / badge cycle as any other mutation.
    func setItemColorLabel(_ id: UUID, color: ItemColor?) {
        guard let idx = state.items.firstIndex(where: { $0.id == id }) else { return }
        state.items[idx].colorLabel = color
        state.items[idx].updatedAt = Date()
    }

    // MARK: - Notes

    @discardableResult
    func addNote(text: String, kind: NoteKind = .free, target: Anchor? = nil) -> Note {
        let note = Note(text: text, kind: kind, target: target)
        state.notes.append(note)
        return note
    }

    func deleteNote(_ id: UUID) {
        guard let idx = state.notes.firstIndex(where: { $0.id == id }) else { return }
        state.notes[idx].deleted = true
    }

    func restoreNote(_ id: UUID) {
        guard let idx = state.notes.firstIndex(where: { $0.id == id }) else { return }
        state.notes[idx].deleted = false
    }

    func updateNote(_ note: Note) {
        guard let idx = state.notes.firstIndex(where: { $0.id == note.id }) else { return }
        state.notes[idx] = note
    }

    // MARK: - Friends

    @discardableResult
    func addFriend(displayName: String, identifier: String) -> Friend {
        let friend = Friend(displayName: displayName, identifier: identifier)
        state.friends.append(friend)
        return friend
    }

    func updateFriend(_ friend: Friend) {
        guard let idx = state.friends.firstIndex(where: { $0.id == friend.id }) else { return }
        state.friends[idx] = friend
    }

    func updateFriendDisplayName(_ id: UUID, newName: String) {
        guard let idx = state.friends.firstIndex(where: { $0.id == id }) else { return }
        state.friends[idx].displayName = newName
    }

    func removeFriend(_ id: UUID) {
        state.friends.removeAll { $0.id == id }
    }

    func friend(withID id: UUID) -> Friend? {
        state.friends.first { $0.id == id }
    }

    // MARK: - Agent Memories

    @discardableResult
    func addAgentMemory(content: String) -> AgentMemory {
        let memory = AgentMemory(content: content)
        state.agentMemories.append(memory)
        return memory
    }

    func deleteAgentMemory(_ id: UUID) {
        guard let idx = state.agentMemories.firstIndex(where: { $0.id == id }) else { return }
        state.agentMemories[idx].deleted = true
    }

    func restoreAgentMemory(_ id: UUID) {
        guard let idx = state.agentMemories.firstIndex(where: { $0.id == id }) else { return }
        state.agentMemories[idx].deleted = false
    }

    // MARK: - Settings

    func updateSettings(_ settings: Settings) {
        state.settings = settings
    }

    /// Wipes all user data while preserving API credentials and Nostr identity.
    func clearAllData() {
        let itemIDs = state.items.compactMap { $0.reminderAt != nil ? $0.id : nil }
        NotificationService.cancelAll(for: itemIDs)
        let preserved = state.settings
        state = AppState()
        state.settings = preserved
        Persistence.save(state)
        SpotlightIndexer.clearAll()
        RecentSearchStore.shared.clearAll()
    }
}
