import Foundation

/// The rule step for contexts (#232, after #215): a word list per default context instead of the
/// model, which guessed "Unterwegs" for a tax letter and "Haus" on the next try. A hit sets the
/// context with the rule origin; no hit leaves the field empty — never a default (Henning: empty
/// beats a guess). Rules before the model (CLAUDE.md).
///
/// The lists are short on purpose: only words that hardly ever mean anything else, because a wrong
/// rule hit carries the » « of "read from your words" and weighs more than an empty field. Every
/// context, a user-made one too, also matches its own name ("Keller" in the note → Keller).
///
/// Pure `Foundation`, like `ImportanceUrgencyRule`: `Shared/` compiles into the watch and widgets.
enum ContextWordRule {
    /// A word is there or not; an in-between number would be invented, as in `DueDateRule`.
    static let confidence = 1.0

    /// The default contexts by their English and German names (`TaskContext.defaultNameKeys` and
    /// their translations), each with its words. A renamed default context keeps only its new name.
    private static let lists: [(names: [String], words: [String])] = [
        (["Computer"],
         ["computer", "laptop", "rechner", "drucker", "ausdrucken", "drucken", "website", "webseite",
          "online", "backup", "software", "installieren", "printer", "print out", "install", "spreadsheet"]),
        (["Phone", "Telefon"],
         ["anruf", "anrufen", "telefonieren", "telefonat", "zurückrufen", "rückruf",
          "call", "phone", "ring back"]),
        (["Home", "Haus"],
         ["putzen", "staubsaugen", "aufräumen", "wäsche", "waschmaschine", "bügeln", "spülmaschine",
          "geschirr", "keller", "dachboden", "glühbirne", "vacuum", "laundry", "dishes", "tidy up"]),
        (["Garden", "Garten"],
         ["rasen", "hecke", "unkraut", "beet", "beete", "kompost", "laub", "umtopfen", "einpflanzen",
          "lawn", "hedge", "weeds", "mow"]),
        (["Errands", "Besorgung"],
         ["kaufen", "einkauf", "einkaufen", "besorgen", "abholen", "apotheke", "supermarkt", "baumarkt",
          "buy", "pick up", "groceries", "pharmacy"]),
        (["Out and about", "Unterwegs"],
         ["unterwegs", "tanken", "tankstelle", "zur post", "zur bank", "waschanlage",
          "on the way", "gas station"]),
    ]

    /// The names of `available` the note points at, in catalog order, with the reason naming the
    /// first word that hit. `nil` when nothing hits. A word list belongs to the first context in
    /// catalog order that carries one of its names: with "Garden" seeded and "Garten" added by
    /// hand, only "Garden" gets the garden words, so no note ends up as "Garden, Garten" (#157).
    static func match(in text: String, available: [String]) -> EnrichmentDraft.Guess<[String]>? {
        var names: [String] = []
        var first: Range<String.Index>?
        var claimed = Set<Int>()
        for name in available {
            var keywords = [name.trimmingCharacters(in: .whitespaces)]
            if let list = listIndex(for: name), claimed.insert(list).inserted {
                keywords += lists[list].words
            }
            guard let hit = earliest(of: keywords, in: text) else { continue }
            names.append(name)
            if let earlier = first, earlier.lowerBound <= hit.lowerBound { continue }
            first = hit
        }
        guard let first else { return nil }
        let word = String(text[first])
        return EnrichmentDraft.Guess(names, confidence: confidence, reason: String(localized: "From “\(word)” in the note."))
    }

    /// Where the word behind `match` stands, for marking it in the field editor (#101). Only the
    /// contexts the task carries count, so a word for another context is not marked.
    static func trigger(in text: String, contexts: [String]) -> Range<String.Index>? {
        contexts.compactMap { earliest(of: keywords(for: $0), in: text) }.min { $0.lowerBound < $1.lowerBound }
    }

    /// The context's own name plus the list of the default context it is, if any.
    private static func keywords(for name: String) -> [String] {
        [name.trimmingCharacters(in: .whitespaces)] + (listIndex(for: name).map { lists[$0].words } ?? [])
    }

    private static func listIndex(for name: String) -> Int? {
        lists.firstIndex { entry in entry.names.contains { same($0, name) } }
    }

    private static func same(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs.trimmingCharacters(in: .whitespaces), options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func earliest(of keywords: [String], in text: String) -> Range<String.Index>? {
        keywords.compactMap { range(of: $0, in: text) }.min { $0.lowerBound < $1.lowerBound }
    }

    /// Case-insensitive, starting at a word boundary. A single word of five letters or more may be
    /// the start of a German compound ("Rasen" in "Rasenmäher", "Garten" in "Gartenschere"); a
    /// shorter word or a phrase must end at a boundary too, so "call" is no hit in "Callcenter"
    /// and "Haus" none in "Hausaufgaben".
    static func range(of keyword: String, in text: String) -> Range<String.Index>? {
        guard !keyword.isEmpty else { return nil }
        var pattern = "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: keyword)
        if keyword.count < 5 || keyword.contains(" ") {
            pattern += "(?![\\p{L}\\p{N}])"
        }
        return text.range(of: pattern, options: [.regularExpression, .caseInsensitive])
    }
}
