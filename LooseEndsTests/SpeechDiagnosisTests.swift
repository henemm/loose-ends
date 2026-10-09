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

    // MARK: - Zeiten (#274 / #279 A, Schnitt 1)

    private func timings(
        open: TimeInterval = 0.1, model: TimeInterval = 0.2, rights: TimeInterval = 0.3,
        analyzer: TimeInterval = 0.4, microphone: TimeInterval = 0.5, firstResult: TimeInterval? = 1
    ) -> SpeechTimings {
        SpeechTimings(open: open, modelCheck: model, rights: rights, analyzer: analyzer,
                      microphone: microphone, firstResult: firstResult)
    }

    private func hint(results: Int, seconds: TimeInterval = 10, timings: SpeechTimings?) -> SpeechDiagnosis? {
        SpeechDiagnosis.hint(
            buffers: 100, results: results, secondsListening: seconds,
            modelStatus: "installed", microphone: true, speech: true, timings: timings
        )
    }

    private func s(_ value: TimeInterval) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    @Test("Slow-start threshold is three seconds, in one place")
    func slowStartThresholdIsThreeSeconds() {
        #expect(SpeechDiagnosis.slowStart == 3)
    }

    @Test("Start is the sum of the five parts")
    func startIsSumOfParts() {
        let t = timings(open: 0.1, model: 0.2, rights: 9.8, analyzer: 1.5, microphone: 0.8)
        #expect(abs(t.start - 12.4) < 0.0001)
    }

    @Test("Report when the start is slow (exactly 3 s)")
    func reportWhenStartIsSlow() {
        let t = timings(open: 1, model: 0.5, rights: 0.5, analyzer: 0.5, microphone: 0.5, firstResult: 1)
        #expect(hint(results: 1, timings: t) != nil)
    }

    @Test("No report just below the thresholds")
    func noReportJustBelowSlowStart() {
        let t = timings(open: 0.5, model: 0.5, rights: 0.5, analyzer: 0.5, microphone: 0.9, firstResult: 5.9)
        #expect(hint(results: 1, timings: t) == nil)
    }

    @Test("Report when the first result is late (exactly 6 s)")
    func reportWhenFirstResultIsLate() {
        #expect(hint(results: 1, timings: timings(firstResult: 6)) != nil)
    }

    @Test("Without timings a result clears the line, as before")
    func noReportWithoutTimings() {
        #expect(hint(results: 1, timings: nil) == nil)
    }

    @Test("Report works without a first-result time")
    func reportWithoutFirstResultTime() throws {
        let t = timings(open: 3, model: 0, rights: 0, analyzer: 0, microphone: 0, firstResult: nil)
        let report = try #require(hint(results: 1, timings: t))
        #expect(!report.text.contains("nil"))
    }

    @Test("Waiting text carries the start parts in order")
    func waitingTextCarriesStartParts() throws {
        let t = timings(open: 0.1, model: 0.2, rights: 9.8, analyzer: 1.5, microphone: 0.8, firstResult: nil)
        let waiting = try #require(hint(results: 0, seconds: 7, timings: t))
        let text = waiting.text
        var cursor = text.startIndex
        for value in [t.start, 0.1, 0.2, 9.8, 1.5, 0.8] {
            let range = try #require(text.range(of: s(value), range: cursor..<text.endIndex))
            cursor = range.upperBound
        }
    }

    @Test("Report text carries first result, sum and parts")
    func reportTextCarriesFirstResultAndParts() throws {
        let t = timings(open: 0.1, model: 0.2, rights: 9.8, analyzer: 1.5, microphone: 0.8, firstResult: 11.4)
        let report = try #require(hint(results: 3, timings: t))
        var cursor = report.text.startIndex
        for value in [11.4, t.start, 0.1, 0.2, 9.8, 1.5, 0.8] {
            let range = try #require(report.text.range(of: s(value), range: cursor..<report.text.endIndex))
            cursor = range.upperBound
        }
        #expect(report.text != hint(results: 0, seconds: 7, timings: t)?.text)
    }

    @Test("Waiting text without timings is the text from before")
    func waitingTextWithoutTimingsIsUnchanged() throws {
        let plain = try #require(hint(seconds: 7, buffers: 62, results: 0))
        let withNil = try #require(hint(results: 0, seconds: 7, timings: nil))
        #expect(!plain.text.contains("Start"))
        #expect(!withNil.text.contains("Start"))
    }

    @Test("Stop forgets the opening time, so a later tap does not count typing as opening (F001)")
    @MainActor
    func stopClearsOpenedAt() {
        let speech = SpeechCapture()
        speech.noteOpened()
        #expect(speech.openedAt != nil)
        speech.stop()
        #expect(speech.openedAt == nil)
    }
}
