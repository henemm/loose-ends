import Foundation
import Testing
@testable import LooseEnds

/// The rule-based time-of-day parser (#92). Kept apart from the date parser because the two
/// languages disagree on "half": German "halb zwölf" is 11:30, English "half past seven" is 07:30.
/// A bare number only counts as a time with a time cue ("Uhr", a colon, am/pm, "um/auf/at",
/// or a preceding "Mittag").
@Suite("Regelparser: Uhrzeit")
struct TimeExpressionParserTests {
    static let parser = TimeExpressionParser()

    static func time(_ text: String) -> String? {
        parser.time(in: text).map { String(format: "%02d:%02d", $0.hour, $0.minute) }
    }

    @Test("um H Uhr, H:MM, H Uhr ohne um, auf H Uhr")
    func germanClock() {
        #expect(Self.time("Heute Abend um 20 Uhr Oma anrufen") == "20:00")
        #expect(Self.time("Morgen früh um 7:30 den Hund zum Tierarzt") == "07:30")
        #expect(Self.time("Morgen um 14 Uhr Rückruf bei der Sparkasse") == "14:00")
        #expect(Self.time("Übermorgen um 9 Uhr die Zählerstände durchgeben") == "09:00")
        #expect(Self.time("Freitag um 15:30 Rückruf bei Dr. Behrens") == "15:30")
        #expect(Self.time("Morgen 18:45 die Kinder vom Training abholen") == "18:45")
        #expect(Self.time("Montag 9 Uhr Teamrunde vorbereiten") == "09:00")
        #expect(Self.time("Übermorgen um 9:15 bei der AOK die Bescheinigung holen") == "09:15")
        #expect(Self.time("Sparkasse anrufen morgen um 14 Uhr") == "14:00")
        #expect(Self.time("Morgen das Standup auf 10 Uhr verschieben") == "10:00")
    }

    @Test("at 5pm, at 9am, at 2:30 pm, at 10am")
    func englishClock() {
        #expect(Self.time("Send the invoice today at 5pm") == "17:00")
        #expect(Self.time("Tomorrow at 9am drop the keys at the office") == "09:00")
        #expect(Self.time("On Friday at 2:30 pm call the clinic") == "14:30")
        #expect(Self.time("Next Thursday at 10am meet the accountant") == "10:00")
        #expect(Self.time("Every day at 8pm take the medication") == "20:00")
    }

    @Test("halb zwölf ist 11:30, half past seven ist 07:30")
    func halfHours() {
        #expect(Self.time("Heute um halb zwölf beim Arzt anrufen") == "11:30")
        #expect(Self.time("also morgen um halb acht die kinder zur schule bringen") == "07:30")
        #expect(Self.time("okay tomorrow at half past seven take the kids to school") == "07:30")
    }

    @Test("Nackte Zahl nur nach einem Zeitwort wie Mittag")
    func bareNumberNeedsContext() {
        #expect(Self.time("Morgen Mittag um 12 die Bestellung für 3 Kisten Wasser aufgeben") == "12:00")
        #expect(Self.time("Morgen um 12 die Bestellung aufgeben") == "12:00")
        #expect(Self.time("Andreas wegen Zimmer 12 anrufen") == nil)
    }

    @Test("Wiederholungen tragen trotzdem eine Uhrzeit")
    func repeatsKeepTheirTime() {
        #expect(Self.time("Jeden Tag um 7 Uhr die Tabletten nehmen") == "07:00")
        #expect(Self.time("Werktags um 6:30 den Wecker für die Schule stellen") == "06:30")
    }

    @Test("Zahlen ohne Zeitkontext sind keine Uhrzeit")
    func numberTraps() {
        let traps = [
            "Rechnung 4711 bei der Buchhaltung reklamieren",
            "250 Euro an den Verein überweisen",
            "3 Kisten Wasser bestellen",
            "Zug fährt von Gleis 9",
            "Police 30021988 umschreiben lassen",
            "Ersatzteil A-2291 nachbestellen",
            "1,5 Liter Milch kaufen",
            "Belege von 2025 sortieren",
            "Am Sonntag den Braten für 6 Personen vorbereiten",
            "In 14 Tagen den Termin beim Amt bestätigen",
            "Bis zum 15. die Unterlagen einreichen",
            "Am 4. Mai die Anmeldung für den Kurs abgeben",
            "Am Wochenende mit Katrin die 7 Kartons in den Keller tragen",
            "Call Ravi about room 12",
            "In 10 days renew the domain",
        ]
        for trap in traps {
            #expect(Self.time(trap) == nil, "\(trap) darf keine Uhrzeit ergeben")
        }
    }

    @Test("Uhrzeit ist im Bereich 0–23 Stunden, 0–59 Minuten")
    func range() {
        #expect(Self.time("Um 24 Uhr feiern") == nil)
        #expect(Self.time("Um 12:75 ist Unsinn") == nil)
        #expect(Self.time("Um 0 Uhr die Sicherung wechseln") == "00:00")
        #expect(Self.time("Um 23:59 die Steuer abgeben") == "23:59")
    }
}
