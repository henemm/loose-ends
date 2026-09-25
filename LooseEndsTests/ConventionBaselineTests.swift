import Foundation
import Testing
@testable import LooseEnds

/// The rule-only baseline for the convention test in Annahme B1 (Spike #69, Ticket A): does a
/// deterministic majority vote over three prior corrections already predict the context of a
/// fourth, unseen note — without a model, without embeddings? This is the zero line B1's possible
/// embedding retrieval (Ticket B) would have to beat.
private func repoFile(_ relativePath: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
}
private let reportURL = repoFile("docs/reference/retrieval-convention-spike.md")

@Suite("Regel-Baseline für den Konventionstest (Spike #69, Ticket A)")
struct ConventionBaselineTests {
    static func pattern(
        id: String = "test",
        corrections: [ConventionCorpus.Pattern.Correction],
        probeText: String,
        expectedContext: String
    ) -> ConventionCorpus.Pattern {
        ConventionCorpus.Pattern(id: id, corrections: corrections,
                                  probe: .init(text: probeText, expectedContext: expectedContext))
    }

    @Test("Lädt zehn Wort→Kontext-Muster, je drei Korrekturen und eine Sonde (AC-1)")
    func loadsTenPatterns() throws {
        let patterns = try ConventionCorpus.load(fileName: "convention-corpus")
        #expect(patterns.count == 10)
        for pattern in patterns {
            #expect(pattern.corrections.count == 3)
        }
    }

    @Test("Kernwort, das in drei Korrekturen und der Sonde vorkommt, liefert deren Kontext (AC-2)")
    func predictsFromSharedCoreWord() {
        let pattern = Self.pattern(
            corrections: [
                .init(text: "Rasen mähen, bevor die Nachbarn kommen", context: "Garten"),
                .init(text: "Rasen düngen am Wochenende", context: "Garten"),
                .init(text: "Rasen vertikutieren im Frühjahr", context: "Garten"),
            ],
            probeText: "Rasen wässern, bevor es zu heiß wird",
            expectedContext: "Garten"
        )
        #expect(RuleBaseline.predict(pattern: pattern) == "Garten")
    }

    @Test("Mehrheitsentscheid gewinnt, nicht der zuletzt gesehene Wert (AC-3)")
    func majorityWinsOverLastSeen() {
        let pattern = Self.pattern(
            corrections: [
                .init(text: "Werkzeug aufräumen nach dem Einsatz", context: "Garten"),
                .init(text: "Werkzeug sortieren", context: "Garten"),
                .init(text: "Werkzeug zurücklegen", context: "Keller"),
            ],
            probeText: "Werkzeug reinigen",
            expectedContext: "Garten"
        )
        #expect(RuleBaseline.predict(pattern: pattern) == "Garten")
    }

    @Test("Kein gemeinsames Wort liefert nil, keinen erzwungenen Kontext (AC-4)")
    func noMatchYieldsNil() {
        let pattern = Self.pattern(
            corrections: [
                .init(text: "Rechnung bezahlen", context: "Finanzen"),
                .init(text: "Überweisung anstoßen", context: "Finanzen"),
                .init(text: "Kontoauszug prüfen", context: "Finanzen"),
            ],
            probeText: "Fahrrad reparieren",
            expectedContext: "Finanzen"
        )
        #expect(RuleBaseline.predict(pattern: pattern) == nil)
    }

    @Test("Auswertung über mehrere Muster liefert eine Trefferquote (AC-5)")
    func evaluatesAllPatterns() {
        let hit = Self.pattern(
            id: "hit",
            corrections: [
                .init(text: "Rasen mähen", context: "Garten"),
                .init(text: "Rasen düngen", context: "Garten"),
                .init(text: "Rasen vertikutieren", context: "Garten"),
            ],
            probeText: "Rasen wässern",
            expectedContext: "Garten"
        )
        let miss = Self.pattern(
            id: "miss",
            corrections: [
                .init(text: "Rechnung bezahlen", context: "Finanzen"),
                .init(text: "Überweisung anstoßen", context: "Finanzen"),
                .init(text: "Kontoauszug prüfen", context: "Finanzen"),
            ],
            probeText: "Fahrrad reparieren",
            expectedContext: "Finanzen"
        )

        let outcomes = RuleBaseline.evaluate(patterns: [hit, miss])
        #expect(outcomes.count == 2)
        #expect(outcomes.first { $0.patternID == "hit" }?.correct == true)
        #expect(outcomes.first { $0.patternID == "miss" }?.correct == false)
    }

    @Test("Bericht wird aus dem eingebetteten Korpus geschrieben, ohne Modell- oder Geräteaufruf (AC-6)")
    func writesReport() throws {
        let patterns = try ConventionCorpus.load(fileName: "convention-corpus")
        let outcomes = RuleBaseline.evaluate(patterns: patterns)
        let hits = outcomes.filter(\.correct).count
        let ticketBNeeded = hits < 8 ? "ja" : "nein"

        var report = """
        # Regel-Baseline für den Konventionstest (Spike #69, Ticket A)

        Trefferquote: \(hits) von \(outcomes.count)

        | Muster | Vorhersage | Erwartet | Richtig |
        |---|---|---|---|

        """
        for outcome in outcomes {
            report += "| \(outcome.patternID) | \(outcome.predicted ?? "–") | \(outcome.expected) | \(outcome.correct ? "richtig" : "falsch") |\n"
        }
        report += "\nTicket B (Embedding-Auslass-Test) nötig: \(ticketBNeeded)\n"

        try report.write(to: reportURL, atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: reportURL.path))
    }
}
