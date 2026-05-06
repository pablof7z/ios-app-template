import Foundation

// MARK: - Derived Views

extension AppStateStore {

    var activeItems: [Item] {
        state.items.filter { !$0.deleted && $0.status == .pending }
    }

    /// Count of items completed today — used by NextActionHero progress ring.
    /// Single lazy pass: avoids the sort performed by `completedItems`.
    var completedTodayCount: Int {
        state.items.lazy.filter {
            !$0.deleted && $0.status == .done && Calendar.current.isDateInToday($0.updatedAt)
        }.count
    }

    var completedItems: [Item] {
        state.items
            .filter { !$0.deleted && $0.status == .done }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func clearCompletedItems() {
        for idx in state.items.indices where !state.items[idx].deleted && state.items[idx].status == .done {
            state.items[idx].deleted = true
        }
    }

    var activeNotes: [Note] {
        state.notes.filter { !$0.deleted }
    }

    var activeMemories: [AgentMemory] {
        state.agentMemories.filter { !$0.deleted }
    }
}
