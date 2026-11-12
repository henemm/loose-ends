import Foundation
import OSLog
import SwiftData

/// The pass of the app for Claude (#795 S3a): send the transcript of all tasks, claim orders, run each as a user
/// change with the reason "Claude" and report its result. Every request goes through `AccountState.withSession`;
/// without a session nothing happens. No retry, no waiting: every failure ends the pass, the next occasion comes from
/// outside. Nothing in the app calls it yet (S3b).
@MainActor final class ClaudeSync {
    enum Ending: Equatable, Sendable {
        case notSignedIn, busy, done, limitReached
        case stopped(Stop)
    }

    /// Why a pass stopped; the raw value is the case name and the only word that reaches the log.
    enum Stop: String, Equatable, Sendable {
        case unauthorized, tooManyRequests, unavailable, serviceError, cancelled
        case deviceIdentity, storeUnreadable, executionFailed
    }

    typealias Execute = (Order, ModelContext, Date, Calendar) throws -> OrderResult

    /// At most two requests per order (claim, result) keep a pass under the burst of 40 at nginx.
    static let maxOrdersPerPass = 15

    private let account: AccountState
    private let container: ModelContainer
    private let device: () throws -> UUID
    private let execute: Execute
    private let now: () -> Date
    private let calendar: Calendar
    private var sending = false
    private var pulling = false

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "claude-sync")

    /// The device id could not be read; carries nothing of the underlying error.
    private struct DeviceUnreadable: Error {}

    init(
        account: AccountState,
        container: ModelContainer,
        device: @escaping () throws -> UUID,
        execute: @escaping Execute = OrderExecutor.execute,
        now: @escaping () -> Date,
        calendar: Calendar
    ) {
        self.account = account
        self.container = container
        self.device = device
        self.execute = execute
        self.now = now
        self.calendar = calendar
    }

    /// Sends the transcript of every task; 204 is `done`, whatever the service keeps.
    func sendTranscript() async -> Ending {
        guard !sending else { return .busy }
        sending = true
        defer { sending = false }
        let tasks: [TaskItem]
        do {
            tasks = try container.mainContext.fetch(FetchDescriptor<TaskItem>())
        } catch {
            return Self.stopped(.storeUnreadable, after: error)
        }
        let transcript = TranscriptCodec.transcript(of: tasks, now: now(), calendar: calendar)
        do {
            let sent = try await account.withSession { client, token in
                try await client.putTranscript(transcript, sessionToken: token)
            }
            return sent == nil ? .notSignedIn : .done
        } catch {
            return Self.stopped(Self.stop(for: error), after: error)
        }
    }

    /// Claims, runs and reports orders until none is left, the session is gone, a failure ends the pass or
    /// `maxOrdersPerPass` orders were handled.
    func pullOrders() async -> Ending {
        guard !pulling else { return .busy }
        pulling = true
        defer { pulling = false }
        var deviceID: UUID?
        for _ in 0..<Self.maxOrdersPerPass {
            let claim: ServiceClient.Claim?
            do {
                claim = try await account.withSession { client, token in
                    let id = try deviceID ?? self.readDevice()
                    deviceID = id
                    return try await client.claimOrder(sessionToken: token, device: id)
                }
            } catch {
                return Self.stopped(Self.stop(for: error), after: error)
            }
            guard let claim, let id = deviceID else { return .notSignedIn }
            if let ending = await handle(claim, device: id) { return ending }
        }
        return .limitReached
    }

    /// One claim: `nil` to claim the next one, else the ending of the pass.
    private func handle(_ claim: ServiceClient.Claim, device: UUID) async -> Ending? {
        let result: OrderResult
        switch claim {
        case .none:
            return .done
        case .unreadable(let id):
            result = OrderResult(orderID: id, outcome: .rejected, reason: .invalid, taskID: nil)
        case .order(let order):
            do {
                result = try execute(order, container.mainContext, now(), calendar)
            } catch {
                return Self.stopped(.executionFailed, after: error)
            }
        }
        return await report(result, device: device)
    }

    /// Reports a result; a 409 drops it (the local change stays) and the pass goes on.
    private func report(_ result: OrderResult, device: UUID) async -> Ending? {
        do {
            let sent = try await account.withSession { client, token in
                try await client.putResult(result, sessionToken: token, device: device)
            }
            return sent == nil ? .notSignedIn : nil
        } catch ServiceError.refused {
            Self.logger.info("result refused by service")
            return nil
        } catch {
            return Self.stopped(Self.stop(for: error), after: error)
        }
    }

    private func readDevice() throws -> UUID {
        do {
            return try device()
        } catch {
            Self.logger.error("device id unreadable: \(String(describing: type(of: error)), privacy: .public)")
            throw DeviceUnreadable()
        }
    }

    private static func stop(for error: any Error) -> Stop {
        switch error {
        case ServiceError.unauthorized: return .unauthorized
        case ServiceError.tooManyRequests: return .tooManyRequests
        case ServiceError.unavailable: return .unavailable
        case is CancellationError: return .cancelled
        case is DeviceUnreadable: return .deviceIdentity
        default: return .serviceError
        }
    }

    /// Logs only the case name and the type of the error, never a value it carries.
    private static func stopped(_ stop: Stop, after error: any Error) -> Ending {
        logger.info("pass stopped: \(stop.rawValue, privacy: .public) (\(String(describing: type(of: error)), privacy: .public))")
        return .stopped(stop)
    }
}
