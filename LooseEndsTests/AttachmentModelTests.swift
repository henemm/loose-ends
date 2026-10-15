import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Attachments on a task (#442, model slice): they keep their bytes and go with the task.
@Suite("Attachment model") struct AttachmentModelTests {
    @Test("An attachment keeps its bytes, name and type")
    @MainActor func keepsData() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Befund ablegen")
        store.context.insert(task)
        let bytes = Data([0x25, 0x50, 0x44, 0x46])
        let attachment = Attachment(task: task, data: bytes, fileName: "Befund.pdf", typeIdentifier: "com.adobe.pdf")
        store.context.insert(attachment)
        try store.context.save()

        let fetched = try store.context.fetch(FetchDescriptor<Attachment>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.data == bytes)
        #expect(fetched.first?.fileName == "Befund.pdf")
        #expect(task.attachments?.count == 1)
    }

    @Test("Deleting the task deletes its attachments")
    @MainActor func cascade() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Rechnung zahlen")
        store.context.insert(task)
        store.context.insert(Attachment(task: task, data: Data([1, 2, 3]), fileName: "Rechnung.jpg", typeIdentifier: "public.jpeg"))
        try store.context.save()

        store.context.delete(task)
        try store.context.save()
        #expect(try store.context.fetchCount(FetchDescriptor<Attachment>()) == 0)
    }
}
