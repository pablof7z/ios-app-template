import Foundation
import Security

enum KeychainStore {
    static func saveString(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        var query = baseQuery(service: service, account: account)
        SecItemDelete(query as CFDictionary)

        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    static func readString(service: String, account: String) throws -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainStoreError.invalidData
        }
        return String(data: data, encoding: .utf8)
    }

    static func deleteString(service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    private static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

enum KeychainStoreError: LocalizedError {
    case invalidData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            "Keychain item could not be decoded."
        case .unhandledStatus:
            "Keychain operation failed."
        }
    }
}

