import Foundation
import Observation

/// Single source of truth. All mutations route through here so the `didSet`
/// observer can persist automatically. UI and agent both call the same methods.
@MainActor
@Observable
final class AppStateStore {

    var state: AppState {
        didSet {
            Persistence.save(state)
            SpotlightIndexer.reindex(state: state)
        }
    }

    /// Most recent Spotlight deep-link the user opened. Views observe this to
    /// scroll-to or highlight the matching record, then clear it. `nil` once
    /// consumed.
    var pendingSpotlightLink: SpotlightIndexer.DeepLink?

    init() {
        var loadedState = (try? Persistence.load()) ?? AppState()
        Self.migrateLegacyOpenRouterSecretIfNeeded(in: &loadedState)
        self.state = loadedState
        // Seed Spotlight with whatever was persisted before this launch — the
        // index can be wiped out independently of our app data (device reset,
        // reinstall, user clearing system search).
        SpotlightIndexer.reindex(state: loadedState)
    }

    private static func migrateLegacyOpenRouterSecretIfNeeded(in state: inout AppState) {
        let legacyKey = state.settings.legacyOpenRouterAPIKey?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !legacyKey.isEmpty else {
            state.settings.legacyOpenRouterAPIKey = nil
            return
        }

        if (try? OpenRouterCredentialStore.saveAPIKey(legacyKey)) != nil {
            state.settings.markOpenRouterManual()
        } else {
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
        state.items[idx].status = status
        state.items[idx].updatedAt = Date()
    }

    @discardableResult
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

    // MARK: - Agent Activity Log

    func recordAgentActivity(_ entry: AgentActivityEntry) {
        state.agentActivity.append(entry)
    }

    func agentActivity(forBatch batchID: UUID) -> [AgentActivityEntry] {
        state.agentActivity
            .filter { $0.batchID == batchID }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Reverses the side-effect of an agent activity entry and marks it `undone`.
    /// Idempotent — calling on an already-undone entry is a no-op.
    func undoAgentActivity(_ entryID: UUID) {
        guard let idx = state.agentActivity.firstIndex(where: { $0.id == entryID }) else { return }
        guard !state.agentActivity[idx].undone else { return }
        switch state.agentActivity[idx].kind {
        case .itemCreated(let itemID):
            deleteItem(itemID)
        case .itemMarkedDone(let itemID, let priorStatus):
            setItemStatus(itemID, status: priorStatus)
        case .itemDeleted(let itemID):
            restoreItem(itemID)
        case .noteCreated(let noteID):
            deleteNote(noteID)
        case .memoryRecorded(let memoryID):
            deleteAgentMemory(memoryID)
        }
        state.agentActivity[idx].undone = true
    }

    func undoAgentActivityBatch(_ batchID: UUID) {
        let ids = state.agentActivity
            .filter { $0.batchID == batchID && !$0.undone }
            .map(\.id)
        for id in ids { undoAgentActivity(id) }
    }

    // MARK: - Nostr Access Control

    func allowNostrPubkey(_ pubkeyHex: String) {
        state.nostrAllowedPubkeys.insert(pubkeyHex)
        state.nostrBlockedPubkeys.remove(pubkeyHex)
        state.nostrPendingApprovals.removeAll { $0.pubkeyHex == pubkeyHex }
    }

    func blockNostrPubkey(_ pubkeyHex: String) {
        state.nostrBlockedPubkeys.insert(pubkeyHex)
        state.nostrAllowedPubkeys.remove(pubkeyHex)
        state.nostrPendingApprovals.removeAll { $0.pubkeyHex == pubkeyHex }
    }

    func removeFromNostrAllowlist(_ pubkeyHex: String) {
        state.nostrAllowedPubkeys.remove(pubkeyHex)
    }

    func removeFromNostrBlocklist(_ pubkeyHex: String) {
        state.nostrBlockedPubkeys.remove(pubkeyHex)
    }

    func addNostrPendingApproval(_ approval: NostrPendingApproval) {
        guard !state.nostrAllowedPubkeys.contains(approval.pubkeyHex),
              !state.nostrBlockedPubkeys.contains(approval.pubkeyHex),
              !state.nostrPendingApprovals.contains(where: { $0.pubkeyHex == approval.pubkeyHex })
        else { return }
        state.nostrPendingApprovals.append(approval)
    }

    func dismissNostrPendingApproval(_ id: UUID) {
        state.nostrPendingApprovals.removeAll { $0.id == id }
    }

    // MARK: - Settings

    func updateSettings(_ settings: Settings) {
        state.settings = settings
    }

    /// Wipes all user data while preserving API credentials and Nostr identity.
    func clearAllData() {
        let preserved = state.settings
        state = AppState()
        state.settings = preserved
        Persistence.save(state)
        SpotlightIndexer.clearAll()
    }

    // MARK: - Derived views

    var activeItems: [Item] {
        state.items.filter { !$0.deleted && $0.status == .pending }
    }

    var activeNotes: [Note] {
        state.notes.filter { !$0.deleted }
    }

    var activeMemories: [AgentMemory] {
        state.agentMemories.filter { !$0.deleted }
    }

    var pendingNostrApprovals: [NostrPendingApproval] {
        state.nostrPendingApprovals
    }
}
