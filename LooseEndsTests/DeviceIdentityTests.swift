import Foundation
import Security
import Synchronization
import Testing
@testable import LooseEnds

/// The installation's own id for the header `X-Device` (#795 S2b): created once, found again, never replaced, against
/// recorded keychain operations. The real keychain answers -34018 in the test host; its proof follows with S3.
@Suite("DeviceIdentity (#795)") struct DeviceIdentityTests {
    /// Answers each call with the next prepared step; a read also returns that step's data. Records every call.
    final class Keychain: KeychainOperations, @unchecked Sendable {
        enum Op: Equatable { case add, copy, update, delete }
        struct Call: @unchecked Sendable { let op: Op; let query: [String: Any] }
        private struct State { var calls: [Call] = []; var steps: [(OSStatus, Data?)] }
        private let state: Mutex<State>

        init(_ steps: [(OSStatus, Data?)]) { state = Mutex(State(steps: steps)) }

        var calls: [Call] { state.withLock { $0.calls } }
        var ops: [Op] { calls.map(\.op) }

        private func next(_ op: Op, _ query: [String: Any]) -> (OSStatus, Data?) {
            state.withLock {
                $0.calls.append(Call(op: op, query: query))
                guard !$0.steps.isEmpty else { Issue.record("unexpected \(op)"); return (errSecInternalComponent, nil) }
                return $0.steps.removeFirst()
            }
        }

        func add(_ attributes: [String: Any]) -> OSStatus { next(.add, attributes).0 }
        func copyMatching(_ query: [String: Any]) -> (OSStatus, Data?) { next(.copy, query) }
        func update(_ query: [String: Any], _ attributes: [String: Any]) -> OSStatus { next(.update, query).0 }
        func delete(_ query: [String: Any]) -> OSStatus { next(.delete, query).0 }
    }

    static let stored = UUID(uuidString: "6F1A2B3C-4D5E-4F60-8A7B-9C0D1E2F3A4B")!
    static let later = UUID(uuidString: "0A1B2C3D-4E5F-4061-9273-A4B5C6D7E8F9")!
    static let failures: [OSStatus] = [errSecMissingEntitlement, errSecInteractionNotAllowed, errSecInternalComponent, 4711]
    static let corrupt: [Data?] = [Data("nicht-eine-uuid".utf8), Data(), Data([0xFF, 0xFE]), nil]

    private func data(_ id: UUID) -> Data { Data(id.uuidString.utf8) }
    private func string(_ query: [String: Any], _ key: CFString) -> String? { query[key as String] as? String }

    @Test("device: erste erzeugung speichert einmal")
    func firstCallCreatesAndStoresOnce() throws {
        let keychain = Keychain([(errSecItemNotFound, nil), (errSecSuccess, nil)])
        let id = try DeviceIdentity(operations: keychain).current()
        #expect(keychain.ops == [.copy, .add])
        #expect(keychain.calls[1].query[kSecValueData as String] as? Data == data(id))
    }

    @Test("device: eintrag nur auf diesem geraet, eigener dienst")
    func entryUsesDeviceOnlyAccessAndOwnService() throws {
        let keychain = Keychain([(errSecItemNotFound, nil), (errSecSuccess, nil)])
        _ = try DeviceIdentity(operations: keychain).current()
        let read = keychain.calls[0].query, add = keychain.calls[1].query
        for query in [read, add] {
            #expect(string(query, kSecClass) == kSecClassGenericPassword as String)
            #expect(string(query, kSecAttrService) == "com.henning.looseends.device")
            #expect(string(query, kSecAttrAccount) == "device")
            #expect(query[kSecUseDataProtectionKeychain as String] as? Bool == true)
            #expect(query[kSecAttrSynchronizable as String] as? Bool != true)
        }
        #expect(string(add, kSecAttrAccessible) == kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        #expect(read[kSecReturnData as String] as? Bool == true)
    }

    @Test("device: gespeicherte kennung bleibt")
    func storedIdentityIsReturnedUnchanged() throws {
        let keychain = Keychain([(errSecSuccess, data(Self.stored)), (errSecSuccess, data(Self.stored))])
        let identity = DeviceIdentity(operations: keychain)
        #expect(try identity.current() == Self.stored)
        #expect(try identity.current() == Self.stored)
        #expect(keychain.ops == [.copy, .copy])
    }

    @Test("device: kein zwischenspeicher")
    func noInMemoryCache() throws {
        let keychain = Keychain([(errSecSuccess, data(Self.stored)), (errSecSuccess, data(Self.later))])
        let identity = DeviceIdentity(operations: keychain)
        #expect(try identity.current() == Self.stored)
        #expect(try identity.current() == Self.later)
        #expect(keychain.ops == [.copy, .copy])
    }

    @Test("device: lesefehler erzeugt nie eine kennung", arguments: failures)
    func readErrorThrowsAndNeverCreates(status: OSStatus) {
        let keychain = Keychain([(status, data(Self.stored))])
        #expect(throws: DeviceIdentityError.keychain(status)) { try DeviceIdentity(operations: keychain).current() }
        #expect(keychain.ops == [.copy])
    }

    @Test("device: kaputter eintrag wird nicht ersetzt", arguments: corrupt)
    func corruptEntryThrowsAndIsNotReplaced(entry: Data?) {
        let keychain = Keychain([(errSecSuccess, entry)])
        #expect(throws: DeviceIdentityError.corruptData) { try DeviceIdentity(operations: keychain).current() }
        #expect(keychain.ops == [.copy])
    }

    @Test("device: schreibfehler", arguments: failures)
    func addErrorThrows(status: OSStatus) {
        let keychain = Keychain([(errSecItemNotFound, nil), (status, nil)])
        #expect(throws: DeviceIdentityError.keychain(status)) { try DeviceIdentity(operations: keychain).current() }
        #expect(keychain.ops == [.copy, .add])
    }

    @Test("device: duplikat gibt die gespeicherte kennung")
    func duplicateReturnsStoredIdentity() throws {
        let keychain = Keychain([(errSecItemNotFound, nil), (errSecDuplicateItem, nil), (errSecSuccess, data(Self.stored))])
        #expect(try DeviceIdentity(operations: keychain).current() == Self.stored)
        #expect(keychain.ops == [.copy, .add, .copy])
        #expect(keychain.calls[1].query[kSecValueData as String] as? Data != data(Self.stored))
    }

    @Test("device: duplikat ohne lesbare gegenstelle", arguments: [
        (errSecItemNotFound, nil, DeviceIdentityError.keychain(errSecItemNotFound)),
        (errSecMissingEntitlement, nil, .keychain(errSecMissingEntitlement)),
        (errSecInteractionNotAllowed, nil, .keychain(errSecInteractionNotAllowed)),
        (errSecSuccess, Data("nicht-eine-uuid".utf8), .corruptData),
    ] as [(OSStatus, Data?, DeviceIdentityError)])
    func duplicateThenUnreadableThrows(status: OSStatus, entry: Data?, expected: DeviceIdentityError) {
        let keychain = Keychain([(errSecItemNotFound, nil), (errSecDuplicateItem, nil), (status, entry)])
        #expect(throws: expected) { try DeviceIdentity(operations: keychain).current() }
        #expect(keychain.ops == [.copy, .add, .copy])
    }

    @Test("device: fehler ohne kennung")
    func errorsCarryNoIdentity() {
        var texts: [String] = []
        func collect(_ steps: [(OSStatus, Data?)]) {
            let keychain = Keychain(steps)
            do { _ = try DeviceIdentity(operations: keychain).current() } catch {
                var text = String(describing: error)
                if let added = keychain.calls.first(where: { $0.op == .add })?.query[kSecValueData as String] as? Data {
                    #expect(!text.contains(String(decoding: added, as: UTF8.self)), "\(text)")
                }
                texts.append(text)
                text = text.lowercased()
                #expect(!text.contains(Self.stored.uuidString.lowercased()), "\(text)")
            }
        }
        for status in Self.failures {
            collect([(status, data(Self.stored))])
            collect([(errSecItemNotFound, nil), (status, nil)])
            collect([(errSecItemNotFound, nil), (errSecDuplicateItem, nil), (status, data(Self.stored))])
        }
        for entry in Self.corrupt { collect([(errSecSuccess, entry)]) }
        #expect(texts.count == Self.failures.count * 3 + Self.corrupt.count)
        for text in texts { #expect(text.contains("keychain") || text.contains("corruptData"), "\(text)") }
    }
}
