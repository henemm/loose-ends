import Foundation
import Testing
@testable import LooseEnds

/// Two rule words sat in rule code, not in the language packs (Epic #750, Schnitt-Lücke aus der DoD, 2026-11-02):
/// "the day after tomorrow" was compared with a literal in `DateExpressionParser`, and the filler words of
/// `ContextWordLearning` were one hard-coded set for both languages. Both now come from `LanguagePack`.
@Suite("Regelwörter kommen aus den Sprachpaketen")
struct RuleWordsInPacksTests {
    @Test("„the day after tomorrow“ liest die Datumsregel aus dem Paket")
    func dayAfterTomorrowComesFromThePack() {
        withPacks([LanguagePack.test]) {
            #expect(DateExpressionParserTests.expression("Pick it up zday zafter zmorrow") == .offsetDays(2))
            #expect(DateExpressionParserTests.expression("Pick it up zmorrow") == nil)
        }
        #expect(LanguagePacks.dayAfterTomorrowPhrases == [["day", "after", "tomorrow"]])
    }

    @Test("Englisch trägt die Phrase, Deutsch nicht (übermorgen ist ein Wort in relativeDays)")
    func onlyEnglishNamesTheDayInWords() {
        #expect(LanguagePack.english.dayAfterTomorrow == ["day", "after", "tomorrow"])
        #expect(LanguagePack.german.dayAfterTomorrow.isEmpty)
    }

    @Test("Füllwörter kommen aus den aktiven Paketen, nicht aus einer festen Liste")
    func fillerWordsComeFromThePack() {
        withPacks([LanguagePack.test]) {
            #expect(ContextWordLearning.fillerWords == ["zfill"])
        }
        #expect(ContextWordLearning.fillerWords.contains("morgen"))
        #expect(ContextWordLearning.fillerWords.contains("tomorrow"))
    }

    @Test("Jedes Paket trägt seine eigenen Füllwörter")
    func eachPackHasItsOwnFillers() {
        #expect(LanguagePack.german.fillerWords.contains("morgen"))
        #expect(!LanguagePack.german.fillerWords.contains("tomorrow"))
        #expect(LanguagePack.english.fillerWords.contains("tomorrow"))
        #expect(!LanguagePack.english.fillerWords.contains("morgen"))
    }
}
