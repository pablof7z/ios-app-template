import Foundation

// MARK: - Anchor
// Polymorphic reference target — links notes/items to their context.
// Discriminated union serialized as { "kind": "...", "id": "..." } for JSON round-trip.

enum Anchor: Codable, Hashable, Sendable {
    case item(id: UUID)
    case note(id: UUID)

    private enum Kind: String, Codable { case item, note }
    private enum CodingKeys: String, CodingKey { case kind, id }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .item: self = .item(id: try c.decode(UUID.self, forKey: .id))
        case .note: self = .note(id: try c.decode(UUID.self, forKey: .id))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .item(let id): try c.encode(Kind.item, forKey: .kind); try c.encode(id, forKey: .id)
        case .note(let id): try c.encode(Kind.note, forKey: .kind); try c.encode(id, forKey: .id)
        }
    }
}

// MARK: - Item

enum ItemStatus: String, Codable, Hashable, Sendable {
    case pending, done, dropped
}

enum ItemSource: String, Codable, Hashable, Sendable {
    case manual, voice, agent
}

struct Item: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    var status: ItemStatus
    var source: ItemSource
    var createdAt: Date
    var updatedAt: Date
    var deleted: Bool
    var requestedByFriendID: UUID?
    var requestedByDisplayName: String?
    var reminderAt: Date?

    init(title: String, source: ItemSource = .manual) {
        self.id = UUID()
        self.title = title
        self.status = .pending
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deleted = false
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, status, source, createdAt, updatedAt, deleted
        case requestedByFriendID, requestedByDisplayName
        case reminderAt
    }

    // Forward-compat: every field decoded with `decodeIfPresent` so adding
    // new fields (e.g. due dates, priority) never breaks decode of older
    // persisted state.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        status = try c.decodeIfPresent(ItemStatus.self, forKey: .status) ?? .pending
        source = try c.decodeIfPresent(ItemSource.self, forKey: .source) ?? .manual
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        requestedByFriendID = try c.decodeIfPresent(UUID.self, forKey: .requestedByFriendID)
        requestedByDisplayName = try c.decodeIfPresent(String.self, forKey: .requestedByDisplayName)
        reminderAt = try c.decodeIfPresent(Date.self, forKey: .reminderAt)
    }
}

// MARK: - Note

enum NoteKind: String, Codable, Hashable, Sendable {
    case free
    case reflection
    case systemEvent
}

struct Note: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var text: String
    var kind: NoteKind
    var target: Anchor?
    var createdAt: Date
    var deleted: Bool

    init(text: String, kind: NoteKind = .free, target: Anchor? = nil) {
        self.id = UUID()
        self.text = text
        self.kind = kind
        self.target = target
        self.createdAt = Date()
        self.deleted = false
    }

    private enum CodingKeys: String, CodingKey {
        case id, text, kind, target, createdAt, deleted
    }

    // Forward-compat: every field decoded with `decodeIfPresent` so adding
    // new fields never breaks decode of older persisted state.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        kind = try c.decodeIfPresent(NoteKind.self, forKey: .kind) ?? .free
        target = try c.decodeIfPresent(Anchor.self, forKey: .target)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
    }
}

// MARK: - Friend
// Represents a trusted Nostr contact. `identifier` stores the hex pubkey.

struct Friend: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var displayName: String
    var identifier: String    // hex pubkey for Nostr contacts
    var addedAt: Date
    var avatarURL: String?
    var about: String?

    init(displayName: String, identifier: String) {
        self.id = UUID()
        self.displayName = displayName
        self.identifier = identifier
        self.addedAt = Date()
    }

    /// Returns a truncated display of the identifier (first 8 + last 8 chars).
    var shortIdentifier: String {
        guard identifier.count > 16 else { return identifier }
        return "\(identifier.prefix(8))…\(identifier.suffix(8))"
    }
}

// MARK: - Agent Memory

struct AgentMemory: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var content: String
    var createdAt: Date
    var deleted: Bool

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.createdAt = Date()
        self.deleted = false
    }
}

// MARK: - Nostr Pending Approval
// A contact requesting communication before being explicitly allowed or blocked.

struct NostrPendingApproval: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var pubkeyHex: String
    var displayName: String?
    var about: String?
    var pictureURL: String?
    var receivedAt: Date

    init(pubkeyHex: String, displayName: String? = nil, about: String? = nil, pictureURL: String? = nil) {
        self.id = UUID()
        self.pubkeyHex = pubkeyHex
        self.displayName = displayName
        self.about = about
        self.pictureURL = pictureURL
        self.receivedAt = Date()
    }

    var shortPubkey: String {
        guard pubkeyHex.count > 16 else { return pubkeyHex }
        return "\(pubkeyHex.prefix(8))…\(pubkeyHex.suffix(8))"
    }
}

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

    init() {}

    private enum CodingKeys: String, CodingKey {
        case items, notes, friends, agentMemories, settings
        case nostrAllowedPubkeys, nostrBlockedPubkeys, nostrPendingApprovals
        case agentActivity
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
    }
}
