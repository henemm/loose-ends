import Foundation

/// Builds a value once per process and returns that same instance on every later call.
///
/// Used so `ModelContainerFactory` never creates two live containers on the same store: CloudKit
/// forbids a second mirroring delegate for the same store in one process (#50).
final class ProcessCache<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value?

    func value(build: () throws -> Value) rethrows -> Value {
        lock.lock()
        defer { lock.unlock() }
        if let value { return value }
        let built = try build()
        value = built
        return built
    }
}
