import Foundation

// MARK: - Nostr Pending Approval
// A contact requesting communication before being explicitly allowed or blocked.

/// Number of characters shown at each end of a truncated pubkey.
private let pubkeyTruncationHalfLength = 8

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
        let half = pubkeyTruncationHalfLength
        guard pubkeyHex.count > half * 2 else { return pubkeyHex }
        return "\(pubkeyHex.prefix(half))…\(pubkeyHex.suffix(half))"
    }
}
