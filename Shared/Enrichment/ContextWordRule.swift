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

    /// The names a default context goes by, one per shipped language: its English catalog key ("Garden")
    /// and the catalog's translation into each language ("Garten"). A renamed default context keeps only
    /// its new name. The words come from `Shared/Language/` (Epic #750).
    private static func names(of key: String) -> [String] {
        [key] + LanguagePacks.active.map { translation(of: key, in: $0.code) }
    }

    /// The catalog's text for `key` in one language, read from that language's resources in the main bundle;
    /// where the target has none (a widget, the share extension carry their own catalog) the key itself,
    /// which is the English name.
    private static func translation(of key: String, in code: String) -> String {
        guard let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) else {
            return key
        }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    /// The names of `available` the note points at, in catalog order, with the reason naming the
    /// first word that hit. `nil` when nothing hits. A word list belongs to the first context in
    /// catalog order that carries one of its names: with "Garden" seeded and "Garten" added by
    /// hand, only "Garden" gets the garden words, so no note ends up as "Garden, Garten" (#157).
    static func match(in text: String, available: [String]) -> EnrichmentDraft.Guess<[String]>? {
        var names: [String] = []
        var first: Range<String.Index>?
        var claimed = Set<String>()
        for name in available {
            var keywords = [name.trimmingCharacters(in: .whitespaces)]
            if let key = key(for: name), claimed.insert(key).inserted {
                keywords += LanguagePacks.contextWords(for: key)
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
        [name.trimmingCharacters(in: .whitespaces)] + (key(for: name).map(LanguagePacks.contextWords(for:)) ?? [])
    }

    /// The default context a name belongs to, in any shipped language.
    private static func key(for name: String) -> String? {
        LanguagePacks.contextKeys.first { key in names(of: key).contains { same($0, name) } }
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
