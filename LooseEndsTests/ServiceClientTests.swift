import Foundation
import Testing
@testable import LooseEnds

/// The app's core for the service for Claude (#615 S4b-1): the nonce and the three routes of `server/src/auth.ts`.
@Suite("ServiceClient (#615)") struct ServiceClientTests {
    /// Records every request and answers each call with the next prepared status and body, or throws the prepared error.
    actor FakeTransport: HTTPTransport {
        enum Reply { case answer(Int, Data), fail(any Error) }
        private(set) var requests: [URLRequest] = []
        private var replies: [Reply]
        init(_ replies: [Reply] = []) { self.replies = replies }

        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests.append(request)
            switch replies.removeFirst() {
            case .fail(let error): throw error
            case .answer(let status, let body):
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (body, response)
            }
        }
    }

    enum Route: String, CaseIterable, Sendable { case signIn, logout, delete }
    static let base = URL(string: "https://example.test")!
    static let token = "SECRET-TOKEN"

    private func call(_ route: Route, _ client: ServiceClient) async throws {
        switch route {
        case .signIn: _ = try await client.signIn(identityToken: Self.token, nonce: "n", code: "c")
        case .logout: try await client.logout(sessionToken: Self.token)
        case .delete: try await client.deleteAccount(sessionToken: Self.token)
        }
    }

    private func bodyKeys(_ request: URLRequest) throws -> [String: String] {
        let object = try JSONSerialization.jsonObject(with: try #require(request.httpBody))
        return try #require(object as? [String: String])
    }

    @Test("nonce: hash testvektoren")
    func nonceHashVectors() {
        let abc = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        #expect(Nonce.hash("abc") == abc)
        #expect(Nonce(raw: "abc").hashed == abc)
        #expect(abc.count == 64 && abc.allSatisfy { "0123456789abcdef".contains($0) })
        // printf 'äö' | shasum -a 256 (UTF-8 bytes c3 a4 c3 b6)
        #expect(Nonce.hash("\u{E4}\u{F6}") == "6641ae9ec35541a9e57cc59f2a3f68f4b7922fd03ebfa524654d7b7b4dd8f752")
    }

    @Test("nonce: roher wert 32 byte base64url und verschieden")
    func nonceRandomForm() throws {
        let first = try Nonce(), second = try Nonce()
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        #expect(first.raw.count == 43 && first.raw.allSatisfy { alphabet.contains($0) })
        let base64 = first.raw.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/") + "="
        #expect(Data(base64Encoded: base64)?.count == 32)
        #expect(first.raw != second.raw)
        #expect(first.hashed == Nonce.hash(first.raw))
    }

    @Test("serviceclient: erzeugen sendet nichts")
    func creatingSendsNothing() async throws {
        let transport = FakeTransport()
        _ = ServiceClient(baseURL: Self.base, transport: transport)
        _ = try Nonce()
        #expect(await transport.requests.isEmpty)
    }

    @Test("serviceclient: signin draht-vertrag", arguments: [
        ("https://example.test", "/auth/apple"), ("https://example.test/", "/auth/apple"), ("https://example.test/api", "/api/auth/apple"),
    ])
    func signInWire(base: String, path: String) async throws {
        let transport = FakeTransport([.answer(200, Data(#"{"sessionToken":"abc123"}"#.utf8))])
        let client = ServiceClient(baseURL: try #require(URL(string: base)), transport: transport)
        #expect(try await client.signIn(identityToken: "id-token", nonce: "raw-nonce", code: "auth-code") == "abc123")
        let requests = await transport.requests
        let request = try #require(requests.first)
        #expect(requests.count == 1 && request.httpMethod == "POST" && request.url?.path() == path)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(try bodyKeys(request) == ["identityToken": "id-token", "nonce": "raw-nonce", "code": "auth-code"])
    }

    @Test("serviceclient: signin ungueltige antwort", arguments: [
        #"{"sessionToken":""}"#, #"{"other":"x"}"#, #"{"sessionToken":42}"#, #"["abc123"]"#, #"{"sessionToken":"#,
    ])
    func signInInvalidAnswer(body: String) async {
        let client = ServiceClient(baseURL: Self.base, transport: FakeTransport([.answer(200, Data(body.utf8))]))
        await #expect(throws: ServiceError.invalidResponse) { try await call(.signIn, client) }
    }

    @Test("serviceclient: logout und delete draht-vertrag", arguments: [(Route.logout, "/auth/logout"), (Route.delete, "/auth/delete")])
    func bearerWire(route: Route, path: String) async throws {
        let transport = FakeTransport([.answer(204, Data())])
        try await call(route, ServiceClient(baseURL: Self.base, transport: transport))
        let requests = await transport.requests
        let request = try #require(requests.first)
        #expect(requests.count == 1 && request.httpMethod == "POST" && request.url?.path() == path)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)")
        #expect(request.httpBody == nil && request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    static let statusCases: [(Route, Int, ServiceError)] = Route.allCases.flatMap { route in
        [(route, 401, .unauthorized), (route, 503, .unavailable)]
            + [400, 405, 413, 415, 500].map { (route, $0, ServiceError.rejected($0)) }
            + [route == .signIn ? (route, 204, .rejected(204)) : (route, 200, .rejected(200))]
    }

    @Test("serviceclient: statusabbildung je route", arguments: statusCases)
    func statusMapping(route: Route, status: Int, expected: ServiceError) async {
        let client = ServiceClient(baseURL: Self.base, transport: FakeTransport([.answer(status, Data())]))
        await #expect(throws: expected) { try await call(route, client) }
    }

    @Test("serviceclient: transportfehler", arguments: Route.allCases)
    func transportErrors(route: Route) async {
        for code in [URLError.Code.notConnectedToInternet, .timedOut, .cannotConnectToHost] {
            let client = ServiceClient(baseURL: Self.base, transport: FakeTransport([.fail(URLError(code))]))
            await #expect(throws: ServiceError.unavailable) { try await call(route, client) }
        }
        let client = ServiceClient(baseURL: Self.base, transport: FakeTransport([.fail(CancellationError())]))
        await #expect(throws: CancellationError.self) { try await call(route, client) }
    }

    @Test("serviceclient: abbruch ist cancellation", arguments: Route.allCases)
    func cancelledIsCancellation(route: Route) async {
        let client = ServiceClient(baseURL: Self.base, transport: FakeTransport([.fail(URLError(.cancelled))]))
        await #expect(throws: CancellationError.self) { try await call(route, client) }
    }

    @Test("serviceclient: fehler ohne token und koerper", arguments: Route.allCases)
    func errorsCarryNoSecrets(route: Route) async {
        let body = Data(#"{"sessionToken":"","detail":"SECRET-BODY"}"#.utf8)
        for reply in [FakeTransport.Reply.answer(401, body), .answer(503, body), .answer(500, body), .answer(200, body),
                      .fail(URLError(.timedOut))] {
            let client = ServiceClient(baseURL: Self.base, transport: FakeTransport([reply]))
            do { try await call(route, client) } catch {
                let text = String(describing: error)
                #expect(!text.contains(Self.token) && !text.contains("SECRET-BODY"), "\(route): \(text)")
            }
        }
    }
}
