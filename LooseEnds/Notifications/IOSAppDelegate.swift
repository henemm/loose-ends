#if os(iOS)
import OSLog
import UIKit

/// App delegate for iOS (#795 S5c-2a): only passes the device token and the silent wake-up to `PushWakeUp.current`.
/// Visible notifications stay with `DueNotificationCenter`.
@MainActor
final class IOSAppDelegate: NSObject, UIApplicationDelegate {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "push-wake-up")

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { await PushWakeUp.current?.didReceive(token: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        Self.logger.info("no device token: \(String(describing: type(of: error)), privacy: .public)")
    }

    /// `userInfo` is read here and never carried into a task; without a node the answer is `.noData`.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        let isWake = PushWakeUp.isWake(userInfo)
        guard let node = PushWakeUp.current else { return .noData }
        return await node.handle(isWake: isWake).fetchResult
    }
}
#endif
