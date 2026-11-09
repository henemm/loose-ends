import Foundation
import Testing
@testable import LooseEnds

/// The account core for the service for Claude (#615 S4b-2): the session store and `AccountState` over `ServiceClient`.
@Suite("AccountState (#615)") @MainActor struct AccountStateTests {
    /// Records every request and answers it with the next prepared reply; runs `hook` once, before the first answer,
    /// so a test can look at the state or call it again while that request is still open.
    actor Wire: HTTPTransport {
        enum Reply: Equatable, Sendable { case status(Int), token(String), offline, invalid, cancel }
        private(set) var requests: [URLRequest] = []
        private var replies: [Reply]
        private var hook: (@MainActor @Sendable () async -> Void)?
        init(_ replies: [Reply]) { self.replies = replies }
        func onFirst(_ hook: @escaping @MainActor @Sendable () async -> Void) { self.hook = hook }

        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests.append(request)
            if let hook { self.hook = nil; await hook() }
            guard !replies.isEmpty else { throw ServiceError.rejected(599) }
            switch replies.removeFirst() {
            case .offline: throw URLError(.notConnectedToInternet)
            case .invalid: throw ServiceError.invalidResponse
            case .cancel: throw CancellationError()
            case .token(let token): return (Data(#"{"sessionToken":"\#(token)"}"#.utf8), Self.response(request, 200))
            case .status(let status): return (Data(), Self.response(request, status))
            }
        }

        private static func response(_ request: URLRequest, _ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
    }

    static let base = URL(string: "https://example.test")!

    private func make(_ replies: [Wire.Reply], token: String? = nil) -> (AccountState, InMemorySessionStore, Wire) {
        let wire = Wire(replies), store = InMemorySessionStore(token: token)
        return (AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: store), store, wire)
    }

    private func signIn(_ state: AccountState) async throws {
        _ = try state.beginSignIn()
        await state.completeSignIn(identityToken: "id", code: "c")
    }

    private func body(_ request: URLRequest) throws -> [String: String] {
        try #require(JSONSerialization.jsonObject(with: try #require(request.httpBody)) as? [String: String])
    }

    @Test("account: start mit token")
    func startWithToken() async {
        let (state, _, wire) = make([], token: "T1")
        #expect(state.status == .signedIn && state.lastProblem == nil)
        #expect(await wire.requests.isEmpty)
    }

    @Test("account: start ohne token und bei lesefehler")
    func startWithoutToken() async {
        let (empty, _, wire) = make([])
        let store = InMemorySessionStore(token: "T1")
        store.failNext(load: true)
        let unreadable = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: store)
        #expect(empty.status == .signedOut && unreadable.status == .signedOut)
        #expect(await wire.requests.isEmpty)
    }

    @Test("account: beginsignin nur aus erlaubten zustaenden")
    func beginSignInStates() async throws {
        for (reply, start) in [(Wire.Reply?.none, AccountState.Status.signedOut), (.status(401), .notAllowed), (.status(503), .retryLater)] {
            let (state, _, _) = make(reply.map { [$0] } ?? [])
            if reply != nil { try await signIn(state) }
            #expect(state.status == start)
            let hashed = try state.beginSignIn()
            #expect(hashed.count == 64 && hashed.allSatisfy { "0123456789abcdef".contains($0) } && state.status == .signingIn)
        }
        let (state, _, wire) = make([.token("T1")])
        let first = try state.beginSignIn()
        #expect(throws: AccountError.notPossibleNow) { try state.beginSignIn() }
        #expect(state.status == .signingIn)
        await state.completeSignIn(identityToken: "id", code: "c")
        let sent = try body(try #require(await wire.requests.first))
        #expect(Nonce.hash(try #require(sent["nonce"])) == first)
        #expect(throws: AccountError.notPossibleNow) { try state.beginSignIn() }
        #expect(state.status == .signedIn)
        let (deleting, _, deleteWire) = make([.status(204)], token: "T1")
        await deleteWire.onFirst {
            #expect(deleting.status == .deleting)
            #expect(throws: AccountError.notPossibleNow) { try deleting.beginSignIn() }
        }
        await deleting.deleteAccount()
        #expect(deleting.status == .signedOut)
    }

    @Test("account: body traegt rohe nonce zum hash")
    func bodyCarriesRawNonce() async throws {
        let (state, _, wire) = make([.token("T1")])
        let hashed = try state.beginSignIn()
        await state.completeSignIn(identityToken: "id-token", code: "auth-code")
        let requests = await wire.requests
        let request = try #require(requests.first)
        let fields = try body(request)
        #expect(requests.count == 1 && request.url?.path() == "/auth/apple")
        #expect(Set(fields.keys) == ["identityToken", "nonce", "code"])
        #expect(fields["identityToken"] == "id-token" && fields["code"] == "auth-code")
        let nonce = try #require(fields["nonce"])
        #expect(nonce.count == 43 && Nonce.hash(nonce) == hashed)
        let (other, _, _) = make([])
        #expect(try other.beginSignIn() != hashed)
    }

    @Test("account: completesignin ohne nonce und nonce einmalig")
    func completeNeedsNonce() async throws {
        for token in [nil, "T1"] as [String?] {
            let (state, _, wire) = make([.token("T2")], token: token)
            let before = state.status
            await state.completeSignIn(identityToken: "id", code: "c")
            #expect(state.status == before)
            #expect(await wire.requests.isEmpty)
        }
        for reply in [Wire.Reply.token("T1"), .status(401), .cancel] {
            let (state, _, wire) = make([reply, .token("T2")])
            try await signIn(state)
            let after = state.status
            await state.completeSignIn(identityToken: "id", code: "c")
            #expect(await wire.requests.count == 1)
            #expect(state.status == after)
        }
    }

    @Test("account: anmelden speichert und ist angemeldet")
    func signInStores() async throws {
        let (state, store, _) = make([.token("T1")])
        try await signIn(state)
        #expect(store.token == "T1" && state.status == .signedIn && state.lastProblem == nil)
    }

    @Test("account: speicherfehler ergibt abgemeldet")
    func saveFailure() async throws {
        let (state, store, _) = make([.token("T1")])
        store.failNext(save: true)
        try await signIn(state)
        #expect(state.status == .signedOut && store.token == nil)
    }

    @Test("account: anmelden fehlerabbildung", arguments: [
        (Wire.Reply.status(401), AccountState.Status.notAllowed), (.status(503), .retryLater), (.offline, .retryLater),
        (.status(400), .signedOut), (.status(500), .signedOut), (.token(""), .signedOut), (.cancel, .signedOut),
    ])
    func signInFailures(reply: Wire.Reply, expected: AccountState.Status) async throws {
        let (state, store, _) = make([reply])
        try await signIn(state)
        #expect(state.status == expected && store.token == nil)
        if reply == .cancel { #expect(state.lastProblem == nil) }
    }

    @Test("account: cancelsignin")
    func cancelSignIn() async throws {
        let (state, _, wire) = make([.token("T1")])
        _ = try state.beginSignIn()
        state.cancelSignIn()
        #expect(state.status == .signedOut)
        await state.completeSignIn(identityToken: "id", code: "c")
        state.cancelSignIn()
        #expect(state.status == .signedOut)
        #expect(await wire.requests.isEmpty)
        let (signedIn, _, _) = make([], token: "T1")
        signedIn.cancelSignIn()
        #expect(signedIn.status == .signedIn)
        let (running, store, runningWire) = make([.token("T2")])
        await runningWire.onFirst {
            running.cancelSignIn()
            #expect(running.status == .signingIn)
        }
        try await signIn(running)
        #expect(running.status == .signedIn && store.token == "T2")
    }

    @Test("account: signout lokal zuerst dann dienst", arguments: [Wire.Reply.status(204), .status(401), .status(503), .cancel])
    func signOutLocalFirst(reply: Wire.Reply) async throws {
        let (state, store, wire) = make([reply], token: "T1")
        await wire.onFirst {
            #expect(store.token == nil && state.status == .signedOut)
        }
        await state.signOut()
        let requests = await wire.requests
        #expect(requests.count == 1 && requests.first?.url?.path() == "/auth/logout")
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer T1")
        #expect(state.status == .signedOut && state.lastProblem == nil)
    }

    @Test("account: signout ohne token und bei loeschfehler")
    func signOutWithoutToken() async throws {
        let (empty, _, emptyWire) = make([])
        await empty.signOut()
        let (unreadable, unreadableStore, unreadableWire) = make([], token: "T1")
        unreadableStore.failNext(load: true)
        await unreadable.signOut()
        #expect(empty.status == .signedOut && unreadable.status == .signedOut)
        #expect(await emptyWire.requests.isEmpty)
        #expect(await unreadableWire.requests.isEmpty)
        let (stuck, stuckStore, stuckWire) = make([.status(204)], token: "T1")
        stuckStore.failNext(clear: true)
        await stuck.signOut()
        let requests = await stuckWire.requests
        #expect(stuck.status == .signedOut)
        #expect(requests.count == 1 && requests.first?.url?.path() == "/auth/logout")
    }

    @Test("account: konto loeschen erfolg und nur aus signedin")
    func deleteOnlyWhenSignedIn() async throws {
        let (state, store, wire) = make([.status(204)], token: "T1")
        await state.deleteAccount()
        let requests = await wire.requests
        #expect(requests.count == 1 && requests.first?.url?.path() == "/auth/delete")
        #expect(requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer T1")
        #expect(store.token == nil && state.status == .signedOut && state.lastProblem == nil)
        // From signedOut, signingIn, notAllowed and retryLater nothing beyond the sign-in itself is sent.
        for (first, start) in [(Wire.Reply?.none, AccountState.Status.signedOut), (.status(401), .notAllowed), (.status(503), .retryLater)] {
            let (other, _, otherWire) = make((first.map { [$0] } ?? []) + [.status(204)])
            if first != nil { try await signIn(other) }
            await other.deleteAccount()
            #expect(other.status == start)
            #expect(await otherWire.requests.count == (first == nil ? 0 : 1))
        }
        let (signing, _, signingWire) = make([.status(204)])
        _ = try signing.beginSignIn()
        await signing.deleteAccount()
        #expect(signing.status == .signingIn)
        #expect(await signingWire.requests.isEmpty)
        for unreadable in [true, false] {
            let (gone, goneStore, goneWire) = make([.status(204)], token: "T1")
            if unreadable { goneStore.failNext(load: true) } else { try goneStore.clear() }
            await gone.deleteAccount()
            #expect(gone.status == .signedOut)
            #expect(await goneWire.requests.isEmpty)
        }
    }

    @Test("account: konto loeschen fehlerabbildung", arguments: [
        (Wire.Reply.status(401), AccountState.Status.signedOut, String?.none, AccountState.Problem?.none),
        (.status(503), .signedIn, "T1", .retryLater), (.offline, .signedIn, "T1", .retryLater),
        (.status(500), .signedIn, "T1", .retryLater), (.invalid, .signedIn, "T1", .retryLater),
        (.cancel, .signedIn, "T1", nil),
    ])
    func deleteFailures(reply: Wire.Reply, status: AccountState.Status, token: String?, problem: AccountState.Problem?) async {
        let (state, store, _) = make([reply, .status(204)], token: "T1")
        await state.deleteAccount()
        #expect(state.status == status && store.token == token && state.lastProblem == problem)
        guard status == .signedIn else { return }
        await state.deleteAccount()
        #expect(state.status == .signedOut && state.lastProblem == nil && store.token == nil)
    }

    @Test("account: veraltete 401 loescht keine neue sitzung")
    func staleUnauthorized() async {
        let (state, store, wire) = make([.status(401)], token: "T1")
        await wire.onFirst {
            do { try store.save("T2") } catch { Issue.record(error) }
        }
        await state.deleteAccount()
        #expect(store.token == "T2" && state.status == .signedIn)
    }

    @Test("account: doppelaufrufe waehrend anfrage")
    func doubleCalls() async throws {
        let (signing, signingStore, signingWire) = make([.token("T1"), .token("T2")])
        await signingWire.onFirst {
            await signing.completeSignIn(identityToken: "id", code: "c")
            await signing.signOut()
            #expect(throws: AccountError.notPossibleNow) { try signing.beginSignIn() }
        }
        try await signIn(signing)
        #expect(await signingWire.requests.count == 1)
        #expect(signing.status == .signedIn && signingStore.token == "T1")
        let (deleting, deletingStore, deletingWire) = make([.status(204), .status(204)], token: "T1")
        await deletingWire.onFirst {
            await deleting.deleteAccount()
            await deleting.signOut()
            #expect(throws: AccountError.notPossibleNow) { try deleting.beginSignIn() }
            #expect(deleting.status == .deleting)
        }
        await deleting.deleteAccount()
        #expect(await deletingWire.requests.count == 1)
        #expect(deleting.status == .signedOut && deletingStore.token == nil)
    }

    @Test("account: zustand ohne token und nonce")
    func noSecretsInState() async throws {
        let marker = "SECRET-TOKEN"
        let (state, store, wire) = make([.token(marker), .status(503), .status(401)])
        var seen: [String] = []
        func look() { seen += [String(describing: state.status), String(describing: state.lastProblem)] }
        let hashed = try state.beginSignIn()
        await state.completeSignIn(identityToken: marker + "-id", code: marker + "-code")
        look()
        do { _ = try state.beginSignIn() } catch { seen.append(String(describing: error)) }
        await state.deleteAccount()
        look()
        await state.deleteAccount()
        look()
        let nonce = try #require(try body(try #require(await wire.requests.first))["nonce"])
        #expect(seen.count == 7 && store.token == nil)
        for text in seen { #expect(!text.contains(marker) && !text.contains(nonce) && !text.contains(hashed)) }
    }
}
