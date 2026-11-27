import Foundation
import Testing
@testable import LooseEnds

/// #1000 Schnitt 3b (ADR-22): the words of "New" and of the AI tint are gone from the catalog,
/// read from the built German bundle as the app reads them.
@Suite("Catalog without New (#1000 S3b)") struct CatalogWithoutNewTests {
    static let gone = [
        "New", "%lld to look over", "Looks right", "Needs a look", "was: %@",
        "Title not checked", "Not sorted yet", "Nothing to look over.", "Changed by AI",
    ]
    static let missing = "§missing§"

    private static func german() throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    @Test("The nine keys of New and the AI tint are no longer in the German bundle", arguments: gone)
    func keyIsGone(key: String) throws {
        #expect(try Self.german().localizedString(forKey: key, value: Self.missing, table: nil) == Self.missing, "\(key)")
    }

    @Test("Keys that stay are still translated")
    func keptKeysStay() throws {
        let german = try Self.german()
        #expect(german.localizedString(forKey: "New date", value: Self.missing, table: nil) == "Neues Datum")
        #expect(german.localizedString(forKey: "Now", value: Self.missing, table: nil) != Self.missing)
    }
}
