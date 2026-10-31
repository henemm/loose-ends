import Testing
@testable import LooseEnds

/// Form of the language packs (#751, Epic #750): which languages ship, that each pack is whole,
/// that the merged views hold both languages and that every word is stored folded.
@Suite("Sprachpakete: Form")
struct LanguagePackTests {
    @Test("shipped sind genau Englisch und Deutsch")
    func shippedIsEnglishAndGerman() {
        #expect(LanguagePacks.shipped.map(\.code) == ["en", "de"])
    }

    @Test("Jedes Pack kennt sieben Wochentage und zwölf Monate")
    func everyPackHasSevenWeekdaysAndTwelveMonths() {
        for pack in LanguagePacks.shipped {
            #expect(Set(pack.weekdays.values) == Set(1...7), "\(pack.code): Wochentage")
            #expect(Set(pack.months.values) == Set(1...12), "\(pack.code): Monate")
        }
    }

    @Test("Die zusammengeführte Sicht hält beide Sprachen")
    func mergedViewsHoldBothLanguages() {
        #expect(LanguagePacks.weekdays["montag"] == 2)
        #expect(LanguagePacks.weekdays["monday"] == 2)
        #expect(LanguagePacks.months["marz"] == 3)
        #expect(LanguagePacks.months["march"] == 3)
        #expect(LanguagePacks.repetitions.contains("every"))
        #expect(LanguagePacks.repetitions.contains("jeden"))
    }

    @Test("Jedes Wort jedes Packs ist gefaltet")
    func wordsAreFolded() {
        for pack in LanguagePacks.shipped {
            let words = Array(pack.numbers.keys) + pack.weekdays.keys + pack.months.keys + pack.relativeDays.keys
                + pack.nextWords + pack.dayUnits + pack.weekUnits + pack.dayPrepositions
                + pack.ordinalSuffixes + pack.repetitions
            for word in words {
                #expect(ExpressionText.folded(word) == word, "\(pack.code): \(word) ist nicht gefaltet")
            }
        }
    }

    @Test("Jedes Pack nennt Einheiten und Dauer-Wendungen")
    func everyPackNamesUnits() {
        for pack in LanguagePacks.shipped {
            #expect(!pack.hourUnits.isEmpty, "\(pack.code): hourUnits")
            #expect(!pack.minuteUnits.isEmpty, "\(pack.code): minuteUnits")
            #expect(!pack.durationPhrases.isEmpty, "\(pack.code): durationPhrases")
        }
    }

    @Test("Dauer-Wendungen kommen längste zuerst")
    func durationPhrasesLongestFirst() {
        let counts = LanguagePacks.durationPhrases.map { $0.phrase.split(separator: " ").count }
        #expect(counts == counts.sorted(by: >))
        let offsets = LanguagePacks.spokenOffsets.map(\.words.count)
        #expect(offsets == offsets.sorted(by: >))
    }

    @Test("Jedes Pack kennt Verneinung und die ausdrücklichen Signale")
    func everyPackHasNegationAndSignals() {
        for pack in LanguagePacks.shipped {
            #expect(!pack.negations.isEmpty, "\(pack.code): negations")
            #expect(!(pack.importanceWords["explicit"] ?? []).isEmpty, "\(pack.code): Wichtigkeit ausdrücklich")
            #expect(!(pack.urgencyWords["immediacy"] ?? []).isEmpty, "\(pack.code): Dringlichkeit ausdrücklich")
        }
    }

    @Test("Jedes Pack hat Ortswendungen für beide Plätze")
    func everyPackHasPlacePhrasesForBothSlots() {
        for pack in LanguagePacks.shipped {
            for slot in SavedPlaces.Slot.allCases {
                #expect(pack.placePhrases.contains { $0.slot == slot }, "\(pack.code): \(slot)")
            }
        }
    }
}
