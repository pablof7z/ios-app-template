import Foundation

// MARK: - AppState

struct AppState: Codable, Sendable {
    var items: [Item] = []
    var notes: [Note] = []
    var friends: [Friend] = []
    var agentMemories: [AgentMemory] = []
    var settings: Settings = Settings()
    var nostrAllowedPubkeys: Set<String> = []
    var nostrBlockedPubkeys: Set<String> = []
    var nostrPendingApprovals: [NostrPendingApproval] = []
    var agentActivity: [AgentActivityEntry] = []
    /// Persists user-defined drag-to-reorder sequence for active items.
    /// Only honoured when sort is "Newest First" with no active filters.
    /// Stale UUIDs (completed / deleted items) are silently ignored at read time.
    var manualItemOrder: [UUID] = []

    init() {}

    private enum CodingKeys: String, CodingKey {
        case items, notes, friends, agentMemories, settings
        case nostrAllowedPubkeys, nostrBlockedPubkeys, nostrPendingApprovals
        case agentActivity
        case manualItemOrder
    }

    // Forward-compat: every field decoded with `decodeIfPresent` so adding new
    // fields never breaks decode of older persisted state.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        notes = try c.decodeIfPresent([Note].self, forKey: .notes) ?? []
        friends = try c.decodeIfPresent([Friend].self, forKey: .friends) ?? []
        agentMemories = try c.decodeIfPresent([AgentMemory].self, forKey: .agentMemories) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        nostrAllowedPubkeys = try c.decodeIfPresent(Set<String>.self, forKey: .nostrAllowedPubkeys) ?? []
        nostrBlockedPubkeys = try c.decodeIfPresent(Set<String>.self, forKey: .nostrBlockedPubkeys) ?? []
        nostrPendingApprovals = try c.decodeIfPresent([NostrPendingApproval].self, forKey: .nostrPendingApprovals) ?? []
        agentActivity = try c.decodeIfPresent([AgentActivityEntry].self, forKey: .agentActivity) ?? []
        manualItemOrder = try c.decodeIfPresent([UUID].self, forKey: .manualItemOrder) ?? []
    }
}
