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

    /// The Info value `LEServiceURL`; missing, empty or not an http(s) address falls back to the live service.
    static func serviceURL(info: [String: Any]?) -> URL {
        guard let text = info?["LEServiceURL"] as? String,
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), ["https", "http"].contains(scheme),
              url.host() != nil else {
            return fallbackURL
        }
        return url
    }

    /// The app's one account state, or nil while the switch is off (then nothing is read and nothing built).
    @MainActor static func forApp(info: [String: Any]?, arguments: [String]) -> AccountState? {
        guard isEnabled(info: info, arguments: arguments) else { return nil }
        if arguments.contains("--ui-testing") {
            let transport = UITestTransport(outcome: UITestTransport.Outcome(arguments: arguments))
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

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw ServiceError.invalidResponse }
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
