import Foundation

// Mirrors LooseEnds/Notifications/BackgroundRefresh.swift: a @MainActor enum registers a launch handler.
@MainActor
enum Refresh {
    static func register(queue: DispatchQueue?) {
        FakeScheduler.shared().register(forTaskWithIdentifier: "refresh", using: queue) { task in
            Task { @MainActor in print("main-actor work done"); exit(0) }
        }
    }

    /// Variant B: the closure is explicitly @Sendable, so it does not inherit the main actor.
    static func registerSendable() {
        FakeScheduler.shared().register(forTaskWithIdentifier: "refresh", using: nil) { @Sendable task in
            Task { @MainActor in print("main-actor work done"); exit(0) }
        }
    }
}

let mode = CommandLine.arguments.dropFirst().first
DispatchQueue.main.async {
    MainActor.assumeIsolated {
        if mode == "sendable" { Refresh.registerSendable() } else { Refresh.register(queue: mode == "main" ? .main : nil) }
    }
    FakeScheduler.shared().fire()
}
dispatchMain()
