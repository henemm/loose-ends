import Foundation
import OSLog

/// UI tests only (#228): tells whether the app's main thread was blocked while XCTest waited for an
/// accessibility snapshot ("Timed out while evaluating UI query"). A background thread pings the
/// main queue every half second; an answer later than one second is logged when the block starts
/// and again when it ends, with its length. CI reads the lines from the simulator's log after a
/// failed run. The app itself never starts it.
enum MainThreadWatchdog {
    static let category = "Watchdog"

    static func start() {
        let thread = Thread {
            let logger = Logger(subsystem: "com.henning.looseends", category: category)
            logger.notice("Watchdog started")
            while true {
                let sent = Date()
                let answered = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { answered.signal() }
                if answered.wait(timeout: .now() + 1) == .timedOut {
                    logger.notice("Main thread blocked for more than 1 s")
                    answered.wait()
                    let blocked = Date().timeIntervalSince(sent)
                    logger.notice("Main thread blocked for \(blocked, format: .fixed(precision: 1), privacy: .public) s")
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        thread.name = "MainThreadWatchdog"
        thread.qualityOfService = .utility
        thread.start()
    }
}
