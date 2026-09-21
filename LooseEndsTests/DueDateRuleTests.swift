import Foundation
import Testing
@testable import LooseEnds

/// Der Regelschritt für das Fälligkeitsdatum (#95, Schnitt 2b): er setzt den gemessenen
/// Regelparser (#92: 99,3 % exakt, 0 % erfunden) zu einem einzigen `Date` zusammen und liefert
/// das Guess-Tripel, das `EnrichmentWriter` schon vom Modell kennt — Wert, Konfidenz, Grund.
/// Der Baustein ist rein: kein Modell, keine Persistenz, kein `#if canImport(FoundationModels)`.
@Suite("Regelschritt: Fälligkeitsdatum")
struct DueDateRuleTests {
    /// Donnerstag, 12. März 2026, Europe/Berlin — derselbe Anker wie in `CorpusTests`.
    static let reference = CorpusTests.reference
    static let calendar = CorpusTests.calendar

    static func match(_ text: String) -> DueDateRule.Match? {
        DueDateRule.match(in: text, reference: reference, calendar: calendar)
    }

    static func day(_ date: Date) -> String {
        DateTitleReportTests.day(date, calendar)
    }

    @Test("Datum und Uhrzeit werden zu einem Zeitpunkt zusammengesetzt (AC-5)")
    func combinesDateAndTime() throws {
        let match = try #require(Self.match("Nächsten Freitag den Zuschuss beantragen, um 14 Uhr"))

        #expect(Self.day(match.guess.value) == "2026-03-20")
        #expect(Self.calendar.component(.hour, from: match.guess.value) == 14)
        #expect(Self.calendar.component(.minute, from: match.guess.value) == 0)
        #expect(match.hasTime)
        #expect(match.guess.confidence == 1.0)
        #expect(!match.guess.reason.isEmpty)
    }

    /// Ein Regel-Treffer ist deterministisch da oder nicht — eine geschätzte Zwischenzahl wäre
    /// eine erfundene Zahl. 1.0 liegt über der Schwelle 0.6 des `EnrichmentWriter` (AC-9).
    @Test("Ein Regel-Treffer trägt immer die Konfidenz 1.0 (AC-9)")
    func confidenceIsAlwaysOne() {
        let sentences = [
            "Morgen beim Zahnarzt einen Termin machen",
            "Am Montag die Bewerbung abschicken",
            "Ende des Monats die Miete überweisen",
            "Am 4. Mai die Anmeldung für den Kurs abgeben",
        ]
        for sentence in sentences {
            #expect(Self.match(sentence)?.guess.confidence == 1.0, "\(sentence)")
        }
    }

    @Test("Ohne Uhrzeit bleibt es der Tagesbeginn und hasTime falsch (AC-5)")
    func dateWithoutTimeStaysAtStartOfDay() throws {
        let match = try #require(Self.match("Nächsten Freitag den Zuschuss beantragen"))

        #expect(Self.day(match.guess.value) == "2026-03-20")
        #expect(match.hasTime == false)
        #expect(match.guess.value == Self.calendar.startOfDay(for: match.guess.value))
    }

    /// `TaskItem.dueHasTime` ist ein Flag neben `dueDate`, kein eigener Zeit-Slot: eine Uhrzeit
    /// ohne Tag hat im Produktschema keinen Platz. Die Wiederholungs-Sperre des Datumsparsers
    /// verhindert ohnehin, dass „jeden Tag" einen Tag benennt (#92).
    @Test("Uhrzeit ohne erkanntes Datum liefert kein Ergebnis (AC-6)")
    func timeWithoutDateYieldsNothing() {
        let repetitions = [
            "Jeden Tag um 7 Uhr die Tabletten nehmen",
            "Werktags um 6:30 den Wecker für die Schule stellen",
            "Every day at 8pm take the medication",
        ]
        for sentence in repetitions {
            #expect(Self.match(sentence) == nil, "\(sentence) ist eine Wiederholung, kein Termin")
        }
    }

    @Test("Ein Satz ohne Zeitausdruck liefert kein Ergebnis (AC-6)")
    func sentenceWithoutExpressionYieldsNothing() {
        let traps = [
            "Rechnung 4711 bei der Buchhaltung reklamieren",
            "250 Euro an den Verein überweisen",
            "Andreas wegen Zimmer 12 anrufen",
            "Svens Geburtstag nicht vergessen",
        ]
        for sentence in traps {
            #expect(Self.match(sentence) == nil, "\(sentence) darf keinen Termin ergeben")
        }
    }

    /// Der Grund erscheint dem Nutzer im Aufgaben-Detail und im Feld-Editor. Bisher schrieb ihn
    /// das Modell in der Sprache der Notiz; die Regel liefert einen eigenen, lokalisierten Satz —
    /// und je Ausdrucksart einen anderen, damit „Ende des Monats" nicht wie „am Montag" begründet
    /// wird (AC-5).
    @Test("Jede Ausdrucksart bekommt einen eigenen, nicht-leeren Grund (AC-5)")
    func reasonIsDistinctPerExpressionKind() throws {
        let sentences = [
            "Morgen beim Zahnarzt einen Termin machen",                     // offsetDays
            "Am Montag die Bewerbung abschicken",                           // weekday
            "Nächste Woche Freitag die Steuererklärung einreichen",         // weekdayNextWeek
            "Nächsten Freitag den Zuschuss beantragen",                     // weekdayEitherNext
            "Ende des Monats die Miete überweisen",                         // endOfMonth
            "Bis zum 15. die Unterlagen einreichen",                        // dayOfMonth
            "Am Wochenende die Garage aufräumen",                           // weekend
            "Nächsten Monat die Versicherung prüfen",                       // monthRange
            "Am 4. Mai die Anmeldung für den Kurs abgeben",                 // dayAndMonth
        ]

        var reasons: [String] = []
        for sentence in sentences {
            let match = try #require(Self.match(sentence), "\(sentence) muss einen Termin ergeben")
            #expect(!match.guess.reason.isEmpty, "\(sentence) braucht einen Grund")
            reasons.append(match.guess.reason)
        }

        #expect(Set(reasons).count == sentences.count, "jede Ausdrucksart begründet sich anders")
    }

    /// Der Baustein muss ohne Modell und ohne Plattform-Klammer kompilieren: `Shared/` geht in
    /// App, Watch, Widgets und Share-Erweiterung, und `FoundationModels` gibt es auf der Watch
    /// nicht. Liegt der Typ im Produktmodul, ist das bewiesen (#95, AC-1).
    @Test("Der Regelschritt liegt im Produktmodul")
    func ruleLivesInProductModule() {
        #expect(String(reflecting: DueDateRule.self).hasPrefix("LooseEnds."))
    }
}
