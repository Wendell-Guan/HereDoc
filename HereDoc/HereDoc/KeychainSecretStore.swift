import Foundation
import Security

struct KeychainSecretStore {
    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)
        case invalidEncoding

        var errorDescription: String? {
            switch self {
            case let .unexpectedStatus(status):
                return "钥匙串操作失败（\(status)）。"
            case .invalidEncoding:
                return "API Key 编码失败。"
            }
        }
    }

    func readSecret(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "HereDoc",
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else { return nil }
        guard status == errSecSuccess else { return nil }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func saveSecret(_ secret: String, account: String) throws {
        guard let data = secret.data(using: .utf8) else {
            throw KeychainError.invalidEncoding
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "HereDoc",
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var creation = baseQuery
            attributes.forEach { creation[$0.key] = $0.value }
            let addStatus = SecItemAdd(creation as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(addStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func deleteSecret(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "HereDoc",
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
