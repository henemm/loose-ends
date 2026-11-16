import Foundation
import OSLog

/// The APNs environment the service sends the wake-up to; the raw values are the ones `POST /app/device` expects.
enum PushEnvironment: String, Sendable {
    case sandbox, production

    /// Only the string "production" is production; anything else, missing included, is sandbox.
    init(infoValue: Any?) {
        self = (infoValue as? String) == "production" ? .production : .sandbox
    }

    /// The build's mark `LEApsEnvironment` (set from S5c-2b on; until then always sandbox).
    static var current: PushEnvironment {
        PushEnvironment(infoValue: Bundle.main.object(forInfoDictionaryKey: "LEApsEnvironment"))
    }
}

/// Reports the device token with its environment to the service, once per pair and process (#795 S5c-1).
/// The only door is `AccountState.withSession`; without a session nothing is read or sent. Nothing calls it yet.
@MainActor final class DeviceRegistration {
    enum Outcome: Equatable, Sendable {
        case registered, unchanged, notSignedIn, busy
        case failed(Failure)
    }

    /// The raw value is the case name and the only word that reaches the log.
    enum Failure: String, Equatable, Sendable {
        case unauthorized, tooManyRequests, unavailable, serviceError, cancelled, deviceIdentity
    }

    private struct Pair: Equatable {
        let hex: String
        let environment: PushEnvironment
    }

    /// The device id could not be read; carries nothing of the underlying error.
    private struct DeviceUnreadable: Error {}

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "device-registration")

    private let account: AccountState
    private let device: () throws -> UUID
    private let environment: PushEnvironment
    private var lastSent: Pair?
    private var running = false

    init(account: AccountState, device: @escaping () throws -> UUID, environment: PushEnvironment) {
        self.account = account
        self.device = device
        self.environment = environment
    }

    /// Lower-case hex, two digits per byte.
    static func hex(_ token: Data) -> String {
        token.map { String(format: "%02x", $0) }.joined()
    }

    /// Sends the pair unless it was the last one sent successfully or a report is running; a failure is not remembered.
    func register(token: Data) async -> Outcome {
        let pair = Pair(hex: Self.hex(token), environment: environment)
        guard pair != lastSent else { return .unchanged }
        guard !running else { return .busy }
        running = true
        defer { running = false }
        do {
            let sent = try await account.withSession { client, session in
                try await client.putDevice(token: pair.hex, environment: pair.environment,
                                           sessionToken: session, device: try self.readDevice())
            }
            guard sent != nil else { return .notSignedIn }
            lastSent = pair
            return .registered
        } catch {
            let failure = Self.failure(for: error)
            Self.logger.info("""
                registration failed: \(failure.rawValue, privacy: .public) \
                (\(String(describing: type(of: error)), privacy: .public))
                """)
            return .failed(failure)
        }
    }

    private func readDevice() throws -> UUID {
        do {
            return try device()
        } catch {
            throw DeviceUnreadable()
        }
    }

    private static func failure(for error: any Error) -> Failure {
        switch error {
        case ServiceError.unauthorized: return .unauthorized
        case ServiceError.tooManyRequests: return .tooManyRequests
        case ServiceError.unavailable: return .unavailable
        case is CancellationError: return .cancelled
        case is DeviceUnreadable: return .deviceIdentity
        default: return .serviceError
        }
    }
}
