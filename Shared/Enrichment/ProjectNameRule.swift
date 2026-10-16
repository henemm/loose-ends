import Foundation

/// The rule step for the project (#469, Henning 2026-10-16): a project is set when its own name
/// stands in the note ("Kartons für den Umzug" → Umzug), never guessed. The model used to choose from
/// the list and put nearly every task into the one project there was. No hit leaves the field empty.
///
/// The name is matched like a context's own name (`ContextWordRule.range`): case- and
/// accent-insensitive at a word start, a name of five letters or more also as the start of a compound.
/// Pure `Foundation`, like the other rules: `Shared/` compiles into the watch and widgets.
enum ProjectNameRule {
    static let confidence = 1.0

    /// The first project in catalog order whose name stands in the note.
    static func match(in text: String, projects: [String]) -> EnrichmentDraft.Guess<String>? {
        for name in projects {
            let trimmed = name.trimmingCharacters(in: .whitespaces)
            guard trimmed.count >= 3, let hit = ContextWordRule.range(of: trimmed, in: text) else { continue }
            let word = String(text[hit])
            return EnrichmentDraft.Guess(name, confidence: confidence, reason: String(localized: "From “\(word)” in the note."))
        }
        return nil
    }
}
