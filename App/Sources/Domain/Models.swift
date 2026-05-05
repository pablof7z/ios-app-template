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

// MARK: - Agent Activity
// One row per agent-driven mutation, capturing just enough to render a
// human-readable summary and undo the effect by flipping a soft-delete or
// restoring a prior status. Grouped by `batchID` (one batch per agent run).

enum AgentActivityKind: Codable, Hashable, Sendable {
    case itemCreated(itemID: UUID)
    case itemMarkedDone(itemID: UUID, priorStatus: ItemStatus)
    case itemDeleted(itemID: UUID)
    case noteCreated(noteID: UUID)
    case memoryRecorded(memoryID: UUID)
}

struct AgentActivityEntry: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var batchID: UUID
    var timestamp: Date
    var kind: AgentActivityKind
    var summary: String
    var undone: Bool

    init(batchID: UUID, kind: AgentActivityKind, summary: String) {
        self.id = UUID()
        self.batchID = batchID
        self.timestamp = Date()
        self.kind = kind
        self.summary = summary
        self.undone = false
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

// MARK: - Settings

enum OpenRouterCredentialSource: String, Codable, Hashable, Sendable {
    case none, manual, byok
}

struct Settings: Codable, Hashable, Sendable {
    // AI / LLM
    var llmModel: String = "openai/gpt-4o-mini"
    var agentMaxTurns: Int = 12

    // OpenRouter credentials (secret stored in Keychain; only metadata here)
    var openRouterCredentialSource: OpenRouterCredentialSource = .none
    var openRouterBYOKKeyID: String?
    var openRouterBYOKKeyLabel: String?
    var openRouterConnectedAt: Date?
    var legacyOpenRouterAPIKey: String?

    // Nostr identity (private key stored in Keychain via NostrCredentialStore)
    var nostrEnabled: Bool = false
    var nostrRelayURL: String = "wss://relay.damus.io"
    var nostrProfileName: String = ""
    var nostrProfileAbout: String = ""
    var nostrProfilePicture: String = ""
    var nostrPublicKeyHex: String?

    init() {}

    private enum CodingKeys: String, CodingKey {
        case llmModel, agentMaxTurns
        case openRouterAPIKey                                             // legacy
        case openRouterCredentialSource
        case openRouterBYOKKeyID, openRouterBYOKKeyLabel, openRouterConnectedAt
        case nostrEnabled, nostrRelayURL
        case nostrProfileName, nostrProfileAbout, nostrProfilePicture
        case nostrPublicKeyHex
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        llmModel = try c.decodeIfPresent(String.self, forKey: .llmModel) ?? "openai/gpt-4o-mini"
        agentMaxTurns = try c.decodeIfPresent(Int.self, forKey: .agentMaxTurns) ?? 12
        openRouterCredentialSource = try c.decodeIfPresent(OpenRouterCredentialSource.self, forKey: .openRouterCredentialSource) ?? .none
        openRouterBYOKKeyID = try c.decodeIfPresent(String.self, forKey: .openRouterBYOKKeyID)
        openRouterBYOKKeyLabel = try c.decodeIfPresent(String.self, forKey: .openRouterBYOKKeyLabel)
        openRouterConnectedAt = try c.decodeIfPresent(Date.self, forKey: .openRouterConnectedAt)
        legacyOpenRouterAPIKey = try c.decodeIfPresent(String.self, forKey: .openRouterAPIKey)
        nostrEnabled = try c.decodeIfPresent(Bool.self, forKey: .nostrEnabled) ?? false
        nostrRelayURL = try c.decodeIfPresent(String.self, forKey: .nostrRelayURL) ?? "wss://relay.damus.io"
        nostrProfileName = try c.decodeIfPresent(String.self, forKey: .nostrProfileName) ?? ""
        nostrProfileAbout = try c.decodeIfPresent(String.self, forKey: .nostrProfileAbout) ?? ""
        nostrProfilePicture = try c.decodeIfPresent(String.self, forKey: .nostrProfilePicture) ?? ""
        nostrPublicKeyHex = try c.decodeIfPresent(String.self, forKey: .nostrPublicKeyHex)

        if openRouterCredentialSource == .none,
           let legacy = legacyOpenRouterAPIKey,
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            openRouterCredentialSource = .manual
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(llmModel, forKey: .llmModel)
        try c.encode(agentMaxTurns, forKey: .agentMaxTurns)
        try c.encode(openRouterCredentialSource, forKey: .openRouterCredentialSource)
        try c.encodeIfPresent(openRouterBYOKKeyID, forKey: .openRouterBYOKKeyID)
        try c.encodeIfPresent(openRouterBYOKKeyLabel, forKey: .openRouterBYOKKeyLabel)
        try c.encodeIfPresent(openRouterConnectedAt, forKey: .openRouterConnectedAt)
        try c.encode(nostrEnabled, forKey: .nostrEnabled)
        try c.encode(nostrRelayURL, forKey: .nostrRelayURL)
        try c.encode(nostrProfileName, forKey: .nostrProfileName)
        try c.encode(nostrProfileAbout, forKey: .nostrProfileAbout)
        try c.encode(nostrProfilePicture, forKey: .nostrProfilePicture)
        try c.encodeIfPresent(nostrPublicKeyHex, forKey: .nostrPublicKeyHex)
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
}
