import Foundation
import Testing
@testable import LooseEnds

/// #88 Teil 2: der Bericht „Titel und Dauer je Textform“ aus einer Ergebnisdatei, die der Laborlauf
/// auf dem iPhone geschrieben hat (`--corpus textform-corpus --runs <n> --result textform-run`, danach
/// `sim.sh lab-fetch`). Ruft kein Modell auf. Gesperrt, weil die Datei persönlich und nicht eingecheckt
/// ist; fehlt sie, wird die Suite laut übersprungen (#149), nie als bestanden gezählt.
private let textFormRunURL = MeasurementData.reference("textform-run.json")

@Suite(.enabled(if: MeasurementData.exists(textFormRunURL),
                "textform-run.json fehlt: entsteht nur aus einem Gerätelauf (#88 Teil 2), Messung nicht gelaufen (#149)"))
struct TextFormModelReportTests {
    @Test("Schreibt den Textform-Bericht aus der vorhandenen Ergebnisdatei nach stdout")
    func printsReport() throws {
        let run = try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(contentsOf: textFormRunURL))
        let entries = try Corpus.load(fileName: "textform-corpus")
        let texts = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.text) })
        let truth = try TextFormColumn.titleWords(fileName: "textform-corpus")
        let titleRows = TextFormColumn.titleRows(results: run.results, texts: texts, truthWords: truth,
                                                 ruleTitle: { TitleRule.title(from: $0) })
        let report = TextFormColumn.render(titleRows: titleRows, durationRows: TextFormColumn.durationRows(results: run.succeeded))
        print("TEXTFORM-MODEL-REPORT BEGIN\n\(report)\nTEXTFORM-MODEL-REPORT END")
        #expect(!titleRows.isEmpty)
    }
}
