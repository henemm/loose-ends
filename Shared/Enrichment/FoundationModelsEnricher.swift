#if canImport(FoundationModels) && !os(watchOS)
import Foundation
import FoundationModels

/// The on-device model behind `TaskEnricher`: guided generation into a flat schema, then mapping
/// into the typed draft. Not compiled for watchOS, which has no Foundation Models.
struct FoundationModelsEnricher: TaskEnricher {
    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(let reason):
            return String(describing: reason)
        }
    }

    func enrich(_ input: EnrichmentInput) async throws -> EnrichmentDraft {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(to: Self.prompt(for: input), generating: ModelEnrichment.self)
        return Self.draft(from: response.content, capturedAt: input.capturedAt)
    }

    // MARK: - Prompt

    static let instructions = """
    You turn one captured note into a task. The note may be German or English; answer in the note's language.
    Title: imperative, up to twelve words, no trailing period. Keep names and numbers from the note.
    Never drop the object or purpose of the task, even if that means using more words.
    Duration buckets: minutes5, minutes15, minutes30, hour1, hours2plus. Energy: low, medium, high.
    Contexts and project must come from the allowed lists; otherwise leave them empty.
    Every confidence is between 0 and 1 and honest: use low confidence when the note does not say.
    Each reason is one short sentence.
    """

    static func prompt(for input: EnrichmentInput) -> String {
        var lines: [String] = []
        let captured = input.capturedAt.formatted(Date.FormatStyle(date: .complete, time: .omitted).locale(Locale(identifier: "en_US")))
        lines.append("Capture date: \(captured).")
        lines.append("Allowed contexts: " + (input.contextVocabulary.isEmpty ? "none" : input.contextVocabulary.joined(separator: ", ")) + ".")
        lines.append("Allowed projects: " + (input.projectNames.isEmpty ? "none" : input.projectNames.joined(separator: ", ")) + ".")
        if !input.examples.isEmpty {
            lines.append("Past tasks and how they ended up:")
            for example in input.examples {
                var attributes: [String] = []
                if let title = example.title { attributes.append("title \"\(title)\"") }
                if let duration = example.duration { attributes.append("duration \(duration.rawValue)") }
                if let energy = example.energy { attributes.append("energy \(energy.rawValue)") }
                if !example.contexts.isEmpty { attributes.append("contexts \(example.contexts.joined(separator: ", "))") }
                lines.append("- \"\(example.rawText)\" → " + (attributes.isEmpty ? "no attributes" : attributes.joined(separator: "; ")))
            }
        }
        lines.append("Note: \"\(input.rawText)\"")
        return lines.joined(separator: "\n")
    }

    // MARK: - Mapping

    static func draft(from result: ModelEnrichment, capturedAt: Date, calendar: Calendar = .current) -> EnrichmentDraft {
        var draft = EnrichmentDraft()
        let title = result.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            draft.title = EnrichmentDraft.Guess(title, confidence: EnrichmentParsing.clamp(result.titleConfidence), reason: result.titleReason)
        }
        if let value = DurationBucket(rawValue: result.duration) {
            draft.duration = EnrichmentDraft.Guess(value, confidence: EnrichmentParsing.clamp(result.durationConfidence), reason: result.durationReason)
        }
        if let value = Energy(rawValue: result.energy) {
            draft.energy = EnrichmentDraft.Guess(value, confidence: EnrichmentParsing.clamp(result.energyConfidence), reason: result.energyReason)
        }
        let contexts = result.contexts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !contexts.isEmpty {
            draft.contexts = EnrichmentDraft.Guess(contexts, confidence: EnrichmentParsing.clamp(result.contextsConfidence), reason: result.contextsReason)
        }
        let people = result.people.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if !people.isEmpty {
            draft.people = EnrichmentDraft.Guess(people, confidence: EnrichmentParsing.clamp(result.peopleConfidence), reason: result.peopleReason)
        }
        let project = result.project.trimmingCharacters(in: .whitespaces)
        if !project.isEmpty {
            draft.project = EnrichmentDraft.Guess(project, confidence: EnrichmentParsing.clamp(result.projectConfidence), reason: result.projectReason)
        }
        return draft
    }
}

/// Flat schema for guided generation. Empty strings mean "not set"; the mapping above drops them.
@Generable
struct ModelEnrichment {
    @Guide(description: "Imperative title, up to twelve words, in the language of the note, keeping the object and purpose of the task")
    var title: String
    @Guide(description: "Confidence 0 to 1 that the title is right")
    var titleConfidence: Double
    @Guide(description: "One sentence why this title")
    var titleReason: String

    @Guide(description: "Duration bucket: minutes5, minutes15, minutes30, hour1, hours2plus, or empty")
    var duration: String
    @Guide(description: "Confidence 0 to 1 for the duration")
    var durationConfidence: Double
    @Guide(description: "One sentence why this duration")
    var durationReason: String

    @Guide(description: "Energy needed: low, medium, high, or empty")
    var energy: String
    @Guide(description: "Confidence 0 to 1 for the energy")
    var energyConfidence: Double
    @Guide(description: "One sentence why this energy")
    var energyReason: String

    @Guide(description: "Names from the allowed contexts that fit, empty list otherwise")
    var contexts: [String]
    @Guide(description: "Confidence 0 to 1 for the contexts")
    var contextsConfidence: Double
    @Guide(description: "One sentence why these contexts")
    var contextsReason: String

    @Guide(description: "Names of people mentioned in the note, empty list otherwise")
    var people: [String]
    @Guide(description: "Confidence 0 to 1 for the people")
    var peopleConfidence: Double
    @Guide(description: "One sentence why these people")
    var peopleReason: String

    @Guide(description: "One of the allowed project names, or empty")
    var project: String
    @Guide(description: "Confidence 0 to 1 for the project")
    var projectConfidence: Double
    @Guide(description: "One sentence why this project")
    var projectReason: String
}
#endif
