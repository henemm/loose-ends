import Foundation
import Testing
@testable import LooseEnds

/// Where the pulled result files live. Outside the suite on purpose: a `@Suite` condition may not
/// reference the type it annotates.
enum MeasurementFiles {
    static var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    static var runs: [URL] {
        let folder = repositoryRoot.appendingPathComponent("Measurement/results")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}

/// Turns what the Lab app measured on the iPhone into the report for Issue #67.
///
/// Scoring happens here, on the Mac, and never on the phone: the phone only records what the
/// model answered. So the numbers can be recomputed, and the rules sharpened, without asking
/// Henning for his device again. Disabled until a run has actually been fetched.
@Suite(.enabled(if: !MeasurementFiles.runs.isEmpty))
struct DateTitleReportTests {

    struct Tally {
        var total = 0
        var hit = 0
        var empty = 0
        var misses: [String] = []
        var share: Double { total == 0 ? 0 : Double(hit) / Double(total) }
        mutating func record(hit isHit: Bool, empty isEmpty: Bool = false, miss: String = "") {
            total += 1
            if isHit { hit += 1; return }
            if isEmpty { empty += 1 }
            if !miss.isEmpty { misses.append(miss) }
        }
    }

    /// One sentence form's share of every criterion (#82): a form may be fine on dates and still
    /// lose entities, so each criterion gets its own tally.
    struct FormTally {
        var date = Tally()
        var invented = Tally()
        var facts = Tally()
        var sentences: Int { date.total + invented.total }
    }

    struct Report {
        var model = Tally()
        var parser = Tally()
        var invented = Tally()
        var parserInvented = Tally()
        var time = Tally()
        var entities = Tally()
        var facts = Tally()
        var foreign = Tally()
        var byRule: [String: Tally] = [:]
        var byCondition: [String: Tally] = [:]
        var byForm: [String: FormTally] = [:]
        var seconds: [Double] = []
        var failures = 0
        var throttled = 0
    }

    @Test("Bericht aus den Messläufen des iPhones")
    func buildReport() throws {
        let corpus = try Corpus.load()
        let byID = Dictionary(uniqueKeysWithValues: corpus.map { ($0.id, $0) })
        let runs = try MeasurementFiles.runs.map { url in
            try MeasurementStore.coder.decoder.decode(MeasurementRun.self, from: Data(contentsOf: url))
        }
        var report = Report()
        let calendar = Calendar.current

        for result in runs.flatMap(\.results) {
            guard let entry = byID[result.entryID], entry.countsForDateMeasurement else { continue }
            guard result.succeeded else {
                report.failures += 1
                if result.wasRateLimited { report.throttled += 1 }
                continue
            }
            report.seconds.append(result.seconds)
            Self.scoreDate(entry, result, calendar: calendar, into: &report)
            Self.scoreTitle(entry, result, into: &report)
        }
        Self.scoreParser(corpus, calendar: calendar, into: &report)

        let markdown = Self.markdown(report, runs: runs, corpus: corpus)
        let destination = MeasurementFiles.repositoryRoot.appendingPathComponent("docs/reference/date-title-fidelity.md")
        try markdown.write(to: destination, atomically: true, encoding: .utf8)
        #expect(report.model.total + report.invented.total > 0, "kein einziger auswertbarer Satz")
    }

    // MARK: - Scoring

    static func scoreDate(_ entry: Corpus.Entry, _ result: MeasurementResult, calendar: Calendar, into report: inout Report) {
        let got = result.dueDate.map { calendar.startOfDay(for: $0) }
        if let expectation = entry.date {
            let accepted = expectation.acceptedDays(reference: result.capturedAt, calendar: calendar)
            let hit = got.map(accepted.contains) ?? false
            let miss = "`\(entry.text)` → \(day(got, calendar)) statt \(day(accepted.min(), calendar))"
            report.model.record(hit: hit, empty: got == nil, miss: miss)
            report.byRule[ruleName(expectation), default: Tally()].record(hit: hit, empty: got == nil)
            report.byCondition[result.conditions.summary, default: Tally()].record(hit: hit)
            report.byForm[entry.form, default: FormTally()].date.record(hit: hit)
        } else {
            report.invented.record(hit: got == nil, miss: "`\(entry.text)` → \(day(got, calendar))")
            report.byForm[entry.form, default: FormTally()].invented.record(hit: got == nil)
        }
        if let expected = entry.time {
            let got = result.dueHasTime ? result.dueDate.map { time($0, calendar) } : nil
            report.time.record(hit: got == expected, empty: got == nil, miss: "`\(entry.text)` → \(got ?? "–") statt \(expected)")
        }
    }

    static func scoreTitle(_ entry: Corpus.Entry, _ result: MeasurementResult, into report: inout Report) {
        guard let title = result.title else { return }
        for entity in entry.entities {
            report.entities.record(hit: TitleCheck.preserves(entity: entity, in: title),
                                   miss: "`\(entry.text)` → „\(title)“ ohne \(entity)")
        }
        let invented = TitleCheck.inventedNumbers(title: title, rawText: entry.text)
            + TitleCheck.alteredNames(title: title, rawText: entry.text, people: entry.people)
        report.facts.record(hit: invented.isEmpty,
                            miss: "`\(entry.text)` → „\(title)“ erfindet \(invented.joined(separator: ", "))")
        report.byForm[entry.form, default: FormTally()].facts.record(hit: invented.isEmpty)
        report.foreign.record(hit: TitleCheck.foreignWords(title: title, rawText: entry.text).isEmpty)
    }

    /// The deterministic alternative from the issue, on the same sentences. `NSDataDetector` always
    /// resolves against the current day, so it is scored against today — which is as valid as any
    /// other day, because it never sees a capture date.
    static func scoreParser(_ corpus: [Corpus.Entry], calendar: Calendar, into report: inout Report) {
        let today = calendar.startOfDay(for: Date())
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        for entry in corpus where entry.countsForDateMeasurement {
            let match = detector?.firstMatch(in: entry.text, range: NSRange(entry.text.startIndex..., in: entry.text))
            let got = match?.date.map { calendar.startOfDay(for: $0) }
            if let expectation = entry.date {
                let accepted = expectation.acceptedDays(reference: today, calendar: calendar)
                report.parser.record(hit: got.map(accepted.contains) ?? false, empty: got == nil)
            } else {
                report.parserInvented.record(hit: got == nil, miss: "`\(entry.text)` → \(day(got, calendar))")
            }
        }
    }

    // MARK: - Report

    static func markdown(_ report: Report, runs: [MeasurementRun], corpus: [Corpus.Entry]) -> String {
        [head(report, runs: runs, corpus: corpus),
         dateSection(report),
         conditionSection(report),
         formSection(report),
         titleSection(report),
         verdictSection(report),
         missesSection(report)].joined(separator: "\n\n")
    }

    static func head(_ report: Report, runs: [MeasurementRun], corpus: [Corpus.Entry]) -> String {
        let seconds = report.seconds.isEmpty ? 0 : report.seconds.reduce(0, +) / Double(report.seconds.count)
        let devices = Set(runs.flatMap { $0.results.map(\.conditions.device) }).sorted().joined(separator: ", ")
        let systems = Set(runs.flatMap { $0.results.map(\.conditions.systemVersion) }).sorted().joined(separator: ", ")
        let days = Set(runs.flatMap { $0.results.map { day($0.capturedAt, Calendar.current) } }).sorted()
        return """
        # Treue von Datum und Titel (Issue #67)

        | | |
        |---|---|
        | Gerät | \(devices.isEmpty ? "–" : devices), iOS \(systems) |
        | Messtage | \(days.joined(separator: ", ")) |
        | Korpus | \(corpus.count) Sätze; ausgewertet: \(report.model.total) mit Datum, \(report.invented.total) ohne Datum als Kontrolle |
        | Fehlversuche | \(report.failures), davon gedrosselt: \(report.throttled) |
        | Sekunden je Satz | \(String(format: "%.1f", seconds)) |

        Gemessen hat die Labor-App auf dem iPhone, in Scheiben über mehrere Sitzungen. Jeder Satz
        wird gegen den Tag ausgewertet, an dem er gemessen wurde; mehrdeutige Formulierungen
        („am Wochenende", „nächsten Freitag") lassen mehrere Tage gelten. `NSDataDetector` ist die
        deterministische Alternative aus dem Issue, auf denselben Sätzen.
        """
    }

    static func dateSection(_ report: Report) -> String {
        var lines = [
            "## Datum",
            "",
            "| Messung | Modell | NSDataDetector |",
            "|---|---|---|",
            "| Exakt getroffen | \(percent(report.model.share)) von \(report.model.total) | \(percent(report.parser.share)) von \(report.parser.total) |",
            "| Feld leer gelassen statt geraten | \(report.model.empty) | \(report.parser.empty) |",
            "| Erfundene Daten bei Sätzen ohne Datum | \(inverse(report.invented)) | \(inverse(report.parserInvented)) |",
            "",
            "### Nach Art des Ausdrucks",
            "",
            "| Ausdruck | Sätze | Modell exakt | Leer gelassen |",
            "|---|---|---|---|",
        ]
        for (rule, tally) in report.byRule.sorted(by: { $0.value.share < $1.value.share }) {
            lines.append("| \(rule) | \(tally.total) | \(percent(tally.share)) | \(tally.empty) |")
        }
        if report.time.total > 0 {
            lines += ["", "**Uhrzeit:** \(percent(report.time.share)) exakt bei \(report.time.total) Sätzen mit Uhrzeit."]
        }
        return lines.joined(separator: "\n")
    }

    /// The answer to "was this measured under realistic conditions?" — not argued, measured.
    static func conditionSection(_ report: Report) -> String {
        var lines = ["## Nach Bedingung gemessen", "",
                     "| Bedingung | Sätze mit Datum | Exakt |", "|---|---|---|"]
        for (condition, tally) in report.byCondition.sorted(by: { $0.key < $1.key }) {
            lines.append("| \(condition) | \(tally.total) | \(percent(tally.share)) |")
        }
        lines += ["", "Laufen die Zeilen auseinander, hängt die Qualität an Vordergrund, Strom oder Wärme — dann gilt die Gesamtzahl oben nicht."]
        return lines.joined(separator: "\n")
    }

    /// The answer to "does the model only work on my sentences?" (#82): every criterion, split by
    /// the form the note was written in. A dash means the form has no sentence of that kind.
    static func formSection(_ report: Report) -> String {
        var lines = ["## Nach Bauform", "",
                     "| Bauform | Sätze | Datum exakt | Datum erfunden | Titel ohne erfundene Fakten |",
                     "|---|---|---|---|---|"]
        for (form, tally) in report.byForm.sorted(by: { $0.key < $1.key }) {
            let date = tally.date.total == 0 ? "–" : "\(percent(tally.date.share)) von \(tally.date.total)"
            let facts = tally.facts.total == 0 ? "–" : percent(tally.facts.share)
            lines.append("| \(form) | \(tally.sentences) | \(date) | \(inverse(tally.invented)) | \(facts) |")
        }
        lines += ["", "„standard“ ist die Form der ersten 203 Sätze (Zeitangabe, Objekt, Verb); die übrigen sind Hennings Formen aus seinen FocusBlox-Rohsätzen."]
        return lines.joined(separator: "\n")
    }

    static func titleSection(_ report: Report) -> String {
        """
        ## Titel

        | Messung | Anteil |
        |---|---|
        | Entitäten aus dem Rohtext erhalten (\(report.entities.total) geprüft) | \(percent(report.entities.share)) |
        | Titel ohne erfundene Fakten (Zahlen, verdrehte Namen) | \(percent(report.facts.share)) von \(report.facts.total) |
        | Titel ganz ohne Fremdwörter | \(percent(report.foreign.share)) |

        Erfundene Fakten sind das Abbruchkriterium. Fremdwörter zeigen nur, wie stark das Modell
        umformuliert; umformulieren ist erlaubt, solange nichts erfunden wird.
        """
    }

    static func verdictSection(_ report: Report) -> String {
        // A criterion nobody has measured yet is open, not held and not broken: a share of an
        // empty tally is 0, and "1 - 0" would otherwise read as 100 % invented dates.
        func row(_ name: String, _ limit: String, _ tally: Tally, passes: (Double) -> Bool, inverted: Bool = false) -> String {
            guard tally.total > 0 else { return "| \(name) | \(limit) | noch nicht gemessen | offen |" }
            let value = inverted ? 1 - tally.share : tally.share
            return "| \(name) | \(limit) | \(percent(value)) | \(passes(value) ? "gehalten" : "**gerissen**") |"
        }
        return """
        ## Abbruchkriterien aus #67

        | Kriterium | Grenze | Gemessen | Ergebnis |
        |---|---|---|---|
        \(row("Datum exakt", "≥ 95 %", report.model, passes: { $0 >= 0.95 }))
        \(row("Erfundene Daten", "≤ 2 %", report.invented, passes: { $0 <= 0.02 }, inverted: true))
        \(row("Titel mit erfundenen Fakten", "≤ 2 %", report.facts, passes: { $0 <= 0.02 }, inverted: true))
        """
    }

    static func missesSection(_ report: Report) -> String {
        func block(_ title: String, _ items: [String]) -> String {
            items.isEmpty ? "" : "### \(title) (\(items.count))\n\n" + items.prefix(25).map { "- \($0)" }.joined(separator: "\n")
        }
        return (["## Was danebenging",
                 block("Falsches Datum", report.model.misses),
                 block("Datum erfunden", report.invented.misses),
                 block("Falsche Uhrzeit", report.time.misses),
                 block("Entität verloren", report.entities.misses),
                 block("Fakt erfunden", report.facts.misses)].filter { !$0.isEmpty }).joined(separator: "\n\n")
    }

    // MARK: - Helpers

    static func percent(_ value: Double) -> String { String(format: "%.1f %%", value * 100) }

    /// The share of misses in a tally that counts hits, or a plain "not measured" for an empty one.
    static func inverse(_ tally: Tally) -> String {
        tally.total == 0 ? "noch nicht gemessen" : "\(percent(1 - tally.share)) von \(tally.total)"
    }

    static func day(_ date: Date?, _ calendar: Calendar) -> String {
        guard let date else { return "–" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func time(_ date: Date, _ calendar: Calendar) -> String {
        String(format: "%02d:%02d", calendar.component(.hour, from: date), calendar.component(.minute, from: date))
    }

    static func ruleName(_ expectation: Corpus.DateExpectation) -> String {
        switch expectation {
        case .offsetDays: return "in N Tagen / morgen"
        case .weekday: return "Wochentag"
        case .weekdayNextWeek: return "nächste Woche <Tag>"
        case .weekdayEitherNext: return "nächster <Tag>"
        case .endOfMonth: return "Monatsende"
        case .dayOfMonth: return "bis zum N."
        case .weekend: return "Wochenende"
        case .monthRange: return "nächster Monat"
        case .dayAndMonth: return "festes Datum"
        }
    }
}

/// The report must split every rate by sentence form (#82), the way it splits dates by condition.
/// Checked on a synthetic report, so it runs before any run was fetched.
@Suite("Bericht nach Bauform")
struct DateTitleFormSectionTests {
    @Test("Jede Bauform bekommt eine Zeile mit Datum, erfundenem Datum und Titel")
    func formSection() {
        var report = DateTitleReportTests.Report()
        report.byForm["stichwort", default: .init()].date.record(hit: true)
        report.byForm["stichwort", default: .init()].date.record(hit: false)
        report.byForm["stichwort", default: .init()].invented.record(hit: true)
        report.byForm["stichwort", default: .init()].facts.record(hit: true)
        report.byForm["frage", default: .init()].invented.record(hit: false)
        report.byForm["frage", default: .init()].facts.record(hit: false)

        let section = DateTitleReportTests.formSection(report)
        #expect(section.hasPrefix("## Nach Bauform"))
        #expect(section.contains("| stichwort | 3 | 50.0 % von 2 | 0.0 % von 1 | 100.0 % |"))
        #expect(section.contains("| frage | 1 | – | 100.0 % von 1 | 0.0 % |"))
        #expect(DateTitleReportTests.markdown(report, runs: [], corpus: []).contains("## Nach Bauform"))
    }
}
