import Foundation
import Testing
@testable import LooseEnds

/// The acceptance bar from #92, computed over the whole corpus against a fixed reference day so
/// it holds in CI without a measurement run: dates at least 95 % exact, no date invented on a
/// control sentence, times at least 95 % exact. Deliberately not gated on `MeasurementFiles.runs`
/// — no model is involved, the Mac is the instrument.
@Suite("Regelparser: Abnahme über den Korpus")
struct DateParserCorpusTests {
    static let reference = CorpusTests.reference
    static let calendar = CorpusTests.calendar

    struct Score {
        var total = 0
        var hit = 0
        var misses: [String] = []
        var share: Double { total == 0 ? 0 : Double(hit) / Double(total) }
        mutating func record(_ isHit: Bool, miss: @autoclosure () -> String) {
            total += 1
            if isHit { hit += 1 } else { misses.append(miss()) }
        }
        var summary: String { "\(hit) von \(total)\n" + misses.map { "  - \($0)" }.joined(separator: "\n") }
    }

    @Test("Datum: mindestens 95 % exakt, kein einziges erfunden")
    func dates() throws {
        let parser = DateExpressionParser(calendar: Self.calendar)
        var exact = Score()
        var invented = Score()
        // Every sentence, repetitions included: "Jeden Montag den Müll rausstellen" is exactly the
        // kind of sentence a parser must not turn into a date, so it belongs in the control group
        // (AC-2: 170 plain controls plus the 8 repetitions).
        for entry in try Corpus.load() {
            let got = parser.date(in: entry.text, reference: Self.reference)
            let day = got.map { DateTitleReportTests.day($0, Self.calendar) } ?? "–"
            if let expectation = entry.date {
                let accepted = expectation.acceptedDays(reference: Self.reference, calendar: Self.calendar)
                exact.record(got.map(accepted.contains) ?? false,
                             miss: "`\(entry.text)` → \(day) statt \(CorpusTests.days(expectation).sorted().joined(separator: "|")) · \(DateTitleReportTests.ruleName(expectation))")
            } else {
                invented.record(got == nil, miss: "`\(entry.text)` → \(day)")
            }
        }
        #expect(exact.total == 139, "Korpus hat \(exact.total) Datumssätze statt 139")
        #expect(invented.total == 180, "Korpus hat \(invented.total) Kontrollsätze statt 180")
        #expect(exact.share >= 0.95, "Datum exakt: \(exact.summary)")
        #expect(invented.misses.isEmpty, "Datum erfunden: \(invented.summary)")
    }

    @Test("Uhrzeit: mindestens 95 % exakt, Wiederholungen eingeschlossen")
    func times() throws {
        let parser = TimeExpressionParser()
        var exact = Score()
        for entry in try Corpus.load() {
            guard let expected = entry.time else { continue }
            let got = parser.time(in: entry.text).map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            exact.record(got == expected, miss: "`\(entry.text)` → \(got ?? "–") statt \(expected)")
        }
        #expect(exact.total >= 24, "Korpus hat nur \(exact.total) Uhrzeit-Sätze")
        #expect(exact.share >= 0.95, "Uhrzeit exakt: \(exact.summary)")
    }

    @Test("Uhrzeit: kein Satz ohne Uhrzeit bekommt eine")
    func noInventedTimes() throws {
        let parser = TimeExpressionParser()
        var invented = Score()
        for entry in try Corpus.load() where entry.time == nil {
            let got = parser.time(in: entry.text).map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            invented.record(got == nil, miss: "`\(entry.text)` → \(got ?? "–")")
        }
        #expect(invented.misses.isEmpty, "Uhrzeit erfunden: \(invented.summary)")
    }
}
