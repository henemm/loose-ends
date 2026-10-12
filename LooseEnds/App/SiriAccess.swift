import OSLog
#if os(iOS)
import Intents
#endif

/// Siri routes a SiriKit intent to the Intents extension only after the user allowed Siri for the
/// app (#353). The system shows its dialog once; later calls return the stored answer at once.
enum SiriAccess {
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Siri")

    static func requestIfNeeded() async {
        #if os(iOS)
        guard !ModelContainerFactory.isRunningTests, !ModelContainerFactory.isUITesting else { return }
        guard INPreferences.siriAuthorizationStatus() == .notDetermined else { return }
        let status = await withCheckedContinuation { continuation in
            INPreferences.requestSiriAuthorization { continuation.resume(returning: $0) }
        }
        logger.info("Siri authorization: \(status.rawValue, privacy: .public)")
        #endif
    }
}
