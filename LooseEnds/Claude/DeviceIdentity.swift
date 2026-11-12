import Foundation
import Security

/// Why the installation's id could not be read or created; never carries the id itself.
enum DeviceIdentityError: Error, Equatable {
    case keychain(OSStatus)
    case corruptData
}

/// The installation's own id for the header `X-Device` (#795 S2b): created once, found again on every call, never
/// replaced. Its own keychain entry on this device only, readable after the first unlock (the wake-up in S5 runs in the
/// background). Stateless like `KeychainSessionStore`. Nothing in the app calls it yet.
struct DeviceIdentity: Sendable {
    let operations: any KeychainOperations

    init(operations: any KeychainOperations = SystemKeychain()) {
        self.operations = operations
    }

    /// A stored id wins; only "not found" creates one. A duplicate on adding means a second caller was faster: read
    /// once more, never update. Any other status, and every status of that second read, is a failure.
    func current() throws -> UUID {
        let (status, data) = operations.copyMatching(Self.read)
        if status == errSecSuccess { return try Self.decode(data) }
        guard status == errSecItemNotFound else { throw DeviceIdentityError.keychain(status) }
        let fresh = UUID()
        let added = operations.add(Self.add(fresh))
        if added == errSecSuccess { return fresh }
        guard added == errSecDuplicateItem else { throw DeviceIdentityError.keychain(added) }
        let (again, stored) = operations.copyMatching(Self.read)
        guard again == errSecSuccess else { throw DeviceIdentityError.keychain(again) }
        return try Self.decode(stored)
    }

    private static let service = "com.henning.looseends.device"
    private static let account = "device"

    /// The same form as the session entry: one generic password, data protection keychain, never synchronized.
    private static var base: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
    }

    private static var read: [String: Any] {
        base.merging([kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]) { _, new in new }
    }

    private static func add(_ id: UUID) -> [String: Any] {
        base.merging([
            kSecValueData as String: Data(id.uuidString.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]) { _, new in new }
    }

    /// Data that is no UTF-8 UUID is a broken entry: an error, never silently replaced.
    private static func decode(_ data: Data?) throws -> UUID {
        guard let data, let text = String(data: data, encoding: .utf8), let id = UUID(uuidString: text) else {
            throw DeviceIdentityError.corruptData
        }
        return id
    }
}
