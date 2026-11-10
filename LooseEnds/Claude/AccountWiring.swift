import Foundation

/// Where the account for Claude is built (#615 S4c-1): one switch that keeps the settings group hidden in every real
/// build until `LEAccountEnabled` says otherwise, the service address `LEServiceURL`, and under `--ui-testing` a store in
/// memory with a fixed stand-in service. Building it sends nothing.
enum AccountWiring {
    static let fallbackURL = URL(string: "https://loose-ends.henemm.com")!

    /// On under `--ui-testing`; otherwise only when the Info value `LEAccountEnabled` is a true Bool. Missing or of
    /// another type counts as off.
    static func isEnabled(info: [String: Any]?, arguments: [String]) -> Bool {
        if arguments.contains("--ui-testing") { return true }
        guard let number = info?["LEAccountEnabled"] as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else {
            return false
        }
        return number.boolValue
    }

    /// True in a Debug build only: the default for allowing plain http to this machine (#615 S4c-2b). Internal, not
    /// private, because it is the default argument of `serviceURL(info:allowsLocalHTTP:)`.
    #if DEBUG
    static let debugBuild = true
    #else
    static let debugBuild = false
    #endif

    /// The Info value `LEServiceURL`: https with a host; http only to `localhost` or `127.0.0.1` and only when
    /// `allowsLocalHTTP` (default: Debug build). Anything else falls back to the live service (#615 S4c-2b).
    static func serviceURL(info: [String: Any]?, allowsLocalHTTP: Bool = AccountWiring.debugBuild) -> URL {
        guard let text = info?["LEServiceURL"] as? String,
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              let host = url.host(), !host.isEmpty else {
            return fallbackURL
        }
        switch scheme {
        case "https": return url
        case "http" where allowsLocalHTTP && ["localhost", "127.0.0.1"].contains(host.lowercased()): return url
        default: return fallbackURL
        }
    }

    /// The app's one account state, or nil while the switch is off (then nothing is read and nothing built).
    @MainActor static func forApp(info: [String: Any]?, arguments: [String]) -> AccountState? {
        guard isEnabled(info: info, arguments: arguments) else { return nil }
        if arguments.contains("--ui-testing") {
            let transport = UITestTransport(arguments: arguments)
            return AccountState(client: ServiceClient(baseURL: serviceURL(info: info), transport: transport),
                                store: InMemorySessionStore())
        }
        return AccountState(client: ServiceClient(baseURL: serviceURL(info: info)), store: KeychainSessionStore())
    }
}

/// The fixed stand-in service of the UI tests: answers like `server/src/auth.ts`, never touches the network.
struct UITestTransport: HTTPTransport {
    enum Outcome: Equatable, Sendable {
        case allowed, notAllowed, retryLater

        init(arguments: [String]) {
            if arguments.contains("--ui-testing-account-not-allowed") {
                self = .notAllowed
            } else if arguments.contains("--ui-testing-account-retry-later") {
                self = .retryLater
            } else {
                self = .allowed
            }
        }
    }

    let outcome: Outcome
    /// How long the stand-in waits before it answers; 2 s under `--ui-testing-account-slow`, else none (#615 S4c-2b).
    let delay: Duration

    init(outcome: Outcome, delay: Duration = .zero) {
        self.outcome = outcome
        self.delay = delay
    }

    init(arguments: [String]) {
        self.init(outcome: Outcome(arguments: arguments),
                  delay: arguments.contains("--ui-testing-account-slow") ? .seconds(2) : .zero)
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw ServiceError.invalidResponse }
        if delay > .zero {
            try await Task.sleep(for: delay)
        }
        let (status, body) = answer(path: url.path())
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else {
            throw ServiceError.invalidResponse
        }
        return (body, response)
    }

    private func answer(path: String) -> (Int, Data) {
        guard path.hasSuffix("auth/apple") else { return (204, Data()) }
        switch outcome {
        case .allowed: return (200, Data(#"{"sessionToken":"UITEST-SESSION"}"#.utf8))
        case .notAllowed: return (401, Data())
        case .retryLater: return (503, Data())
        }
    }
}
