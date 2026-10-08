import Foundation
import Testing
@testable import LooseEnds

/// Corpus of 100 sensitive but ordinary task texts (#71). Measured on the device in the lab app
/// (`--corpus guardrail-corpus`): does the model refuse them or answer with a rate-limit error?
@Suite("Guardrail corpus (#71)")
struct GuardrailCorpusTests {
    @Test("100 unique, non-empty texts in ten groups, German and English")
    func corpusIsWellFormed() throws {
        let entries = try Corpus.load(fileName: "guardrail-corpus")
        #expect(entries.count == 100)
        #expect(Set(entries.map(\.id)).count == 100)
        #expect(Set(entries.map(\.text)).count == 100)
        #expect(entries.allSatisfy { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
        #expect(Set(entries.map(\.lang)) == ["de", "en"])
        #expect(Set(entries.map(\.form)).count == 10)
    }
}
