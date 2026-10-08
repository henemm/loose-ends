import Foundation
import Testing
@testable import LooseEnds

/// Die Zeile „Ton ohne Text“ (#274): Die Regel entscheidet aus Zählern und Zeit, ob der Nutzer eine
/// Kurzdiagnose sieht. Rein, ohne Systemzugriff; Zähler und Neustart in `SpeechCapture` belegt der
/// Durchlauf auf dem Gerät.
@Suite("Speech diagnosis (#274)") struct SpeechDiagnosisTests {
    private func hint(
        seconds: TimeInterval, buffers: Int, results: Int,
        status: String = "installed", microphone: Bool = true, speech: Bool = true
    ) -> SpeechDiagnosis? {
        SpeechDiagnosis.hint(
            buffers: buffers, results: results, secondsListening: seconds,
            modelStatus: status, microphone: microphone, speech: speech
        )
    }

    @Test("Threshold is six seconds, in one place")
    func thresholdIsSixSeconds() {
        #expect(SpeechDiagnosis.threshold == 6)
    }

    @Test("No hint before the threshold")
    func noHintBeforeThreshold() {
        #expect(hint(seconds: 5.9, buffers: 50, results: 0) == nil)
    }

    @Test("Hint at exactly the threshold (inclusive)")
    func hintAtExactlyThreshold() {
        #expect(hint(seconds: SpeechDiagnosis.threshold, buffers: 60, results: 0) != nil)
    }

    @Test("Hint stays after the threshold")
    func hintAfterThreshold() {
        #expect(hint(seconds: 30, buffers: 300, results: 0) != nil)
    }

    @Test("No hint without audio: that is a different failure")
    func noHintWithoutBuffers() {
        #expect(hint(seconds: 10, buffers: 0, results: 0) == nil)
    }

    @Test("No hint once any result arrived")
    func noHintWhenResultsArrived() {
        #expect(hint(seconds: 10, buffers: 100, results: 1) == nil)
    }

    @Test("Hint disappears when a result comes later")
    func hintDisappearsWhenResultComesLater() {
        #expect(hint(seconds: 7, buffers: 70, results: 0) != nil)
        #expect(hint(seconds: 8, buffers: 80, results: 1) == nil)
    }

    @Test("A fresh start (zeroed counters) shows nothing")
    func restartStartsFresh() {
        #expect(hint(seconds: 0, buffers: 0, results: 0) == nil)
    }

    @Test("The text carries every fact")
    func textCarriesAllFacts() throws {
        let micOnly = try #require(hint(seconds: 7, buffers: 62, results: 0, microphone: true, speech: false))
        let speechOnly = try #require(hint(seconds: 7, buffers: 62, results: 0, microphone: false, speech: true))
        let both = try #require(hint(seconds: 7, buffers: 62, results: 0, microphone: true, speech: true))
        #expect(micOnly.text.contains("installed"))
        #expect(micOnly.text.contains("62"))
        // Mikrofon und Sprache sind getrennte Angaben in fester Reihenfolge: jede Belegung ergibt einen anderen Text.
        #expect(micOnly.text != speechOnly.text)
        #expect(micOnly.text != both.text)
        #expect(speechOnly.text != both.text)
        // Ergebnisse stehen im Text: bei 0 Ergebnissen kommt die Null vor.
        #expect(both.text.contains("0"))
    }
}
