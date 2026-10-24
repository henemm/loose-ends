import Foundation
#if os(iOS)
import UIKit
#endif

/// Which right the capture scene is missing (#280). The system asks only once: after a "Don't
/// Allow" (or an answer from an earlier build) the request returns no without any dialog, and the
/// scene used to say only "not allowed" — on the Mac with no way to change it. Now it names the
/// right and opens the matching page in Settings. Pure, so the mapping is testable without TCC.
/// Since #293 only the microphone: SpeechAnalyzer does not need the speech recognition right
/// (shown on the Mac, 2026-10-24).
enum SpeechAccess: Equatable, Sendable {
    case microphone

    /// Nil when the microphone is allowed.
    static func missing(microphone: Bool) -> SpeechAccess? {
        microphone ? nil : .microphone
    }

    var message: String {
        String(localized: "Microphone access is off. Type instead, or allow it in Settings.")
    }

    /// The page that switches the right on: on the Mac the microphone's privacy pane, on iPhone and
    /// iPad the app's own page in Settings.
    var settingsURL: URL? {
        #if os(macOS)
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        #else
        return URL(string: UIApplication.openSettingsURLString)
        #endif
    }
}
