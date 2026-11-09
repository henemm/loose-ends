import Foundation
import Security
import Synchronization
import Testing
@testable import LooseEnds

/// The session token in the keychain (#615 S4b-3): queries, status mapping and the flow of `save`, `load` and `clear`
/// against recorded keychain operations. The real keychain answers -34018 in the test host; its proof follows in S4c.
@Suite("KeychainSessionStore (#615)") struct KeychainSessionStoreTests {
    /// Records every call and answers each with the next prepared status; a read also returns the prepared data.
    final class FakeKeychain: KeychainOperations, @unchecked Sendable {
        enum Op: Equatable { case add, copy, update, delete }
        struct Call { let op: Op; let query: [String: Any]; let attributes: [String: Any]? }
        private struct State { var calls: [Call] = []; var statuses: [OSStatus]; var data: Data? }
        private let state: Mutex<State>

        init(_ statuses: [OSStatus], data: Data? = nil) {
            state = Mutex(State(statuses: statuses, data: data))
        }

        var calls: [Call] { state.withLock { $0.calls } }
        var ops: [Op] { calls.map(\.op) }

        private func next(_ call: Call) -> OSStatus {
            state.withLock {
                $0.calls.append(call)
                guard !$0.statuses.isEmpty else { Issue.record("unexpected \(call.op)"); return errSecInternalComponent }
                return $0.statuses.removeFirst()
            }
        }

        func add(_ attributes: [String: Any]) -> OSStatus { next(Call(op: .add, query: attributes, attributes: nil)) }
        func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?) {
            let status = next(Call(op: .copy, query: query, attributes: nil))
            return (status, state.withLock { $0.data })
        }
        func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus {
            next(Call(op: .update, query: query, attributes: attributes))
        }
        func delete(_ query: [String: Any]) -> OSStatus { next(Call(op: .delete, query: query, attributes: nil)) }
    }

    static let token = "SECRET-TOKEN"
    static let other: OSStatus = 4711
    static let failures: [OSStatus] = [errSecMissingEntitlement, errSecInteractionNotAllowed, errSecInternalComponent, other]

    private func string(_ query: [String: Any], _ key: CFString) -> String? { query[key as String] as? String }

    private func expectBase(_ query: [String: Any], _ label: String) {
        #expect(string(query, kSecClass) == kSecClassGenericPassword as String, "\(label)")
        #expect(string(query, kSecAttrService) == "com.henning.looseends.session", "\(label)")
        #expect(string(query, kSecAttrAccount) == KeychainQuery.account && !KeychainQuery.account.isEmpty, "\(label)")
        #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true, "\(label)")
        #expect(query[kSecAttrSynchronizable as String] == nil, "\(label)")
    }

    @Test("keychain: abfragen")
    func queries() throws {
        let fake = FakeKeychain([errSecDuplicateItem, errSecSuccess, errSecSuccess, errSecSuccess], data: Data("T1".utf8))
        let store = KeychainSessionStore(operations: fake)
        try store.save(Self.token)
        _ = try store.load()
        try store.clear()
        let calls = fake.calls
        #expect(calls.map(\.op) == [.add, .update, .copy, .delete])
        for call in calls { expectBase(call.query, "\(call.op)") }
        let add = calls[0].query, update = calls[1], read = calls[2].query
        #expect(string(add, kSecAttrAccessible) == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(add[kSecValueData as String] as? Data == Data(Self.token.utf8))
        #expect(read[kSecReturnData as String] as? Bool == true)
        #expect(string(read, kSecMatchLimit) == kSecMatchLimitOne as String)
        #expect(read[kSecValueData as String] == nil && update.query[kSecValueData as String] == nil)
        let attributes = try #require(update.attributes)
        #expect(Array(attributes.keys) == [kSecValueData as String])
        #expect(attributes[kSecValueData as String] as? Data == Data(Self.token.utf8))
        #expect(calls[3].query[kSecReturnData as String] == nil && calls[3].query[kSecValueData as String] == nil)
    }

    @Test("keychain: statusabbildung save", arguments: [errSecSuccess] + failures)
    func saveStatus(status: OSStatus) {
        let fake = FakeKeychain([status])
        let store = KeychainSessionStore(operations: fake)
        if status == errSecSuccess {
            #expect(throws: Never.self) { try store.save("T1") }
        } else {
            #expect(throws: SessionStoreError.keychain(status)) { try store.save("T1") }
        }
        #expect(fake.ops == [.add])
    }

    @Test("keychain: save duplikat wird update")
    func duplicateBecomesUpdate() throws {
        let fake = FakeKeychain([errSecDuplicateItem, errSecSuccess])
        try KeychainSessionStore(operations: fake).save("T2")
        #expect(fake.ops == [.add, .update])
        let update = fake.calls[1]
        expectBase(update.query, "update")
        #expect(update.query.count == 4)
        #expect(update.attributes?.count == 1 && update.attributes?[kSecValueData as String] as? Data == Data("T2".utf8))
    }

    @Test("keychain: update ohne treffer ist fehler ohne retry", arguments: [errSecItemNotFound, errSecMissingEntitlement, other])
    func updateFailureNoRetry(status: OSStatus) {
        let fake = FakeKeychain([errSecDuplicateItem, status])
        #expect(throws: SessionStoreError.keychain(status)) { try KeychainSessionStore(operations: fake).save("T2") }
        #expect(fake.ops == [.add, .update])
    }

    @Test("keychain: load statusabbildung")
    func loadStatus() throws {
        #expect(try KeychainSessionStore(operations: FakeKeychain([errSecItemNotFound])).load() == nil)
        let found = FakeKeychain([errSecSuccess], data: Data("T1".utf8))
        #expect(try KeychainSessionStore(operations: found).load() == "T1")
        #expect(found.ops == [.copy])
        for status in Self.failures {
            let fake = FakeKeychain([status], data: Data("T1".utf8))
            #expect(throws: SessionStoreError.keychain(status)) { try KeychainSessionStore(operations: fake).load() }
        }
    }

    @Test("keychain: clear statusabbildung", arguments: [errSecSuccess, errSecItemNotFound] + failures)
    func clearStatus(status: OSStatus) {
        let fake = FakeKeychain([status])
        let store = KeychainSessionStore(operations: fake)
        if status == errSecSuccess || status == errSecItemNotFound {
            #expect(throws: Never.self) { try store.clear() }
        } else {
            #expect(throws: SessionStoreError.keychain(status)) { try store.clear() }
        }
        #expect(fake.ops == [.delete])
        expectBase(fake.calls[0].query, "delete")
    }

    @Test("keychain: leere und ungueltige daten", arguments: [nil, Data(), Data([0xFF, 0xFE])])
    func corruptData(data: Data?) {
        let fake = FakeKeychain([errSecSuccess], data: data)
        #expect(throws: SessionStoreError.corruptData) { try KeychainSessionStore(operations: fake).load() }
    }

    @Test("keychain: fehlende berechtigung ist kein nil")
    func missingEntitlementIsNoNil() {
        let missing = errSecMissingEntitlement
        #expect(missing == -34018)
        #expect(throws: SessionStoreError.keychain(missing)) {
            try KeychainSessionStore(operations: FakeKeychain([missing])).save("T1")
        }
        for data in [nil, Data("T1".utf8)] {
            #expect(throws: SessionStoreError.keychain(missing)) {
                try KeychainSessionStore(operations: FakeKeychain([missing], data: data)).load()
            }
        }
        #expect(throws: SessionStoreError.keychain(missing)) {
            try KeychainSessionStore(operations: FakeKeychain([missing])).clear()
        }
    }

    @Test("keychain: fehler ohne token")
    func errorsCarryNoToken() {
        let secret = Data(Self.token.utf8)
        var errors: [any Error] = []
        func collect(_ body: () throws -> Void) {
            do { try body() } catch { errors.append(error) }
        }
        for status in Self.failures {
            collect { try KeychainSessionStore(operations: FakeKeychain([status])).save(Self.token) }
            collect { try KeychainSessionStore(operations: FakeKeychain([errSecDuplicateItem, status])).save(Self.token) }
            collect { _ = try KeychainSessionStore(operations: FakeKeychain([status], data: secret)).load() }
            collect { try KeychainSessionStore(operations: FakeKeychain([status])).clear() }
        }
        collect { _ = try KeychainSessionStore(operations: FakeKeychain([errSecSuccess], data: secret + Data([0xFF]))).load() }
        #expect(errors.count == Self.failures.count * 4 + 1)
        for error in errors {
            let text = String(describing: error)
            #expect(!text.contains(Self.token), "\(text)")
        }
    }
}
