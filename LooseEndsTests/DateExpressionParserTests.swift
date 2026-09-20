import Foundation
import Testing
@testable import LooseEnds

/// The rule-based date parser (#92, "rules before the model"): one test per kind of expression,
/// German and English, each with a trap sentence that must stay empty. Recognition is checked as
/// the expression itself; resolution is checked against the corpus rule `Corpus.DateExpectation`,
/// which stays the independent reference (the parser must not share its calendar code).
@Suite("Regelparser: Datum")
struct DateExpressionParserTests {
    /// Thursday, 12 March 2026, Europe/Berlin — the same anchor as `CorpusTests`.
    static let reference = CorpusTests.reference
    static let calendar = CorpusTests.calendar
    static let parser = DateExpressionParser(calendar: calendar)

    static func expression(_ text: String) -> DateExpression? {
        parser.expression(in: text)
    }

    /// The resolved day, formatted, or nil when the parser found nothing.
    static func day(_ text: String) -> String? {
        parser.date(in: text, reference: reference).map { DateTitleReportTests.day($0, calendar) }
    }

    /// True when the parser's single date is one the corpus rule accepts for the reference day.
    static func accepted(_ text: String, by expectation: Corpus.DateExpectation) -> Bool {
        guard let got = day(text) else { return false }
        return CorpusTests.days(expectation).contains(got)
    }

    @Test("heute, morgen, übermorgen, in N Tagen / Wochen — Deutsch")
    func offsetDaysGerman() {
        #expect(Self.expression("Heute noch die Mülltonne rausstellen") == .offsetDays(0))
        #expect(Self.expression("Morgen früh um 7:30 den Hund zum Tierarzt") == .offsetDays(1))
        #expect(Self.expression("Übermorgen den Rasen mähen") == .offsetDays(2))
        #expect(Self.expression("In drei Tagen die Rechnung bezahlen") == .offsetDays(3))
        #expect(Self.expression("In 14 Tagen den Termin beim Amt bestätigen") == .offsetDays(14))
        #expect(Self.expression("In einer Woche beim Vermieter nachhaken") == .offsetDays(7))
        #expect(Self.expression("In vier Wochen den Vertrag kündigen") == .offsetDays(28))
        #expect(Self.expression("Müll rausstellen heute Abend") == .offsetDays(0))
        #expect(Self.expression("äh also morgen dann die reifen wechseln lassen") == .offsetDays(1))
        #expect(Self.day("Morgen beim Zahnarzt einen Termin machen") == "2026-03-13")
        #expect(Self.day("Übermorgen das Auto in die Werkstatt bringen") == "2026-03-14")
        #expect(Self.accepted("In zwei Wochen die Zahlung von 250 Euro prüfen", by: .offsetDays(14)))
    }

    @Test("today, tomorrow, the day after tomorrow, in N days / weeks — English")
    func offsetDaysEnglish() {
        #expect(Self.expression("Call the insurance company today") == .offsetDays(0))
        #expect(Self.expression("Call the landlord tomorrow about the heating") == .offsetDays(1))
        #expect(Self.expression("The day after tomorrow return the rental car") == .offsetDays(2))
        #expect(Self.expression("In three days check the delivery") == .offsetDays(3))
        #expect(Self.expression("In 10 days renew the domain") == .offsetDays(10))
        #expect(Self.expression("In two weeks send the reminder to Paul") == .offsetDays(14))
        #expect(Self.expression("In one week cancel the trial subscription") == .offsetDays(7))
        #expect(Self.day("Pick up the suit the day after tomorrow") == "2026-03-14")
    }

    @Test("Wochentag mit und ohne Präposition, am Anfang, in der Mitte, am Ende")
    func weekday() {
        #expect(Self.expression("Am Montag die Bewerbung abschicken") == .weekday(2))
        #expect(Self.expression("Dienstag den Vertrag von Frau Kowalski gegenzeichnen") == .weekday(3))
        #expect(Self.expression("Kommenden Freitag die Tonne an die Straße stellen") == .weekday(6))
        #expect(Self.expression("Diesen Donnerstag das Protokoll verschicken") == .weekday(5))
        #expect(Self.expression("Schaffe ich den Bericht bis Freitag?") == .weekday(6))
        #expect(Self.expression("Laternenumzug Freitag") == .weekday(6))
        #expect(Self.expression("Freitag Andrea die 250 Euro zurückgeben") == .weekday(6))
        #expect(Self.expression("am freitag mit herrn bier hoff telefonieren") == .weekday(6))
        #expect(Self.expression("Am Sonntag den Braten für 6 Personen vorbereiten") == .weekday(1))
        #expect(Self.expression("On Monday send the contract to Miriam") == .weekday(2))
        #expect(Self.expression("Review the budget on Wednesday") == .weekday(4))
        #expect(Self.expression("Saturday clean the gutters") == .weekday(7))
        #expect(Self.day("Am Freitag den Bericht an die Geschäftsführung geben") == "2026-03-13")
        #expect(Self.day("Am Montag die Bewerbung abschicken") == "2026-03-16")
        // Said on a Thursday, "Donnerstag" may mean today or next week — either is accepted.
        #expect(Self.accepted("Donnerstag die Fahrräder zum Service bringen", by: .weekday(5)))
    }

    @Test("nächsten <Tag> / next <day> lässt beide Vorkommen gelten")
    func weekdayEitherNext() {
        #expect(Self.expression("Nächsten Montag die Reifen wechseln lassen") == .weekdayEitherNext(2))
        #expect(Self.expression("Nächsten Donnerstag um 11 Uhr zur Physiotherapie") == .weekdayEitherNext(5))
        #expect(Self.expression("Next Tuesday hand in the application") == .weekdayEitherNext(3))
        #expect(Self.expression("Submit the form by next Friday") == .weekdayEitherNext(6))
        #expect(Self.expression("send the invoice to Ravi next Friday") == .weekdayEitherNext(6))
        #expect(Self.accepted("Nächsten Freitag den Zuschuss beantragen", by: .weekdayEitherNext(6)))
        #expect(Self.accepted("Next Monday call Ravi about room 12", by: .weekdayEitherNext(2)))
    }

    @Test("nächste Woche <Tag> meint die Folgewoche, auch kleingeschrieben und hinten")
    func weekdayNextWeek() {
        #expect(Self.expression("Nächste Woche Freitag die Steuererklärung einreichen") == .weekdayNextWeek(6))
        #expect(Self.expression("Nächste Woche Montag Andreas wegen Zimmer 12 anrufen") == .weekdayNextWeek(2))
        #expect(Self.expression("ähm nächste woche freitag den zahnarzttermin verschieben") == .weekdayNextWeek(6))
        #expect(Self.expression("Reifen wechseln nächste Woche Dienstag") == .weekdayNextWeek(3))
        #expect(Self.day("Nächste Woche Freitag die Steuererklärung einreichen") == "2026-03-20")
        #expect(Self.day("Nächste Woche Montag den Urlaubsantrag stellen") == "2026-03-16")
    }

    @Test("Monatsende in allen Schreibweisen")
    func endOfMonth() {
        #expect(Self.expression("Ende des Monats die Miete überweisen") == .endOfMonth)
        #expect(Self.expression("Zum Monatsende den Zählerstand ablesen") == .endOfMonth)
        #expect(Self.expression("Nebenkosten prüfen bis Monatsende") == .endOfMonth)
        #expect(Self.expression("Es wäre gut, wenn ich bis Ende des Monats die Nebenkosten prüfe") == .endOfMonth)
        #expect(Self.expression("Pay the rent at the end of the month") == .endOfMonth)
        #expect(Self.expression("End of the month send the report to the board") == .endOfMonth)
        #expect(Self.day("Ende des Monats die Miete überweisen") == "2026-03-31")
    }

    @Test("Tag im Monat nur mit Ordnungszeichen und Präposition")
    func dayOfMonth() {
        #expect(Self.expression("Bis zum 3. den Vertrag kündigen") == .dayOfMonth(3))
        #expect(Self.expression("Am 20. den Beitrag überweisen") == .dayOfMonth(20))
        #expect(Self.expression("Ich darf die Abrechnung bis zum 15. nicht vergessen") == .dayOfMonth(15))
        #expect(Self.expression("Angebot an Özdemir schicken bis zum 20.") == .dayOfMonth(20))
        #expect(Self.expression("By the 5th transfer the deposit") == .dayOfMonth(5))
        #expect(Self.expression("On the 12th collect the parcel") == .dayOfMonth(12))
        #expect(Self.day("Bis zum 15. die Unterlagen einreichen") == "2026-03-15")
        #expect(Self.day("Bis zum 3. den Vertrag kündigen") == "2026-04-03")   // der 3. ist vorbei
        #expect(Self.expression("Bis zum 15. die Police 30021988 umschreiben lassen") == .dayOfMonth(15))
    }

    @Test("Wochenende, dieses Wochenende, over the weekend")
    func weekend() {
        #expect(Self.expression("Am Wochenende die Garage aufräumen") == .weekend)
        #expect(Self.expression("Dieses Wochenende den Grill sauber machen") == .weekend)
        #expect(Self.expression("Keller aufräumen am Wochenende") == .weekend)
        #expect(Self.expression("This weekend fix the bike") == .weekend)
        #expect(Self.expression("Over the weekend sort the photos") == .weekend)
        // Working assumption for slice 1: Saturday, the first free day.
        #expect(Self.day("Am Wochenende die Garage aufräumen") == "2026-03-14")
        #expect(Self.accepted("Ich will am Wochenende den Keller aufräumen", by: .weekend))
    }

    @Test("nächsten Monat / next month")
    func monthRange() {
        #expect(Self.expression("Nächsten Monat die Versicherung prüfen") == .monthRange(1))
        #expect(Self.expression("Im nächsten Monat die Reise nach Rom planen") == .monthRange(1))
        #expect(Self.expression("Vertrag kündigen nächsten Monat") == .monthRange(1))
        #expect(Self.expression("Next month renew the passport") == .monthRange(1))
        // Working assumption for slice 1: the first day of the following month.
        #expect(Self.day("Nächsten Monat die Versicherung prüfen") == "2026-04-01")
        #expect(Self.accepted("Next month book the dentist for Lea", by: .monthRange(1)))
    }

    @Test("Festes Datum mit Monatsname, Deutsch und Englisch")
    func dayAndMonth() {
        #expect(Self.expression("Am 4. Mai die Anmeldung für den Kurs abgeben") == .dayAndMonth(day: 4, month: 5))
        #expect(Self.expression("Am 24. Dezember die Geschenke einpacken") == .dayAndMonth(day: 24, month: 12))
        #expect(Self.expression("Am 31. Juli die Zählerstände melden") == .dayAndMonth(day: 31, month: 7))
        #expect(Self.expression("On May 4th register for the course") == .dayAndMonth(day: 4, month: 5))
        #expect(Self.expression("On November 11 pay the club fee") == .dayAndMonth(day: 11, month: 11))
        #expect(Self.day("Am 4. Mai die Anmeldung für den Kurs abgeben") == "2026-05-04")
        #expect(Self.day("Am 1. März den Beitrag für den Verein zahlen") == "2027-03-01")   // schon vorbei
    }

    @Test("Zahlen ohne Zeitkontext ergeben kein Datum")
    func numberTraps() {
        let traps = [
            "Rechnung 4711 bei der Buchhaltung reklamieren",
            "250 Euro an den Verein überweisen",
            "Andreas wegen Zimmer 12 anrufen",
            "3 Kisten Wasser bestellen",
            "Zug fährt von Gleis 9",
            "Police 30021988 umschreiben lassen",
            "Ersatzteil A-2291 nachbestellen",
            "1,5 Liter Milch kaufen",
            "Belege von 2025 sortieren",
            "Svens Geburtstag nicht vergessen",
            "Call Ravi about room 12",
            "Invoice 4711 needs a reply",
        ]
        for trap in traps {
            #expect(Self.expression(trap) == nil, "\(trap) darf kein Datum ergeben")
        }
    }

    @Test("Wiederholungen sind kein Datum: jeden, every, werktags")
    func repeatTraps() {
        let traps = [
            "Jeden Montag den Müll rausstellen",
            "Jeden Tag um 7 Uhr die Tabletten nehmen",
            "Jeden ersten Montag im Monat den Rauchmelder prüfen",
            "Jedes Jahr im April die Reifen wechseln",
            "Werktags um 6:30 den Wecker für die Schule stellen",
            "Every Monday water the plants",
            "Every day at 8pm take the medication",
            "Every month check the smoke detector",
        ]
        for trap in traps {
            #expect(Self.expression(trap) == nil, "\(trap) ist eine Wiederholung, kein Datum")
        }
    }

    @Test("Zwei Ausdrücke im Satz: der erste gewinnt")
    func firstExpressionWins() {
        #expect(Self.expression("Deadline für das Rollout am Freitag checken") == .weekday(6))
        #expect(Self.expression("Morgen die Kita anrufen und Passbilder machen lassen") == .offsetDays(1))
        #expect(Self.expression("Bis zum 15. die Unterlagen einreichen und am Wochenende ausruhen") == .dayOfMonth(15))
    }

    @Test("Uhrzeiten lösen keinen Tagesversatz aus")
    func timeIsNotADayOffset() {
        #expect(Self.expression("Heute Abend um 20 Uhr Oma anrufen") == .offsetDays(0))
        #expect(Self.expression("Morgen das Standup auf 10 Uhr verschieben") == .offsetDays(1))
        #expect(Self.expression("Montag 9 Uhr Teamrunde vorbereiten") == .weekday(2))
    }
}
