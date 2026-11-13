import Foundation
import Testing
@testable import LooseEnds

/// The settings group "Claude" (#615 S4c-1): which rows each account state shows, the switch that hides the group in
/// every real build, and the stand-in service under `--ui-testing`. Nothing here talks to the network.
@Suite("AccountSection (#615)") @MainActor struct AccountSectionTests {
    /// Counts every request and answers sign-in with a token, logout and delete with 204.
    actor CountingWire: HTTPTransport {
        private(set) var count = 0

        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            count += 1
            let path = request.url?.path ?? ""
            let status = path.hasSuffix("auth/apple") ? 200 : 204
            let body = status == 200 ? Data(#"{"sessionToken":"T1"}"#.utf8) : Data()
            return (body, HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    static let base = URL(string: "https://example.test")!
    static let fallback = URL(string: "https://loose-ends.henemm.com")!

    private func layout(_ button: Bool, _ enabled: Bool, _ progress: Bool, _ rows: Bool,
                        _ hint: AccountSection.Hint) -> AccountSection.Layout {
        AccountSection.Layout(showsAppleButton: button, appleButtonEnabled: enabled, showsProgress: progress,
                              showsSignedInRows: rows, hint: hint)
    }

    @Test("account: layout je status")
    func layoutPerStatus() {
        let table: [(AccountState.Status, AccountState.Problem?, AccountSection.Layout)] = [
            (.signedOut, nil, layout(true, true, false, false, .intro)),
            // #615 S4c-2b (F001): the button stays while Apple's sheet runs, grey, so the sheet keeps its answer.
            (.signingIn, nil, layout(true, false, true, false, .intro)),
            (.signedIn, nil, layout(false, false, false, true, .signedIn)),
            (.signedIn, .retryLater, layout(false, false, false, true, .retryLater)),
            (.deleting, nil, layout(false, false, true, false, .signedIn)),
            (.notAllowed, nil, layout(true, true, false, false, .notAllowed)),
            (.retryLater, nil, layout(true, true, false, false, .retryLater)),
        ]
        for (status, problem, expected) in table {
            #expect(AccountSection.layout(status: status, problem: problem) == expected, "\(status), \(String(describing: problem))")
        }
    }

    @Test("account: laufende anfrage hat keinen bedienbaren knopf")
    func busyHasNoTappableButton() {
        let all: [AccountState.Status] = [.signedOut, .signingIn, .signedIn, .deleting, .notAllowed, .retryLater]
        for status in all {
            for problem in [nil, AccountState.Problem.retryLater] {
                let shown = AccountSection.layout(status: status, problem: problem)
                #expect(!shown.appleButtonEnabled || shown.showsAppleButton, "\(status): enabled only where shown")
            }
        }
        // While a request runs nothing can be tapped a second time.
        for status in [AccountState.Status.signingIn, .deleting] {
            let busy = AccountSection.layout(status: status, problem: nil)
            #expect(!busy.appleButtonEnabled && !busy.showsSignedInRows && busy.showsProgress, "\(status)")
        }
    }

    @Test("account: dienstadresse nur https")
    func serviceAddressOnlyHTTPS() {
        let fallback = AccountWiring.fallbackURL
        let table: [(Any?, Bool, URL)] = [
            ("https://dienst.example", true, URL(string: "https://dienst.example")!),
            ("https://dienst.example", false, URL(string: "https://dienst.example")!),
            ("HTTPS://Dienst.example", true, URL(string: "HTTPS://Dienst.example")!),
            ("HTTPS://Dienst.example", false, URL(string: "HTTPS://Dienst.example")!),
            ("http://dienst.example", true, fallback),
            ("http://dienst.example", false, fallback),
            ("http://localhost:8780", true, URL(string: "http://localhost:8780")!),
            ("http://localhost:8780", false, fallback),
            ("http://127.0.0.1:8780", true, URL(string: "http://127.0.0.1:8780")!),
            ("http://127.0.0.1:8780", false, fallback),
            ("ftp://dienst.example", true, fallback),
            ("ftp://dienst.example", false, fallback),
            ("https://", true, fallback),
            ("https:///pfad", true, fallback),
            ("https:///pfad", false, fallback),
            (nil, true, fallback),
            ("", true, fallback),
            ("kein url", true, fallback),
            (42, true, fallback),
        ]
        for (value, local, expected) in table {
            let info: [String: Any]? = value.map { ["LEServiceURL": $0] }
            #expect(AccountWiring.serviceURL(info: info, allowsLocalHTTP: local) == expected,
                    "\(String(describing: value)), local \(local)")
        }
    }

    @Test("account: dienstadresse standard folgt debug")
    func serviceAddressDefaultFollowsDebug() {
        #if DEBUG
        let expected = URL(string: "http://localhost:8780")!
        #else
        let expected = AccountWiring.fallbackURL
        #endif
        #expect(AccountWiring.serviceURL(info: ["LEServiceURL": "http://localhost:8780"]) == expected)
        #expect(AccountWiring.serviceURL(info: ["LEServiceURL": "http://fremd.example"]) == AccountWiring.fallbackURL)
        // `forApp` reads the address through the same default; the stand-in still builds on a foreign http value.
        #expect(AccountWiring.forApp(info: ["LEServiceURL": "http://fremd.example"], arguments: ["--ui-testing"]) != nil)
    }

    @Test("account: ersatz-transport langsam nur auf wunsch")
    func standInSlowOnlyOnRequest() async throws {
        let plain = UITestTransport(arguments: ["--ui-testing"])
        #expect(plain.delay == .zero)
        #expect(plain.outcome == .allowed)
        #expect(UITestTransport(outcome: .allowed).delay == .zero)

        let slow = UITestTransport(arguments: ["--ui-testing", "--ui-testing-account-slow"])
        #expect(slow.delay == .seconds(15))
        #expect(slow.outcome == .allowed)
        let slowRefused = UITestTransport(arguments: ["--ui-testing", "--ui-testing-account-slow",
                                                      "--ui-testing-account-not-allowed"])
        #expect(slowRefused.delay == .seconds(15))
        #expect(slowRefused.outcome == .notAllowed)
        #expect(UITestTransport(arguments: ["--ui-testing", "--ui-testing-account-retry-later"]).outcome == .retryLater)

        // A short explicit delay proves the wait without holding the unit run for 15 s.
        let delayed = UITestTransport(outcome: .allowed, delay: .milliseconds(300))
        let clock = ContinuousClock()
        let start = clock.now
        let token = try await ServiceClient(baseURL: Self.base, transport: delayed)
            .signIn(identityToken: "UITEST-IDENTITY", nonce: "n", code: "UITEST-CODE")
        #expect(token == "UITEST-SESSION")
        #expect(clock.now - start >= .milliseconds(300), "A stand-in with a delay answers only after it")

        let quickStart = clock.now
        _ = try await ServiceClient(baseURL: Self.base, transport: plain)
            .signIn(identityToken: "UITEST-IDENTITY", nonce: "n", code: "UITEST-CODE")
        #expect(clock.now - quickStart < .seconds(1), "Without the argument the stand-in answers at once")
    }

    @Test("account: wiring schalter und adresse")
    func wiringSwitchAndAddress() {
        #expect(!AccountWiring.isEnabled(info: nil, arguments: []))
        #expect(!AccountWiring.isEnabled(info: [:], arguments: []))
        #expect(!AccountWiring.isEnabled(info: ["LEAccountEnabled": false], arguments: []))
        #expect(!AccountWiring.isEnabled(info: ["LEAccountEnabled": NSNumber(value: false)], arguments: []))
        #expect(!AccountWiring.isEnabled(info: ["LEAccountEnabled": "YES"], arguments: []))
        #expect(AccountWiring.isEnabled(info: ["LEAccountEnabled": true], arguments: []))
        #expect(AccountWiring.isEnabled(info: ["LEAccountEnabled": NSNumber(value: true)], arguments: []))
        #expect(AccountWiring.isEnabled(info: nil, arguments: ["--ui-testing"]))
        #expect(AccountWiring.isEnabled(info: ["LEAccountEnabled": false], arguments: ["--ui-testing"]))

        #expect(AccountWiring.forApp(info: nil, arguments: []) == nil)
        #expect(AccountWiring.forApp(info: ["LEAccountEnabled": false], arguments: []) == nil)
        #expect(AccountWiring.forApp(info: ["LEAccountEnabled": "YES"], arguments: []) == nil)

        #expect(AccountWiring.serviceURL(info: nil) == Self.fallback)
        #expect(AccountWiring.serviceURL(info: ["LEServiceURL": ""]) == Self.fallback)
        #expect(AccountWiring.serviceURL(info: ["LEServiceURL": "kein url"]) == Self.fallback)
        #expect(AccountWiring.serviceURL(info: ["LEServiceURL": 42]) == Self.fallback)
        #expect(AccountWiring.serviceURL(info: ["LEServiceURL": "https://dienst.example"]) == URL(string: "https://dienst.example")!)
    }

    @Test("account: init sendet nichts")
    func initSendsNothing() async throws {
        let ui = try #require(AccountWiring.forApp(info: nil, arguments: ["--ui-testing"]))
        #expect(ui.status == .signedOut)

        let wire = CountingWire()
        let state = AccountState(client: ServiceClient(baseURL: Self.base, transport: wire), store: InMemorySessionStore())
        for status in [AccountState.Status.signedOut, .signingIn, .signedIn, .deleting, .notAllowed, .retryLater] {
            _ = AccountSection.layout(status: status, problem: nil)
            _ = AccountSection.layout(status: status, problem: .retryLater)
        }
        _ = AccountSection.layout(status: state.status, problem: state.lastProblem)
        #expect(await wire.count == 0)

        _ = try state.beginSignIn()
        #expect(await wire.count == 0)
        await state.completeSignIn(identityToken: "id", code: "c")
        #expect(await wire.count == 1)
        #expect(state.status == .signedIn)
    }

    @Test("account: ersatz-transport ausgaenge")
    func standInOutcomes() async throws {
        #expect(UITestTransport.Outcome(arguments: ["--ui-testing"]) == .allowed)
        #expect(UITestTransport.Outcome(arguments: ["--ui-testing", "--ui-testing-account-not-allowed"]) == .notAllowed)
        #expect(UITestTransport.Outcome(arguments: ["--ui-testing", "--ui-testing-account-retry-later"]) == .retryLater)

        let allowed = ServiceClient(baseURL: Self.base, transport: UITestTransport(outcome: .allowed))
        #expect(try await allowed.signIn(identityToken: "UITEST-IDENTITY", nonce: "n", code: "UITEST-CODE") == "UITEST-SESSION")
        try await allowed.logout(sessionToken: "UITEST-SESSION")
        try await allowed.deleteAccount(sessionToken: "UITEST-SESSION")

        let refused = ServiceClient(baseURL: Self.base, transport: UITestTransport(outcome: .notAllowed))
        await #expect(throws: ServiceError.unauthorized) {
            try await refused.signIn(identityToken: "UITEST-IDENTITY", nonce: "n", code: "UITEST-CODE")
        }
        let away = ServiceClient(baseURL: Self.base, transport: UITestTransport(outcome: .retryLater))
        await #expect(throws: ServiceError.unavailable) {
            try await away.signIn(identityToken: "UITEST-IDENTITY", nonce: "n", code: "UITEST-CODE")
        }
    }

    // MARK: Debug-Weg zum lokalen Dienst (#795 S3b-2)

    static func debugArgs(_ url: String, _ token: String = "TOKEN") -> [String] {
        ["-LEDebugService", url, "-LEDebugSession", token]
    }

    @Test("debug: adresse und sitzung gelesen")
    func debugServiceReadsAddressAndSession() throws {
        let local = try #require(URL(string: "http://localhost:8780"))
        let plain = try #require(AccountWiring.debugService(arguments: Self.debugArgs("http://localhost:8780"), debugBuild: true))
        #expect(plain.url == local)
        #expect(plain.token == "TOKEN")
        let reordered = ["-x", "-LEDebugSession", "TOKEN", "--other", "-LEDebugService", "http://localhost:8780", "-y"]
        let mixed = try #require(AccountWiring.debugService(arguments: reordered, debugBuild: true))
        #expect(mixed.url == local)
        #expect(mixed.token == "TOKEN")
    }

    @Test("debug: nie im release")
    func debugServiceNeverInRelease() {
        let args = Self.debugArgs("http://localhost:8780")
        #expect(AccountWiring.debugService(arguments: args, debugBuild: false) == nil)
        #expect(!AccountWiring.isEnabled(info: nil, arguments: args, debugBuild: false))
        #expect(AccountWiring.forApp(info: nil, arguments: args, debugBuild: false) == nil)
    }

    @Test("debug: beide argumente noetig")
    func debugServiceNeedsBothArguments() {
        for args in [["-LEDebugService", "http://localhost:8780"], ["-LEDebugSession", "TOKEN"],
                     ["-LEDebugSession", "TOKEN", "-LEDebugService"], ["-LEDebugService", "http://localhost:8780", "-LEDebugSession"],
                     Self.debugArgs("http://localhost:8780", ""), Self.debugArgs("http://localhost:8780", "  \n\t ")] {
            #expect(AccountWiring.debugService(arguments: args, debugBuild: true) == nil, "\(args)")
        }
    }

    @Test("debug: nur http localhost")
    func debugServiceAcceptsOnlyLocalhostHTTP() {
        let refused = ["https://localhost:8780", "http://127.0.0.1:8780", "http://fremd.example:8780",
                       "http://localhost.evil.example:8780", "http://user@localhost:8780", "http://user:pw@localhost:8780",
                       "http://localhost:8780#x", "http://localhost:8780/pfad", "http://localhost:8780/?x=1",
                       "ftp://localhost:8780", "kein url", ""]
        for address in refused {
            #expect(AccountWiring.debugService(arguments: Self.debugArgs(address), debugBuild: true) == nil, "\(address)")
        }
        for address in ["http://LOCALHOST:8780", "http://localhost:8780/"] {
            #expect(AccountWiring.debugService(arguments: Self.debugArgs(address), debugBuild: true) != nil, "\(address)")
        }
    }

    @Test("debug: port ist pflicht")
    func debugServiceNeedsAPort() {
        #expect(AccountWiring.debugService(arguments: Self.debugArgs("http://localhost"), debugBuild: true) == nil)
        #expect(AccountWiring.debugService(arguments: Self.debugArgs("http://localhost/"), debugBuild: true) == nil)
    }

    @Test("debug: argumente schalten das konto ein")
    func debugArgumentsSwitchTheAccountOn() {
        #expect(AccountWiring.isEnabled(info: nil, arguments: Self.debugArgs("http://localhost:8780"), debugBuild: true))
        #expect(!AccountWiring.isEnabled(info: nil, arguments: [], debugBuild: true))
        #expect(!AccountWiring.isEnabled(info: nil, arguments: ["-LEDebugService", "http://localhost:8780"], debugBuild: true))
        #expect(!AccountWiring.isEnabled(info: nil, arguments: ["-LEDebugSession", "TOKEN"], debugBuild: true))
        #expect(!AccountWiring.isEnabled(info: nil, arguments: Self.debugArgs("https://localhost:8780"), debugBuild: true))
        #expect(AccountWiring.isEnabled(info: nil, arguments: ["--ui-testing"], debugBuild: false))
        #expect(AccountWiring.isEnabled(info: ["LEAccountEnabled": true], arguments: [], debugBuild: false))
        #expect(!AccountWiring.isEnabled(info: ["LEAccountEnabled": false], arguments: [], debugBuild: true))
    }

    @Test("debug: forApp ist angemeldet")
    func forAppWithDebugArgumentsIsSignedIn() throws {
        let state = try #require(AccountWiring.forApp(info: nil, arguments: Self.debugArgs("http://localhost:8780")))
        #expect(state.status == .signedIn)
        #expect(AccountWiring.forApp(info: nil, arguments: Self.debugArgs("http://fremd.example:8780")) == nil)
    }

    @Test("debug: ui-testing gewinnt")
    func uiTestingBeatsDebugArguments() throws {
        let state = try #require(AccountWiring.forApp(info: nil,
                                                      arguments: ["--ui-testing"] + Self.debugArgs("http://localhost:8780")))
        #expect(state.status == .signedOut)
    }
}
