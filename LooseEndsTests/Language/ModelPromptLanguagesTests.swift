import Foundation
import Testing
@testable import LooseEnds

/// #757 (Epic #750): der Modell-Prompt nennt jede ausgelieferte Sprache. Der Test liest die Datei als Text und fasst das
/// Symbol nicht an, damit er nicht an `canImport(FoundationModels)` hängt und `FoundationModelsEnricher.swift` (Geräteliste,
/// Stufe 3) unberührt bleibt. Eine dritte Sprache in `LanguagePacks.shipped` macht ihn rot, bis der Prompt sie nennt.
@Suite("Modell-Prompt und ausgelieferte Sprachen")
struct ModelPromptLanguagesTests {
    static var promptURL: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Shared/Enrichment/FoundationModelsEnricher.swift")
    }

    @Test("Der Prompt nennt jede ausgelieferte Sprache")
    func promptNamesEveryShippedLanguage() throws {
        let text = try String(contentsOf: Self.promptURL, encoding: .utf8)
        for pack in LanguagePacks.shipped {
            #expect(text.contains(pack.name),
                    "Prompt nennt \(pack.name) nicht. Prompt anpassen und auf dem Gerät messen (Stufe 3, docs/reference/neue-sprache.md Punkt 4).")
        }
    }
}
