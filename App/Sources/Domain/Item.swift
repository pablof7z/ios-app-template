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

/// Recurrence period for a repeating item.
/// When an item with a non-`.none` recurrence is completed, a new pending copy
/// is automatically inserted with the reminder date advanced by the period.
enum Recurrence: String, Codable, Hashable, CaseIterable, Sendable {
    case none
    case daily
    case weekly
    case monthly

    /// Human-readable label shown in the picker.
    var label: String {
        switch self {
        case .none:    return "None"
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    /// SF Symbol shown in ItemRow when the item repeats.
    var systemImage: String { "arrow.triangle.2.circlepath" }

    /// Advances `date` by one period using the given calendar.
    func nextDate(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none:    return nil
        case .daily:   return calendar.date(byAdding: .day, value: 1, to: date)
        case .weekly:  return calendar.date(byAdding: .weekOfYear, value: 1, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        }
    }
}

struct Item: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var title: String
    /// Optional multi-line description or extra context for this item.
    /// Distinct from the top-level `Note` type which is a free-form journal entry.
    var details: String
    var status: ItemStatus
    var source: ItemSource
    var createdAt: Date
    var updatedAt: Date
    var deleted: Bool
    var requestedByFriendID: UUID?
    var requestedByDisplayName: String?
    var reminderAt: Date?
    var isPriority: Bool
    /// If non-`.none`, completing this item spawns a new pending copy advanced by the period.
    var recurrence: Recurrence

    init(title: String, source: ItemSource = .manual) {
        self.id = UUID()
        self.title = title
        self.details = ""
        self.status = .pending
        self.source = source
        self.createdAt = Date()
        self.updatedAt = Date()
        self.deleted = false
        self.isPriority = false
        self.recurrence = .none
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, details, status, source, createdAt, updatedAt, deleted
        case requestedByFriendID, requestedByDisplayName
        case reminderAt, isPriority, recurrence
    }

    // Forward-compat: every field decoded with `decodeIfPresent` so adding
    // new fields never breaks decode of older persisted state.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        details = try c.decodeIfPresent(String.self, forKey: .details) ?? ""
        status = try c.decodeIfPresent(ItemStatus.self, forKey: .status) ?? .pending
        source = try c.decodeIfPresent(ItemSource.self, forKey: .source) ?? .manual
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        deleted = try c.decodeIfPresent(Bool.self, forKey: .deleted) ?? false
        requestedByFriendID = try c.decodeIfPresent(UUID.self, forKey: .requestedByFriendID)
        requestedByDisplayName = try c.decodeIfPresent(String.self, forKey: .requestedByDisplayName)
        reminderAt = try c.decodeIfPresent(Date.self, forKey: .reminderAt)
        isPriority = try c.decodeIfPresent(Bool.self, forKey: .isPriority) ?? false
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? .none
    }
}

// MARK: - Item sharing

extension Item {
    /// Plain-text summary formatted for sharing (Messages, Mail, Notes, etc.).
    /// Includes title, optional details, recurrence, and optional reminder date.
    var shareText: String {
        var parts: [String] = [title]
        if !details.isEmpty {
            parts.append(details)
        }
        if recurrence != .none {
            parts.append("Repeats: \(recurrence.label)")
        }
        if let date = reminderAt {
            let formatted = date.formatted(.dateTime.month(.wide).day().year().hour().minute())
            parts.append("Reminder: \(formatted)")
        }
        return parts.joined(separator: "\n\n")
    }
}
