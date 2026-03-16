import Foundation
import Security

enum KeychainKey: String {
    case renderAPIKey = "render-api-key"
    case githubToken = "github-token"
}

enum KeychainService {
    private static let service = "com.rendermenu"

    static func save(_ key: KeychainKey, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(_ key: KeychainKey) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    static func delete(_ key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    static func deleteAll() {
        delete(.renderAPIKey)
        delete(.githubToken)
    }
}
