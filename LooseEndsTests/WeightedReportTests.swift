import Foundation
import Testing
@testable import LooseEnds

/// #88 Teil 1: the report states its total once more, weighted by Henning's distribution, with the
/// rule column next to the model. Only two weights are his own statement (a third keywords, 12 % with a
/// time); the weighting therefore runs over two groups per criterion, never over the twelve forms.
/// Checked on synthetic reports, so it runs before any run was fetched.
@Suite("Bericht: Gewichtung nach Hennings Verteilung")
struct WeightedReportTests {

    typealias Tally = DateTitleReportTests.Tally

    static func tally(hits: Int, of total: Int) -> Tally {
        var tally = Tally()
        for index in 0..<total { tally.record(hit: index < hits) }
        return tally
    }

    /// A report whose numbers are easy to check by hand.
    static func report() -> DateTitleReportTests.Report {
        var report = DateTitleReportTests.Report()
        // Titles, model: keywords 2 of 2, every other form 9 of 10.
        report.byForm["stichwort", default: .init()].facts = tally(hits: 2, of: 2)
        report.byForm["standard", default: .init()].facts = tally(hits: 5, of: 5)
        report.byForm["frage", default: .init()].facts = tally(hits: 4, of: 5)
        // Titles, rule: keywords 1 of 2, every other form 10 of 10.
        report.byForm["stichwort", default: .init()].ruleFacts = tally(hits: 1, of: 2)
        report.byForm["standard", default: .init()].ruleFacts = tally(hits: 10, of: 10)
        // Dates, model: exact 1 of 2, invented-free 10 of 10.
        report.model = tally(hits: 1, of: 2)
        report.invented = tally(hits: 10, of: 10)
        // Dates, rule parser: exact 2 of 2, invented-free 10 of 10.
        report.ruleParser = tally(hits: 2, of: 2)
        report.ruleParserInvented = tally(hits: 10, of: 10)
        return report
    }

    @Test("Die Gewichte sind Hennings Angabe, mit Quelle und eingefrorener Zählung")
    func weightsAreHennings() {
        #expect(Corpus.Weights.keywordShare == 1.0 / 3.0)
        #expect(Corpus.Weights.timeShare == 0.12)
        #expect(Corpus.Weights.source.contains("Angabe Henning"))
        #expect(Corpus.Weights.source.contains("nicht nachgezählt"))
        #expect(Corpus.Weights.counted.titles == 287)
        #expect(Corpus.Weights.counted.measured == "2026-10-24")
    }

    @Test("Titel: ein Drittel Stichwörter, zwei Drittel alle übrigen Formen zusammen")
    func titleWeighting() throws {
        let value = try #require(DateTitleReportTests.weighted([
            (Corpus.Weights.keywordShare, Self.tally(hits: 2, of: 2)),
            (1 - Corpus.Weights.keywordShare, Self.tally(hits: 9, of: 10)),
        ]))
        #expect(abs(value - (1.0 / 3.0 + 2.0 / 3.0 * 0.9)) < 1e-9)
        #expect(DateTitleReportTests.percent(value) == "93.3 %")
    }

    @Test("Datum: 12 % Sätze mit Datum, 88 % ohne")
    func dateWeighting() throws {
        let value = try #require(DateTitleReportTests.weighted([
            (Corpus.Weights.timeShare, Self.tally(hits: 1, of: 2)),
            (1 - Corpus.Weights.timeShare, Self.tally(hits: 10, of: 10)),
        ]))
        #expect(DateTitleReportTests.percent(value) == "94.0 %")
    }

    @Test("Eine leere Gruppe wird nie still umnormiert")
    func emptyGroupIsNotRenormalised() {
        #expect(DateTitleReportTests.weighted([
            (Corpus.Weights.keywordShare, Tally()),
            (1 - Corpus.Weights.keywordShare, Self.tally(hits: 9, of: 10)),
        ]) == nil)

        var report = Self.report()
        report.byForm["stichwort"] = nil
        let section = DateTitleReportTests.weightedSection(report)
        #expect(section.contains("(Gruppe ohne Sätze, nicht gewichtet)"))
        #expect(!section.contains("90.0 %"), "the other group's rate must not stand in for the total")
    }

    @Test("Der Abschnitt nennt Gewichte, Quelle, Formel, Regel-Spalte und kein Gewicht für die übrigen Formen")
    func section() {
        let section = DateTitleReportTests.weightedSection(Self.report())
        #expect(section.hasPrefix("## Gewichtet nach Hennings Verteilung"))
        #expect(section.contains("Angabe Henning, nicht nachgezählt"))
        #expect(section.contains("| Kriterium | Modell | Regel |"))
        #expect(section.contains("| Titel ohne erfundene Fakten | 93.3 % | 83.3 % |"))
        #expect(section.contains("| Datum richtig behandelt | 94.0 % | 100.0 % |"))
        #expect(section.contains("0,12 × Anteil"), "the formula stands in the report")
        for form in Corpus.forms where form != "stichwort" {
            #expect(section.contains("| \(form) | kein Gewicht |"), "\(form) carries no weight")
        }
    }

    @Test("Die Zählung steht als zweite Zeile, eingefroren, als Titel statt Rohsätze")
    func countLine() {
        let section = DateTitleReportTests.weightedSection(Self.report())
        #expect(section.contains("Zählung an 287 FocusBlox-Titeln, Stand 2026-10-24"))
        #expect(section.contains("Titel, keine Rohsätze"))
        #expect(section.contains("Zählskript nicht im Repo"))
    }

    @Test("Der Regelparser und TitleRule werden je Bauform gezählt")
    func ruleTalliesByForm() throws {
        let corpus = try JSONDecoder().decode([Corpus.Entry].self, from: Data("""
        [{"id": "a", "lang": "de", "text": "Morgen die Kita anrufen", "form": "standard", "date": {"rule": "offsetDays", "value": 1}},
         {"id": "b", "lang": "de", "text": "Rechnung 4711 reklamieren", "form": "stichwort"}]
        """.utf8))
        var report = DateTitleReportTests.Report()
        DateTitleReportTests.scoreRuleParser(corpus, calendar: CorpusTests.calendar, reference: CorpusTests.reference, into: &report)
        DateTitleReportTests.scoreTitleRule(corpus, calendar: CorpusTests.calendar, reference: CorpusTests.reference, into: &report)
        #expect(report.byForm["standard"]?.ruleDate.total == 1)
        #expect(report.byForm["standard"]?.ruleDate.hit == 1)
        #expect(report.byForm["stichwort"]?.ruleInvented.total == 1)
        #expect(report.byForm["stichwort"]?.ruleInvented.hit == 1)
        #expect(report.byForm["standard"]?.ruleFacts.total == 1)
        #expect(report.byForm["stichwort"]?.ruleFacts.hit == 1, "TitleRule keeps 4711, invents nothing")
    }

    @Test("Der neue Abschnitt steht nach „Nach Bauform“ und vor „Titel“, die alten behalten ihre Reihenfolge")
    func order() throws {
        let markdown = DateTitleReportTests.markdown(Self.report(), runs: [], corpus: [])
        let headings = markdown.split(separator: "\n").filter { $0.hasPrefix("## ") }.map(String.init)
        let form = try #require(headings.firstIndex(of: "## Nach Bauform"))
        let weighted = try #require(headings.firstIndex(of: "## Gewichtet nach Hennings Verteilung"))
        let title = try #require(headings.firstIndex(of: "## Titel"))
        #expect(form + 1 == weighted)
        #expect(weighted + 1 == title)
    }
}
