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
    /// 429: the pass stops at once and is never repeated within it (contract "Wege der App", #795 S1b).
    case tooManyRequests
    /// 409: a result for an order this device does not (or no longer) hold.
    case refused
}

/// The routes of `server/src/auth.ts` and `server/src/app-routes.ts` (#795 S2a).
/// Creating it sends nothing; nothing in the app calls it yet.
struct ServiceClient: Sendable {
    /// What `claimOrder` brings back: nothing open, a readable order, or an order whose id alone could be read.
    enum Claim: Equatable, Sendable {
        case none
        case order(Order)
        case unreadable(UUID)
    }

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
        let body = try await send(request, success: [200]).body
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
        _ = try await send(bearer(path: "auth/logout", sessionToken), success: [204])
    }

    /// `POST /auth/delete`: deletes the account behind this session.
    func deleteAccount(sessionToken: String) async throws {
        _ = try await send(bearer(path: "auth/delete", sessionToken), success: [204])
    }

    /// `POST /app/transcript`: the body only from `TranscriptCodec`; an older transcript is 204 for the service too.
    func putTranscript(_ transcript: Transcript, sessionToken: String) async throws {
        var request = bearer(path: "app/transcript", sessionToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try TranscriptCodec.encode(transcript)
        _ = try await send(request, success: [204])
    }

    /// `POST /app/orders/claim` without a body: 204 is `.none`, 200 the order
    /// or, if only its id is readable, `.unreadable`.
    func claimOrder(sessionToken: String, device: UUID) async throws -> Claim {
        var request = bearer(path: "app/orders/claim", sessionToken)
        request.setValue(device.uuidString.lowercased(), forHTTPHeaderField: "X-Device")
        let answer = try await send(request, success: [200, 204])
        return answer.status == 204 ? .none : try Self.claim(from: answer.body)
    }

    /// `POST /app/orders/result`: the result for an order this device holds; 409 is `refused`.
    func putResult(_ result: OrderResult, sessionToken: String, device: UUID) async throws {
        var request = bearer(path: "app/orders/result", sessionToken)
        request.setValue(device.uuidString.lowercased(), forHTTPHeaderField: "X-Device")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try TranscriptCodec.encode(result)
        _ = try await send(request, success: [204])
    }

    /// A readable order, else the id rescued from a JSON object so the order can be refused, else `invalidResponse`.
    /// Nothing of the body is logged or put into an error.
    private static func claim(from body: Data) throws -> Claim {
        do {
            return .order(try TranscriptCodec.decode(Order.self, from: body))
        } catch {
            let object: Any
            do {
                object = try JSONSerialization.jsonObject(with: body)
            } catch {
                throw ServiceError.invalidResponse
            }
            guard let text = (object as? [String: Any])?["id"] as? String, let id = UUID(uuidString: text) else {
                throw ServiceError.invalidResponse
            }
            return .unreadable(id)
        }
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

    /// The route's success statuses give the body and its status, 401, 409, 429 and 503 their own case,
    /// every other status `rejected`; a cancelled `URLError` becomes `CancellationError`, every other `URLError`
    /// means the service is out of reach, any other error passes through unchanged.
    private func send(_ request: URLRequest, success: Set<Int>) async throws -> (body: Data, status: Int) {
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is URLError {
            throw ServiceError.unavailable
        }
        if success.contains(response.statusCode) { return (data, response.statusCode) }
        switch response.statusCode {
        case 401: throw ServiceError.unauthorized
        case 409: throw ServiceError.refused
        case 429: throw ServiceError.tooManyRequests
        case 503: throw ServiceError.unavailable
        default: throw ServiceError.rejected(response.statusCode)
        }
    }
}
