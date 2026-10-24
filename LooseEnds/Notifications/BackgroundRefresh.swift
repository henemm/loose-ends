#if os(iOS)
import BackgroundTasks
import Foundation
import OSLog

/// The notification plan holds without an app start (#553). Morning and evening are planned seven
/// days ahead and renewed on every save and foreground; without this, eight days without opening the
/// app went silent, and a task done on the Watch stayed in the evening notification. A daily app
/// refresh rewrites the plan; the system picks the moment. Registered at launch, asked for whenever
/// the app goes to the back and after every run. Silent under tests.
@MainActor
enum BackgroundRefresh {
    static let identifier = "com.henning.looseends.refresh"
    /// Not before six hours: once a day is enough, and the system spaces it further anyway.
    static let earliest: TimeInterval = 6 * 3600
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Notifications")

    static func register(_ notifications: DueNotificationCenter) {
        guard !ModelContainerFactory.isRunningTests, !ModelContainerFactory.isUITesting else { return }
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            let handle = RefreshHandle(task)
            task.expirationHandler = { handle.task.setTaskCompleted(success: false) }
            Task { @MainActor in
                await notifications.reschedule()
                schedule()
                handle.task.setTaskCompleted(success: true)
            }
        }
        if !registered {
            logger.error("Background refresh \(identifier, privacy: .public) could not be registered")
        }
    }

    /// One request at a time: submitting again replaces the pending one.
    static func schedule() {
        guard !ModelContainerFactory.isRunningTests, !ModelContainerFactory.isUITesting else { return }
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: earliest)
        // #580: the error the old `submit` threw arrives in the handler; Apple DTS confirms the main thread is fine.
        // The handler may run off the main actor, so it takes the (Sendable) logger as a local.
        let log = Self.logger
        BGTaskScheduler.shared.submitTaskRequest(request) { error in
            if let error {
                log.error("Scheduling the background refresh failed: \(error, privacy: .public)")
            }
        }
    }
}

/// The system hands the task to a background queue; the box carries it onto the main actor.
private final class RefreshHandle: @unchecked Sendable {
    let task: BGTask
    init(_ task: BGTask) { self.task = task }
}
#endif
