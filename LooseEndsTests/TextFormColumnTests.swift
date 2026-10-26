import Foundation
import Testing
@testable import LooseEnds

/// #88 Teil 2 (vorab, ohne Gerät): der Adapter, der aus dem Textform-Korpus Notizen für den Laborlauf
/// macht, und die Auswertung „Titel und Dauer je Textform“. Kein Modellaufruf: die Ergebnisse unten
/// sind erfunden und beweisen nur Laden und Rechnen, nicht die Modellqualität.
struct TextFormColumnTests {
    private let conditions = Conditions(appState: "vordergrund", power: "strom", batteryPercent: 80,
                                        lowPowerMode: false, thermal: "normal", device: "test", systemVersion: "27")

    private func result(_ id: String, title: String? = nil, duration: String? = nil,
                        error: String? = nil, run: Int = 0) -> MeasurementResult {
        MeasurementResult(entryID: id, capturedAt: Date(timeIntervalSince1970: 0), finishedAt: Date(timeIntervalSince1970: 1),
                          seconds: 1, conditions: conditions, title: title, error: error, runIndex: run, duration: duration)
    }

    private func repoFile(_ relativePath: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(relativePath)
    }

    // MARK: - Adapter (AC-1 bis AC-4)

    @Test("Der Adapter liefert 120 Notizen für 40 Inhalte, keine Mail (AC-1, AC-3)")
    func adapterYields120Notes() throws {
        let entries = try Corpus.load(fileName: "textform-corpus")
        #expect(entries.count == 120)
        #expect(entries.allSatisfy { !$0.id.hasSuffix(".mail") })
        #expect(Set(entries.map { $0.id.split(separator: ".").first.map(String.init) ?? "" }).count == 40)
    }

    @Test("Kennung <inhalt>.<form>, Sprache aus der Form, Text unverändert (AC-2)")
    func idsAndLanguage() throws {
        let entries = try Corpus.load(fileName: "textform-corpus")
        let byID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        #expect(byID["tf-01.typed"]?.lang == "de")
        #expect(byID["tf-01.dictated"]?.lang == "de")
        #expect(byID["tf-01.english"]?.lang == "en")
        #expect(byID["tf-01.typed"]?.text == "Morgen um 14 Uhr Zahnarzt")
        #expect(byID["tf-01.english"]?.text == "Dentist tomorrow at 2 pm")
    }

    @Test("Die bisherigen Korpusse laden genauso wie zuvor (AC-4)")
    func otherCorporaUnchanged() throws {
        for name in ["date-title-corpus", "latency-corpus"] {
            let url = repoFile("Measurement/\(name).json")
            let expected = try JSONDecoder().decode([Corpus.Entry].self, from: Data(contentsOf: url))
            let loaded = try Corpus.load(fileName: name)
            #expect(loaded.map(\.id) == expected.map(\.id), Comment(rawValue: name))
            #expect(loaded.map(\.text) == expected.map(\.text), Comment(rawValue: name))
        }
    }

    // MARK: - Auswertung (AC-5 bis AC-7)

    private let texts = [
        "tf-01.typed": "Morgen um 14 Uhr Zahnarzt",
        "tf-01.dictated": "ähm morgen um 14 uhr muss ich zum zahnarzt",
        "tf-01.english": "Dentist tomorrow at 2 pm",
        "tf-02.typed": "Rechnung Müller bezahlen",
        "tf-02.dictated": "ich muss die rechnung von müller bezahlen",
    ]
    private let truth = ["tf-01": ["zahnarzt"], "tf-02": ["rechnung", "müller"]]

    /// Die Regel wird eingespeist: `Measurement/` kennt `TitleRule` nicht (es liegt nicht im Lab-Ziel).
    private func ruleTitle(_ text: String) -> String? { text.contains("zahnarzt") || text.contains("Zahnarzt") ? "Zahnarzt" : "Hallo" }

    @Test("Titel-Spalte: Anteil der Modelltitel mit allen Schlüsselwörtern, Regel daneben, Fehler gezählt (AC-5)")
    func titleColumn() {
        let results = [
            result("tf-01.typed", title: "Zahnarzt"),
            result("tf-02.typed", title: "Rechnung bezahlen"),            // „müller“ fehlt
            result("tf-01.dictated", title: "Zum Zahnarzt gehen"),
            result("tf-02.dictated", error: "guardrail"),
        ]
        let rows = TextFormColumn.titleRows(results: results, texts: texts, truthWords: truth, ruleTitle: ruleTitle)
        let typed = rows.first { $0.form == "typed" }
        let dictated = rows.first { $0.form == "dictated" }
        #expect(typed?.notes == 2)
        #expect(typed?.modelHits == 1)
        #expect(typed?.errors == 0)
        #expect(dictated?.modelHits == 1)
        #expect(dictated?.errors == 1)
        // Regel: Titel „Zahnarzt“ trifft tf-01, „Hallo“ trifft tf-02 nicht.
        #expect(typed?.ruleHits == 1)
    }

    @Test("Dauer-Spalte: Mehrheit der Form gegen die Mehrheit von typed, Unvergleichbares gezählt (AC-6)")
    func durationAgreement() {
        let results = [
            result("tf-01.typed", duration: "30", run: 0), result("tf-01.typed", duration: "30", run: 1),
            result("tf-01.dictated", duration: "30", run: 0), result("tf-01.dictated", duration: "60", run: 1),
            result("tf-01.dictated", duration: "30", run: 2),
            result("tf-02.typed", duration: "15"),
            result("tf-02.dictated", duration: "60"),                      // andere Mehrheit
            result("tf-01.english", duration: "30"),
            result("tf-02.english", error: "timeout"),                     // ohne Dauer: nicht vergleichbar
        ]
        let rows = TextFormColumn.durationRows(results: results)
        let dictated = rows.first { $0.form == "dictated" }
        let english = rows.first { $0.form == "english" }
        #expect(dictated?.compared == 2)
        #expect(dictated?.same == 1)
        #expect(english?.compared == 1)
        #expect(english?.same == 1)
        #expect(english?.skipped == 1)

        let report = TextFormColumn.render(titleRows: [], durationRows: rows)
        #expect(report.contains("keine Wahrheit"))
    }

    @Test("Eine Form ohne Ergebnisse zeigt „–“, nicht 0 % (AC-7)")
    func emptyFormShowsDash() {
        let titleRows = TextFormColumn.titleRows(results: [], texts: texts, truthWords: truth, ruleTitle: ruleTitle)
        let durationRows = TextFormColumn.durationRows(results: [])
        let report = TextFormColumn.render(titleRows: titleRows, durationRows: durationRows)
        #expect(report.contains("–"))
        #expect(!report.contains("0 %"))
    }

    // MARK: - Doku (AC-9)

    @Test("Die Referenz nennt den Aufruf und nicht mehr „Modellspalte fehlt noch“ (AC-9)")
    func referenceDocNamesCall() throws {
        let doc = try String(contentsOf: repoFile("docs/reference/textform-rules.md"), encoding: .utf8)
        #expect(doc.contains("--corpus textform-corpus"))
        #expect(!doc.contains("Modellspalte fehlt noch"))
    }
}
