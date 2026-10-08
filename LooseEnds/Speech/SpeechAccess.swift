import Foundation
#if os(iOS)
import UIKit
#endif

/// Which right the capture scene is missing (#280). The system asks only once: after a "Don't
/// Allow" (or an answer from an earlier build) the request returns no without any dialog, and the
/// scene used to say only "not allowed" — on the Mac with no way to change it. Now it names the
/// right and opens the matching page in Settings. Pure, so the mapping is testable without TCC.
enum SpeechAccess: Equatable, Sendable {
    case microphone
    case speechRecognition
    case both

    /// Nil when both rights are there.
    static func missing(microphone: Bool, speech: Bool) -> SpeechAccess? {
        switch (microphone, speech) {
        case (true, true): nil
        case (false, true): .microphone
        case (true, false): .speechRecognition
        case (false, false): .both
        }
    }

    var message: String {
        switch self {
        case .microphone:
            String(localized: "Microphone access is off. Type instead, or allow it in Settings.")
        case .speechRecognition:
            String(localized: "Speech recognition is off. Type instead, or allow it in Settings.")
        case .both:
            String(localized: "Microphone and speech recognition are off. Type instead, or allow them in Settings.")
        }
    }

    /// The page that switches the right on. On the Mac the privacy pane of the missing right (with
    /// both missing, the microphone first: without it nothing is heard); on iPhone and iPad the
    /// app's own page in Settings, which lists both switches.
    var settingsURL: URL? {
        #if os(macOS)
        let pane = self == .speechRecognition ? "Privacy_SpeechRecognition" : "Privacy_Microphone"
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
        #else
        return URL(string: UIApplication.openSettingsURLString)
        #endif
    }
}
