import Foundation

/// The words one language contributes to the rules (Epic #750). One file per language holds them;
/// `LanguagePacks.shipped` is the one list of shipped languages. Every word is stored folded
/// (lowercase, no diacritics: "nachste", "ubermorgen"), exactly as `ExpressionText.folded` yields it.
/// The rules check all shipped languages at once, like the Denglisch notes in the corpus need.
struct LanguagePack: Sendable {
    /// ISO 639-1, "en", "de".
    let code: String
    /// English name, for the model prompt test (#757).
    let name: String
    let numbers: [String: Int]
    /// 1 = Sunday, like `Calendar`.
    let weekdays: [String: Int]
    let months: [String: Int]
    let relativeDays: [String: Int]
    let nextWords: [String]
    let dayUnits: [String]
    let weekUnits: [String]
    let dayPrepositions: [String]
    let ordinalSuffixes: [String]
    let repetitions: [String]
}

enum LanguagePacks {
    static let shipped: [LanguagePack] = [.english, .german]

    /// Test hook (#755): tests plug a pack in. Product code reads only `active`. Written from tests on
    /// the main thread before any rule runs, never from the product, hence `nonisolated(unsafe)`.
    nonisolated(unsafe) static var active: [LanguagePack] = shipped

    static var numbers: [String: Int] { merged(\.numbers) }
    static var weekdays: [String: Int] { merged(\.weekdays) }
    static var months: [String: Int] { merged(\.months) }
    static var relativeDays: [String: Int] { merged(\.relativeDays) }
    static var nextWords: [String] { list(\.nextWords) }
    static var dayUnits: [String] { list(\.dayUnits) }
    static var weekUnits: [String] { list(\.weekUnits) }
    static var dayPrepositions: [String] { list(\.dayPrepositions) }
    static var ordinalSuffixes: [String] { list(\.ordinalSuffixes) }
    static var repetitions: [String] { list(\.repetitions) }

    /// A word may stand in two packs ("april"), but never with two values.
    private static func merged(_ key: KeyPath<LanguagePack, [String: Int]>) -> [String: Int] {
        active.reduce(into: [:]) { result, pack in
            result.merge(pack[keyPath: key]) { old, new in
                precondition(old == new, "Wort mit zwei Werten in zwei Packs")
                return old
            }
        }
    }

    /// Longest first, duplicates removed.
    private static func list(_ key: KeyPath<LanguagePack, [String]>) -> [String] {
        var seen = Set<String>()
        return active.flatMap { $0[keyPath: key] }
            .filter { seen.insert($0).inserted }
            .sorted { $0.count > $1.count }
    }
}
