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

    private func layout(_ button: Bool, _ progress: Bool, _ rows: Bool, _ hint: AccountSection.Hint) -> AccountSection.Layout {
        AccountSection.Layout(showsAppleButton: button, showsProgress: progress, showsSignedInRows: rows, hint: hint)
    }

    @Test("account: layout je status")
    func layoutPerStatus() {
        let table: [(AccountState.Status, AccountState.Problem?, AccountSection.Layout)] = [
            (.signedOut, nil, layout(true, false, false, .intro)),
            (.signingIn, nil, layout(false, true, false, .intro)),
            (.signedIn, nil, layout(false, false, true, .signedIn)),
            (.signedIn, .retryLater, layout(false, false, true, .retryLater)),
            (.deleting, nil, layout(false, true, false, .signedIn)),
            (.notAllowed, nil, layout(true, false, false, .notAllowed)),
            (.retryLater, nil, layout(true, false, false, .retryLater)),
        ]
        for (status, problem, expected) in table {
            #expect(AccountSection.layout(status: status, problem: problem) == expected, "\(status), \(String(describing: problem))")
        }
        // While a request runs nothing can be tapped a second time.
        for status in [AccountState.Status.signingIn, .deleting] {
            let busy = AccountSection.layout(status: status, problem: nil)
            #expect(!busy.showsAppleButton && !busy.showsSignedInRows && busy.showsProgress)
        }
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
}
