import Foundation

/// The word list grows from the user's own context assignments (#233, after #232): the model cannot
/// learn on the device, and prompt examples only carry on near-verbatim text (#131), so learning is a
/// counted word list instead. A word joins a context's list once it appears in at least N different
/// raw texts the user filed under that context, and in none filed under any other context.
///
/// Pure `Foundation`, like `ContextWordRule`: `Shared/` compiles into the watch and widgets. The
/// caller gathers the assignments (only contexts with the user origin) and keeps the result; N is a
/// parameter until the measurement (`docs/reference/context-word-learning.md`) has settled it.
enum ContextWordLearning {
    /// One raw text and the contexts the user put on it.
    struct Assignment: Sendable {
        let rawText: String
        let contexts: [String]
    }

    /// N in the product path (Schnitt 2, Henning 2026-10-22): the smallest N that met the rule fixed
    /// before the measurement (`docs/reference/context-word-learning.md`) — fixed list plus learned
    /// words hit 32 % of the tasks exactly instead of 12 %, and the share of foreign contexts among
    /// the set ones does not rise. One assignment by hand teaches every content word of its text.
    static let minimumCount = 1

    /// A learned hit carries the fixed list's confidence: the word is there or it is not.
    static let confidence = ContextWordRule.confidence

    /// The learned words per context name, each normalized like `RawTextWords.normalized`.
    ///
    /// Counted over *distinct* word sets: a task captured ten times is one assignment, not ten, or a
    /// single recurring note would push all its words past N on its own. A word seen under two
    /// contexts — in two assignments or in one carrying both — belongs to neither. `forgotten` holds
    /// the words the user deleted from a list; they are never learned for that context again.
    static func learn(from assignments: [Assignment], minimumCount: Int,
                      forgotten: [String: Set<String>] = [:]) -> [String: Set<String>] {
        var wordSets: [String: Set<Set<String>>] = [:]
        for assignment in assignments {
            let words = candidateWords(in: assignment.rawText)
            guard !words.isEmpty else { continue }
            for context in Set(assignment.contexts) {
                wordSets[context, default: []].insert(words)
            }
        }

        var counts: [String: [String: Int]] = [:]
        var contextsOfWord: [String: Set<String>] = [:]
        for (context, sets) in wordSets {
            for words in sets {
                for word in words {
                    counts[context, default: [:]][word, default: 0] += 1
                    contextsOfWord[word, default: []].insert(context)
                }
            }
        }

        var learned: [String: Set<String>] = [:]
        for (context, wordCounts) in counts {
            let words = wordCounts.filter { word, count in
                count >= minimumCount
                    && contextsOfWord[word]?.count == 1
                    && !(forgotten[context]?.contains(word) ?? false)
            }.keys
            if !words.isEmpty { learned[context] = Set(words) }
        }
        return learned
    }

    /// The context names whose learned words appear in `text`, sorted by name so the answer never
    /// depends on dictionary order. Whole words only: a learned word is a word the user said, not a
    /// stem, so "Rasen" learned does not hit "Rasenmäher" (`ContextWordRule` keeps its compound rule
    /// for its own hand-picked lists).
    static func match(in text: String, learned: [String: Set<String>]) -> [String] {
        let words = candidateWords(in: text)
        return learned.filter { !$0.value.isDisjoint(with: words) }.keys.sorted()
    }

    /// The first word of `text`, in its own spelling, that a learned list of one of `names` carries —
    /// the word the reason quotes (#101). `nil` when none does.
    static func firstWord(in text: String, learned: [String: Set<String>], names: [String]) -> String? {
        let words = names.reduce(into: Set<String>()) { $0.formUnion(learned[$1] ?? []) }
        return RawTextWords.words(in: text).first { words.contains(RawTextWords.normalized($0)) }
    }

    /// The reason of a learned hit, next to the fixed list's "From “…” in the note.": it says where
    /// the word comes from, so the user knows which tag taught it and where to delete it.
    static func reason(word: String) -> String {
        String(localized: "From “\(word)” in the note, learned from your tags.")
    }

    /// The words of a raw text that may be learned: normalized, four characters or more (the
    /// threshold of `LeaveOneOut.similarityWords` and `TitleCheck.foreignWords`), no pure numbers and
    /// no filler words.
    static func candidateWords(in text: String) -> Set<String> {
        Set(RawTextWords.words(in: text).map(RawTextWords.normalized).filter { word in
            word.count >= 4 && !word.allSatisfy(\.isNumber) && !fillerWords.contains(word)
        })
    }

    /// Words of four letters or more that say nothing about where a task is done: function words,
    /// days and times. Normalized spelling ("uber", "fruh"), because they are compared after
    /// `RawTextWords.normalized`. Shorter function words fall to the length filter already.
    static let fillerWords: Set<String> = [
        "eine", "einen", "einem", "einer", "eines", "dass", "oder", "aber", "auch", "noch", "wenn",
        "dann", "denn", "doch", "mich", "dich", "sich", "mein", "meine", "meinen", "meinem", "meiner",
        "dein", "deine", "sein", "seine", "ihre", "ihren", "unser", "unsere", "nach", "uber", "unter",
        "beim", "gegen", "ohne", "durch", "bitte", "schon", "nicht", "mehr", "ganz", "alle", "alles",
        "diese", "dieser", "dieses", "diesen", "wieder", "haben", "habe", "machen", "muss", "mussen",
        "soll", "sollte", "kann", "konnen", "werden", "wird", "will", "etwas", "jetzt", "immer", "bald",
        "sofort", "spater", "heute", "morgen", "ubermorgen", "gestern", "woche", "wochenende", "abend",
        "abends", "fruh", "mittag", "nachste", "nachsten", "nachstes", "kommenden", "montag",
        "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag", "zwei", "drei", "vier",
        "funf",
        "that", "this", "with", "from", "have", "need", "make", "some", "then", "there", "they", "them",
        "your", "about", "into", "over", "also", "again", "please", "today", "tomorrow", "week",
        "weekend", "next", "later", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
        "sunday",
    ]
}
