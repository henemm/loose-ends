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
