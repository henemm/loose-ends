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
///
/// The report is reproducible (#99, #148): a fixed calendar (Europe/Berlin) and the fixed reference
/// day of `CorpusTests` instead of today, so CI (UTC) and the Mac write the same file on any day. A
/// report that differs from the checked-in one fails the run: the numbers changed, and that has to
/// be looked at and committed, not discovered by chance in the next diff. The fresh report goes to
/// stdout between `DATE-TITLE-REPORT BEGIN` and `END`, which CI copies into its log.
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
        var invented = Tally()
        var time = Tally()
        /// The rule parser of #92, measured on the same sentences as the two columns above.
        var ruleParser = Tally()
        var ruleParserInvented = Tally()
        var ruleParserTime = Tally()
        var entities = Tally()
        var facts = Tally()
        var foreign = Tally()
        var byRule: [String: Tally] = [:]
        var ruleParserByRule: [String: Tally] = [:]
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
        let calendar = CorpusTests.calendar

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
        Self.scoreRuleParser(corpus, calendar: calendar, reference: CorpusTests.reference, into: &report)

        let markdown = Self.markdown(report, runs: runs, corpus: corpus)
        print(["DATE-TITLE-REPORT BEGIN", "", markdown, "", "DATE-TITLE-REPORT END"].joined(separator: "\n"))
        let destination = MeasurementFiles.repositoryRoot.appendingPathComponent("docs/reference/date-title-fidelity.md")
        let committed = try String(contentsOf: destination, encoding: .utf8)
        try markdown.write(to: destination, atomically: true, encoding: .utf8)
        #expect(report.model.total + report.invented.total > 0, "kein einziger auswertbarer Satz")
        #expect(committed == markdown,
                "Der Bericht weicht vom eingecheckten ab: Die Zahlen haben sich geändert. Neuen Stand prüfen und date-title-fidelity.md mitcommitten.")
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

    /// `NSDataDetector`, the deterministic alternative from #67, resolves against the real clock and
    /// takes no reference day, so its column cannot be reproduced (#99, #148): on the same sentences
    /// it scored between 65.5 % and 68.3 % exact, depending on the weekday of the run. The column is
    /// frozen at the last checked-in run and no longer recomputed; since #95 the rule parser sets the
    /// due date, the detector is a historical comparison only.
    enum FrozenDetector {
        static let measured = "2026-09-25"
        static let exact = "67.6 % von 139"
        static let empty = "41"
        static let invented = "0.0 % von 172"
    }

    /// The rule parser from #92 on the whole corpus, scored like the `NSDataDetector` column:
    /// against the fixed reference day of `CorpusTests` (#148). Times are scored on every sentence that has one,
    /// repetitions included — "jeden Tag um 7 Uhr" carries a time even though it carries no date.
    static func scoreRuleParser(_ corpus: [Corpus.Entry], calendar: Calendar, reference: Date, into report: inout Report) {
        let parser = DateExpressionParser(calendar: calendar)
        let clock = TimeExpressionParser()
        for entry in corpus {
            if entry.countsForDateMeasurement {
                let got = parser.date(in: entry.text, reference: reference)
                if let expectation = entry.date {
                    let accepted = expectation.acceptedDays(reference: reference, calendar: calendar)
                    let hit = got.map(accepted.contains) ?? false
                    let miss = "`\(entry.text)` \u{2192} \(day(got, calendar)) statt \(day(accepted.min(), calendar)) \u{b7} \(ruleName(expectation))"
                    report.ruleParser.record(hit: hit, empty: got == nil, miss: miss)
                    report.ruleParserByRule[ruleName(expectation), default: Tally()].record(hit: hit, empty: got == nil)
                } else {
                    report.ruleParserInvented.record(hit: got == nil, miss: "`\(entry.text)` \u{2192} \(day(got, calendar))")
                }
            }
            guard let expected = entry.time else { continue }
            let got = clock.time(in: entry.text).map { String(format: "%02d:%02d", $0.hour, $0.minute) }
            report.ruleParserTime.record(hit: got == expected, empty: got == nil,
                                         miss: "`\(entry.text)` \u{2192} \(got ?? "\u{2013}") statt \(expected)")
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
        let days = Set(runs.flatMap { $0.results.map { day($0.capturedAt, CorpusTests.calendar) } }).sorted()
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
        („am Wochenende", „nächsten Freitag") lassen mehrere Tage gelten. Der Regelparser rechnet
        gegen den festen Bezugstag Do 12.03.2026 (Europe/Berlin), damit der Bericht an jedem Tag
        gleich ausfällt (#99, #148); bis dahin rechnete er gegen den Tag des Laufs, daher die
        anderen Daten unter „Was danebenging“. `NSDataDetector` ist die deterministische
        Alternative aus dem Issue, auf denselben Sätzen.
        """
    }

    static func dateSection(_ report: Report) -> String {
        var lines = [
            "## Datum",
            "",
            "| Messung | Modell | NSDataDetector | Regelparser |",
            "|---|---|---|---|",
            "| Exakt getroffen | \(percent(report.model.share)) von \(report.model.total) | \(FrozenDetector.exact) | \(percent(report.ruleParser.share)) von \(report.ruleParser.total) |",
            "| Feld leer gelassen statt geraten | \(report.model.empty) | \(FrozenDetector.empty) | \(report.ruleParser.empty) |",
            "| Erfundene Daten bei Sätzen ohne Datum | \(inverse(report.invented)) | \(FrozenDetector.invented) | \(inverse(report.ruleParserInvented)) |",
            "",
            "`NSDataDetector` rechnet immer gegen die echte Uhr und lässt sich auf keinen Bezugstag festlegen; je nach Wochentag des Laufs traf er 65.5 % bis 68.3 %. Die Spalte ist der eingefrorene Stand vom \(FrozenDetector.measured) und wird nicht neu berechnet (#148).",
            "",
            "### Nach Art des Ausdrucks",
            "",
            "| Ausdruck | Sätze | Modell exakt | Leer gelassen | Regelparser exakt |",
            "|---|---|---|---|---|",
        ]
        // Rules the model never answered still get their row from the rule parser, which runs over
        // the whole corpus: a missing row would read as "nothing to see here".
        let rules = Set(report.byRule.keys).union(report.ruleParserByRule.keys)
        for rule in rules.sorted(by: { (report.byRule[$0]?.share ?? 0, $0) < (report.byRule[$1]?.share ?? 0, $1) }) {
            let tally = report.byRule[rule] ?? Tally()
            let ruleTally = report.ruleParserByRule[rule]
            let parsed = ruleTally.map { percent($0.share) } ?? "–"
            lines.append("| \(rule) | \(tally.total) | \(percent(tally.share)) | \(tally.empty) | \(parsed) |")
        }
        if report.time.total > 0 {
            lines += ["", "**Uhrzeit:** \(percent(report.time.share)) exakt bei \(report.time.total) Sätzen mit Uhrzeit."]
        }
        if report.ruleParserTime.total > 0 {
            lines += ["", "**Uhrzeit Regelparser:** \(percent(report.ruleParserTime.share)) exakt bei \(report.ruleParserTime.total) Sätzen mit Uhrzeit."]
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
        // Every known form gets its row, measured or not: a missing row would read as "this form
        // is fine". Unknown keys follow, so nothing is swallowed.
        let unknown = report.byForm.keys.filter { !Corpus.forms.contains($0) }.sorted()
        for form in Corpus.forms + unknown {
            let tally = report.byForm[form] ?? FormTally()
            let date = tally.date.total == 0 ? "–" : "\(percent(tally.date.share)) von \(tally.date.total)"
            let facts = tally.facts.total == 0 ? "–" : percent(tally.facts.share)
            let invented = tally.invented.total == 0 ? "–" : inverse(tally.invented)
            lines.append("| \(form) | \(tally.sentences) | \(date) | \(invented) | \(facts) |")
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
                 block("Regelparser danebenging", report.ruleParser.misses),
                 block("Regelparser erfand ein Datum", report.ruleParserInvented.misses),
                 block("Regelparser falsche Uhrzeit", report.ruleParserTime.misses),
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

/// The report carries the rule-based parser (#92) as a third column next to the model and the frozen
/// `NSDataDetector` column (#148), split by kind of expression, with its own "what went wrong" block. Checked on
/// a synthetic corpus and report, so it runs before any run was fetched.
@Suite("Bericht: Regelparser-Spalte")
struct DateTitleRuleParserSectionTests {
    static func corpus(_ json: String) throws -> [Corpus.Entry] {
        try JSONDecoder().decode([Corpus.Entry].self, from: Data(json.utf8))
    }

    @Test("Der Regelparser wird über Datum, Kontrolle und Uhrzeit gezählt, Wiederholungen nur bei der Uhrzeit")
    func scoring() throws {
        let corpus = try Self.corpus("""
        [{"id": "a", "lang": "de", "text": "Morgen die Kita anrufen", "date": {"rule": "offsetDays", "value": 1}},
         {"id": "b", "lang": "de", "text": "Rechnung 4711 reklamieren"},
         {"id": "c", "lang": "de", "text": "Jeden Tag um 7 Uhr die Tabletten nehmen", "time": "07:00", "repeat": "daily"}]
        """)
        var report = DateTitleReportTests.Report()
        DateTitleReportTests.scoreRuleParser(corpus, calendar: CorpusTests.calendar, reference: CorpusTests.reference, into: &report)
        #expect(report.ruleParser.total == 1)
        #expect(report.ruleParser.hit == 1)
        #expect(report.ruleParserInvented.total == 1)
        #expect(report.ruleParserInvented.hit == 1)
        #expect(report.ruleParserTime.total == 1)
        #expect(report.ruleParserTime.hit == 1)
        #expect(report.ruleParserByRule["in N Tagen / morgen"]?.hit == 1)
    }

    @Test("Datumstabelle hat die Spalte Regelparser, auch nach Art des Ausdrucks")
    func dateSection() {
        var report = DateTitleReportTests.Report()
        report.model.record(hit: true)
        report.ruleParser.record(hit: true)
        report.ruleParser.record(hit: false, empty: true)
        report.ruleParserInvented.record(hit: true)
        report.ruleParserTime.record(hit: true)
        report.byRule["Wochentag", default: .init()].record(hit: true)
        report.ruleParserByRule["Wochentag", default: .init()].record(hit: false)
        report.ruleParserByRule["Wochentag", default: .init()].record(hit: true)

        let section = DateTitleReportTests.dateSection(report)
        #expect(section.contains("| Messung | Modell | NSDataDetector | Regelparser |"))
        #expect(section.contains("| Exakt getroffen | 100.0 % von 1 | 67.6 % von 139 | 50.0 % von 2 |"))
        #expect(section.contains("| Feld leer gelassen statt geraten | 0 | 41 | 1 |"))
        #expect(section.contains("| Erfundene Daten bei Sätzen ohne Datum | noch nicht gemessen | 0.0 % von 172 | 0.0 % von 1 |"))
        #expect(section.contains("eingefrorene Stand vom 2026-09-25"), "NSDataDetector carries its frozen date (#148)")
        #expect(section.contains("| Ausdruck | Sätze | Modell exakt | Leer gelassen | Regelparser exakt |"))
        #expect(section.contains("| Wochentag | 1 | 100.0 % | 0 | 50.0 % |"))
        #expect(section.contains("**Uhrzeit Regelparser:** 100.0 % exakt bei 1 Sätzen mit Uhrzeit."))
    }

    @Test("Was der Regelparser verfehlt, steht mit Ausdrucksart im Bericht")
    func missesSection() {
        var report = DateTitleReportTests.Report()
        report.ruleParser.record(hit: false, miss: "`Am Freitga den Zählerstand melden` → – statt 2026-03-13 · Wochentag")
        report.ruleParserTime.record(hit: false, miss: "`Um halb zwölf anrufen` → 12:30 statt 11:30")

        let section = DateTitleReportTests.missesSection(report)
        #expect(section.contains("### Regelparser danebenging (1)"))
        #expect(section.contains("- `Am Freitga den Zählerstand melden` → – statt 2026-03-13 · Wochentag"))
        #expect(section.contains("### Regelparser falsche Uhrzeit (1)"))
        #expect(DateTitleReportTests.markdown(report, runs: [], corpus: []).contains("Regelparser danebenging"))
    }
}
