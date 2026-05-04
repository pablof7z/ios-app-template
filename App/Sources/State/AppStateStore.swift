import Foundation
import Observation

/// Single source of truth. All mutations route through here so the `didSet`
/// observer can persist automatically. UI and agent both call the same methods.
@MainActor
@Observable
final class AppStateStore {

    var state: AppState {
        didSet { Persistence.save(state) }
    }

    init() {
        self.state = (try? Persistence.load()) ?? AppState()
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

    // MARK: - Friends

    @discardableResult
    func addFriend(displayName: String, identifier: String) -> Friend {
        let friend = Friend(displayName: displayName, identifier: identifier)
        state.friends.append(friend)
        return friend
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

    // MARK: - Settings

    func updateSettings(_ settings: Settings) {
        state.settings = settings
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
}
