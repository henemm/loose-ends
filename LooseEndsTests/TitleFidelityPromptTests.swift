import Foundation
import Testing
@testable import LooseEnds

/// Bug #125, Punkt 2: the prompt must not let the model drop the object or purpose of a task to
/// stay within a strict word count ("Termin bei Auto Senger machen für Inspektion und
/// Reifenwechsel" → "Termin bei Auto Senger machen"). Checked as plain string content — no
/// on-device model call. Measuring the actual model output against the corpus happens in the lab
/// app, never as an Xcode test (non-deterministic, needs Apple Intelligence on device), following
/// the same pattern as `ModelEnrichmentSchemaTests` in ImportanceUrgencyRuleTests.swift (#117).
#if canImport(FoundationModels) && !os(watchOS)
@Suite("FoundationModelsEnricher title prompt (Bug #125)")
struct TitleFidelityPromptTests {
    @Test("The instructions raise the word limit and forbid dropping object or purpose")
    func instructionsPreserveObjectAndPurpose() {
        let instructions = FoundationModelsEnricher.instructions
        #expect(!instructions.contains("at most eight words"), "the old, too-strict word limit must be gone")
        #expect(instructions.contains("twelve words"), "the loosened word limit must be stated")
        #expect(
            instructions.localizedCaseInsensitiveContains("purpose")
                || instructions.localizedCaseInsensitiveContains("object"),
            "the instructions must explicitly protect the task's object or purpose"
        )
    }

    @Test("Past tasks never hand their title to the prompt (#272)")
    func examplesCarryNoTitles() {
        let input = EnrichmentInput(
            rawText: "Rechnung der Werkstatt bezahlen",
            capturedAt: Date(timeIntervalSince1970: 0),
            contextVocabulary: [],
            projectNames: [],
            examples: [EnrichmentExample(rawText: "Rasen mähen am Samstag", title: "Rasen mähen", importance: nil, urgency: nil, duration: .hour1, contexts: ["Garten"])]
        )
        let prompt = FoundationModelsEnricher.prompt(for: input)
        #expect(!prompt.contains("title \"Rasen mähen\""))
        #expect(prompt.contains("duration"))
        #expect(FoundationModelsEnricher.instructions.contains("from the note alone"))
    }
}
#endif
