import Foundation
import Testing
@testable import LooseEnds

/// The measuring instrument itself, checked before it measures anything (Issue #67): a wrong rule
/// would turn a correct model answer into a miss and kill a field on bad numbers. Runs without a
/// model, so it also runs in CI.
@Suite("Korpus-Regelwerk")
struct CorpusTests {
    /// Thursday, 12 March 2026 — mid-week and mid-month, so weekday, weekend and month rules all
    /// have a non-trivial answer.
    static let reference: Date = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar.date(from: DateComponents(year: 2026, month: 3, day: 12))!
    }()

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    static func days(_ expectation: Corpus.DateExpectation, reference: Date = reference) -> Set<String> {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        return Set(expectation.acceptedDays(reference: reference, calendar: calendar).map(formatter.string(from:)))
    }

    @Test("Tagesversatz zählt vom Erfassungstag")
    func offsetDays() {
        #expect(Self.days(.offsetDays(0)) == ["2026-03-12"])
        #expect(Self.days(.offsetDays(1)) == ["2026-03-13"])
        #expect(Self.days(.offsetDays(14)) == ["2026-03-26"])
        #expect(Self.days(.offsetDays(28)) == ["2026-04-09"])
    }

    @Test("Wochentag meint den nächsten, am Tag selbst auch heute")
    func weekday() {
        #expect(Self.days(.weekday(6)) == ["2026-03-13"])            // Freitag
        #expect(Self.days(.weekday(2)) == ["2026-03-16"])            // Montag
        #expect(Self.days(.weekday(5)) == ["2026-03-12", "2026-03-19"])  // Donnerstag ist der Erfassungstag
    }

    @Test("Nächste Woche meint die Folgewoche, nächster Freitag beides")
    func weekdayNextWeek() {
        #expect(Self.days(.weekdayNextWeek(6)) == ["2026-03-20"])
        #expect(Self.days(.weekdayNextWeek(2)) == ["2026-03-16"])
        #expect(Self.days(.weekdayEitherNext(6)) == ["2026-03-13", "2026-03-20"])
    }

    @Test("Monatsende, Tag im Monat, Wochenende")
    func monthAndWeekend() {
        #expect(Self.days(.endOfMonth) == ["2026-03-31"])
        #expect(Self.days(.dayOfMonth(15)) == ["2026-03-15"])
        #expect(Self.days(.dayOfMonth(3)) == ["2026-04-03"])         // der 3. ist vorbei
        #expect(Self.days(.weekend) == ["2026-03-14", "2026-03-15"])
    }

    @Test("Nächster Monat lässt jeden Tag des Folgemonats gelten")
    func monthRange() {
        let april = Self.days(.monthRange(1))
        #expect(april.count == 30)
        #expect(april.contains("2026-04-01"))
        #expect(april.contains("2026-04-30"))
        #expect(!april.contains("2026-03-31"))
        #expect(!april.contains("2026-05-01"))
    }

    @Test("Datum mit Monat rollt ins nächste Jahr, wenn es vorbei ist")
    func dayAndMonth() {
        #expect(Self.days(.dayAndMonth(day: 4, month: 5)) == ["2026-05-04"])
        #expect(Self.days(.dayAndMonth(day: 1, month: 3)) == ["2027-03-01"])
    }

    @Test("Am Sonntag meint 'am Wochenende' heute und das nächste Wochenende")
    func weekendOnSunday() {
        let sunday = Self.calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!
        #expect(Self.days(.weekend, reference: sunday) == ["2026-03-29", "2026-04-04"])
    }

    @Test("Monatsende im Februar und Jahreswechsel")
    func edgeMonths() {
        let january = Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        #expect(Self.days(.endOfMonth, reference: january) == ["2026-01-31"])
        #expect(Self.days(.offsetDays(1), reference: january) == ["2026-02-01"])
        let december = Self.calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        #expect(Self.days(.monthRange(1), reference: december).count == 31)
        #expect(Self.days(.monthRange(1), reference: december).contains("2027-01-15"))
    }

    @Test("Der Korpus lädt, ist eindeutig und jede Entität steht im Rohtext")
    func corpusIsSound() throws {
        let entries = try Corpus.load()
        #expect(entries.count >= 200)
        #expect(Set(entries.map(\.id)).count == entries.count)
        for entry in entries {
            for entity in entry.entities {
                #expect(TitleCheck.preserves(entity: entity, in: entry.text), "\(entry.id): \(entity) fehlt im Rohtext")
            }
            for person in entry.people {
                #expect(TitleCheck.preserves(entity: person, in: entry.text), "\(entry.id): \(person) fehlt im Rohtext")
            }
            if entry.time != nil { #expect(entry.date != nil || entry.repeatRule != nil, "\(entry.id): Uhrzeit ohne Tag") }
        }
        let withDate = entries.filter { $0.date != nil }
        let controls = entries.filter { $0.date == nil && $0.countsForDateMeasurement }
        #expect(withDate.count >= 100)
        #expect(controls.count >= 80)
    }

    /// Issue #82: the corpus must carry Henning's sentence forms, not only "time, object, verb".
    /// Every form is named, every named form is known, and each one is thick enough to give a
    /// rate of its own in the report.
    /// Spoken filler words that mark a dictated sentence. Deliberately without "um", "so" or
    /// "dann": those also carry meaning in ordinary sentences and would pass by accident.
    static let dictationFillers: Set<String> = ["äh", "ähm", "also", "halt", "quasi", "irgendwie", "uh", "erm", "like", "okay"]

    @Test("Der Korpus kennt Hennings Bauformen, mindestens 100 Sätze außerhalb der Standardform")
    func corpusHasSentenceForms() throws {
        let entries = try Corpus.load()
        for entry in entries {
            #expect(Corpus.forms.contains(entry.form), "\(entry.id): unbekannte Bauform \(entry.form)")
        }
        let varied = entries.filter { $0.form != Corpus.standardForm }
        #expect(varied.count >= 100)
        let counts = Dictionary(grouping: varied, by: \.form).mapValues(\.count)
        for form in Corpus.forms where form != Corpus.standardForm {
            #expect((counts[form] ?? 0) >= 6, "Bauform \(form) hat nur \(counts[form] ?? 0) Sätze")
        }
        for entry in varied {
            let words = TitleCheck.words(in: entry.text)
            switch entry.form {
            case "stichwort": #expect(words.count <= 3, "\(entry.id): Stichwort mit \(words.count) Wörtern")
            case "frage": #expect(entry.text.hasSuffix("?"), "\(entry.id): Frage ohne Fragezeichen")
            case "ich-satz": #expect(words.first?.lowercased() == "ich", "\(entry.id): Ich-Satz beginnt nicht mit „ich“")
            case "diktat":
                #expect(entry.text == entry.text.lowercased() && !entry.text.contains(","), "\(entry.id): Diktat mit Großschreibung oder Satzzeichen")
                let hasFiller = words.contains { Self.dictationFillers.contains($0.lowercased()) }
                #expect(hasFiller, "\(entry.id): Diktat ohne Füllwort (Issue #82 verlangt „äh also morgen dann …“)")
            default: break
            }
        }
    }

    // MARK: - Spike #65 Schritt 1: Korpus per Namen laden (AC-1, AC-6)

    @Test("Ausdrücklich genannter Dateiname lädt dieselben Einträge wie der Default (AC-1)")
    func loadByExplicitFileName() throws {
        let byDefault = try Corpus.load()
        let byName = try Corpus.load(fileName: "date-title-corpus")
        #expect(byName.count == byDefault.count)
        #expect(Set(byName.map(\.id)) == Set(byDefault.map(\.id)))
    }

    @Test("Unbekannter Dateiname wirft denselben Fehler wie eine fehlende Standarddatei (AC-1)")
    func loadUnknownFileNameThrows() {
        #expect(throws: CocoaError.self) {
            _ = try Corpus.load(fileName: "does-not-exist-corpus")
        }
    }

    @Test("--corpus liest den Korpusnamen aus den Startargumenten (AC-6)")
    func corpusFileNameFromArguments() {
        #expect(Corpus.corpusFileName(from: ["LooseEndsLab", "--corpus", "focusblox-corpus"]) == "focusblox-corpus")
        #expect(Corpus.corpusFileName(from: ["LooseEndsLab"]) == Corpus.fileName)
        #expect(Corpus.corpusFileName(from: ["LooseEndsLab", "--measure"]) == Corpus.fileName)
    }

    // MARK: - Spike #65 Schritt 2 (#108): FocusBlox-Wahrheitsfelder, --runs (AC-1, AC-4)

    @Test("FocusBlox-Wahrheitsfelder dekodieren additiv aus dem Korpus-Eintrag (AC-1)")
    func focusBloxTruthFieldsDecode() throws {
        let json = """
        [{"id":"fb-1","lang":"de","text":"Rechnung prüfen","importanceTruth":"high","urgencyTruth":"low",
          "durationTruth":"minutes15","energyTruth":"high","contextsTruth":["zuhause","telefon"]}]
        """
        let entries = try JSONDecoder().decode([Corpus.Entry].self, from: Data(json.utf8))
        #expect(entries[0].importanceTruth == "high")
        #expect(entries[0].urgencyTruth == "low")
        #expect(entries[0].durationTruth == "minutes15")
        #expect(entries[0].energyTruth == "high")
        #expect(entries[0].contextsTruth == ["zuhause", "telefon"])
    }

    @Test("Ein Eintrag der bestehenden date-title-corpus-Datei ohne die neuen Schlüssel dekodiert sie als nil (AC-1)")
    func focusBloxTruthFieldsDefaultToNilForDateTitleCorpus() throws {
        let entries = try Corpus.load()
        #expect(entries[0].importanceTruth == nil)
        #expect(entries[0].urgencyTruth == nil)
        #expect(entries[0].durationTruth == nil)
        #expect(entries[0].energyTruth == nil)
        #expect(entries[0].contextsTruth == nil)
    }

    @Test("--runs liest die Laufzahl aus den Startargumenten, Default bleibt 1 (AC-4)")
    func runsPerEntryFromArguments() {
        #expect(Corpus.runsPerEntry(from: ["LooseEndsLab", "--runs", "5"]) == 5)
        #expect(Corpus.runsPerEntry(from: ["LooseEndsLab"]) == 1)
        #expect(Corpus.runsPerEntry(from: ["LooseEndsLab", "--corpus", "focusblox-corpus"]) == 1)
    }
}

@Suite("Titelprüfung")
struct TitleCheckTests {
    @Test("Entität bleibt erhalten, unabhängig von Groß- und Kleinschreibung")
    func preservesEntity() {
        #expect(TitleCheck.preserves(entity: "Özdemir", in: "Liefertermin mit özdemir klären"))
        #expect(TitleCheck.preserves(entity: "4711", in: "Rechnung 4711 reklamieren"))
        #expect(!TitleCheck.preserves(entity: "Sparkasse", in: "Bei der Bank anrufen"))
    }

    @Test("Eine Zahl im Titel, die der Rohtext nicht nennt, ist erfunden")
    func inventedNumbers() {
        #expect(TitleCheck.inventedNumbers(title: "Rechnung 4712 reklamieren", rawText: "Rechnung 4711 bei der Buchhaltung reklamieren") == ["4712"])
        #expect(TitleCheck.inventedNumbers(title: "Rechnung 4711 reklamieren", rawText: "Rechnung 4711 bei der Buchhaltung reklamieren").isEmpty)
        #expect(TitleCheck.inventedNumbers(title: "250 Euro überweisen", rawText: "250 Euro an den Verein überweisen").isEmpty)
    }

    @Test("Andrea darf im Titel nicht zu Andreas werden")
    func alteredNames() {
        #expect(TitleCheck.alteredNames(title: "Andreas anrufen", rawText: "Andrea wegen der Abrechnung anrufen", people: ["Andrea"]) == ["Andreas"])
        #expect(TitleCheck.alteredNames(title: "Andrea anrufen", rawText: "Andrea wegen der Abrechnung anrufen", people: ["Andrea"]).isEmpty)
        #expect(TitleCheck.alteredNames(title: "Frau Kowalski anschreiben", rawText: "Frau Kowalski wegen der Nebenkosten anschreiben", people: ["Frau Kowalski"]).isEmpty)
    }

    @Test("Umformulierungen zeigen sich als Fremdwörter im Titel")
    func foreignWords() {
        #expect(TitleCheck.foreignWords(title: "Zahnarzt anrufen", rawText: "Morgen beim Zahnarzt anrufen").isEmpty)
        #expect(TitleCheck.foreignWords(title: "Zahnarzttermin vereinbaren", rawText: "Morgen beim Zahnarzt anrufen") == ["vereinbaren"])
    }

    @Test("Editierabstand misst kleine Namensverdreher")
    func editDistance() {
        #expect(TitleCheck.editDistance("andrea", "andreas") == 1)
        #expect(TitleCheck.editDistance("meier", "meyer") == 1)
        #expect(TitleCheck.editDistance("tom", "ravi") == 4)
        #expect(TitleCheck.editDistance("", "abc") == 3)
    }
}
