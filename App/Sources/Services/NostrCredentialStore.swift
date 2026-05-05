import Foundation

/// Stores the Nostr private key (hex) in Keychain.
/// The matching public key hex is stored in Settings (non-secret).
/// Implement secp256k1 key derivation (e.g. via swift-secp256k1) to derive pubkey from privkey.
enum NostrCredentialStore {
    private static let service = "\(Bundle.main.bundleIdentifier ?? "AppTemplate").nostr"
    private static let account = "private-key-hex"

    static func savePrivateKey(_ hexKey: String) throws {
        let trimmed = hexKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try KeychainStore.saveString(trimmed, service: service, account: account)
    }

    static func privateKey() throws -> String? {
        guard let value = try KeychainStore.readString(service: service, account: account) else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func hasPrivateKey() -> Bool {
        ((try? privateKey()) ?? nil) != nil
    }

    static func deletePrivateKey() throws {
        try KeychainStore.deleteString(service: service, account: account)
    }
}
