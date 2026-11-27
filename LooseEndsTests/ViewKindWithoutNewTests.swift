import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// #1000 Schnitt 3a (ADR-22): "New" is gone from the views and from the rules.
@Suite("No view New (#1000 S3a)") struct ViewKindWithoutNewTests {
    @Test("ViewKind holds exactly the eleven views, none of them New")
    func noNewCase() {
        let raw = ViewKind.allCases.map(\.rawValue)
        #expect(!raw.contains("new"))
        #expect(raw == ["next", "due", "quick", "old", "waiting", "repeating", "parked", "open", "done", "context", "project"])
    }

    @Test("A saved view with the old raw value new reads as Next up")
    func oldSavedViewReadsAsNext() {
        let view = SavedView(name: "Neu", kind: .next)
        view.kindRaw = "new"
        #expect(view.kind == .next)
    }

    @Test("A captured task stands in Loose ends and counts in Now like an active one")
    @MainActor func capturedTaskStandsInItsList() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let captured = try CaptureService.save("Dachrinne reinigen", via: .keyboard, in: context)
        let changed = try CaptureService.save("Rasen mähen", via: .keyboard, in: context)
        changed.status = .active
        context.insert(Revision(task: changed, field: .duration, oldValue: nil, newValue: "30", author: .rule, reason: "test"))
        captured.nextRank = 1
        changed.nextRank = 2
        try context.save()
        let all = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(captured.status == .unprocessed)
        #expect(changed.hasUnseenAutomaticRevisions)

        #expect(Set(ViewRules.tasks(for: .open, in: all).map(\.id)) == [captured.id, changed.id])
        let countAsCaptured = ViewRules.nowCount(in: all)
        captured.status = .active
        #expect(countAsCaptured == ViewRules.nowCount(in: all))
        #expect(countAsCaptured == 2)
    }
}
