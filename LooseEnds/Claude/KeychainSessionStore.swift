import Foundation
import Security

/// The four keychain calls the store needs; replaced in the tests (#615 S4b-3), like `HTTPTransport`.
protocol KeychainOperations: Sendable {
    func add(_ attributes: [String: Any]) -> OSStatus
    func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?)
    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus
    func delete(_ query: [String: Any]) -> OSStatus
}

/// The real keychain: only the `SecItem*` calls, no logic.
struct SystemKeychain: KeychainOperations {
    func add(_ attributes: [String: Any]) -> OSStatus { SecItemAdd(attributes as CFDictionary, nil) }

    func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?) {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return (status, result as? Data)
    }

    func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
        SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    func delete(_ query: [String: Any]) -> OSStatus { SecItemDelete(query as CFDictionary) }
}

/// The queries of the session entry: one generic password on this device only, never synchronized; the data
/// protection keychain on the Mac too.
enum KeychainQuery {
    static let service = "com.henning.looseends.session"
    static let account = "session"

    static var base: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    static func add(_ token: String) -> [String: Any] {
        base.merging([
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]) { _, new in new }
    }

    static var read: [String: Any] {
        base.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, new in new }
    }

    /// The only attribute an update changes.
    static func value(_ token: String) -> [String: Any] { [kSecValueData as String: Data(token.utf8)] }

    /// Any status but success is a failure, -34018 (missing entitlement) too: it must never read as "signed out".
    static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else { throw SessionStoreError.keychain(status) }
    }

    /// Empty data or data that is no UTF-8 is no token.
    static func decode(_ data: Data?) throws -> String {
        guard let data, !data.isEmpty, let token = String(data: data, encoding: .utf8) else {
            throw SessionStoreError.corruptData
        }
        return token
    }
}

/// The session token in the keychain (ADR-21: never in `UserDefaults`). Nothing in the app calls it yet.
struct KeychainSessionStore: SessionStoring {
    let operations: any KeychainOperations

    init(operations: any KeychainOperations = SystemKeychain()) {
        self.operations = operations
    }

    /// A duplicate is updated with the value only, never deleted first; an update without a hit is a failure, no retry.
    func save(_ token: String) throws {
        let status = operations.add(KeychainQuery.add(token))
        guard status == errSecDuplicateItem else { return try KeychainQuery.check(status) }
        try KeychainQuery.check(operations.update(KeychainQuery.base, KeychainQuery.value(token)))
    }

    func load() throws -> String? {
        let (status, data) = operations.copyMatching(KeychainQuery.read)
        if status == errSecItemNotFound { return nil }
        try KeychainQuery.check(status)
        return try KeychainQuery.decode(data)
    }

    func clear() throws {
        let status = operations.delete(KeychainQuery.base)
        if status == errSecItemNotFound { return }
        try KeychainQuery.check(status)
    }
}
