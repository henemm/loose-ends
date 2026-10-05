import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Its bundle has no `de` translations, so the words fall back to the English keys.
private final class EnergyBundleMarker {}

/// Energy gives or takes, −3 … +3, set by hand only (#112).
@Suite("Energy") struct EnergyTests {
    @Test("Seven stops, stored as the number's text (AC-1)")
    func storedRoundTrip() {
        #expect(Energy.allCases.map(\.rawValue) == [-3, -2, -1, 0, 1, 2, 3])
        for energy in Energy.allCases {
            #expect(Energy(stored: energy.stored) == energy)
        }
        #expect(Energy.takesClearly.stored == "-2")
        #expect(Energy(stored: "4") == nil)
        #expect(Energy(stored: "") == nil)
    }

    @Test("The old low/medium/high read as empty (AC-2)")
    @MainActor func legacyValuesReadAsEmpty() throws {
        let store = try TestStore()
        for legacy in ["low", "medium", "high"] {
            let task = TaskItem(rawText: legacy)
            store.context.insert(task)
            task.energyRaw = legacy
            task.energySourceRaw = FieldSource.ai.rawValue
            #expect(task.energy == nil)
            #expect(FieldCodec.encode(.energy, of: task) == nil)
            #expect(FieldFormatting.value(task.energyRaw, for: .energy) == nil)
            #expect(!RevisionService.aiSetFields(on: task).contains(.energy), "no spark on an empty field")
        }
    }

    @Test("A slider position is a user revision; Remove value is another (AC-3)")
    @MainActor func setAndRemoveAreUserRevisions() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Steuererklärung abgeben")
        store.context.insert(task)

        let set = try #require(RevisionService.set(.energy, to: Energy.takesClearly.stored, on: task, contexts: [], projects: []))
        #expect(task.energy == .takesClearly)
        #expect(task.energyRaw == "-2")
        #expect(task.energySourceRaw == FieldSource.user.rawValue)
        #expect(set.author == .user)
        #expect(set.oldValue == nil)
        #expect(set.newValue == "-2")

        #expect(RevisionService.set(.energy, to: "-2", on: task, contexts: [], projects: []) == nil, "same stop, no revision")

        let removed = try #require(RevisionService.set(.energy, to: nil, on: task, contexts: [], projects: []))
        #expect(task.energy == nil)
        #expect(task.energySourceRaw == nil)
        #expect(removed.oldValue == "-2")
        #expect((task.revisions ?? []).filter { $0.field == .energy }.count == 2)
    }

    @Test("Only words, never the number (AC-4)")
    func words() {
        let bundle = Bundle(for: EnergyBundleMarker.self)
        #expect(FieldFormatting.energy(.takesVery, bundle: bundle) == "takes a lot of energy")
        #expect(FieldFormatting.energy(.takesClearly, bundle: bundle) == "takes a fair amount of energy")
        #expect(FieldFormatting.energy(.takesLittle, bundle: bundle) == "takes a little energy")
        #expect(FieldFormatting.energy(.neither, bundle: bundle) == "neither gives nor takes energy")
        #expect(FieldFormatting.energy(.givesLittle, bundle: bundle) == "gives a little energy")
        #expect(FieldFormatting.energy(.givesClearly, bundle: bundle) == "gives a fair amount of energy")
        #expect(FieldFormatting.energy(.givesVery, bundle: bundle) == "gives a lot of energy")
        for energy in Energy.allCases {
            #expect(!FieldFormatting.energy(energy, bundle: bundle).contains { $0.isNumber })
        }
    }

    @Test("The model run leaves energy alone (AC-5)")
    @MainActor func modelNeverWritesEnergy() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Klavier spielen")
        store.context.insert(task)
        try store.context.save()
        var draft = EnrichmentDraft()
        draft.title = EnrichmentDraft.Guess("Klavier spielen", confidence: 0.9, reason: "Stub.")
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(draft: draft), container: store.container)

        await coordinator.processPending()

        #expect(task.processedAt != nil)
        #expect(task.energyRaw == nil)
        #expect(!(task.revisions ?? []).contains { $0.field == .energy })
    }
}

#if canImport(FoundationModels) && !os(watchOS)
@Suite("ModelEnrichment ohne Energie (#112, AC-5)")
struct ModelEnrichmentEnergySchemaTests {
    @Test("Das Schema trägt keine energy-Eigenschaften mehr")
    func schemaHasNoEnergy() {
        let sample = ModelEnrichment(
            title: "x", titleConfidence: 1, titleReason: "x",
            duration: "x", durationConfidence: 1, durationReason: "x",
            contexts: [], contextsConfidence: 1, contextsReason: "x",
            people: [], peopleConfidence: 1, peopleReason: "x",
            project: "x", projectConfidence: 1, projectReason: "x"
        )
        let labels = Set(Mirror(reflecting: sample).children.compactMap(\.label))
        #expect(!labels.contains { $0.lowercased().contains("energy") })
        #expect(!FoundationModelsEnricher.instructions.lowercased().contains("energy"))
    }
}
#endif
