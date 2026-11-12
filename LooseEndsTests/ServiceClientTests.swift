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
    } + Route.allCases.flatMap { route -> [(Route, Int, ServiceError)] in
        [(route, 429, .tooManyRequests), (route, 409, .refused)]
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

    // MARK: - The app's routes (#795 S2a)

    enum AppRoute: String, CaseIterable, Sendable { case transcript, claim, result }
    static let device = UUID(uuidString: "A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF")!
    static let orderID = UUID(uuidString: "0F1E2D3C-4B5A-4978-8695-A4B3C2D1E0F9")!
    static let taskID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
    static let moment = Date(timeIntervalSince1970: 1_800_000_000)
    static let transcript = Transcript(
        version: 1, generatedAt: moment, nowCount: 1,
        now: .init(knaeuel: nil, today: [taskID], lined: [], waiting: []),
        tasks: [.init(id: taskID, title: "Steuer", status: .active, dueDate: moment, dueHasTime: false,
                      contexts: [], project: nil, nextRank: nil, isKnaeuel: false)],
        views: nil
    )
    static let result = OrderResult(orderID: orderID, outcome: .rejected, reason: .stale, taskID: taskID)

    private func call(_ route: AppRoute, _ client: ServiceClient) async throws {
        switch route {
        case .transcript: try await client.putTranscript(Self.transcript, sessionToken: Self.token)
        case .claim: _ = try await client.claimOrder(sessionToken: Self.token, device: Self.device)
        case .result: try await client.putResult(Self.result, sessionToken: Self.token, device: Self.device)
        }
    }

    private func fake(_ replies: [FakeTransport.Reply]) -> (ServiceClient, FakeTransport) {
        let transport = FakeTransport(replies)
        return (ServiceClient(baseURL: Self.base, transport: transport), transport)
    }

    @Test("app: transcript draht-vertrag", arguments: [
        ("https://example.test", "/app/transcript"), ("https://example.test/", "/app/transcript"),
        ("https://example.test/api", "/api/app/transcript"),
    ])
    func putTranscriptWire(base: String, path: String) async throws {
        let transport = FakeTransport([.answer(204, Data())])
        let client = ServiceClient(baseURL: try #require(URL(string: base)), transport: transport)
        try await client.putTranscript(Self.transcript, sessionToken: Self.token)
        let requests = await transport.requests
        let request = try #require(requests.first)
        #expect(requests.count == 1 && request.httpMethod == "POST" && request.url?.path() == path)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "X-Device") == nil)
        #expect(request.httpBody == (try TranscriptCodec.encode(Self.transcript)))
    }

    @Test("app: claim draht-vertrag und kein auftrag")
    func claimOrderWireAndNone() async throws {
        let (client, transport) = fake([.answer(204, Data())])
        #expect(try await client.claimOrder(sessionToken: Self.token, device: Self.device) == .none)
        let requests = await transport.requests
        let request = try #require(requests.first)
        #expect(requests.count == 1 && request.httpMethod == "POST" && request.url?.path() == "/app/orders/claim")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)")
        #expect(request.value(forHTTPHeaderField: "X-Device") == "a1b2c3d4-e5f6-4711-8899-aabbccddeeff")
        #expect(request.httpBody == nil && request.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test("app: result draht-vertrag")
    func putResultWire() async throws {
        let (client, transport) = fake([.answer(204, Data())])
        try await client.putResult(Self.result, sessionToken: Self.token, device: Self.device)
        let requests = await transport.requests
        let request = try #require(requests.first)
        #expect(requests.count == 1 && request.httpMethod == "POST" && request.url?.path() == "/app/orders/result")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)")
        #expect(request.value(forHTTPHeaderField: "X-Device") == "a1b2c3d4-e5f6-4711-8899-aabbccddeeff")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody == (try TranscriptCodec.encode(Self.result)))
    }

    static let everyKind: [Order] = [
        Order(id: orderID, kind: .capture, text: "Milch kaufen"),
        Order(id: orderID, kind: .complete, taskID: taskID, expectedStatus: .active),
        Order(id: orderID, kind: .setDue, taskID: taskID, date: moment, hasTime: true, expectedDueDate: moment),
        Order(id: orderID, kind: .setNext, taskID: taskID, expectedStatus: .unverified, on: true, expectedNextRank: 2.5),
        Order(id: orderID, kind: .park, taskID: taskID, expectedStatus: .unprocessed),
        Order(id: orderID, kind: .addSubtask, text: "Belege", taskID: taskID, expectedStatus: .active),
    ]

    @Test("app: claim liest jede auftragsart", arguments: everyKind)
    func claimOrderReadsEveryKind(order: Order) async throws {
        let (client, _) = fake([.answer(200, try TranscriptCodec.encode(order))])
        #expect(try await client.claimOrder(sessionToken: Self.token, device: Self.device) == .order(order))
    }

    @Test("app: giftauftrag behaelt die kennung", arguments: [
        #"{"version":1,"id":"0F1E2D3C-4B5A-4978-8695-A4B3C2D1E0F9","kind":"teleport"}"#,
        #"{"version":1,"id":"0f1e2d3c-4b5a-4978-8695-a4b3c2d1e0f9","text":"x"}"#,
        #"{"version":1,"id":"0F1E2D3C-4B5A-4978-8695-A4B3C2D1E0F9","kind":"setDue","hasTime":"ja"}"#,
        #"{"version":1,"id":"0F1E2D3C-4B5A-4978-8695-A4B3C2D1E0F9","kind":"park","expectedStatus":"floating"}"#,
    ])
    func claimOrderPoisonKeepsId(body: String) async throws {
        let (client, _) = fake([.answer(200, Data(body.utf8))])
        #expect(try await client.claimOrder(sessionToken: Self.token, device: Self.device) == .unreadable(Self.orderID))
    }

    @Test("app: claim ohne rettbare kennung ist ungueltig", arguments: [
        "kein json", "", #"[{"id":"0F1E2D3C-4B5A-4978-8695-A4B3C2D1E0F9"}]"#, #"{"kind":"capture"}"#, #"{"id":42}"#,
        #"{"id":"nicht-eine-uuid"}"#,
    ])
    func claimOrderWithoutIdIsInvalid(body: String) async {
        let (client, _) = fake([.answer(200, Data(body.utf8))])
        await #expect(throws: ServiceError.invalidResponse) { try await call(.claim, client) }
    }

    @Test("app: erfolgsstatus je weg")
    func successStatusPerRoute() async throws {
        for route in [AppRoute.transcript, .result] {
            try await call(route, fake([.answer(204, Data())]).0)
            await #expect(throws: ServiceError.rejected(200)) { try await call(route, fake([.answer(200, Data())]).0) }
        }
        await #expect(throws: ServiceError.rejected(202)) { try await call(.claim, fake([.answer(202, Data())]).0) }
    }

    @Test("app: 409 ist refused", arguments: AppRoute.allCases)
    func conflictIsRefused(route: AppRoute) async {
        await #expect(throws: ServiceError.refused) { try await call(route, fake([.answer(409, Data())]).0) }
    }

    @Test("app: 429 bricht ab, genau eine anfrage", arguments: AppRoute.allCases)
    func tooManyRequestsPerRoute(route: AppRoute) async {
        let (client, transport) = fake([.answer(429, Data()), .answer(204, Data())])
        await #expect(throws: ServiceError.tooManyRequests) { try await call(route, client) }
        #expect(await transport.requests.count == 1)
    }

    static let appStatusCases: [(AppRoute, Int, ServiceError)] = AppRoute.allCases.flatMap { route in
        [(route, 401, .unauthorized), (route, 503, .unavailable)]
            + [400, 413, 415, 405, 500].map { (route, $0, ServiceError.rejected($0)) }
    }

    @Test("app: statusabbildung je weg", arguments: appStatusCases)
    func statusMappingAppRoutes(route: AppRoute, status: Int, expected: ServiceError) async {
        await #expect(throws: expected) { try await call(route, fake([.answer(status, Data())]).0) }
    }

    @Test("app: transportfehler", arguments: AppRoute.allCases)
    func appRoutesTransportErrors(route: AppRoute) async {
        for code in [URLError.Code.notConnectedToInternet, .timedOut, .cannotConnectToHost] {
            await #expect(throws: ServiceError.unavailable) { try await call(route, fake([.fail(URLError(code))]).0) }
        }
        await #expect(throws: CancellationError.self) { try await call(route, fake([.fail(CancellationError())]).0) }
    }

    @Test("app: abbruch ist cancellation", arguments: AppRoute.allCases)
    func appRoutesCancelledIsCancellation(route: AppRoute) async {
        await #expect(throws: CancellationError.self) { try await call(route, fake([.fail(URLError(.cancelled))]).0) }
    }

    @Test("app: fehler ohne token, koerper und adresse", arguments: AppRoute.allCases)
    func appRoutesErrorsCarryNoSecrets(route: AppRoute) async {
        let secret = Data(#"{"detail":"SECRET-BODY"}"#.utf8)
        var replies: [FakeTransport.Reply] = [401, 409, 429, 503, 500].map { .answer($0, secret) }
            + [.answer(200, secret), .fail(URLError(.timedOut))]
        if route == .claim {
            let order = #"{"version":1,"id":"0F1E2D3C-4B5A-4978-8695-A4B3C2D1E0F9","kind":"capture","text":"SECRET-BODY"}"#
            replies += [.answer(500, Data(order.utf8)), .answer(200, Data("SECRET-BODY kein json".utf8))]
        }
        var failures = 0
        for reply in replies {
            do { try await call(route, fake([reply]).0) } catch {
                failures += 1
                let text = String(describing: error)
                #expect(!text.contains(Self.token) && !text.contains("SECRET-BODY") && !text.contains("example.test"),
                        "\(route): \(text)")
            }
        }
        #expect(failures == replies.count)
    }
}
