import Foundation
import Testing
@testable import LooseEnds

/// Die Wortliste lernt aus eigenen Zuordnungen (#233): Ein Wort kommt zu einem Kontext, sobald es in
/// mindestens N verschiedenen Rohtexten steht, die der Nutzer diesem Kontext gegeben hat, und in
/// keinem eines anderen Kontexts. Füllwörter nie; vom Nutzer gelöschte Wörter nie wieder.
@Suite("Regelschritt: Wortliste lernt aus eigenen Zuordnungen")
struct ContextWordLearningTests {
    private typealias Assignment = ContextWordLearning.Assignment

    private func learn(_ assignments: [Assignment], n: Int = 2,
                       forgotten: [String: Set<String>] = [:]) -> [String: Set<String>] {
        ContextWordLearning.learn(from: assignments, minimumCount: n, forgotten: forgotten)
    }

    @Test("Ein Wort kommt in die Liste, sobald es N-mal beim selben Kontext steht")
    func learnsAtN() {
        let once = [Assignment(rawText: "Kirschbaum schneiden", contexts: ["Garten"])]
        #expect(learn(once).isEmpty)

        let twice = once + [Assignment(rawText: "Kirschbaum gießen", contexts: ["Garten"])]
        #expect(learn(twice) == ["Garten": ["kirschbaum"]])
        // Mit N = 1 reicht jede eigene Zuordnung, und jedes Inhaltswort kommt hinein.
        #expect(learn(twice, n: 1)["Garten"]?.isSuperset(of: ["kirschbaum", "schneiden"]) == true)
    }

    @Test("Derselbe Rohtext zehnmal ist eine Zuordnung, nicht zehn")
    func repeatedTextCountsOnce() {
        let same = Array(repeating: Assignment(rawText: "Kirschbaum schneiden", contexts: ["Garten"]),
                         count: 10)
        #expect(learn(same).isEmpty)
    }

    @Test("Konflikt: ein Wort bei zwei Kontexten gehört keinem")
    func conflictBetweenTwoContexts() {
        let assignments = [
            Assignment(rawText: "Kirschbaum schneiden", contexts: ["Garten"]),
            Assignment(rawText: "Kirschbaum gießen", contexts: ["Garten"]),
            Assignment(rawText: "Rechnung Kirschbaum überweisen", contexts: ["Computer"]),
            Assignment(rawText: "Rechnung Strom prüfen", contexts: ["Computer"]),
        ]
        let learned = learn(assignments)
        #expect(learned["Garten"] == nil)
        #expect(learned["Computer"] == ["rechnung"])
    }

    @Test("Eine Aufgabe mit zwei Kontexten macht ihre Wörter zum Konflikt")
    func oneTaskWithTwoContextsIsAConflict() {
        let assignments = [
            Assignment(rawText: "Steuerberater anrufen", contexts: ["Telefon", "Computer"]),
            Assignment(rawText: "Steuerberater mailen", contexts: ["Telefon", "Computer"]),
        ]
        #expect(learn(assignments).isEmpty)
    }

    @Test("Ein gelöschtes Wort wird für diesen Kontext nie wieder gelernt")
    func forgottenWordStaysOut() {
        let assignments = [
            Assignment(rawText: "Kirschbaum Rasen", contexts: ["Garten"]),
            Assignment(rawText: "Kirschbaum Rasen mähen", contexts: ["Garten"]),
            Assignment(rawText: "Kirschbaum Rasen düngen", contexts: ["Garten"]),
        ]
        #expect(learn(assignments) == ["Garten": ["kirschbaum", "rasen"]])

        let learned = learn(assignments, forgotten: ["Garten": ["kirschbaum"]])
        #expect(learned == ["Garten": ["rasen"]])
        // Gelöscht heißt nur für diesen Kontext: der Eintrag eines anderen Kontexts bleibt wirkungslos.
        #expect(learn(assignments, forgotten: ["Haus": ["rasen"]]) == ["Garten": ["kirschbaum", "rasen"]])
    }

    @Test("Füllwörter, Zahlen und kurze Wörter werden nie gelernt")
    func fillerWordsAreNeverLearned() {
        let assignments = [
            Assignment(rawText: "Morgen bitte 2024 die Hecke", contexts: ["Garten"]),
            Assignment(rawText: "morgen bitte 2024 die Hecke", contexts: ["Garten"]),
            Assignment(rawText: "Morgen bitte 2024 die Hecke schneiden", contexts: ["Garten"]),
        ]
        #expect(learn(assignments) == ["Garten": ["hecke"]])
        #expect(ContextWordLearning.candidateWords(in: "Über die Brücke am Montag") == ["brucke"])
    }

    @Test("Gelernte Wörter treffen ganze Wörter, groß, klein und mit Umlaut")
    func matchesLearnedWords() {
        let learned: [String: Set<String>] = ["Garten": ["kirschbaum"], "Computer": ["rechnung"]]
        #expect(ContextWordLearning.match(in: "KIRSCHBAUM düngen", learned: learned) == ["Garten"])
        #expect(ContextWordLearning.match(in: "Rechnung für den Kirschbaum", learned: learned)
            == ["Computer", "Garten"])
        #expect(ContextWordLearning.match(in: "Kirschbaumholz holen", learned: learned).isEmpty)
        #expect(ContextWordLearning.match(in: "Brücke prüfen", learned: ["Haus": ["brucke"]]) == ["Haus"])
    }
}
