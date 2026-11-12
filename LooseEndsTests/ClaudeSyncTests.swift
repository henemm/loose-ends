import Foundation
import SwiftData
import Synchronization
import Testing
@testable import LooseEnds

/// The pass of the app for Claude (#795 S3a): send the transcript, claim orders, run them as the user with the
/// reason "Claude" and report the result. Every row of the reaction table against a stand-in transport and a store in
/// memory; orders run through the real `OrderExecutor`, only AC-8 plays in a failing `execute`.
@Suite("ClaudeSync (#795)") @MainActor struct ClaudeSyncTests {
    static let calendar = TranscriptCodecTests.calendar
    static let now = TranscriptCodecTests.now
    static let base = URL(string: "https://example.test")!
    static let token = "T-secret-session"
    nonisolated static let device = UUID(uuidString: "A1B2C3D4-E5F6-4711-8899-AABBCCDDEEFF")!

    static let transcriptPath = "/app/transcript", claimPath = "/app/orders/claim", resultPath = "/app/orders/result"

    /// Records every request (path, headers, body) and answers from a queue per path; `fallback` answers a path whose
    /// queue is empty. A hook runs once before the answer to the request with that index (counted over all paths).
    actor FakeTransport: HTTPTransport {
        enum Reply: Sendable {
            case status(Int)
            case order(Order)
            /// A fresh `capture` order with a new id on every answer.
            case capture
            case body(Int, String)
            case cancel
        }

        private(set) var requests: [URLRequest] = []
        private var replies: [String: [Reply]]
        private let fallback: [String: Reply]
        private var hooks: [Int: @MainActor @Sendable () async -> Void] = [:]

        init(_ replies: [String: [Reply]] = [:], fallback: [String: Reply] = [:]) {
            self.replies = replies
            self.fallback = fallback
        }

        func on(_ index: Int, _ hook: @escaping @MainActor @Sendable () async -> Void) { hooks[index] = hook }

        var paths: [String] { requests.map { $0.url?.path ?? "" } }

        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            let index = requests.count
            requests.append(request)
            if let hook = hooks.removeValue(forKey: index) { await hook() }
            let path = request.url?.path ?? ""
            let reply: Reply
            if var queue = replies[path], !queue.isEmpty {
                reply = queue.removeFirst()
                replies[path] = queue
            } else if let standing = fallback[path] {
                reply = standing
            } else {
                return (Data(), Self.response(request, 599))
            }
            switch reply {
            case .status(let status): return (Data(), Self.response(request, status))
            case .order(let order): return (try TranscriptCodec.encode(order), Self.response(request, 200))
            case .capture:
                let order = Order(id: UUID(), kind: .capture, text: "Von Claude erfasst")
                return (try TranscriptCodec.encode(order), Self.response(request, 200))
            case .body(let status, let text): return (Data(text.utf8), Self.response(request, status))
            case .cancel: throw CancellationError()
            }
        }

        private static func response(_ request: URLRequest, _ status: Int) -> HTTPURLResponse {
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        }
    }

    /// How often `device()` was read; throws once `fails` is set.
    final class DeviceProbe: Sendable {
        private let state = Mutex((reads: 0, fails: false))
        init(fails: Bool = false) { state.withLock { $0.fails = fails } }
        var reads: Int { state.withLock { $0.reads } }

        func read() throws -> UUID {
            try state.withLock {
                $0.reads += 1
                if $0.fails { throw SessionStoreError.corruptData }
                return ClaudeSyncTests.device
            }
        }
    }

    @MainActor final class Box {
        var endings: [ClaudeSync.Ending] = []
    }

    struct Boom: Error {}

    /// One pass with everything it needs; holds the container so its context lives as long as the test.
    struct Harness {
        let store: TestStore
        let sessions: InMemorySessionStore
        let account: AccountState
        let wire: FakeTransport
        let probe: DeviceProbe
        let sync: ClaudeSync
        @MainActor var context: ModelContext { store.context }

        @MainActor func tasks() throws -> [TaskItem] { try context.fetch(FetchDescriptor<TaskItem>()) }
        @MainActor func revisions() throws -> Int { try context.fetchCount(FetchDescriptor<Revision>()) }
    }

    private func make(
        _ wire: FakeTransport,
        token: String? = ClaudeSyncTests.token,
        probe: DeviceProbe = DeviceProbe(),
        execute: ((Order, ModelContext, Date, Calendar) throws -> OrderResult)? = nil
    ) throws -> Harness {
        let store = try TestStore()
        let sessions = InMemorySessionStore(token: token)
        let account = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: sessions)
        let sync: ClaudeSync
        if let execute {
            sync = ClaudeSync(
                account: account, container: store.container, device: { try probe.read() },
                execute: execute, now: { Self.now }, calendar: Self.calendar
            )
        } else {
            sync = ClaudeSync(
                account: account, container: store.container, device: { try probe.read() },
                now: { Self.now }, calendar: Self.calendar
            )
        }
        return Harness(store: store, sessions: sessions, account: account, wire: wire, probe: probe, sync: sync)
    }

    private func resultBody(_ request: URLRequest) throws -> OrderResult {
        try TranscriptCodec.decode(OrderResult.self, from: try #require(request.httpBody))
    }

    // MARK: AC-1

    @Test("AC-1: ohne Sitzung keine Anfrage und keine Gerätekennung")
    func withoutSessionNothingIsSent() async throws {
        let h = try make(FakeTransport(), token: nil)
        #expect(await h.sync.sendTranscript() == .notSignedIn)
        #expect(await h.sync.pullOrders() == .notSignedIn)
        #expect(await h.wire.requests.isEmpty)
        #expect(h.probe.reads == 0)
    }

    // MARK: AC-2, AC-3

    @Test("AC-2: Abschrift aus allen Aufgaben, mit Bearer-Token")
    func transcriptIsBuiltFromAllTasksAndSent() async throws {
        let h = try make(FakeTransport([Self.transcriptPath: [.status(204)]]))
        for (text, status) in [("Offen", TaskStatus.active), ("Erledigt", .done), ("Entfernt", .removed)] {
            h.context.insert(TranscriptCodecTests.task(text, status: status))
        }
        try h.context.save()

        #expect(await h.sync.sendTranscript() == .done)

        let requests = await h.wire.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.url?.path == Self.transcriptPath)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)")
        let all = try h.tasks()
        #expect(all.count == 3)
        let expected = try TranscriptCodec.encode(TranscriptCodec.transcript(of: all, now: Self.now, calendar: Self.calendar))
        #expect(request.httpBody == expected)
    }

    @Test("AC-3: jeder Fehler der Abschrift beendet den Durchgang", arguments: [
        (FakeTransport.Reply.status(401), ClaudeSync.Stop.unauthorized),
        (.status(429), .tooManyRequests),
        (.status(503), .unavailable),
        (.status(400), .serviceError),
        (.cancel, .cancelled),
    ])
    func transcriptErrorsEndThePass(reply: FakeTransport.Reply, stop: ClaudeSync.Stop) async throws {
        let h = try make(FakeTransport([Self.transcriptPath: [reply]]))
        #expect(await h.sync.sendTranscript() == .stopped(stop))
        #expect(await h.wire.requests.count == 1)
        if stop == .unauthorized { #expect(h.account.status == .signedOut) }
    }

    // MARK: AC-4 to AC-7

    @Test("AC-4: nichts offen endet nach einem claim mit X-Device")
    func emptyClaimEndsThePass() async throws {
        let h = try make(FakeTransport([Self.claimPath: [.status(204)]]))
        #expect(await h.sync.pullOrders() == .done)
        let requests = await h.wire.requests
        #expect(requests.count == 1)
        let claim = try #require(requests.first)
        #expect(claim.url?.path == Self.claimPath)
        #expect(claim.value(forHTTPHeaderField: "X-Device") == Self.device.uuidString.lowercased())
        #expect(claim.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.token)")
    }

    @Test("AC-5: Auftrag wird als Nutzeränderung „Claude“ ausgeführt und gemeldet")
    func orderIsExecutedAsClaudeAndReported() async throws {
        let task = TranscriptCodecTests.task("Angebot schreiben", due: TranscriptCodecTests.day(1))
        let newDate = TranscriptCodecTests.day(3, hour: 14)
        let order = Order(
            id: UUID(), kind: .setDue, taskID: task.id, date: newDate, hasTime: true,
            expectedDueDate: TranscriptCodecTests.day(1)
        )
        let h = try make(FakeTransport([Self.claimPath: [.order(order), .status(204)], Self.resultPath: [.status(204)]]))
        h.context.insert(task)
        try h.context.save()

        #expect(await h.sync.pullOrders() == .done)

        #expect(task.dueDate == newDate)
        let revisions = (task.revisions ?? []).filter { $0.field == .dueDate }
        #expect(revisions.count == 1)
        #expect(revisions.first?.author == .user)
        #expect(revisions.first?.reason == "Claude")
        #expect(await h.wire.paths == [Self.claimPath, Self.resultPath, Self.claimPath])
        let result = try resultBody(try #require(await h.wire.requests.dropFirst().first))
        #expect(result == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))
    }

    @Test("AC-6: der Durchgang holt, bis nichts mehr offen ist")
    func loopContinuesUntilNothingIsLeft() async throws {
        let h = try make(FakeTransport(
            [Self.claimPath: [.capture, .capture, .status(204)], Self.resultPath: [.status(204), .status(204)]]
        ))
        #expect(await h.sync.pullOrders() == .done)
        #expect(try h.tasks().count == 2)
        #expect(await h.wire.paths == [Self.claimPath, Self.resultPath, Self.claimPath, Self.resultPath, Self.claimPath])
    }

    @Test("AC-7: ein unlesbarer Auftrag wird als invalid abgelehnt, nichts ausgeführt")
    func unreadableOrderIsRejectedAsInvalid() async throws {
        let id = UUID()
        let h = try make(FakeTransport([
            Self.claimPath: [.body(200, #"{"id":"\#(id.uuidString)","kind":"teleport"}"#), .status(204)],
            Self.resultPath: [.status(204)],
        ]))
        #expect(await h.sync.pullOrders() == .done)
        #expect(await h.wire.paths == [Self.claimPath, Self.resultPath, Self.claimPath])
        let result = try resultBody(try #require(await h.wire.requests.dropFirst().first))
        #expect(result == OrderResult(orderID: id, outcome: .rejected, reason: .invalid, taskID: nil))
        #expect(try h.tasks().isEmpty)
        #expect(try h.revisions() == 0)
    }

    // MARK: AC-8 to AC-12

    @Test("AC-8: ein Ausführungsfehler meldet nichts und beendet den Durchgang")
    func executionFailureReportsNothingAndEndsThePass() async throws {
        let h = try make(
            FakeTransport([Self.claimPath: [.capture, .status(204)], Self.resultPath: [.status(204)]]),
            execute: { _, _, _, _ in throw Boom() }
        )
        #expect(await h.sync.pullOrders() == .stopped(.executionFailed))
        #expect(await h.wire.paths == [Self.claimPath])
    }

    @Test("AC-9: ein verworfenes Ergebnis (409) wird fallen gelassen, der Durchgang holt weiter")
    func refusedResultIsDroppedAndPassContinues() async throws {
        let h = try make(FakeTransport(
            [Self.claimPath: [.capture, .status(204)], Self.resultPath: [.status(409)]]
        ))
        #expect(await h.sync.pullOrders() == .done)
        #expect(try h.tasks().count == 1)
        #expect(await h.wire.paths == [Self.claimPath, Self.resultPath, Self.claimPath])
    }

    @Test("AC-10: 429 beendet den Durchgang sofort", arguments: ["claim", "result"])
    func tooManyRequestsEndsAtOnce(at stage: String) async throws {
        let wire = stage == "claim"
            ? FakeTransport([Self.claimPath: [.status(429), .status(204)]])
            : FakeTransport([Self.claimPath: [.capture, .status(204)], Self.resultPath: [.status(429), .status(204)]])
        let h = try make(wire)
        #expect(await h.sync.pullOrders() == .stopped(.tooManyRequests))
        let expected = stage == "claim" ? [Self.claimPath] : [Self.claimPath, Self.resultPath]
        #expect(await h.wire.paths == expected)
    }

    @Test("AC-11: weitere Fehler am claim beenden den Durchgang", arguments: [
        (FakeTransport.Reply.status(401), ClaudeSync.Stop.unauthorized),
        (.status(503), .unavailable),
        (.status(500), .serviceError),
        (.body(200, "{}"), .serviceError),
        (.cancel, .cancelled),
    ])
    func otherErrorsEndThePass(reply: FakeTransport.Reply, stop: ClaudeSync.Stop) async throws {
        let h = try make(FakeTransport([Self.claimPath: [reply, .status(204)]]))
        #expect(await h.sync.pullOrders() == .stopped(stop))
        #expect(await h.wire.requests.count == 1)
        if stop == .unauthorized {
            #expect(h.account.status == .signedOut)
            #expect(h.sessions.token == nil)
        }
    }

    @Test("AC-12: scheitert das Melden, endet der Durchgang und die Änderung bleibt", arguments: [
        (503, ClaudeSync.Stop.unavailable), (500, .serviceError),
    ])
    func resultFailureEndsThePassAndKeepsTheChange(status: Int, stop: ClaudeSync.Stop) async throws {
        let h = try make(FakeTransport(
            [Self.claimPath: [.capture, .status(204)], Self.resultPath: [.status(status)]]
        ))
        #expect(await h.sync.pullOrders() == .stopped(stop))
        #expect(try h.tasks().count == 1)
        #expect(await h.wire.paths == [Self.claimPath, Self.resultPath])
    }

    // MARK: AC-13, AC-14

    @Test("AC-13: wirft die Gerätekennung, geht keine Anfrage hinaus")
    func deviceIdentityFailureEndsWithoutRequest() async throws {
        let h = try make(FakeTransport([Self.claimPath: [.status(204)]]), probe: DeviceProbe(fails: true))
        #expect(await h.sync.pullOrders() == .stopped(.deviceIdentity))
        #expect(await h.wire.requests.isEmpty)
        #expect(h.probe.reads == 1)
    }

    @Test("AC-14: die Kennung wird je Durchgang genau einmal gelesen")
    func deviceIsReadOncePerPass() async throws {
        let h = try make(FakeTransport(
            [Self.claimPath: [.capture, .capture, .status(204), .status(204)], Self.resultPath: [.status(204), .status(204)]]
        ))
        #expect(await h.sync.pullOrders() == .done)
        #expect(h.probe.reads == 1)
        let requests = await h.wire.requests
        #expect(requests.count == 5)
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "X-Device") == Self.device.uuidString.lowercased() })
        #expect(await h.sync.pullOrders() == .done)
        #expect(h.probe.reads == 2)
    }

    // MARK: AC-15 to AC-18

    @Test("AC-15: nach 15 Aufträgen ist Schluss")
    func passStopsAtFifteenOrders() async throws {
        #expect(ClaudeSync.maxOrdersPerPass == 15)
        let h = try make(FakeTransport(fallback: [Self.claimPath: .capture, Self.resultPath: .status(204)]))
        #expect(await h.sync.pullOrders() == .limitReached)
        #expect(try h.tasks().count == 15)
        let paths = await h.wire.paths
        #expect(paths.count == 30)
        #expect(paths.filter { $0 == Self.claimPath }.count == 15)
        #expect(paths.filter { $0 == Self.resultPath }.count == 15)
    }

    @Test("AC-16: ein zweiter Aufruf während des Durchgangs ist busy, die beiden Durchgänge sperren einander nicht")
    func secondConcurrentCallDoesNotStartAPass() async throws {
        let wire = FakeTransport([
            Self.claimPath: [.status(204), .status(204)],
            Self.transcriptPath: [.status(204), .status(204)],
        ])
        let h = try make(wire)
        let box = Box()
        let sync = h.sync
        await wire.on(0) {
            box.endings.append(await sync.pullOrders())
            box.endings.append(await sync.sendTranscript())
        }
        await wire.on(1) {
            box.endings.append(await sync.sendTranscript())
        }

        #expect(await sync.pullOrders() == .done)
        #expect(box.endings == [.busy, .busy, .done])
        #expect(await wire.paths == [Self.claimPath, Self.transcriptPath])

        #expect(await sync.pullOrders() == .done)
        #expect(await sync.sendTranscript() == .done)
        #expect(await wire.paths == [Self.claimPath, Self.transcriptPath, Self.claimPath, Self.transcriptPath])
    }

    @Test("AC-17: die Sperre wird nach jedem Ausgang frei", arguments: ["stopped", "notSignedIn", "limitReached"])
    func lockIsReleasedAfterEveryEnding(ending: String) async throws {
        let h: Harness
        let expected: ClaudeSync.Ending
        switch ending {
        case "stopped":
            h = try make(FakeTransport([Self.claimPath: [.status(503), .status(204)]]))
            expected = .stopped(.unavailable)
        case "notSignedIn":
            h = try make(FakeTransport(), token: nil)
            expected = .notSignedIn
        default:
            h = try make(FakeTransport(fallback: [Self.claimPath: .capture, Self.resultPath: .status(204)]))
            expected = .limitReached
        }
        #expect(await h.sync.pullOrders() == expected)
        let again = await h.sync.pullOrders()
        #expect(again != .busy)
        if ending == "stopped" { #expect(again == .done) }

        let transcript = try make(FakeTransport([Self.transcriptPath: [.status(503), .status(204)]]))
        #expect(await transcript.sync.sendTranscript() == .stopped(.unavailable))
        #expect(await transcript.sync.sendTranscript() == .done)
    }

    @Test("AC-18: fällt die Sitzung mitten im Durchgang weg, endet er still")
    func sessionLostMidPassEndsQuietly() async throws {
        let wire = FakeTransport([Self.claimPath: [.capture, .status(204)], Self.resultPath: [.status(204)]])
        let h = try make(wire)
        let sessions = h.sessions
        await wire.on(1) {
            do { try sessions.clear() } catch { Issue.record("store not cleared") }
        }
        #expect(await h.sync.pullOrders() == .notSignedIn)
        #expect(await wire.paths == [Self.claimPath, Self.resultPath])
    }

    // MARK: AC-19

    @Test("AC-19: Ausgänge tragen nur Fallnamen")
    func endingsCarryNoSecrets() async throws {
        var endings: [ClaudeSync.Ending] = []
        for reply in [FakeTransport.Reply.status(401), .status(429), .status(503), .status(400), .cancel] {
            endings.append(try await make(FakeTransport([Self.transcriptPath: [reply]])).sync.sendTranscript())
        }
        for reply in [FakeTransport.Reply.status(401), .status(503), .status(500), .body(200, "{}"), .cancel, .status(429)] {
            endings.append(try await make(FakeTransport([Self.claimPath: [reply]])).sync.pullOrders())
        }
        for status in [409, 503, 500, 429] {
            endings.append(try await make(FakeTransport(
                [Self.claimPath: [.capture, .status(204)], Self.resultPath: [.status(status)]]
            )).sync.pullOrders())
        }
        endings.append(try await make(
            FakeTransport([Self.claimPath: [.capture]]), execute: { _, _, _, _ in throw Boom() }
        ).sync.pullOrders())
        endings.append(try await make(FakeTransport(), probe: DeviceProbe(fails: true)).sync.pullOrders())

        let secrets = [Self.token, Self.device.uuidString, Self.device.uuidString.lowercased(), "Von Claude erfasst", "Bearer"]
        for ending in endings {
            let text = String(describing: ending)
            let leaks = secrets.filter { (secret: String) in text.contains(secret) }
            #expect(leaks.isEmpty, "\(text)")
            if case .stopped(let stop) = ending {
                let name: String = stop.rawValue
                #expect(name.allSatisfy(\.isLetter), "\(name)")
            }
        }
        #expect(endings.contains(.stopped(.executionFailed)) && endings.contains(.stopped(.deviceIdentity)))
    }
}
