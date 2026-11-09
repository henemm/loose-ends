import Foundation

/// Sends one request and returns its answer; replaced in the tests (#615 S4b-1).
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// The real transport: an ephemeral session keeps no cookies, cache or credentials.
struct URLSessionTransport: HTTPTransport {
    private let session = URLSession(configuration: .ephemeral)

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
        return (data, http)
    }
}

/// What a call to the service can end in. Never carries a token, a body or a URL.
enum ServiceError: Error, Equatable {
    case unauthorized
    case unavailable
    case rejected(Int)
    case invalidResponse
}

/// The three routes of `server/src/auth.ts`. Creating it sends nothing; nothing in the app calls it yet.
struct ServiceClient: Sendable {
    let baseURL: URL
    let transport: any HTTPTransport

    init(baseURL: URL, transport: any HTTPTransport = URLSessionTransport()) {
        self.baseURL = baseURL
        self.transport = transport
    }

    /// `POST /auth/apple` with exactly `identityToken`, the raw `nonce` and `code`; returns the session token.
    func signIn(identityToken: String, nonce: String, code: String) async throws -> String {
        var request = request(path: "auth/apple")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["identityToken": identityToken, "nonce": nonce, "code": code]
        )
        let body = try await send(request, success: 200)
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: body)
        } catch {
            throw ServiceError.invalidResponse
        }
        guard let token = (object as? [String: Any])?["sessionToken"] as? String, !token.isEmpty else {
            throw ServiceError.invalidResponse
        }
        return token
    }

    /// `POST /auth/logout`: ends exactly this session.
    func logout(sessionToken: String) async throws {
        _ = try await send(bearer(path: "auth/logout", sessionToken), success: 204)
    }

    /// `POST /auth/delete`: deletes the account behind this session.
    func deleteAccount(sessionToken: String) async throws {
        _ = try await send(bearer(path: "auth/delete", sessionToken), success: 204)
    }

    private func request(path: String) -> URLRequest {
        var request = URLRequest(
            url: baseURL.appending(path: path), cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15
        )
        request.httpMethod = "POST"
        return request
    }

    private func bearer(path: String, _ token: String) -> URLRequest {
        var request = request(path: path)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    /// The route's success status gives the body, 401 and 503 their own case, every other status `rejected`;
    /// a `URLError` means the service is out of reach, any other error passes through unchanged.
    private func send(_ request: URLRequest, success: Int) async throws -> Data {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch is URLError {
            throw ServiceError.unavailable
        }
        switch response.statusCode {
        case success: return data
        case 401: throw ServiceError.unauthorized
        case 503: throw ServiceError.unavailable
        default: throw ServiceError.rejected(response.statusCode)
        }
    }
}
