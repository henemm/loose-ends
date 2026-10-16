import Foundation
import Testing
@testable import LooseEnds

/// A stated length, sorted into the next bucket up (#441). Never guessed.
@Suite("Duration rule") struct DurationRuleTests {
    static func bucket(_ text: String) -> DurationBucket? { DurationRule.match(in: text)?.guess.value }

    @Test("Numbers with a unit, German and English")
    func numbers() {
        #expect(Self.bucket("dauert 5 Minuten") == .minutes5)
        #expect(Self.bucket("10 min") == .minutes15)
        #expect(Self.bucket("20 Minuten") == .minutes30)
        #expect(Self.bucket("45 minutes") == .hour1)
        #expect(Self.bucket("1,5 Std") == .hours2plus)
        #expect(Self.bucket("2h") == .hours2plus)
        #expect(Self.bucket("1 hour") == .hour1)
    }

    @Test("Spoken lengths")
    func phrases() {
        #expect(Self.bucket("eine halbe Stunde") == .minutes30)
        #expect(Self.bucket("eine Viertelstunde") == .minutes15)
        #expect(Self.bucket("eine Stunde") == .hour1)
        #expect(Self.bucket("half an hour") == .minutes30)
    }

    @Test("A point in time or no length is no duration")
    func misses() {
        #expect(Self.bucket("in 2 Stunden erinnern") == nil)
        #expect(Self.bucket("nach 10 Minuten") == nil)
        #expect(Self.bucket("Stundenplan drucken") == nil)
        #expect(Self.bucket("um 15 Uhr") == nil)
        #expect(Self.bucket("Hecke schneiden") == nil)
    }

    @Test("The range covers the words that said it")
    func range() throws {
        let text = "Rasen mähen, 30 Minuten"
        let hit = try #require(DurationRule.match(in: text))
        #expect(text[hit.range] == "30 Minuten")
    }
}
