import Foundation

// MARK: - Agent Activity Log

extension AppStateStore {

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
}
