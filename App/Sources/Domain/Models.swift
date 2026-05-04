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

    // Peer attribution: set when a friend's agent creates or modifies this item
    var requestedByFriendID: UUID?
    var requestedByDisplayName: String?

    init(title: String, source: ItemSource = .manual) {
        self.id = UUID()
        self.title = title
        self.status = .pending
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deleted = false
    }
}

// MARK: - Note

enum NoteKind: String, Codable, Hashable, Sendable {
    case free         // General text note
    case reflection   // Intentional reflection
    case systemEvent  // Written by agent/system, not user
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
}

// MARK: - Friend
// Represents a trusted contact whose agent can interact with this app.
// `identifier` is app-specific: could be a Nostr pubkey, username, email, etc.

struct Friend: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var displayName: String
    var identifier: String
    var addedAt: Date
    var avatarURL: String?
    var about: String?

    init(displayName: String, identifier: String) {
        self.id = UUID()
        self.displayName = displayName
        self.identifier = identifier
        self.addedAt = Date()
    }
}

// MARK: - Agent Memory
// Individual facts the agent learns and stores for future sessions.

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

// MARK: - Settings

enum OpenRouterCredentialSource: String, Codable, Hashable, Sendable {
    case none
    case manual
    case byok
}

struct Settings: Codable, Hashable, Sendable {
    var llmModel: String = "openai/gpt-4o-mini"
    var agentMaxTurns: Int = 12
    var openRouterCredentialSource: OpenRouterCredentialSource = .none
    var openRouterBYOKKeyID: String?
    var openRouterBYOKKeyLabel: String?
    var openRouterConnectedAt: Date?
    var legacyOpenRouterAPIKey: String?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case llmModel
        case openRouterAPIKey
        case agentMaxTurns
        case openRouterCredentialSource
        case openRouterBYOKKeyID
        case openRouterBYOKKeyLabel
        case openRouterConnectedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        llmModel = try container.decodeIfPresent(String.self, forKey: .llmModel) ?? "openai/gpt-4o-mini"
        agentMaxTurns = try container.decodeIfPresent(Int.self, forKey: .agentMaxTurns) ?? 12
        openRouterCredentialSource = try container.decodeIfPresent(
            OpenRouterCredentialSource.self,
            forKey: .openRouterCredentialSource
        ) ?? .none
        openRouterBYOKKeyID = try container.decodeIfPresent(String.self, forKey: .openRouterBYOKKeyID)
        openRouterBYOKKeyLabel = try container.decodeIfPresent(String.self, forKey: .openRouterBYOKKeyLabel)
        openRouterConnectedAt = try container.decodeIfPresent(Date.self, forKey: .openRouterConnectedAt)
        legacyOpenRouterAPIKey = try container.decodeIfPresent(String.self, forKey: .openRouterAPIKey)

        if openRouterCredentialSource == .none,
           let legacyOpenRouterAPIKey,
           !legacyOpenRouterAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            openRouterCredentialSource = .manual
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(llmModel, forKey: .llmModel)
        try container.encode(agentMaxTurns, forKey: .agentMaxTurns)
        try container.encode(openRouterCredentialSource, forKey: .openRouterCredentialSource)
        try container.encodeIfPresent(openRouterBYOKKeyID, forKey: .openRouterBYOKKeyID)
        try container.encodeIfPresent(openRouterBYOKKeyLabel, forKey: .openRouterBYOKKeyLabel)
        try container.encodeIfPresent(openRouterConnectedAt, forKey: .openRouterConnectedAt)
    }

    mutating func markOpenRouterManual(connectedAt: Date = Date()) {
        openRouterCredentialSource = .manual
        openRouterBYOKKeyID = nil
        openRouterBYOKKeyLabel = nil
        openRouterConnectedAt = connectedAt
        legacyOpenRouterAPIKey = nil
    }

    mutating func markOpenRouterBYOK(keyID: String?, keyLabel: String?, connectedAt: Date = Date()) {
        openRouterCredentialSource = .byok
        openRouterBYOKKeyID = keyID
        openRouterBYOKKeyLabel = keyLabel
        openRouterConnectedAt = connectedAt
        legacyOpenRouterAPIKey = nil
    }

    mutating func clearOpenRouterCredential() {
        openRouterCredentialSource = .none
        openRouterBYOKKeyID = nil
        openRouterBYOKKeyLabel = nil
        openRouterConnectedAt = nil
        legacyOpenRouterAPIKey = nil
    }
}

// MARK: - AppState
// The single serializable source of truth. Persisted to disk on every mutation.

struct AppState: Codable, Sendable {
    var items: [Item] = []
    var notes: [Note] = []
    var friends: [Friend] = []
    var agentMemories: [AgentMemory] = []
    var settings: Settings = Settings()

    init() {}
}
