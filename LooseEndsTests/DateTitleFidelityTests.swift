#if canImport(FoundationModels) && !os(watchOS)
import Foundation
import Testing
@testable import LooseEnds

/// Issue #67, assumption A3: a wrong title falsifies every line, a wrong date fires a
/// notification and turns a task red. This measures both against a corpus whose truth is
/// objective (`Measurement/date-title-corpus.json`) and, in the same run, against the
/// deterministic alternative from the issue (`NSDataDetector`).
///
/// Hundreds of model calls, so it never runs with the ordinary suite: set `LOOSEENDS_MEASURE=1`
/// (`./scripts/sim.sh measure`, `./scripts/sim.sh device-measure`). The report goes to
/// `docs/reference/`; on a device, where the repository is out of reach, it is printed between
/// markers and `sim.sh` picks it up from there.
@Suite(.enabled(if: ProcessInfo.processInfo.environment["LOOSEENDS_MEASURE"] == "1"), .serialized)
struct DateTitleFidelityTests {
    struct Tally {
        var total = 0
        var hit = 0
        var empty = 0
        var wrong: [String] = []
        var share: Double { total == 0 ? 0 : Double(hit) / Double(total) }
        mutating func record(hit isHit: Bool, empty isEmpty: Bool = false, note: String = "") {
            total += 1
            if isHit { hit += 1 } else if isEmpty { empty += 1 } else if !note.isEmpty { wrong.append(note) }
        }
    }

    struct Result {
        var model = Tally()
        var parser = Tally()
        var byRule: [String: Tally] = [:]
        var modelInvented = Tally()
        var parserInvented = Tally()
        var time = Tally()
        var entities = Tally()
        var facts = Tally()
        var foreign = Tally()
        var modelErrors = 0
        var rateLimited = 0
        var seconds: [Double] = []
    }

    // MARK: - The run

    @Test("Datum und Titel gegen den Treue-Korpus")
    func measure() async throws {
        let enricher = FoundationModelsEnricher()
        try #require(enricher.unavailableReason == nil, "Modell nicht verfügbar: \(enricher.unavailableReason ?? "-")")

        let calendar = Calendar.current
        let reference = calendar.date(byAdding: .hour, value: 9, to: calendar.startOfDay(for: Date()))!
        var entries = try Corpus.load()
        // A smoke run for the harness itself: LOOSEENDS_MEASURE_LIMIT=5 keeps it to a few notes.
        if let limit = ProcessInfo.processInfo.environment["LOOSEENDS_MEASURE_LIMIT"].flatMap(Int.init) {
            entries = Array(entries.prefix(limit))
        }
        var result = Result()

        for (index, entry) in entries.enumerated() {
            let started = Date()
            let attempt = await Self.enrich(entry, at: reference, with: enricher)
            if index % 20 == 0 { print("[messung] \(index)/\(entries.count), Fehler bisher: \(result.modelErrors)") }
            guard let draft = attempt.draft else {
                result.modelErrors += 1
                if attempt.rateLimited { result.rateLimited += 1 }
                continue
            }
            result.seconds.append(Date().timeIntervalSince(started))
            Self.scoreDate(entry, draft: draft, reference: reference, calendar: calendar, into: &result)
            Self.scoreTitle(entry, draft: draft, into: &result)
        }

        let report = Self.report(result: result, entries: entries, reference: reference, calendar: calendar)
        print("<<<REPORT:\(Self.reportName)>>>\n\(report)\n<<<END REPORT>>>")
        Self.writeToRepository(report)
        #expect(result.model.total > 0, "kein einziger Satz gemessen")
    }

    /// Three attempts with a growing pause. A guardrail false positive or a rate limit on a single
    /// note must not cost the whole run — and on battery the system throttles after a handful of
    /// calls ("Client rate limit exceeded"), which the pause rides out.
    static func enrich(_ entry: Corpus.Entry, at reference: Date, with enricher: FoundationModelsEnricher) async -> (draft: EnrichmentDraft?, rateLimited: Bool) {
        let input = EnrichmentInput(rawText: entry.text, capturedAt: reference, contextVocabulary: [], projectNames: [], examples: [])
        var throttled = false
        for pause in [0, 5, 20] {
            if pause > 0 { try? await Task.sleep(for: .seconds(pause)) }
            do {
                return (try await enricher.enrich(input), throttled)
            } catch {
                throttled = throttled || "\(error)".localizedCaseInsensitiveContains("rate limit")
            }
        }
        return (nil, throttled)
    }

    // MARK: - Scoring

    static func scoreDate(_ entry: Corpus.Entry, draft: EnrichmentDraft, reference: Date, calendar: Calendar, into result: inout Result) {
        guard entry.countsForDateMeasurement else { return }
        let modelDay = draft.dueDate.map { calendar.startOfDay(for: $0.value) }
        let parserDay = parsedDay(in: entry.text, calendar: calendar)

        if let expectation = entry.date {
            let accepted = expectation.acceptedDays(reference: reference, calendar: calendar)
            let hit = modelDay.map(accepted.contains) ?? false
            result.model.record(hit: hit, empty: modelDay == nil,
                                note: "`\(entry.text)` → \(day(modelDay, calendar)) statt \(day(accepted.min(), calendar))")
            result.parser.record(hit: parserDay.map(accepted.contains) ?? false, empty: parserDay == nil)
            result.byRule[ruleName(expectation), default: Tally()].record(hit: hit, empty: modelDay == nil)
        } else {
            result.modelInvented.record(hit: modelDay == nil, note: "`\(entry.text)` → \(day(modelDay, calendar))")
            result.parserInvented.record(hit: parserDay == nil)
        }

        if let expected = entry.time {
            let got = draft.dueHasTime ? draft.dueDate.map { timeString($0.value, calendar) } : nil
            result.time.record(hit: got == expected, empty: got == nil, note: "`\(entry.text)` → \(got ?? "–") statt \(expected)")
        }
    }

    static func scoreTitle(_ entry: Corpus.Entry, draft: EnrichmentDraft, into result: inout Result) {
        guard let title = draft.title?.value else { return }
        for entity in entry.entities {
            let kept = TitleCheck.preserves(entity: entity, in: title)
            result.entities.record(hit: kept, note: "`\(entry.text)` → „\(title)“ ohne \(entity)")
        }
        let invented = TitleCheck.inventedNumbers(title: title, rawText: entry.text)
            + TitleCheck.alteredNames(title: title, rawText: entry.text, people: entry.people)
        result.facts.record(hit: invented.isEmpty, note: "`\(entry.text)` → „\(title)“ erfindet \(invented.joined(separator: ", "))")
        result.foreign.record(hit: TitleCheck.foreignWords(title: title, rawText: entry.text).isEmpty)
    }

    /// The alternative from the issue: Apple's deterministic detector. It always resolves against
    /// the current day, which is exactly the reference day of this run.
    static func parsedDay(in text: String, calendar: Calendar) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let match = detector.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        return match?.date.map { calendar.startOfDay(for: $0) }
    }

    // MARK: - Report

    static var reportName: String {
        #if os(macOS)
        return "date-title-fidelity-mac"
        #elseif targetEnvironment(simulator)
        return "date-title-fidelity-simulator"
        #else
        return "date-title-fidelity-iphone"
        #endif
    }

    static func report(result: Result, entries: [Corpus.Entry], reference: Date, calendar: Calendar) -> String {
        let seconds = result.seconds.isEmpty ? 0 : result.seconds.reduce(0, +) / Double(result.seconds.count)
        let head = """
        # Treue von Datum und Titel (Issue #67)

        | | |
        |---|---|
        | Gerät | \(deviceDescription) |
        | Tag des Laufs | \(day(reference, calendar)) |
        | Korpus | \(entries.count) Sätze, \(result.model.total) mit Datum, \(result.modelInvented.total) ohne Datum als Kontrolle |
        | Modellfehler (übersprungen) | \(result.modelErrors), davon Rate Limit: \(result.rateLimited) |
        | Sekunden je Satz | \(String(format: "%.1f", seconds)) |

        Wahrheit ist im Korpus als Regel hinterlegt und wird gegen den Tag des Laufs ausgewertet;
        mehrdeutige Formulierungen („am Wochenende", „nächsten Freitag") lassen mehrere Tage gelten.
        `NSDataDetector` ist die deterministische Alternative aus dem Issue, auf denselben Sätzen.
        """
        return ([head, dateSection(result), titleSection(result), verdictSection(result)] + [missesSection(result)])
            .joined(separator: "\n\n")
    }

    static func dateSection(_ result: Result) -> String {
        var lines = [
            "## Datum",
            "",
            "| Messung | Modell | NSDataDetector |",
            "|---|---|---|",
            "| Exakt getroffen (\(result.model.total) Sätze mit Datum) | \(percent(result.model.share)) | \(percent(result.parser.share)) |",
            "| Davon leer gelassen statt geraten | \(percent(Double(result.model.empty) / Double(max(result.model.total, 1)))) | \(percent(Double(result.parser.empty) / Double(max(result.parser.total, 1)))) |",
            "| Erfundene Daten (\(result.modelInvented.total) Sätze ohne Datum) | \(percent(1 - result.modelInvented.share)) | \(percent(1 - result.parserInvented.share)) |",
            "",
            "### Nach Art des Ausdrucks",
            "",
            "| Ausdruck | Sätze | Modell exakt | Leer gelassen |",
            "|---|---|---|---|",
        ]
        for (rule, tally) in result.byRule.sorted(by: { $0.key < $1.key }) {
            lines.append("| \(rule) | \(tally.total) | \(percent(tally.share)) | \(tally.empty) |")
        }
        if result.time.total > 0 {
            lines += ["", "**Uhrzeit:** \(percent(result.time.share)) exakt bei \(result.time.total) Sätzen mit Uhrzeit, \(result.time.empty) ohne Uhrzeit geliefert."]
        }
        return lines.joined(separator: "\n")
    }

    static func titleSection(_ result: Result) -> String {
        """
        ## Titel

        | Messung | Anteil |
        |---|---|
        | Entitäten aus dem Rohtext erhalten (\(result.entities.total) geprüft) | \(percent(result.entities.share)) |
        | Titel ohne erfundene Fakten (Zahlen, verdrehte Namen) | \(percent(result.facts.share)) |
        | Titel ganz ohne Fremdwörter (nur Wörter aus dem Rohtext) | \(percent(result.foreign.share)) |

        Erfundene Fakten sind das Abbruchkriterium. Fremdwörter zeigen nur, wie stark das Modell
        umformuliert; eine Umformulierung ist erlaubt, solange sie nichts erfindet.
        """
    }

    static func verdictSection(_ result: Result) -> String {
        let invented = 1 - result.modelInvented.share
        let hallucination = 1 - result.facts.share
        func verdict(_ passed: Bool) -> String { passed ? "gehalten" : "**gerissen**" }
        return """
        ## Abbruchkriterien aus #67

        | Kriterium | Grenze | Gemessen | Ergebnis |
        |---|---|---|---|
        | Datum exakt | ≥ 95 % | \(percent(result.model.share)) | \(verdict(result.model.share >= 0.95)) |
        | Erfundene Daten | ≤ 2 % | \(percent(invented)) | \(verdict(invented <= 0.02)) |
        | Titel mit erfundenen Fakten | ≤ 2 % | \(percent(hallucination)) | \(verdict(hallucination <= 0.02)) |
        """
    }

    static func missesSection(_ result: Result) -> String {
        func block(_ title: String, _ items: [String]) -> String {
            guard !items.isEmpty else { return "" }
            return "### \(title) (\(items.count))\n\n" + items.prefix(25).map { "- \($0)" }.joined(separator: "\n")
        }
        return (["## Was danebenging",
                 block("Falsches Datum", result.model.wrong),
                 block("Datum erfunden", result.modelInvented.wrong),
                 block("Falsche Uhrzeit", result.time.wrong),
                 block("Entität verloren", result.entities.wrong),
                 block("Fakt erfunden", result.facts.wrong)]
            .filter { !$0.isEmpty }).joined(separator: "\n\n")
    }

    // MARK: - Small helpers

    static func percent(_ value: Double) -> String { String(format: "%.1f %%", value * 100) }

    static func day(_ date: Date?, _ calendar: Calendar) -> String {
        guard let date else { return "–" }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func timeString(_ date: Date, _ calendar: Calendar) -> String {
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

    static var deviceDescription: String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        #if os(macOS)
        return "Mac, \(os)"
        #elseif targetEnvironment(simulator)
        return "iOS-Simulator, \(os)"
        #else
        return "iPhone, \(os)"
        #endif
    }

    /// Works from the Mac and the simulator, where the repository is on the same file system.
    /// On a device this quietly does nothing; the printed report is the way out.
    static func writeToRepository(_ report: String) {
        let folder = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/reference")
        guard FileManager.default.fileExists(atPath: folder.path) else { return }
        try? report.write(to: folder.appendingPathComponent("\(reportName).md"), atomically: true, encoding: .utf8)
    }
}
#endif
