import Foundation

/// What the task detail shows where (#187). Set fields come first in their usual order; empty
/// ones wait behind "Add detail", so the detail never reads as a form asking to be filled in
/// (design briefing: nothing is mandatory). Pure, so it is unit-tested.
enum DetailLayout {
    struct Entry: Equatable {
        let field: RevisedField
        let value: String?
    }

    static func split(_ entries: [Entry]) -> (set: [Entry], empty: [Entry]) {
        (entries.filter { $0.value != nil }, entries.filter { $0.value == nil })
    }

    /// The raw text is worth a line only while it says something the title does not: no title
    /// yet, or other words. Word order, case and punctuation do not count (`RawTextWords`).
    static func showsRawText(_ raw: String, title: String?) -> Bool {
        guard let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return words(raw) != words(title)
    }

    private static func words(_ text: String) -> Set<String> {
        Set(RawTextWords.words(in: RawTextWords.normalized(text)))
    }
}
