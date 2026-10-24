import Foundation
import Testing
@testable import LooseEnds

/// Fehlendes Recht in der Erfassung (#280): Das System fragt nur einmal. Danach muss die Erfassung
/// sagen, welches Recht fehlt, und die passende Seite der Einstellungen öffnen. Seit #293 ist das nur
/// noch das Mikrofon: SpeechAnalyzer liefert Text auch bei abgelehnter Spracherkennung.
@Suite("Erfassung: fehlende Rechte (#280, #293)")
struct SpeechAccessTests {
    @Test("Gesperrt wird nur ohne Mikrofon")
    func missingFollowsTheMicrophone() {
        #expect(SpeechAccess.missing(microphone: true) == nil)
        #expect(SpeechAccess.missing(microphone: false) == .microphone)
    }

    @Test("Der Satz nennt das Mikrofon, nicht die Spracherkennung")
    func messageNamesTheMicrophone() {
        let message = SpeechAccess.microphone.message
        #expect(message.localizedCaseInsensitiveContains("microphone")
                || message.localizedCaseInsensitiveContains("mikrofon"))
        #expect(!message.localizedCaseInsensitiveContains("speech recognition"))
        #expect(!message.localizedCaseInsensitiveContains("spracherkennung"))
    }

    #if os(macOS)
    @Test("Auf dem Mac öffnet der Knopf die Datenschutz-Seite des Mikrofons")
    func macOpensThePrivacyPane() {
        #expect(SpeechAccess.microphone.settingsURL?.absoluteString
                == "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }
    #endif
}
