import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("CaptureService") struct CaptureServiceTests {
    @Test("Saves trimmed raw text with channel and source, unprocessed, visible in New")
    func savesTrimmed() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let link = try #require(URL(string: "message://%3Cabc@example.com%3E"))

        let saved = try CaptureService.save("  Rasenmäher Ölwechsel am Wochenende \n", via: .share, sourceURL: link, in: context)

        let fetched = try context.fetch(FetchDescriptor<TaskItem>())
        let stored = try #require(fetched.first)
        #expect(fetched.count == 1)
        #expect(stored.id == saved.id)
        #expect(stored.rawText == "Rasenmäher Ölwechsel am Wochenende")
        #expect(stored.capturedVia == .share)
        #expect(stored.sourceURL == link)
        #expect(stored.status == .unprocessed)
        #expect(stored.title == nil)
        #expect(ViewRules.tasks(for: .new, in: fetched).map(\.id) == [saved.id])
    }

    @Test("Blank text is rejected and nothing is stored", arguments: ["", "   ", "\n\t "])
    func rejectsBlank(input: String) throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)

        #expect(throws: CaptureError.emptyText) {
            try CaptureService.save(input, via: .app, in: context)
        }
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }

    @Test("Newest capture comes first in New")
    func newestFirst() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let first = try CaptureService.save("Erste", via: .app, in: context)
        let second = try CaptureService.save("Zweite", via: .siri, in: context)
        second.capturedAt = first.capturedAt.addingTimeInterval(1)
        try context.save()

        let all = try context.fetch(FetchDescriptor<TaskItem>())
        #expect(ViewRules.tasks(for: .new, in: all).map(\.rawText) == ["Zweite", "Erste"])
    }
}
