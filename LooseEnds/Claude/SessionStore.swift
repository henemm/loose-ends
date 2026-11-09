import Foundation
import Synchronization

/// Where the session token of the service for Claude lives (#615 S4b-2). `load` gives `nil` when nothing is stored,
/// `clear` without a stored token is no error. The keychain store is `KeychainSessionStore` (S4b-3).
protocol SessionStoring: Sendable {
    func load() throws -> String?
    func save(_ token: String) throws
    func clear() throws
}

/// A failure of the store: played in by a test, a keychain status, or an entry that is no token. Never carries a token.
enum SessionStoreError: Error, Equatable {
    case injected
    case keychain(OSStatus)
    case corruptData
}

/// The store in memory: for the tests now, later under `--ui-testing`. Works without failure unless one is played in.
final class InMemorySessionStore: SessionStoring {
    private struct Contents {
        var token: String?
        var failLoad = false, failSave = false, failClear = false
    }

    private let contents: Mutex<Contents>

    init(token: String? = nil) {
        contents = Mutex(Contents(token: token))
    }

    var token: String? { contents.withLock { $0.token } }

    /// The next `load`, `save` or `clear` named here throws `SessionStoreError.injected`, once.
    func failNext(load: Bool = false, save: Bool = false, clear: Bool = false) {
        contents.withLock {
            $0.failLoad = $0.failLoad || load
            $0.failSave = $0.failSave || save
            $0.failClear = $0.failClear || clear
        }
    }

    func load() throws -> String? {
        try contents.withLock {
            if $0.failLoad { $0.failLoad = false; throw SessionStoreError.injected }
            return $0.token
        }
    }

    func save(_ token: String) throws {
        try contents.withLock {
            if $0.failSave { $0.failSave = false; throw SessionStoreError.injected }
            $0.token = token
        }
    }

    func clear() throws {
        try contents.withLock {
            if $0.failClear { $0.failClear = false; throw SessionStoreError.injected }
            $0.token = nil
        }
    }
}
