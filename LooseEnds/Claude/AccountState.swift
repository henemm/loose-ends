import Foundation
import Observation
import OSLog

enum AccountError: Error, Equatable {
    case notPossibleNow
}

/// Whether this device is signed in to the service for Claude, and the steps of signing in, out and deleting
/// (#615 S4b-2). `signingIn` and `deleting` are also the lock against a second request: everything runs on the
/// main actor. Neither the state, an error nor a log line ever names a token or a nonce. Nothing in the app calls it yet.
@MainActor @Observable final class AccountState {
    enum Status: Equatable, Sendable { case signedOut, signingIn, signedIn, deleting, notAllowed, retryLater }
    enum Problem: Equatable, Sendable { case retryLater }

    private(set) var status: Status
    private(set) var lastProblem: Problem?
    @ObservationIgnored private let client: ServiceClient
    @ObservationIgnored private let store: any SessionStoring
    /// Open between `beginSignIn` and the request of `completeSignIn`, which uses it up.
    @ObservationIgnored private var nonce: Nonce?

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "account")

    /// Reads the store once and sends nothing.
    init(client: ServiceClient, store: any SessionStoring) {
        self.client = client
        self.store = store
        status = Self.storedToken(in: store) == nil ? .signedOut : .signedIn
    }

    /// Starts a sign-in and returns the hashed nonce for Apple's request. Only from `signedOut`, `notAllowed`, `retryLater`.
    func beginSignIn() throws -> String {
        guard [.signedOut, .notAllowed, .retryLater].contains(status) else { throw AccountError.notPossibleNow }
        let fresh = try Nonce()
        nonce = fresh
        status = .signingIn
        lastProblem = nil
        return fresh.hashed
    }

    /// Hands Apple's answer to the service with the raw nonce; stores the session token before it counts as signed in.
    func completeSignIn(identityToken: String, code: String) async {
        guard status == .signingIn, let open = nonce else { return }
        nonce = nil
        let token: String
        do {
            token = try await client.signIn(identityToken: identityToken, nonce: open.raw, code: code)
        } catch {
            status = Self.signInStatus(after: error)
            return
        }
        do {
            try store.save(token)
            status = .signedIn
        } catch {
            Self.logger.error("sign-in not stored: \(String(describing: type(of: error)), privacy: .public)")
            status = .signedOut
        }
    }

    /// Drops an open nonce before its request started; without effect in every other state.
    func cancelSignIn() {
        guard status == .signingIn, nonce != nil else { return }
        nonce = nil
        status = .signedOut
    }

    /// Ends the session here first, then asks the service to end it as well; the service's answer changes nothing.
    func signOut() async {
        guard status != .signingIn, status != .deleting else { return }
        guard let token = Self.storedToken(in: store) else {
            status = .signedOut
            return
        }
        do {
            try store.clear()
        } catch {
            Self.logger.error("sign-out not cleared: \(String(describing: type(of: error)), privacy: .public)")
        }
        status = .signedOut
        lastProblem = nil
        do {
            try await client.logout(sessionToken: token)
        } catch {
            Self.logger.info("logout at service failed: \(Self.caseName(error), privacy: .public)")
        }
    }

    /// Deletes the account behind the stored session. Only from `signedIn`; a failure keeps the session visible.
    func deleteAccount() async {
        guard status == .signedIn else { return }
        guard let token = Self.storedToken(in: store) else {
            status = .signedOut
            return
        }
        status = .deleting
        lastProblem = nil
        do {
            try await client.deleteAccount(sessionToken: token)
            clearStore()
            status = .signedOut
        } catch ServiceError.unauthorized {
            status = dropSession(token, during: "delete")
        } catch is CancellationError {
            status = .signedIn
        } catch {
            Self.logger.error("delete failed: \(Self.caseName(error), privacy: .public)")
            status = .signedIn
            lastProblem = .retryLater
        }
    }

    /// The one way to the app routes (#795 S2b): only from `signedIn`, with the token read fresh from the store; without
    /// one nothing is sent and the result is `nil`. Every failure goes to the caller unchanged; a 401 first drops the
    /// session, but only if the store still holds that token, and only turns a status that is still `signedIn`.
    func withSession<T: Sendable>(_ call: (ServiceClient, String) async throws -> T) async throws -> T? {
        guard status == .signedIn, let token = Self.storedToken(in: store) else { return nil }
        do {
            return try await call(client, token)
        } catch ServiceError.unauthorized {
            let next = dropSession(token, during: "session")
            if status == .signedIn { status = next }
            throw ServiceError.unauthorized
        }
    }

    /// The service no longer knows `token`: clear the store only if it still holds that one (a newer session stays).
    private func dropSession(_ token: String, during reason: StaticString) -> Status {
        Self.logger.info("\(reason.description, privacy: .public): session unknown at service")
        guard let stored = Self.storedToken(in: store) else { return .signedOut }
        guard stored == token else { return .signedIn }
        clearStore()
        return .signedOut
    }

    private func clearStore() {
        do {
            try store.clear()
        } catch {
            Self.logger.error("store not cleared: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    /// The stored token; a read failure counts as none and is logged.
    private static func storedToken(in store: any SessionStoring) -> String? {
        do {
            return try store.load()
        } catch {
            logger.error("store not readable: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    private static func signInStatus(after error: any Error) -> Status {
        switch error {
        case ServiceError.unauthorized: return .notAllowed
        case ServiceError.unavailable: return .retryLater
        case is CancellationError: return .signedOut
        default:
            logger.error("sign-in failed: \(caseName(error), privacy: .public)")
            return .signedOut
        }
    }

    /// The name of the failure, never a value it might carry beyond a status code.
    private static func caseName(_ error: any Error) -> String {
        if let service = error as? ServiceError { return String(describing: service) }
        return String(describing: type(of: error))
    }
}
