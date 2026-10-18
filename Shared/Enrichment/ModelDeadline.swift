import Foundation

/// A time limit for one model call (#530). `LanguageModelSession.respond` has none of its own; a call
/// that hangs held the whole catch-up pass, so no later task was enriched until the app restarted.
/// The call and a timer race in one task group; whichever ends first wins and the other is cancelled.
/// The call must honour cancellation (the Foundation Models API and the test stub both do), or the
/// group waits for it to finish before it can return.
enum ModelDeadline {
    struct Exceeded: Error, Equatable {
        let limit: Duration
    }

    static func run<Value: Sendable>(
        within limit: Duration,
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withThrowingTaskGroup(of: Value.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: limit)
                throw Exceeded(limit: limit)
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw Exceeded(limit: limit) }
            return first
        }
    }
}
