import Foundation
import XCTest
@testable import LooseEnds

/// The device token for the wake-up (#795 S5c-1): `POST /app/device` on the wire, the push environment from the build's
/// mark, and the registration that sends a token and environment once through the session. The wire is a stand-in;
/// nothing here reaches the network.
@MainActor final class DeviceRegistrationTests: XCTestCase {
    /// Answers in the order given and records every request; an answer can be held back for `delay`.
    actor Wire: HTTPTransport {
        enum Reply: Sendable {
            case status(Int, String = "")
            case failure(URLError.Code)
        }

        private(set) var requests: [URLRequest] = []
        private var replies: [Reply]
        private let delay: Duration

        init(_ replies: [Reply] = [], delay: Duration = .zero) {
            self.replies = replies
            self.delay = delay
        }

        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            requests.append(request)
            if delay > .zero { try await Task.sleep(for: delay) }
            let reply = replies.isEmpty ? .status(599) : replies.removeFirst()
            switch reply {
            case .status(let status, let body):
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1",
                                               headerFields: nil)!
                return (Data(body.utf8), response)
            case .failure(let code):
                throw URLError(code)
            }
        }
    }

    /// Counts how often the device id was read; `fail` makes the read throw.
    @MainActor final class DeviceProbe {
        struct Unreadable: Error {}
        let id = UUID(uuidString: "6F1C2A3B-4D5E-4F60-8A7B-9C0D1E2F3A4B")!
        var reads = 0
        var fail = false

        func read() throws -> UUID {
            reads += 1
            if fail { throw Unreadable() }
            return id
        }
    }

    private static let base = URL(string: "https://example.test")!
    private static let session = "session-token"
    private static let tokenBytes = Data((0..<32).map { UInt8($0) })
    private static let tokenHex = "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"
    private static let device = UUID(uuidString: "ABCDEF01-2345-4678-9ABC-DEF012345678")!

    private func client(_ wire: Wire, base: URL = DeviceRegistrationTests.base) -> ServiceClient {
        ServiceClient(baseURL: base, transport: wire)
    }

    private func account(_ wire: Wire, token: String? = DeviceRegistrationTests.session) -> AccountState {
        AccountState(client: client(wire), store: InMemorySessionStore(token: token))
    }

    private func registration(_ account: AccountState, _ probe: DeviceProbe,
                              environment: PushEnvironment = .sandbox) -> DeviceRegistration {
        DeviceRegistration(account: account, device: { try probe.read() }, environment: environment)
    }

    private func body(_ request: URLRequest) throws -> [String: String] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    /// Waits for a condition with a deadline, never a fixed long sleep.
    private func waitUntil(_ what: String, timeout: Duration = .seconds(3),
                           _ condition: @MainActor () async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !(await condition()) {
            guard clock.now < deadline else {
                XCTFail("timed out waiting for: \(what)")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: AC-1

    func testPutDeviceWire() async throws {
        for (environment, raw) in [(PushEnvironment.production, "production"), (.sandbox, "sandbox")] {
            for base in [Self.base, URL(string: "https://example.test/api")!] {
                let wire = Wire([.status(204)])
                try await client(wire, base: base).putDevice(
                    token: "ab12cd34", environment: environment, sessionToken: "S", device: Self.device
                )
                let requests = await wire.requests
                XCTAssertEqual(requests.count, 1)
                let request = try XCTUnwrap(requests.first)
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.url?.path, base.path + "/app/device")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer S")
                XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device"), Self.device.uuidString.lowercased())
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
                XCTAssertEqual(try body(request), ["token": "ab12cd34", "environment": raw])
            }
        }
    }

    // MARK: AC-2

    func testPutDeviceStatusMapping() async throws {
        let expected: [(Int, ServiceError)] = [
            (401, .unauthorized), (409, .refused), (429, .tooManyRequests), (503, .unavailable),
            (400, .rejected(400)), (413, .rejected(413)), (500, .rejected(500)), (200, .rejected(200)),
        ]
        for (status, error) in expected {
            let wire = Wire([.status(status)])
            do {
                try await client(wire).putDevice(token: "ab", environment: .sandbox, sessionToken: "S",
                                                 device: Self.device)
                XCTFail("\(status) was taken as success")
            } catch let thrown as ServiceError {
                XCTAssertEqual(thrown, error, "status \(status)")
            }
        }
    }

    // MARK: AC-3

    func testPutDeviceErrorsCarryNoSecrets() async throws {
        let secrets = ["SECRET-BODY", "SECRET-SESSION", "SECRET-DEVICE"]
        let replies: [Wire.Reply] = [
            .status(401, "SECRET-BODY"), .status(500, "SECRET-BODY"), .status(200, "SECRET-BODY"), .failure(.timedOut),
        ]
        for reply in replies {
            let wire = Wire([reply])
            do {
                try await client(wire).putDevice(token: "SECRET-DEVICE", environment: .production,
                                                 sessionToken: "SECRET-SESSION", device: Self.device)
                XCTFail("\(reply) was taken as success")
            } catch {
                let text = String(describing: error) + String(reflecting: error) + error.localizedDescription
                for secret in secrets { XCTAssertFalse(text.contains(secret), "\(reply) carried \(secret)") }
            }
        }

        do {
            try await client(Wire([.failure(.cancelled)])).putDevice(
                token: "ab", environment: .sandbox, sessionToken: "S", device: Self.device
            )
            XCTFail("a cancelled request was taken as success")
        } catch {
            XCTAssertTrue(error is CancellationError, "cancelled became \(error)")
        }

        do {
            try await client(Wire([.failure(.notConnectedToInternet)])).putDevice(
                token: "ab", environment: .sandbox, sessionToken: "S", device: Self.device
            )
            XCTFail("an unreachable service was taken as success")
        } catch let thrown as ServiceError {
            XCTAssertEqual(thrown, .unavailable)
        }
    }

    // MARK: AC-4

    func testEnvironmentFromInfoValue() {
        XCTAssertEqual(PushEnvironment(infoValue: "production"), .production)
        let sandboxValues: [Any?] = ["sandbox", "Production", "", nil, 42, "prod"]
        for value in sandboxValues {
            XCTAssertEqual(PushEnvironment(infoValue: value), .sandbox, "\(String(describing: value))")
        }
        XCTAssertEqual(PushEnvironment.sandbox.rawValue, "sandbox")
        XCTAssertEqual(PushEnvironment.production.rawValue, "production")
        XCTAssertEqual(PushEnvironment.current, .sandbox, "the build carries no LEApsEnvironment before S5c-2b")
    }

    // MARK: AC-5

    func testHexIsLowercaseTwoDigitsPerByte() {
        XCTAssertEqual(DeviceRegistration.hex(Data([0x00, 0x0f, 0xa0, 0xff])), "000fa0ff")
        let hex = DeviceRegistration.hex(Self.tokenBytes)
        XCTAssertEqual(hex, Self.tokenHex)
        XCTAssertEqual(hex.count, 64)
        XCTAssertEqual(hex, hex.lowercased())
    }

    // MARK: AC-6

    func testRegistersTokenThroughTheSession() async throws {
        let wire = Wire([.status(204)])
        let probe = DeviceProbe()
        let outcome = await registration(account(wire), probe).register(token: Self.tokenBytes)
        XCTAssertEqual(outcome, .registered)
        let requests = await wire.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.path, "/app/device")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer \(Self.session)")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Device"), probe.id.uuidString.lowercased())
        XCTAssertEqual(try body(request), ["token": Self.tokenHex, "environment": "sandbox"])
    }

    // MARK: AC-7

    func testWithoutSessionNothingIsSent() async throws {
        let wire = Wire([.status(204)])
        let probe = DeviceProbe()
        let account = account(wire, token: nil)
        XCTAssertEqual(account.status, .signedOut)
        let outcome = await registration(account, probe).register(token: Self.tokenBytes)
        XCTAssertEqual(outcome, .notSignedIn)
        let count = await wire.requests.count
        XCTAssertEqual(count, 0)
        XCTAssertEqual(probe.reads, 0, "the device id was read without a session")
    }

    // MARK: AC-8

    func testSamePairIsSentOnlyOnce() async throws {
        let wire = Wire([.status(204), .status(204), .status(204)])
        let probe = DeviceProbe()
        let account = account(wire)
        let sandbox = registration(account, probe)
        let first = await sandbox.register(token: Self.tokenBytes)
        XCTAssertEqual(first, .registered)
        let second = await sandbox.register(token: Self.tokenBytes)
        XCTAssertEqual(second, .unchanged)
        var count = await wire.requests.count
        XCTAssertEqual(count, 1, "the same pair went out twice")

        let other = await sandbox.register(token: Data([0xff, 0xee, 0xdd, 0xcc]))
        XCTAssertEqual(other, .registered)
        count = await wire.requests.count
        XCTAssertEqual(count, 2)

        let production = await registration(account, probe, environment: .production).register(token: Self.tokenBytes)
        XCTAssertEqual(production, .registered)
        let requests = await wire.requests
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(try body(try XCTUnwrap(requests.last))["environment"], "production")
    }

    // MARK: AC-9

    func testFailureIsRetriedAndNothingIsRemembered() async throws {
        let wire = Wire([.status(503), .status(204)])
        let probe = DeviceProbe()
        let registration = registration(account(wire), probe)
        let failed = await registration.register(token: Self.tokenBytes)
        XCTAssertEqual(failed, .failed(.unavailable))
        let retried = await registration.register(token: Self.tokenBytes)
        XCTAssertEqual(retried, .registered)
        let count = await wire.requests.count
        XCTAssertEqual(count, 2)

        let cases: [(Int, DeviceRegistration.Failure)] = [
            (429, .tooManyRequests), (500, .serviceError), (409, .serviceError),
        ]
        for (status, failure) in cases {
            let outcome = await self.registration(account(Wire([.status(status)])), DeviceProbe())
                .register(token: Self.tokenBytes)
            XCTAssertEqual(outcome, .failed(failure), "status \(status)")
        }

        let cancelled = await self.registration(account(Wire([.failure(.cancelled)])), DeviceProbe())
            .register(token: Self.tokenBytes)
        XCTAssertEqual(cancelled, .failed(.cancelled))

        let unauthorizedAccount = account(Wire([.status(401)]))
        let unauthorized = await self.registration(unauthorizedAccount, DeviceProbe()).register(token: Self.tokenBytes)
        XCTAssertEqual(unauthorized, .failed(.unauthorized))
        XCTAssertEqual(unauthorizedAccount.status, .signedOut)

        let unreadableWire = Wire([.status(204)])
        let unreadable = DeviceProbe()
        unreadable.fail = true
        let outcome = await self.registration(account(unreadableWire), unreadable).register(token: Self.tokenBytes)
        XCTAssertEqual(outcome, .failed(.deviceIdentity))
        let sent = await unreadableWire.requests.count
        XCTAssertEqual(sent, 0, "a request went out without a device id")
    }

    // MARK: AC-10

    func testNoSecondRegistrationWhileOneRuns() async throws {
        let wire = Wire([.status(204), .status(204)], delay: .milliseconds(300))
        let registration = registration(account(wire), DeviceProbe())
        let first = Task { await registration.register(token: Self.tokenBytes) }
        try await waitUntil("first registration on the wire") { await wire.requests.count == 1 }
        let second = await registration.register(token: Data([0x01, 0x02]))
        XCTAssertEqual(second, .busy)
        let firstOutcome = await first.value
        XCTAssertEqual(firstOutcome, .registered)
        let count = await wire.requests.count
        XCTAssertEqual(count, 1)
    }
}
