import Foundation

// MARK: - Friend
// Represents a trusted Nostr contact. `identifier` stores the hex pubkey.

/// Number of characters shown at each end of a truncated identifier/pubkey.
private let identifierTruncationHalfLength = 8

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
        let half = identifierTruncationHalfLength
        guard identifier.count > half * 2 else { return identifier }
        return "\(identifier.prefix(half))…\(identifier.suffix(half))"
    }
}
