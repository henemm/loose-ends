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
    @Test("Eine Wiederholung mit Uhrzeit liefert kein Ergebnis (AC-6)")
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

    /// Donnerstag, 12. März 2026, 10:01:30 in Berlin: der Moment der Erfassung aus Hennings Bildschirmfoto (#679).
    static func at(hour: Int, minute: Int, second: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: hour, minute: minute, second: second))!
    }

    static func stamp(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return String(format: "%04d-%02d-%02d %02d:%02d:%02d", parts.year!, parts.month!, parts.day!,
                      parts.hour!, parts.minute!, parts.second!)
    }

    static func match(_ text: String, at reference: Date) -> DueDateRule.Match? {
        DueDateRule.match(in: text, reference: reference, calendar: calendar)
    }

    /// Henning, 2026-10-25 (#679): „Erinnere mich zu Hause daran, Donauwellen rausnehmen um 10:00 Uhr“
    /// bekam kein Datum. Eine Uhrzeit ohne Tag gilt heute, solange sie noch kommt, sonst morgen.
    @Test("Uhrzeit ohne Tag: heute, solange sie noch kommt, sonst morgen (#679)", arguments: [
        ("Donauwellen rausnehmen um 10:00 Uhr", 9, 55, "2026-03-12 10:00:00"),
        ("Donauwellen rausnehmen um 10:00 Uhr", 10, 0, "2026-03-12 10:00:00"),
        ("Donauwellen rausnehmen um 10:00 Uhr", 10, 1, "2026-03-13 10:00:00"),
        ("Treffen um 15 Uhr", 10, 1, "2026-03-12 15:00:00"),
        ("Oma anrufen 18:45", 10, 1, "2026-03-12 18:45:00"),
        ("Um halb acht die Kinder abholen", 10, 1, "2026-03-13 07:30:00"),
        ("Call the bank at 9am", 10, 1, "2026-03-13 09:00:00"),
        ("Um acht Uhr die Tabletten", 10, 1, "2026-03-13 08:00:00"),
    ])
    func timeWithoutDay(text: String, hour: Int, minute: Int, expected: String) throws {
        let match = try #require(Self.match(text, at: Self.at(hour: hour, minute: minute, second: 30)))
        #expect(Self.stamp(match.guess.value) == expected)
        #expect(match.hasTime)
        #expect(match.guess.confidence == 1.0)
        #expect(match.guess.reason == DueDateRule.timeOnlyReason)
    }

    /// Ohne Tag reicht das „um“ vor der Zahl nicht: „um 5 Euro bitten“ ist keine Uhrzeit.
    @Test("Ohne Tag braucht die Uhrzeit ihr eigenes Wort: Uhr, Doppelpunkt, am/pm (#679)", arguments: [
        "Andreas um 5 Euro bitten",
        "Die Bestellung um 12 erhöhen",
        "Jeden Tag um 7 Uhr die Tabletten nehmen",
        "Every day at 8pm take the medication",
    ])
    func weakTimeWithoutDayYieldsNothing(text: String) {
        #expect(Self.match(text, at: Self.at(hour: 10, minute: 1)) == nil, "\(text)")
    }

    /// „In 1 Stunde“ (Henning, 2026-10-25, #679): ab dem Moment der Erfassung, auf die Minute.
    @Test("in N Stunden oder Minuten zählt ab der Erfassung (#679)", arguments: [
        ("In 1 Stunde Donauwellen rausnehmen", 60),
        ("Donauwellen in einer Stunde rausnehmen", 60),
        ("in 2 Stunden den Ofen ausmachen", 120),
        ("In 20 Minuten Wäsche aufhängen", 20),
        ("in einer halben Stunde losfahren", 30),
        ("in einer Viertelstunde Tee abgießen", 15),
        ("in anderthalb Stunden Brot rausholen", 90),
        ("Check the oven in an hour", 60),
        ("Leave in half an hour", 30),
        ("Call back in 10 minutes", 10),
    ])
    func relativeTime(text: String, minutes: Int) throws {
        let reference = Self.at(hour: 10, minute: 1, second: 30)
        let match = try #require(Self.match(text, at: reference), "\(text)")
        let expected = Self.calendar.date(byAdding: .minute, value: minutes, to: Self.at(hour: 10, minute: 1))!
        #expect(match.guess.value == expected, "\(text): \(Self.stamp(match.guess.value))")
        #expect(match.hasTime)
        #expect(match.guess.reason == DueDateRule.offsetReason)
    }

    @Test("Was kein Zeitpunkt ist, bleibt ohne Datum: Länge, Wiederholung, Raum (#679)", arguments: [
        "20 Minuten Steuerberater beantworten",
        "Eine Stunde Klavier üben",
        "Jeden Tag in 10 Minuten aufräumen",
        "Die Akte liegt in 3 Stapeln",
    ])
    func noRelativeTime(text: String) {
        #expect(Self.match(text, at: Self.at(hour: 10, minute: 1)) == nil, "\(text)")
    }

    @Test("Die neuen Begründungssätze sind im deutschen Bundle übersetzt (#679)")
    func newReasonsAreTranslated() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let germanBundle = try #require(Bundle(path: path))
        for key in ["From “in” plus hours or minutes in the note.",
                    "From the time in the note: today, or tomorrow once it has passed."] {
            #expect(germanBundle.localizedString(forKey: key, value: key, table: nil) != key, "\(key)")
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

    /// Der Begründungssatz erscheint im Aufgaben-Detail und im Feld-Editor (`TaskDetailView`,
    /// `FieldEditorView`) über `revision.reason`. Bisher fehlten die deutschen Übersetzungen im
    /// Katalog komplett — auf einem deutschen Gerät fiel die Anzeige auf den englischen
    /// Schlüsseltext zurück (#98). `LooseEndsTests` läuft mit `TEST_HOST` gegen `LooseEnds.app`,
    /// `Bundle.main` im Testprozess ist damit der App-Bundle — der Test liest die deutsche
    /// Übersetzung direkt aus dem gebauten `de.lproj`-Bundle, unabhängig von der
    /// Simulator-/Geräte-Systemsprache. Die Schlüssel sind wörtlich aus `DueDateRule.swift`
    /// kopiert (Anführungszeichen exakt), sonst prüft der Test den falschen Katalogeintrag.
    @Test("Alle neun Begründungssätze sind im deutschen Bundle übersetzt (#98, AC-1)")
    func reasonsAreTranslatedToGerman() throws {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let germanBundle = try #require(Bundle(path: path))

        let expressionKinds: [(name: String, key: String)] = [
            ("offsetDays", "From a day count in the note."),
            ("weekday", "From the weekday named in the note."),
            ("weekdayNextWeek", "From a weekday of next week in the note."),
            ("weekdayEitherNext", "From “next” plus a weekday in the note: the following week."),
            ("endOfMonth", "From “end of the month” in the note."),
            ("dayOfMonth", "From the day of the month in the note."),
            ("weekend", "From “weekend” in the note: Saturday."),
            ("monthRange", "From “next month” in the note: the first of that month."),
            ("dayAndMonth", "From the day and month in the note."),
        ]

        for (name, key) in expressionKinds {
            let translated = germanBundle.localizedString(forKey: key, value: key, table: nil)
            #expect(translated != key, "\(name): \(key)")
        }
    }
}
