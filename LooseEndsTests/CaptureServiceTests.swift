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
        #expect(stored.title == "Rasenmäher Ölwechsel", "the date leaves the title (#217)")
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

    // MARK: - Attachments (#399)

    /// A temporary folder per test, removed by the caller.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("capture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func file(_ name: String, _ bytes: Data, in folder: URL, type: String, status: SharedAttachment.Status = .ready) throws -> SharedAttachment {
        let url = folder.appendingPathComponent(name)
        try bytes.write(to: url)
        return SharedAttachment(fileURL: url, fileName: name, typeIdentifier: type, byteCount: bytes.count, status: status)
    }

    @Test("Ready attachments are stored on the new task, in the order they were shared")
    func savesAttachments() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let dir = try folder()
        defer { do { try FileManager.default.removeItem(at: dir) } catch { Issue.record(error) } }
        let a = try file("Befund.pdf", Data("pdf".utf8), in: dir, type: "com.adobe.pdf")
        let b = try file("Photo.heic", Data("heic".utf8), in: dir, type: "public.heic")

        let saved = try CaptureService.save("Befund Dr Meier", via: .share, attachments: [a, b], in: context)

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        let stored = try context.fetch(FetchDescriptor<TaskAttachment>()).sorted { $0.createdAt < $1.createdAt }
        #expect(stored.map(\.fileName) == ["Befund.pdf", "Photo.heic"])
        #expect(stored.map(\.typeIdentifier) == ["com.adobe.pdf", "public.heic"])
        #expect(stored.map(\.data) == [Data("pdf".utf8), Data("heic".utf8)])
        #expect(stored.allSatisfy { $0.task?.id == saved.id })
        #expect(Set(stored.map(\.createdAt)).count == 2, "distinct times keep the order in the detail")
    }

    @Test("Too large and over the limit are never read; a file over 50 MB on disk is not stored either")
    func neverReadsSkipped() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let dir = try folder()
        defer { do { try FileManager.default.removeItem(at: dir) } catch { Issue.record(error) } }
        let missing = dir.appendingPathComponent("gone.pdf")
        let tooLarge = SharedAttachment(fileURL: missing, fileName: "gone.pdf", typeIdentifier: "com.adobe.pdf", byteCount: 1, status: .tooLarge)
        let overLimit = SharedAttachment(fileURL: missing, fileName: "gone.pdf", typeIdentifier: "com.adobe.pdf", byteCount: 1, status: .overLimit)
        let big = dir.appendingPathComponent("big.pdf")
        #expect(FileManager.default.createFile(atPath: big.path, contents: nil))
        let handle = try FileHandle(forWritingTo: big)
        try handle.truncate(atOffset: UInt64(AttachmentKind.maximumBytes + 1))
        try handle.close()
        let grown = SharedAttachment(fileURL: big, fileName: "big.pdf", typeIdentifier: "com.adobe.pdf", byteCount: 10, status: .ready)

        try CaptureService.save("Befund", via: .share, attachments: [tooLarge, overLimit, grown], in: context)

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<TaskAttachment>()).isEmpty)
    }

    @Test("An unreadable file is skipped, the task and the others are kept")
    func skipsUnreadable() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let dir = try folder()
        defer { do { try FileManager.default.removeItem(at: dir) } catch { Issue.record(error) } }
        let gone = try file("gone.pdf", Data("x".utf8), in: dir, type: "com.adobe.pdf")
        try FileManager.default.removeItem(at: gone.fileURL)
        let kept = try file("kept.pdf", Data("y".utf8), in: dir, type: "com.adobe.pdf")

        try CaptureService.save("Befund", via: .share, attachments: [gone, kept], in: context)

        #expect(try context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<TaskAttachment>()).map(\.fileName) == ["kept.pdf"])
    }

    @Test("No task without text, even with an attachment")
    func emptyTextWithAttachment() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = ModelContext(container)
        let dir = try folder()
        defer { do { try FileManager.default.removeItem(at: dir) } catch { Issue.record(error) } }
        let pdf = try file("Befund.pdf", Data("pdf".utf8), in: dir, type: "com.adobe.pdf")

        #expect(throws: CaptureError.emptyText) {
            try CaptureService.save("  ", via: .share, attachments: [pdf], in: context)
        }
        #expect(try context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TaskAttachment>()).isEmpty)
    }
}
