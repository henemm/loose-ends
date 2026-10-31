import Foundation
import Testing
@testable import LooseEnds

/// #755 (Epic #750): was jedes Sprachpaket einhalten muss, damit die zusammengeführten Sichten stimmen. Die Schleifen
/// laufen über die ausgelieferten Pakete und das Testpaket `zz`; ein neues Paket in `shipped` fällt ohne weiteres darunter.
@Suite("Sprachpakete halten die Regeln ein")
struct LanguagePackConformanceTests {
    static var packs: [LanguagePack] { LanguagePacks.shipped + [.test] }

    /// Wörter, die in zwei Paketen mit verschiedener Rolle stehen dürfen, mit Begründung. Heute gibt es keine:
    /// jedes Wort, das zwei ausgelieferte Pakete teilen (`april`, `h`, `in`, `min` …), hat in beiden dieselbe Rolle.
    static let allowedCrossings: [String: String] = [:]

    /// Tabellen Wort → Zahl: ein Wort darf in zwei Paketen nicht zwei Werte haben (die Sichten brechen sonst ab).
    static var valueTables: [(name: String, table: KeyPath<LanguagePack, [String: Int]>)] { [
        ("numbers", \.numbers), ("weekdays", \.weekdays), ("months", \.months), ("relativeDays", \.relativeDays),
        ("spelledHours", \.spelledHours), ("durationPhrases", \.durationPhrases),
    ] }

    /// Listen aus gefalteten Wörtern (`ExpressionText.folded`), wie die Datums- und Zeitregeln sie vergleichen.
    static var wordLists: [(name: String, words: KeyPath<LanguagePack, [String]>)] { [
        ("nextWords", \.nextWords), ("dayUnits", \.dayUnits), ("weekUnits", \.weekUnits),
        ("dayPrepositions", \.dayPrepositions), ("ordinalSuffixes", \.ordinalSuffixes), ("repetitions", \.repetitions),
        ("timeCues", \.timeCues), ("clockWords", \.clockWords), ("timeArticles", \.timeArticles),
        ("articleCues", \.articleCues), ("hourUnits", \.hourUnits), ("abbreviatedHourUnits", \.abbreviatedHourUnits),
        ("minuteUnits", \.minuteUnits), ("pointInTime", \.pointInTime), ("titleLeadIns", \.titleLeadIns),
        ("titleConnectors", \.titleConnectors),
    ] }

    /// Alle gefalteten Wörter eines Pakets, je Feld; Zahlentabellen mit ihrem Wert als Rolle.
    static func foldedWords(of pack: LanguagePack) -> [(field: String, word: String, role: String)] {
        var result: [(field: String, word: String, role: String)] = []
        for (name, table) in valueTables {
            for (word, value) in pack[keyPath: table] { result.append((name, word, "\(name)=\(value)")) }
        }
        for (name, words) in wordLists {
            for word in pack[keyPath: words] { result.append((name, word, name)) }
        }
        for word in pack.spokenOffsets.keys.joined() { result.append(("spokenOffsets", word, "spokenOffsets")) }
        for phrase in pack.placePhrases {
            for word in phrase.words { result.append(("placePhrases", word, "placePhrases")) }
        }
        return result
    }

    @Test("Kein Wort steht in zwei Paketen mit verschiedenem Wert")
    func noWordHasTwoValues() {
        for (name, table) in Self.valueTables {
            for (index, first) in Self.packs.enumerated() {
                for second in Self.packs[(index + 1)...] {
                    for (word, value) in first[keyPath: table] {
                        if let other = second[keyPath: table][word] {
                            #expect(other == value, "\(name): „\(word)“ ist \(value) in \(first.code), \(other) in \(second.code)")
                        }
                    }
                }
            }
        }
        for (index, first) in Self.packs.enumerated() {
            for second in Self.packs[(index + 1)...] {
                for (words, minutes) in first.spokenOffsets {
                    if let other = second.spokenOffsets[words] {
                        #expect(other == minutes, "spokenOffsets: „\(words.joined(separator: " "))“ in \(first.code) und \(second.code) verschieden")
                    }
                }
            }
        }
    }

    /// Wo ein Paket eine Tabelle leer lassen darf (die Sprache kennt die Sache nicht).
    static let allowedEmpty: [String: Set<String>] = [
        "en": ["dayPrepositions", "clockWords", "timeArticles", "articleCues", "spelledHours"],
        "de": ["ordinalSuffixes", "abbreviatedHourUnits"],
    ]

    @Test("Keine Tabelle ist leer, außer wo die Sprache die Sache nicht kennt")
    func noTableIsEmpty() {
        for pack in Self.packs {
            for child in Mirror(reflecting: pack).children {
                guard let label = child.label, label != "code", label != "name",
                      let collection = child.value as? any Collection else { continue }
                if collection.isEmpty {
                    #expect(Self.allowedEmpty[pack.code]?.contains(label) == true, "\(pack.code): \(label) ist leer")
                }
            }
            #expect(!pack.code.isEmpty && !pack.name.isEmpty, "\(pack.code): Code und Name gesetzt")
        }
    }

    @Test("Jedes Wort ist gefaltet, ohne Leerzeichen am Rand und nicht leer")
    func everyWordIsFolded() {
        for pack in Self.packs {
            for entry in Self.foldedWords(of: pack) {
                #expect(!entry.word.isEmpty, "\(pack.code): \(entry.field) enthält ein leeres Wort")
                #expect(entry.word == entry.word.trimmingCharacters(in: .whitespaces),
                        "\(pack.code): \(entry.field): „\(entry.word)“ hat Leerzeichen am Rand")
                #expect(ExpressionText.folded(entry.word) == entry.word,
                        "\(pack.code): \(entry.field): „\(entry.word)“ ist nicht gefaltet (\(ExpressionText.folded(entry.word)))")
            }
        }
    }

    @Test("Ein Wort mit zwei Rollen in zwei Paketen steht in der Liste der erlaubten Kreuzungen")
    func crossingsAreListed() {
        var roles: [String: [String: Set<String>]] = [:]
        for pack in Self.packs {
            // Wörter von Wendungen („at home“) sind keine Rollen eines Einzelworts und gelten hier nicht.
            for entry in Self.foldedWords(of: pack) where entry.field != "placePhrases" && entry.field != "spokenOffsets" {
                roles[entry.word, default: [:]][pack.code, default: []].insert(entry.role)
            }
        }
        for (word, perPack) in roles where perPack.count >= 2 {
            let distinct = Set(perPack.values)
            #expect(distinct.count == 1 || Self.allowedCrossings[word] != nil,
                    "„\(word)“ hat in den Paketen \(perPack.keys.sorted()) verschiedene Rollen \(perPack) und steht nicht in allowedCrossings")
        }
    }
}
