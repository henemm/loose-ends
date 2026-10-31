import Foundation
import Testing
@testable import LooseEnds

/// Goldene Regelausgabe (#764, Schnitt 0 von Epic #750): die Ausgabe jeder Wortregel über jeden Korpussatz,
/// eingefroren in `Fixtures/rule-golden.json`. Die Korpus-Abnahmen sind Schwellen; ein verlorenes Wort, das drei
/// Sätze kostet, bliebe darunter unsichtbar. Hier gilt Gleichheit, ohne Schwelle und ohne Toleranz.
/// Ändert sich die Ausgabe absichtlich: `LOOSEENDS_UPDATE_GOLDEN=1 ./scripts/sim.sh sim-unit RuleGoldenTests`
/// schreibt die Datei neu und endet absichtlich rot; den Diff prüfen, den Schalter entfernen.
@Suite("Goldene Regelausgabe über alle Korpora")
struct RuleGoldenTests {
    /// Feste Zeilenzahl, damit ein stillschweigend kleinerer Korpus auffällt (0 = Fixture noch nicht erzeugt).
    static let expectedRows = 0

    static let fields = ["date", "time", "duration", "importance", "urgency", "place", "contexts", "title"]

    static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/rule-golden.json")
    }

    private struct TextFormFile: Decodable {
        struct Content: Decodable { var id: String; var forms: [String: String] }
        var entries: [Content]
    }

    /// Alle Sätze: Datum/Titel-Korpus (`entry.id`), Textform-Korpus (`<Inhalt>.<Form>`), Konvention (`conv.<Muster>.<n>`).
    static func sentences() throws -> [String: String] {
        var all: [String: String] = [:]
        for entry in try Corpus.load() { all[entry.id] = entry.text }
        let measurement = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Measurement/textform-corpus.json")
        for content in try JSONDecoder().decode(TextFormFile.self, from: Data(contentsOf: measurement)).entries {
            for (form, text) in content.forms { all["\(content.id).\(form)"] = text }
        }
        for pattern in try ConventionCorpus.load() {
            for (index, correction) in pattern.corrections.enumerated() {
                all["conv.\(pattern.id).c\(index)"] = correction.text
            }
            all["conv.\(pattern.id).probe"] = pattern.probe.text
        }
        return all
    }

    static func row(for text: String) -> [String: String] {
        let calendar = CorpusTests.calendar
        let reference = CorpusTests.reference
        let dash = "–"
        let day = DateFormatter()
        day.calendar = calendar
        day.timeZone = calendar.timeZone
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let available = ["Computer", "Phone", "Home", "Garden", "Errands", "Out and about",
                         "Telefon", "Haus", "Garten", "Besorgung", "Unterwegs"]
        return [
            "date": DateExpressionParser(calendar: calendar).date(in: text, reference: reference).map(day.string(from:)) ?? dash,
            "time": TimeExpressionParser().time(in: text).map { String(format: "%02d:%02d", $0.hour, $0.minute) } ?? dash,
            "duration": DurationRule.match(in: text)?.guess.value.rawValue ?? dash,
            "importance": ImportanceUrgencyRule.matchImportance(in: text)?.value.rawValue ?? dash,
            "urgency": ImportanceUrgencyRule.matchUrgency(in: text)?.value.rawValue ?? dash,
            "place": PlaceWordRule.slot(in: text)?.rawValue ?? dash,
            "contexts": ContextWordRule.match(in: text, available: available).map { $0.value.joined(separator: ", ") } ?? dash,
            "title": TitleRule.title(from: text, reference: reference, calendar: calendar) ?? dash,
        ]
    }

    @Test("Jede Regel liefert über jeden Korpussatz dieselbe Ausgabe wie die Fixture")
    func matchesFixture() throws {
        var rows: [String: [String: String]] = [:]
        for (id, text) in try Self.sentences() { rows[id] = Self.row(for: text) }

        let update = ProcessInfo.processInfo.environment["LOOSEENDS_UPDATE_GOLDEN"] == "1"
        let stored: [String: [String: String]]? = (try? Data(contentsOf: Self.fixtureURL))
            .flatMap { try? JSONDecoder().decode([String: [String: String]].self, from: $0) }

        if update || stored == nil {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            // Eine Zeile je Satz im Log (CI kopiert `*-REPORT`-Blöcke in den Job), damit die Fixture daraus gebaut werden kann.
            print("RULEGOLDEN-REPORT BEGIN")
            for id in rows.keys.sorted() {
                let line = String(decoding: try encoder.encode(["id": id].merging(rows[id] ?? [:]) { a, _ in a }), as: UTF8.self)
                print("RULE-GOLDEN-ROW \(line)")
            }
            print("RULEGOLDEN-REPORT END")
            if update {
                let pretty = JSONEncoder()
                pretty.outputFormatting = [.sortedKeys, .prettyPrinted]
                try pretty.encode(rows).write(to: Self.fixtureURL)
            }
            Issue.record("Fixture \(update ? "neu geschrieben" : "fehlt"): \(rows.count) Zeilen. Diff prüfen und den Schalter entfernen.")
            return
        }

        let golden = try #require(stored)
        if Self.expectedRows > 0 { #expect(rows.count == Self.expectedRows, "Korpus hat \(rows.count) Sätze statt \(Self.expectedRows)") }
        #expect(golden.count == rows.count, "Fixture hat \(golden.count) Zeilen, der Korpus \(rows.count)")
        var diffs: [String] = []
        for id in rows.keys.sorted() {
            guard let old = golden[id] else { diffs.append("\(id): nicht in der Fixture"); continue }
            for field in Self.fields where old[field] != rows[id]?[field] {
                diffs.append("\(id): \(field) war \(old[field] ?? "?") → ist \(rows[id]?[field] ?? "?")")
            }
        }
        let shown = diffs.prefix(20).joined(separator: "\n")
        #expect(diffs.isEmpty, "\(diffs.count) Abweichungen, erste 20:\n\(shown)")
    }
}
