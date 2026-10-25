import Foundation

/// The rule step for the place (#680, Henning 2026-10-25): "zu Hause" names the saved home, "im Büro"
/// the saved work place, each with "on arrival". The words are fixed, the place is the user's own slot
/// (`SavedPlaces`); with that slot empty the field stays empty, nothing is looked up or guessed.
///
/// Pure `Foundation`, like the other rules: `Shared/` compiles into the watch and widgets.
enum PlaceWordRule {
    static let confidence = 1.0

    /// Folded like `ExpressionText`, so "zu Hause", "Zuhause" and "im Büro" read alike.
    static let phrases: [(words: [String], slot: SavedPlaces.Slot)] = [
        (["zu", "hause"], .home), (["zuhause"], .home), (["daheim"], .home), (["at", "home"], .home),
        (["im", "buro"], .work), (["auf", "der", "arbeit"], .work), (["bei", "der", "arbeit"], .work),
        (["at", "work"], .work), (["at", "the", "office"], .work),
    ]

    /// The slot the first such phrase in the text names, or nothing.
    static func slot(in text: String) -> SavedPlaces.Slot? {
        let words = ExpressionText.words(in: text)
        for index in words.indices {
            for phrase in phrases
            where phrase.words.indices.allSatisfy({ ExpressionText.word(words, index + $0) == phrase.words[$0] }) {
                return phrase.slot
            }
        }
        return nil
    }

    /// The saved place the note names, arriving there; nil without a phrase or with its slot empty.
    static func match(in text: String, places: SavedPlaces) -> EnrichmentDraft.Guess<TaskPlace>? {
        guard let slot = slot(in: text), let place = places.place(slot, event: .arrive) else { return nil }
        let reason = switch slot {
        case .home: String(localized: "From “at home” in the note: your saved home.")
        case .work: String(localized: "From “at work” in the note: your saved work place.")
        }
        return EnrichmentDraft.Guess(place, confidence: confidence, reason: reason)
    }
}
