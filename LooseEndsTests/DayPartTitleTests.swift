import Foundation
import Testing
@testable import LooseEnds

/// #1001: Tageszeitwörter direkt am Datum fallen aus dem Titel ("heute Abend", "morgen früh", "tomorrow
/// morning"); "tonight" setzt das Datum heute. Aus einer Tageszeit wird nie eine Uhrzeit (nichts erfinden).
@Suite("Tageszeit am Datum (#1001)") struct DayPartTitleTests {
    /// Ein Mittwoch um 12 Uhr, wie in `TitleRuleTests`: jedes Datum unten löst sich in jeder Zeitzone auf.
    private static let wednesday = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!

    private static func title(_ raw: String) -> String? {
        TitleRule.title(from: raw, reference: wednesday)
    }

    // MARK: AC-1 … AC-3: das Tageszeitwort geht mit dem Datum

    @Test("Tageszeit am Datum verlässt den Titel", arguments: [
        ("Pakete wegbringen heute Morgen", "Pakete wegbringen"),                      // AC-1, Issue-Beispiel
        ("Heute Abend um 20 Uhr Oma anrufen", "Oma anrufen"),                          // AC-2
        ("Müll rausstellen heute Abend", "Müll rausstellen"),                          // AC-2
        ("Morgen früh um 7:30 den Hund zum Tierarzt", "Den Hund zum Tierarzt"),        // AC-2
        ("Morgen Mittag um 12 die Bestellung aufgeben", "Die Bestellung aufgeben"),   // AC-3
        ("Heute Abend eine Nachricht an die Hundefamilie schreiben",
         "Eine Nachricht an die Hundefamilie schreiben"),
        ("Bitte nicht vergessen: morgen früh die Unterlagen einreichen",
         "Bitte nicht vergessen: die Unterlagen einreichen"),
        ("Montag Abend Kinokarten kaufen", "Kinokarten kaufen"),                       // AC-3
        ("Am Montag am Abend Kinokarten kaufen", "Kinokarten kaufen"),                 // AC-3: „am“ geht mit
        ("Montag Morgen Bäcker anrufen", "Bäcker anrufen"),                            // „Morgen“ nach Wochentag
        ("Heute Nachmittag Rasen mähen", "Rasen mähen"),
        ("Heute Nacht Spülmaschine anstellen", "Spülmaschine anstellen"),
        ("Reminder: tomorrow morning hand in the papers", "Reminder: hand in the papers"),  // AC-3
        ("Tomorrow in the evening call Anna", "Call Anna"),                            // „in the“ geht mit
        ("Today afternoon pick up the parcel", "Pick up the parcel"),
    ])
    func dayPartLeaves(raw: String, expected: String) {
        #expect(Self.title(raw) == expected)
    }

    // MARK: AC-4: „tonight“ ist heute

    @Test("„tonight“ setzt das Datum heute und verlässt den Titel")
    func tonightIsToday() throws {
        let match = try #require(DueDateRule.match(in: "Call mom tonight", reference: Self.wednesday))
        #expect(Calendar.current.isDate(match.guess.value, inSameDayAs: Self.wednesday))
        #expect(match.hasTime == false)
        #expect(Self.title("Call mom tonight") == "Call mom")
    }

    // MARK: AC-5: Gegenproben

    @Test("Inhaltswörter und Tageszeiten ohne Datum bleiben", arguments: [
        ("Heute Abendessen kochen", "Abendessen kochen"),
        ("Am Abend Tabletten nehmen", "Am Abend Tabletten nehmen"),
        ("Morgens Tabletten nehmen", "Morgens Tabletten nehmen"),
        ("Morgen Morgenrunde laufen", "Morgenrunde laufen"),
        ("Montagabend Jenny absagen", "Montagabend Jenny absagen"),
        ("Samstagmorgen Brötchen holen", "Samstagmorgen Brötchen holen"),
        ("Früh los zum Flughafen", "Früh los zum Flughafen"),
        ("Parents' evening at primary school Friday at 7 pm", "Parents' evening at primary school"),
    ])
    func contentStays(raw: String, expected: String) {
        #expect(Self.title(raw) == expected)
    }

    @Test("„Morgen“ am Satzanfang bleibt das Datum morgen, nicht die Tageszeit")
    func morgenAloneIsTomorrow() throws {
        let match = try #require(DueDateRule.match(in: "Morgen Bäcker anrufen", reference: Self.wednesday))
        let tomorrow = try #require(Calendar.current.date(byAdding: .day, value: 1, to: Self.wednesday))
        #expect(Calendar.current.isDate(match.guess.value, inSameDayAs: tomorrow))
        #expect(Self.title("Morgen Bäcker anrufen") == "Bäcker anrufen")
    }

    // MARK: AC-1, AC-6: keine Uhrzeit aus einer Tageszeit

    @Test("Eine Tageszeit ohne Zahl setzt keine Uhrzeit", arguments: [
        "Pakete wegbringen heute Morgen",
        "Müll rausstellen heute Abend",
        "Montag Abend Kinokarten kaufen",
        "Reminder: tomorrow morning hand in the papers",
        "Call mom tonight",
    ])
    func noInventedTime(raw: String) throws {
        let match = try #require(DueDateRule.match(in: raw, reference: Self.wednesday))
        #expect(match.hasTime == false)
    }

    @Test("„heute Morgen“ ist heute, nicht morgen")
    func heuteMorgenIsToday() throws {
        let match = try #require(DueDateRule.match(in: "Pakete wegbringen heute Morgen", reference: Self.wednesday))
        #expect(Calendar.current.isDate(match.guess.value, inSameDayAs: Self.wednesday))
    }
}
