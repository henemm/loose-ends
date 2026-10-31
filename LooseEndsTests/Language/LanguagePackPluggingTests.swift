import Foundation
import Testing
@testable import LooseEnds

/// #755 (Epic #750): ein Pack mit erfundenen Wörtern wird eingehängt, und jede Regel versteht es, ohne dass eine
/// Regeldatei etwas davon weiß. Ohne das Pack versteht keine Regel den Satz.
@Suite("Sprachpakete sind steckbar")
struct LanguagePackPluggingTests {
    static let sentence = "grassle cutting byy snib att duo klok, takes halfquarnt, zingo, at florp"
    static let available = ["Garden"]

    @Test("Ein eingehängtes Testpaket setzt alle Felder des Satzes")
    func packSetsEveryField() {
        let calendar = CorpusTests.calendar
        let reference = CorpusTests.reference
        let text = Self.sentence
        withPacks(LanguagePacks.shipped + [.test]) {
            let date = DateExpressionParser(calendar: calendar).date(in: text, reference: reference)
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: reference)
            #expect(date != nil && tomorrow != nil && calendar.isDate(date ?? reference, inSameDayAs: tomorrow ?? reference),
                    "Datum: \(String(describing: date)), erwartet Bezugstag + 1")
            let time = TimeExpressionParser().time(in: text)
            #expect(time?.hour == 2 && time?.minute == 0, "Zeit: \(String(describing: time)), erwartet 02:00")
            #expect(DurationRule.match(in: text)?.guess.value == .minutes30, "Dauer: erwartet minutes30")
            #expect(ImportanceUrgencyRule.matchImportance(in: text)?.value == .high, "Wichtigkeit: erwartet high")
            #expect(PlaceWordRule.slot(in: text) == .home, "Ort: erwartet home")
            #expect(ContextWordRule.match(in: text, available: Self.available)?.value == ["Garden"], "Etikett: erwartet Garden")
            let title = TitleRule.title(from: text, reference: reference, calendar: calendar) ?? ""
            #expect(!title.contains("snib") && !title.contains("byy") && !title.contains("zingo"),
                    "Titel: Datum, Einleitung und Wichtigkeitswort bleiben draußen, ist: \(title)")
            #expect(title.contains("grassle"), "Titel: der Inhalt bleibt, ist: \(title)")
        }
    }

    @Test("Das Testpaket versteht auch Dringlichkeit")
    func packSetsUrgency() {
        withPacks(LanguagePacks.shipped + [.test]) {
            #expect(ImportanceUrgencyRule.matchUrgency(in: "grassle cutting zoom")?.value == .high, "Dringlichkeit: erwartet high")
        }
    }

    @Test("Ohne das Testpaket setzt derselbe Satz nichts")
    func withoutTestPackNothingIsSet() {
        let calendar = CorpusTests.calendar
        let reference = CorpusTests.reference
        let text = Self.sentence
        #expect(DateExpressionParser(calendar: calendar).date(in: text, reference: reference) == nil, "Datum")
        #expect(TimeExpressionParser().time(in: text) == nil, "Zeit")
        #expect(DurationRule.match(in: text) == nil, "Dauer")
        #expect(ImportanceUrgencyRule.matchImportance(in: text) == nil, "Wichtigkeit")
        #expect(PlaceWordRule.slot(in: text) == nil, "Ort")
        #expect(ContextWordRule.match(in: text, available: Self.available) == nil, "Etikett")
    }

    @Test("withPacks stellt die Pakete auch nach einem Fehler zurück")
    func activeIsRestoredAfterThrow() {
        struct Boom: Error {}
        let before = LanguagePacks.active.map(\.code)
        #expect(throws: Boom.self) {
            try withPacks([.test]) {
                #expect(LanguagePacks.active.map(\.code) == ["zz"], "innerhalb: nur das Testpaket")
                throw Boom()
            }
        }
        #expect(LanguagePacks.active.map(\.code) == before, "nach dem Fehler wieder die ausgelieferten Pakete")
    }
}
