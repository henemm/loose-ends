import Foundation
import Testing
@testable import LooseEnds

/// #88 Teil 2, Schnitt A: Hennings echte Rohsätze als zweite Messquelle. Alles unten mit erfundenen
/// Sätzen: es wird Einlesen, Entduplizieren, Einteilen und Rechnen bewiesen, nie Modellqualität, und
/// kein Test ruft ein Modell auf.
struct RawSentenceColumnTests {
    private let conditions = Conditions(appState: "vordergrund", power: "strom", batteryPercent: 80,
                                        lowPowerMode: false, thermal: "normal", device: "test", systemVersion: "27")

    private func result(_ id: String, title: String? = nil, duration: String? = nil,
                        error: String? = nil, run: Int = 0) -> MeasurementResult {
        MeasurementResult(entryID: id, capturedAt: Date(timeIntervalSince1970: 0), finishedAt: Date(timeIntervalSince1970: 1),
                          seconds: 1, conditions: conditions, title: title, error: error, runIndex: run, duration: duration)
    }

    private func sentence(_ id: String, _ raw: String, before: String = "alt", user: String? = nil,
                          duration: String? = nil) -> RawSentenceColumn.Sentence {
        RawSentenceColumn.Sentence(id: id, rawText: raw, titleBefore: before, titleUser: user,
                                   durationUser: duration, capturedAt: "2026-10-01T08:00:00Z", lang: nil)
    }

    private func json(_ rows: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: rows)
    }

    // MARK: AC-1, AC-2

    @Test("AC-1: das dritte Format wird am Inhalt erkannt und als Entry geliefert")
    func thirdFormatLoads() throws {
        let data = try json([
            ["id": "s-0001", "rawText": "Zahnarzt anrufen!", "titleBefore": "Zahnarzt", "capturedAt": "2026-10-01T08:00:00Z"],
            ["id": "s-0002", "rawText": "call the bank", "titleBefore": "bank", "capturedAt": "2026-10-02T08:00:00Z", "lang": "en"],
        ])
        let entries = try Corpus.entries(from: data)
        #expect(entries.map(\.id) == ["s-0001", "s-0002"])
        #expect(entries.map(\.lang) == ["de", "en"])
        #expect(entries.map(\.text) == ["Zahnarzt anrufen!", "call the bank"])
    }

    @Test("AC-2: bisherige Korpusse laden wie zuvor, das neue Format greift bei keinem")
    func otherCorporaUnchanged() throws {
        #expect(try Corpus.load(fileName: "textform-corpus").count == 120)
        for name in [Corpus.fileName, "latency-corpus"] {
            let direct = try JSONDecoder().decode([Corpus.Entry].self, from: Data(contentsOf: Corpus.url(fileName: name)))
            let loaded = try Corpus.load(fileName: name)
            #expect(loaded.map(\.id) == direct.map(\.id))
            #expect(loaded.map(\.text) == direct.map(\.text))
        }
    }

    // MARK: AC-3, AC-4

    @Test("AC-3: Dubletten falten, Vertreter mit Korrektur, vor und nach gezählt")
    func duplicatesFoldWithCounts() {
        let all = [
            sentence("a", "Zahnarzt anrufen"),
            sentence("b", "zahnarzt anrufen!", user: "Zahnarzt"),
            sentence("c", "Anrufen: Zahnarzt"),
            sentence("d", "Steuer machen"),
            sentence("e", "Auto waschen"),
        ]
        let folded = RawSentenceColumn.distinct(all)
        #expect(folded.before == 5)
        #expect(folded.after == 3)
        #expect(folded.kept.map(\.id) == ["b", "d", "e"])
    }

    @Test("AC-3: ohne Korrektur bleibt der erste der Datei")
    func duplicatesWithoutCorrectionKeepFirst() {
        let folded = RawSentenceColumn.distinct([sentence("a", "Eins zwei"), sentence("b", "zwei eins")])
        #expect(folded.kept.map(\.id) == ["a"])
    }

    @Test("AC-4: Wahrheitsstufen, keine Doppelzählung")
    func truthTiers() {
        let tiers = RawSentenceColumn.tiers([
            sentence("a", "eins", before: "x", user: "y", duration: "minutes15"),
            sentence("b", "zwei", before: "x", user: "X"),
            sentence("c", "drei", before: "x"),
        ])
        #expect(tiers.titleCorrected.map(\.id) == ["a"])
        #expect(tiers.titleUncorrected.map(\.id) == ["b", "c"])
        #expect(tiers.durationCorrected.map(\.id) == ["a"])
        #expect(tiers.durationUncorrected.map(\.id) == ["b", "c"])
    }

    // MARK: AC-5, AC-6

    @Test("AC-5: Titel-Spalte mit Regel über dieselben Sätze, Fehler gezählt, Unkorrigierte gesondert")
    func titleColumnWithRule() {
        let sentences = [
            sentence("a", "alpha text", user: "Alpha"),
            sentence("b", "beta text", user: "Beta"),
            sentence("c", "gamma text", user: "Gamma"),
            sentence("d", "delta text"),
            sentence("e", "epsilon text", user: "Epsilon"),   // nicht im Lauf
        ]
        let results = [result("a", title: "alpha"), result("b", title: "Falsch"), result("c", error: "refused"),
                       result("d", title: "Delta")]
        let row = RawSentenceColumn.titleRow(results: results, sentences: sentences,
                                             ruleTitle: { $0.hasPrefix("alpha") ? "Alpha" : "Nix" })
        #expect(row.corrected == 3)
        #expect(row.modelHits == 1)
        #expect(row.ruleHits == 1)
        #expect(row.errors == 1)
        #expect(row.uncorrected == 1)
    }

    @Test("AC-6: Dauer-Spalte, Mehrheit gegen durationUser, Regel daneben, Unkorrigierte nur gezählt")
    func durationColumnWithRule() {
        let sentences = [
            sentence("a", "alpha", duration: "minutes15"),
            sentence("b", "beta", duration: "hour1"),
            sentence("c", "gamma"),
        ]
        let results = [result("a", duration: "minutes15", run: 0), result("a", duration: "minutes15", run: 1),
                       result("a", duration: "hour1", run: 2), result("a", error: "x", run: 3),
                       result("b", duration: "minutes5"), result("c", duration: "hour1")]
        let row = RawSentenceColumn.durationRow(results: results, sentences: sentences,
                                                ruleDuration: { $0 == "beta" ? "hour1" : nil })
        #expect(row.corrected == 2)
        #expect(row.modelHits == 1)
        #expect(row.ruleHits == 1)
        #expect(row.uncorrected == 1)
    }

    // MARK: AC-7, AC-8, AC-9

    private func titleRows(corrected: Int) -> (RawSentenceColumn.TitleRow, RawSentenceColumn.DurationRow) {
        (RawSentenceColumn.TitleRow(corrected: corrected, modelHits: corrected / 2, ruleHits: corrected / 3,
                                    errors: 0, uncorrected: 4),
         RawSentenceColumn.DurationRow(corrected: corrected, modelHits: corrected / 2, ruleHits: corrected / 3,
                                       uncorrected: 4))
    }

    @Test("AC-7: unter der Mindestmenge steht „zu wenig“ statt einer Rate, ab ihr die Rate")
    func belowMinimumSaysTooLittle() {
        #expect(RawSentenceColumn.minimumCorrected == 30)
        let few = titleRows(corrected: 29)
        let textFew = RawSentenceColumn.render(before: 40, after: 30, title: few.0, duration: few.1)
        #expect(textFew.contains("zu wenig (29 von mindestens 30)"))
        #expect(!textFew.contains("%"))
        let enough = titleRows(corrected: 30)
        let textEnough = RawSentenceColumn.render(before: 40, after: 30, title: enough.0, duration: enough.1)
        #expect(!textEnough.contains("zu wenig"))
        #expect(textEnough.contains("50 %"))
    }

    @Test("AC-8: ohne korrigierte Sätze zeigt die Zelle „–“")
    func emptyGroupShowsDash() {
        let none = titleRows(corrected: 0)
        let text = RawSentenceColumn.render(before: 0, after: 0, title: none.0, duration: none.1)
        #expect(text.contains("–"))
        #expect(!text.contains("0 %"))
        #expect(!text.contains("zu wenig"))
    }

    @Test("AC-9: der Bericht enthält keinen Satz, nur Zählungen")
    func reportNeverContainsSentences() {
        let marked = [sentence("a", "ZEBRAFELL Quartalsbericht", before: "KAKTUSMARKE", user: "WOLKENTITEL")]
        let title = RawSentenceColumn.titleRow(results: [result("a", title: "WOLKENTITEL")], sentences: marked,
                                               ruleTitle: { _ in "KAKTUSMARKE" })
        let duration = RawSentenceColumn.durationRow(results: [], sentences: marked, ruleDuration: { _ in nil })
        let text = RawSentenceColumn.render(before: 1, after: 1, title: title, duration: duration)
        for marker in ["ZEBRAFELL", "Quartalsbericht", "KAKTUSMARKE", "WOLKENTITEL"] {
            #expect(!text.contains(marker))
        }
    }
}

// MARK: - AC-10: der gesperrte Bericht

private let rawSentencesURL = MeasurementData.rawSentences
private let rawSentencesRunURL = MeasurementData.reference("loose-ends-rawtexts-run.json")

@Suite(.enabled(if: MeasurementData.exists(rawSentencesURL),
                "loose-ends-rawtexts.json fehlt: entsteht nur aus dem Export (#88 Teil 2, Schnitt B), Messung nicht gelaufen (#149)"))
struct RawSentenceReportTests {
    @Test("Schreibt den Abschnitt „Echte Rohsätze“ nach stdout, ohne Modellaufruf")
    func printsSeparateSection() throws {
        let all = try RawSentenceColumn.decode(Data(contentsOf: rawSentencesURL))
        let folded = RawSentenceColumn.distinct(all)
        let results = MeasurementData.exists(rawSentencesRunURL)
            ? try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(contentsOf: rawSentencesRunURL)).results
            : []
        let title = RawSentenceColumn.titleRow(results: results, sentences: folded.kept,
                                               ruleTitle: { TitleRule.title(from: $0) })
        let duration = RawSentenceColumn.durationRow(results: results, sentences: folded.kept,
                                                     ruleDuration: { DurationRule.match(in: $0)?.guess.value.rawValue })
        let report = RawSentenceColumn.render(before: folded.before, after: folded.after, title: title, duration: duration)
        print("RAWSENTENCE-REPORT BEGIN\n\(report)\nRAWSENTENCE-REPORT END")
        #expect(report.contains("Echte Rohsätze"))
    }
}

extension MeasurementData {
    /// Hennings eigene Erfassungen (#88 Teil 2), nur lokal, nie eingecheckt.
    static var rawSentences: URL { reference("loose-ends-rawtexts.json") }
}
