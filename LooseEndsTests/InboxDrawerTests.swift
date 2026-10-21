import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The start page's writing line and the drawer it opens (#601, form 2): Return makes a task at
/// once, the drawer shows this sitting's tasks, ending the entry folds it.
@Suite("Inbox drawer") struct InboxDrawerTests {
    @Test("Return makes a task that New counts at once; the drawer opens and keeps the order")
    @MainActor func returnCountsAtOnce() async throws {
        let store = try TestStore()
        var drawer = InboxDrawer()
        #expect(!drawer.isOpen && drawer.rows(in: []).isEmpty)

        let first = try CaptureService.save("Reifen wechseln am Freitag", via: .app, in: store.context)
        drawer.didCapture(first.id)
        let second = try CaptureService.save("Mama anrufen", via: .app, in: store.context)
        drawer.didCapture(second.id)
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        #expect(drawer.isOpen)
        #expect(ViewRules.tasks(for: .new, in: all).count == 2, "the number on the button is honest: both are in New")
        #expect(drawer.rows(in: all).map(\.id) == [first.id, second.id], "oldest first, the line follows the newest")
    }

    @Test("Ending the entry folds the drawer and ends the sitting")
    @MainActor func closeEndsTheSitting() async throws {
        let store = try TestStore()
        var drawer = InboxDrawer()
        let task = try CaptureService.save("Keller ausräumen", via: .app, in: store.context)
        drawer.didCapture(task.id)
        drawer.close()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        #expect(!drawer.isOpen)
        #expect(drawer.rows(in: all).isEmpty, "a closed drawer shows nothing")
        #expect(ViewRules.tasks(for: .new, in: all).count == 1, "the task stays in New")
        drawer.didCapture(task.id)
        #expect(drawer.rows(in: all).map(\.id) == [task.id], "the next Return starts a new sitting")
    }

    @Test("A task done or deleted from its detail leaves the drawer; the rest stays in order")
    @MainActor func doneAndDeletedLeave() async throws {
        let store = try TestStore()
        var drawer = InboxDrawer()
        let a = try CaptureService.save("Angebot vergleichen", via: .app, in: store.context)
        let b = try CaptureService.save("Versicherung fragen", via: .app, in: store.context)
        let c = try CaptureService.save("Blumen kaufen", via: .app, in: store.context)
        for id in [a.id, b.id, c.id] { drawer.didCapture(id) }
        TaskActions.complete(b)
        store.context.delete(c)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        #expect(drawer.rows(in: all).map(\.id) == [a.id])
    }
}
