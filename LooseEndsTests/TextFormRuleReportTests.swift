import Foundation
import Testing
@testable import LooseEnds

/// Spike #70, Regelspalte: Ist die Textform egal? Derselbe Inhalt als getippter Satz, als Diktat, als
/// Mail-Auszug mit Signatur, Zitat und Haftungshinweis und als englischer Satz läuft durch die
/// Regeln, die heute Datum, Uhrzeit, Wichtigkeit, Dringlichkeit und Kontexte setzen (`DueDateRule`,
/// `ImportanceUrgencyRule`, `ContextWordRule`) und den Titel (`TitleRule`). Regeln vor dem Modell
/// (CLAUDE.md): Die Regelspalte ist die Baseline, die Modellspalte kommt vom iPhone dazu.
///
/// Ein Messbericht, keine Prüfung des Ergebnisses: Die Tests unten prüfen nur, dass der Korpus heil ist.
/// Der Bericht geht als Markdown nach stdout, zwischen `TEXTFORM-REPORT BEGIN` und `END`.
private struct TextFormCorpus: Decodable {
    struct Truth: Decodable {
        var due: String?
        var time: String?
        var importance: String?
        var urgency: String?
        var contexts: [String]
        var titleWords: [String]
    }

    struct Entry: Decodable {
        var id: String
        var forms: [String: String]
        var dictatedNumbers: String
        var truth: Truth
    }

    var reference: String
    var timeZone: String
    var entries: [Entry]

    static let formNames = ["typed", "dictated", "mail", "english"]

    static func load() throws -> TextFormCorpus {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Measurement/textform-corpus.json")
        return try JSONDecoder().decode(TextFormCorpus.self, from: Data(contentsOf: url))
    }
}

/// Was die Regeln aus einem Text lesen, in Zeichenketten, damit Wahrheit und Lesung vergleichbar sind.
private struct Reading: Equatable {
    var due: String?
    var time: String?
    var importance: String?
    var urgency: String?
    var contexts: String?

    /// Berechnet statt gespeichert: Ein statisches `let` mit KeyPaths ist unter Swift 6 nicht nebenläufigkeitssicher.
    static var fields: [(name: String, value: KeyPath<Reading, String?>)] {
        [("Tag", \.due), ("Uhrzeit", \.time), ("Wichtigkeit", \.importance),
         ("Dringlichkeit", \.urgency), ("Kontexte", \.contexts)]
    }
}

private struct Measurer {
    let reference: Date
    let calendar: Calendar
    let contextNames = ["Computer", "Phone", "Home", "Garden", "Errands", "Out and about"]

    struct SetupError: Error { var message: String }

    init(corpus: TextFormCorpus) throws {
        var calendar = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(identifier: corpus.timeZone) else { throw SetupError(message: "Zeitzone \(corpus.timeZone)") }
        calendar.timeZone = zone
        guard let reference = ISO8601DateFormatter().date(from: corpus.reference) else {
            throw SetupError(message: "Referenztag \(corpus.reference)")
        }
        self.calendar = calendar
        self.reference = reference
    }

    func day(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func clock(_ date: Date) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    func read(_ text: String) -> Reading {
        var reading = Reading()
        if let match = DueDateRule.match(in: text, reference: reference, calendar: calendar) {
            reading.due = day(match.guess.value)
            reading.time = match.hasTime ? clock(match.guess.value) : nil
        }
        reading.importance = ImportanceUrgencyRule.matchImportance(in: text).map { $0.value.rawValue }
        reading.urgency = ImportanceUrgencyRule.matchUrgency(in: text).map { $0.value.rawValue }
        let contexts = ContextWordRule.match(in: text, available: contextNames)?.value ?? []
        reading.contexts = contexts.isEmpty ? nil : contexts.sorted().joined(separator: ", ")
        return reading
    }

    func truth(_ truth: TextFormCorpus.Truth) -> Reading {
        Reading(
            due: truth.due, time: truth.time, importance: truth.importance, urgency: truth.urgency,
            contexts: truth.contexts.isEmpty ? nil : truth.contexts.sorted().joined(separator: ", ")
        )
    }

    /// Anteil der Schlüsselwörter des Inhalts, die im Titel stehen.
    func titleCoverage(_ words: [String], text: String) -> Double {
        let title = (TitleRule.title(from: text, reference: reference, calendar: calendar) ?? "").lowercased()
        guard !words.isEmpty else { return 1 }
        return Double(words.filter { title.contains($0) }.count) / Double(words.count)
    }

    func title(_ text: String) -> String {
        TitleRule.title(from: text, reference: reference, calendar: calendar) ?? ""
    }

    /// Der einfachste Zuschnitt einer Mail ohne Modell, nur zum Messen (#70, kein Produktcode): die
    /// Anrede fällt weg, und der Text endet vor dem Gruß, der Trennlinie, einem Zitat ("> …") oder einer
    /// Zeile "Am … schrieb …". Zeigt, ob Vorverarbeitung die Mail-Form rettet.
    func cutMail(_ text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        if let first = lines.first, first.hasSuffix(","), first.split(separator: " ").count <= 3 { lines.removeFirst() }
        var kept: [String] = []
        for line in lines {
            let lowered = line.lowercased().trimmingCharacters(in: .whitespaces)
            let isStop = lowered.hasPrefix("viele grüße") || lowered.hasPrefix("mit freundlichen grüßen")
                || lowered.hasPrefix("------") || lowered.hasPrefix(">")
                || (lowered.hasPrefix("am ") && lowered.contains(" schrieb "))
            if isStop { break }
            kept.append(line)
        }
        return kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private func percent(_ part: Int, of total: Int) -> String {
    String(format: "%.0f %%", total == 0 ? 0 : Double(part) / Double(total) * 100)
}

struct TextFormRuleReportTests {
    @Test("Der Korpus hat 40 Inhalte in je vier Formen, gültige Wahrheit und eine Mail mit Rauschen")
    func corpusIsWellFormed() throws {
        let corpus = try TextFormCorpus.load()
        let measurer = try Measurer(corpus: corpus)

        #expect(corpus.entries.count == 40)
        #expect(Set(corpus.entries.map(\.id)).count == 40)
        for entry in corpus.entries {
            #expect(Set(entry.forms.keys) == Set(TextFormCorpus.formNames), "\(entry.id): Formen")
            #expect(entry.forms.values.allSatisfy { !$0.isEmpty }, "\(entry.id): leere Form")
            #expect((entry.forms["mail"] ?? "").count >= 600, "\(entry.id): Mail ohne Rauschen")
            #expect(!entry.truth.titleWords.isEmpty, "\(entry.id): Schlüsselwörter")
            #expect(["digits", "words", "none"].contains(entry.dictatedNumbers))
            if let due = entry.truth.due {
                #expect(ISO8601DateFormatter().date(from: due + "T00:00:00+02:00") != nil, "\(entry.id): Datum")
            }
            if entry.truth.time != nil { #expect(entry.truth.due != nil, "\(entry.id): Uhrzeit ohne Tag") }
        }
        #expect(measurer.day(measurer.reference) == "2026-10-07")
    }

    @Test("Misst die Regelspalte über die vier Formen und schreibt den Bericht nach stdout")
    func printsReport() throws {
        let corpus = try TextFormCorpus.load()
        let measurer = try Measurer(corpus: corpus)
        // Die vier Formen des Korpus plus der Zuschnitt der Mail als fünfte Spalte.
        let forms = ["typed", "dictated", "mail", "mailCut", "english"]
        func text(_ entry: TextFormCorpus.Entry, _ form: String) -> String {
            form == "mailCut" ? measurer.cutMail(entry.forms["mail"] ?? "") : (entry.forms[form] ?? "")
        }
        let readings: [String: [Reading]] = Dictionary(uniqueKeysWithValues: forms.map { form in
            (form, corpus.entries.map { measurer.read(text($0, form)) })
        })
        let truths = corpus.entries.map { measurer.truth($0.truth) }
        let typed = try #require(readings["typed"])

        var lines: [String] = ["TEXTFORM-REPORT BEGIN", ""]
        lines.append("Referenztag \(corpus.reference), \(corpus.entries.count) Inhalte × \(forms.count) Formen.")
        lines += ["", "### Treffer gegen die Wahrheit (richtig / verpasst / falsch / erfunden)", ""]
        lines.append("| Feld | " + forms.joined(separator: " | ") + " |")
        lines.append("|---|" + forms.map { _ in "---|" }.joined())
        for (name, path) in Reading.fields {
            var cells: [String] = []
            for form in forms {
                var right = 0, missed = 0, wrong = 0, invented = 0
                for (reading, truth) in zip(readings[form] ?? [], truths) {
                    let got = reading[keyPath: path], want = truth[keyPath: path]
                    if got == want { right += 1 }
                    else if want != nil && got == nil { missed += 1 }
                    else if want != nil { wrong += 1 }
                    else { invented += 1 }
                }
                cells.append("\(right) / \(missed) / \(wrong) / \(invented)")
            }
            lines.append("| \(name) | " + cells.joined(separator: " | ") + " |")
        }

        lines += ["", "### Übereinstimmung mit dem getippten Satz (gleiche Lesung, auch gleich leer)", ""]
        lines.append("| Feld | dictated | mail | mailCut | english |")
        lines.append("|---|---|---|---|---|")
        for (name, path) in Reading.fields {
            var cells: [String] = []
            for form in ["dictated", "mail", "mailCut", "english"] {
                let same = zip(readings[form] ?? [], typed).filter { $0.0[keyPath: path] == $0.1[keyPath: path] }.count
                cells.append("\(same)/\(corpus.entries.count) (\(percent(same, of: corpus.entries.count)))")
            }
            lines.append("| \(name) | " + cells.joined(separator: " | ") + " |")
        }

        // Diktat nach Zahlenform: ausgeschriebene Zahlen ("neunzehn uhr") sind der Verdachtsfall.
        lines += ["", "### Diktat nach Zahlenform (Tag und Uhrzeit gegen die Wahrheit)", ""]
        for numbers in ["digits", "words", "none"] {
            let rows = zip(corpus.entries, readings["dictated"] ?? []).enumerated()
                .filter { $0.element.0.dictatedNumbers == numbers }
            let dueRight = rows.filter { $0.element.1.due == truths[$0.offset].due }.count
            let timeRight = rows.filter { $0.element.1.time == truths[$0.offset].time }.count
            lines.append("- \(numbers): \(rows.count) Inhalte, Tag richtig \(dueRight), Uhrzeit richtig \(timeRight)")
        }

        lines += ["", "### Titel (Anteil der Schlüsselwörter im Titel; beginnt mit Gruß; nur deutsche Formen, die Schlüsselwörter sind deutsch)", ""]
        for form in ["typed", "dictated", "mail", "mailCut"] {
            let coverage = corpus.entries.map { measurer.titleCoverage($0.truth.titleWords, text: text($0, form)) }
            let mean = coverage.reduce(0, +) / Double(coverage.count)
            let greeting = corpus.entries.filter { measurer.title(text($0, form)).lowercased().hasPrefix("hallo") }.count
            lines.append("- \(form): \(String(format: "%.0f", mean * 100)) % der Schlüsselwörter, \(greeting) Titel beginnen mit „Hallo“")
        }

        lines += ["", "### Mail: Felder aus dem Rauschen (Wahrheit leer, Regel setzt trotzdem)", ""]
        let mailReadings = readings["mail"] ?? []
        for (entry, reading) in zip(corpus.entries, mailReadings) {
            let truth = measurer.truth(entry.truth)
            for (name, path) in Reading.fields where truth[keyPath: path] == nil && reading[keyPath: path] != nil {
                lines.append("- \(entry.id) \(name): \(reading[keyPath: path] ?? "")")
            }
        }

        lines += ["", "### Mail nach dem Zuschnitt: Felder aus dem Rauschen", ""]
        let cutReadings = readings["mailCut"] ?? []
        var leftover = 0
        for (entry, reading) in zip(corpus.entries, cutReadings) {
            let truth = measurer.truth(entry.truth)
            for (name, path) in Reading.fields where truth[keyPath: path] == nil && reading[keyPath: path] != nil {
                leftover += 1
                lines.append("- \(entry.id) \(name): \(reading[keyPath: path] ?? "")")
            }
        }
        lines.append("Zusammen \(leftover) erfundene Felder nach dem Zuschnitt.")

        lines += ["", "### Abweichungen im getippten Satz (Prüfung der Wahrheit)", ""]
        for (entry, reading) in zip(corpus.entries, typed) {
            let truth = measurer.truth(entry.truth)
            for (name, path) in Reading.fields where reading[keyPath: path] != truth[keyPath: path] {
                lines.append("- \(entry.id) \(name): Regel \(reading[keyPath: path] ?? "–"), Wahrheit \(truth[keyPath: path] ?? "–")")
            }
        }
        lines += ["", "TEXTFORM-REPORT END"]
        print(lines.joined(separator: "\n"))
    }
}
