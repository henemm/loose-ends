import Foundation
import Testing
@testable import LooseEnds

/// Misst N für die lernende Wortliste (#233) auf dem FocusBlox-Korpus, Auslass-Test wie #131, mit der
/// festen Wortliste aus #232 als Regelspalte. Gegattert auf den Export: persönliche, gitignorierte
/// Daten, die es in CI nie gibt. Kein Modell, kein Gerät.
private func repoFile(_ relativePath: String) -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(relativePath)
}
private let focusBloxURL = MeasurementData.focusBloxCorpus
private let reportURL = repoFile("docs/reference/context-word-learning.md")

/// Eine Spalte des Berichts: wie oft der Arm die Kontextmenge exakt trifft, wie oft er überhaupt
/// etwas setzt und wie oft er dabei einen Kontext setzt, den die Aufgabe nicht trägt — der Fehler,
/// der zählt, weil leer besser ist als geraten.
private struct Arm {
    var correct: [Bool] = []
    var answered = 0
    var foreign = 0

    mutating func add(_ predicted: Set<String>, truth: Set<String>) {
        correct.append(!predicted.isEmpty && predicted == truth)
        if !predicted.isEmpty { answered += 1 }
        if !predicted.subtracting(truth).isEmpty { foreign += 1 }
    }

    var hits: Int { correct.filter { $0 }.count }
    var foreignRate: Double { answered == 0 ? 0 : Double(foreign) / Double(answered) }
}

private func percent(_ part: Int, of total: Int) -> String {
    String(format: "%.1f %%", total == 0 ? 0 : Double(part) / Double(total) * 100)
}

@Suite(.enabled(if: MeasurementData.exists(focusBloxURL), MeasurementData.corpusMissing))
struct ContextWordLearningReportTests {
    private static let nValues = [1, 2, 3, 4, 5]

    /// Der Textschlüssel, über den Dubletten erkannt werden — derselbe wie in der Gegenprobe von #131.
    private static func key(_ entry: Corpus.Entry) -> String {
        entry.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Ein Durchlauf über `probes`: Gelernt wird je Prüffall aus allen Aufgaben des Pools mit anderem
    /// Text — eine textgleiche Aufgabe wäre Wiedererkennung (#136), nicht Lernen.
    private static func run(probes: [Corpus.Entry], pool: [Corpus.Entry], names: [String], n: Int)
        -> (rule: Arm, learned: Arm, combined: Arm) {
        var rule = Arm(), learned = Arm(), combined = Arm()
        for probe in probes {
            guard let truth = LeaveOneOut.contextValue(probe) else { continue }
            let training = pool.filter { key($0) != key(probe) }.map {
                ContextWordLearning.Assignment(rawText: $0.text, contexts: Array(LeaveOneOut.contextValue($0) ?? []))
            }
            let list = ContextWordLearning.learn(from: training, minimumCount: n)
            let fromRule = Set(ContextWordRule.match(in: probe.text, available: names)?.value ?? [])
            let fromLearning = Set(ContextWordLearning.match(in: probe.text, learned: list))
            rule.add(fromRule, truth: truth)
            learned.add(fromLearning, truth: truth)
            combined.add(fromRule.union(fromLearning), truth: truth)
        }
        return (rule, learned, combined)
    }

    @Test("Schreibt den Bericht zur lernenden Wortliste und wählt N nach der vorab festgelegten Regel")
    func writesReport() throws {
        let entries = try JSONDecoder().decode([Corpus.Entry].self, from: Data(contentsOf: focusBloxURL))
        let pool = entries.filter { LeaveOneOut.contextValue($0) != nil }
        var seen: Set<String> = []
        let deduplicated = pool.filter { seen.insert(Self.key($0)).inserted }
        let names = Set(pool.flatMap { LeaveOneOut.contextValue($0) ?? [] }).sorted()
        let constant = LeaveOneOut.baselineClass(pool: deduplicated) { LeaveOneOut.contextValue($0) }
        let constantHits = deduplicated.filter { LeaveOneOut.contextValue($0) == constant }.count

        var table = ""
        var chosen: Int?
        var ruleColumn = Arm()
        for n in Self.nValues {
            let result = Self.run(probes: deduplicated, pool: pool, names: names, n: n)
            ruleColumn = result.rule
            let test = LeaveOneOut.mcNemar(ruleCorrect: result.combined.correct, baselineCorrect: result.rule.correct)
            let passes = result.combined.hits > result.rule.hits
                && result.combined.foreignRate <= result.rule.foreignRate
            if passes, chosen == nil { chosen = n }
            let total = deduplicated.count
            table += "| \(n) | \(percent(result.learned.hits, of: total)) | \(result.learned.answered) | \(result.learned.foreign) "
                + "| \(percent(result.combined.hits, of: total)) | \(result.combined.answered) | \(result.combined.foreign) "
                + "| \(test.b) | \(test.c) | \(String(format: "%.4f", test.pValue)) | \(passes ? "erfüllt" : "nicht erfüllt") |\n"
        }
        let total = deduplicated.count
        let verdict = chosen.map { "\($0)" } ?? "keines — die gelernte Liste geht nicht in den Produktpfad"

        let report = """
        # Lernende Wortliste: N gemessen (#233)

        Auslass-Test ohne Modell auf `docs/reference/focusblox-corpus.json` (\(entries.count) Aufgaben,
        \(pool.count) mit Kontext-Wahrheit, \(total) verschiedene Texte). Je Prüffall lernt
        `ContextWordLearning` aus allen Aufgaben mit **anderem** Text — Textdubletten erkennt schon die
        Wiedererkennung (#136), gemessen wird nur, was neu formulierte Aufgaben gewinnen. Bewertet wird die
        exakte Kontextmenge; „fremd" zählt Prüffälle, bei denen ein Kontext gesetzt wird, den die Aufgabe
        nicht trägt.

        ## Baselines

        | Arm | Treffer | gesetzt | fremd |
        |---|---|---|---|
        | Konstante (häufigste Menge) | \(percent(constantHits, of: total)) | \(total) | \(total - constantHits) |
        | Feste Wortliste #232 (Regelspalte) | \(percent(ruleColumn.hits, of: total)) | \(ruleColumn.answered) | \(ruleColumn.foreign) |

        ## Gelernt je N

        | N | gelernt allein: Treffer | gesetzt | fremd | fest + gelernt: Treffer | gesetzt | fremd | b | c | p-Wert | Regel |
        |---|---|---|---|---|---|---|---|---|---|---|
        \(table)
        b/c und p-Wert: zweiseitiger McNemar-Exakttest „fest + gelernt" gegen die feste Wortliste allein.

        ## Urteil nach der vorab festgelegten Regel

        Erfüllt heißt: „fest + gelernt" trifft mehr Aufgaben als die feste Wortliste allein, und der Anteil
        fremder Kontexte unter den gesetzten Aufgaben steigt nicht. Gewählt wird das kleinste erfüllende N.

        **Gewähltes N: \(verdict)**

        ## Grenzen dieser Zahlen

        - Der Korpus trägt gepflegte Titel als Rohtext, nicht diktierte Sätze.
        - Alle Kontexte im Korpus hat Henning in FocusBlox von Hand gesetzt; sie gelten hier als
          Zuordnungen mit Ursprung `user`.
        - Gelernt werden nur Wörter ab vier Zeichen; kurze Inhaltswörter („Tee", „Bad", „App") fehlen.
        - Bei \(total) Prüffällen kann ein realer Vorsprung an der Signifikanz scheitern; die Regel oben
          verlangt deshalb keinen p-Wert, sondern keinen Zuwachs an fremden Kontexten.

        """
        try report.write(to: reportURL, atomically: true, encoding: .utf8)

        let written = try String(contentsOf: reportURL, encoding: .utf8)
        #expect(written.contains("Feste Wortliste #232 (Regelspalte)"))
        #expect(written.contains("**Gewähltes N: "))
        #expect(table.split(separator: "\n").count == Self.nValues.count)
    }
}
