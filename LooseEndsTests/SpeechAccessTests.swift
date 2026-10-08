import Foundation
import Testing
@testable import LooseEnds

/// Fehlendes Recht in der Erfassung (#280): Das System fragt nur einmal. Danach muss die Erfassung
/// sagen, welches Recht fehlt, und die passende Seite der Einstellungen öffnen.
@Suite("Erfassung: fehlende Rechte (#280)")
struct SpeechAccessTests {
    @Test("Welches Recht fehlt, folgt aus beiden Antworten")
    func missingFollowsBothAnswers() {
        #expect(SpeechAccess.missing(microphone: true, speech: true) == nil)
        #expect(SpeechAccess.missing(microphone: false, speech: true) == .microphone)
        #expect(SpeechAccess.missing(microphone: true, speech: false) == .speechRecognition)
        #expect(SpeechAccess.missing(microphone: false, speech: false) == .both)
    }

    @Test("Jede Lage hat einen eigenen Satz")
    func eachCaseHasItsOwnMessage() {
        let messages = [SpeechAccess.microphone, .speechRecognition, .both].map(\.message)
        #expect(Set(messages).count == 3)
        #expect(messages.allSatisfy { !$0.isEmpty })
    }

    #if os(macOS)
    @Test("Auf dem Mac öffnet der Knopf die Datenschutz-Seite des fehlenden Rechts")
    func macOpensThePrivacyPane() {
        #expect(SpeechAccess.microphone.settingsURL?.absoluteString
                == "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        #expect(SpeechAccess.speechRecognition.settingsURL?.absoluteString
                == "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        #expect(SpeechAccess.both.settingsURL == SpeechAccess.microphone.settingsURL,
                "ohne Mikrofon hört die App nichts, deshalb zuerst diese Seite")
    }
    #endif
}
