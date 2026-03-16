import Foundation
import Security

struct StoredCredentials: Codable {
    var renderAPIKey: String = ""
    var githubToken: String = ""
}

enum KeychainService {
    private static let service = "com.rendermenu"
    private static let account = "credentials"

    static func save(_ credentials: StoredCredentials) -> Bool {
        guard let data = try? JSONEncoder().encode(credentials) else { return false }
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data,
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load() -> StoredCredentials? {
        // Try new combined format
        if let creds = loadRaw(account: account) {
            if let decoded = try? JSONDecoder().decode(StoredCredentials.self, from: creds) {
                return decoded
            }
        }

        // Migrate from old separate-entry format
        let renderKey = loadRaw(account: "render-api-key").flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let ghToken = loadRaw(account: "github-token").flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // Also check the original service name from v1
        let renderKeyOld = loadRaw(service: "com.rendermenu.apikey", account: "render-api-key").flatMap { String(data: $0, encoding: .utf8) } ?? ""

        let key = !renderKey.isEmpty ? renderKey : renderKeyOld
        guard !key.isEmpty else { return nil }

        let migrated = StoredCredentials(renderAPIKey: key, githubToken: ghToken)
        // Save in new format and clean up old entries
        _ = save(migrated)
        deleteRaw(account: "render-api-key")
        deleteRaw(account: "github-token")
        deleteRaw(service: "com.rendermenu.apikey", account: "render-api-key")
        return migrated
    }

    @discardableResult
    static func delete() -> Bool {
        deleteRaw(account: account)
    }

    // MARK: - Raw helpers

    private static func loadRaw(service svc: String? = nil, account acct: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc ?? service,
            kSecAttrAccount as String: acct,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    private static func deleteRaw(service svc: String? = nil, account acct: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: svc ?? service,
            kSecAttrAccount as String: acct,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
