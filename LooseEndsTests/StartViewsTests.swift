import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("Start screen views") struct StartViewsTests {
    @Test("With no task at all only the daily three remain")
    @MainActor func dailyThreeAlways() async throws {
        #expect(ViewRules.startViews(in: []) == [.next, .new, .due])
    }

    @Test("An occasional view appears once it holds a task, in its fixed place")
    @MainActor func occasionalViewsOnlyWithTasks() async throws {
        let store = try TestStore()
        let parked = TaskItem(rawText: "Fahrrad verkaufen")
        store.context.insert(parked)
        TaskActions.park(parked)
        let repeating = TaskItem(rawText: "Blumen gießen")
        repeating.status = .active
        repeating.repeatRule = RepeatRule(frequency: .weekly)
        store.context.insert(repeating)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        let views = ViewRules.startViews(in: all)

        #expect(views == [.next, .new, .due, .repeating, .parked])
        #expect(!views.contains(.waiting), "nothing waits, so Waiting stays out")
        #expect(!views.contains(.done), "Done sits apart at the bottom of the start screen")
    }

    @Test("Daily and occasional views together cover every list view except Done and All open")
    func everyViewHasAPlace() {
        let placed = Set(ViewRules.dailyViews + ViewRules.occasionalViews)
        let lists = Set(ViewKind.allCases).subtracting([.done, .open, .context, .project])
        #expect(placed == lists)
    }

    // MARK: - All open (#319)

    @Test("All open holds new, unverified, active, waiting and parked tasks")
    @MainActor func openViewContainsEveryUnfinishedTask() async throws {
        let store = try TestStore()
        let new = TaskItem(rawText: "Rechnung bezahlen")
        let unverified = TaskItem(rawText: "Steuer machen")
        unverified.status = .unverified
        let active = TaskItem(rawText: "Auto waschen")
        active.status = .active
        let waiting = TaskItem(rawText: "Angebot prüfen")
        waiting.status = .active
        waiting.blockedBy = [active]
        let parked = TaskItem(rawText: "Fahrrad verkaufen")
        for task in [new, unverified, active, waiting, parked] { store.context.insert(task) }
        TaskActions.park(parked)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(waiting.isBlocked)

        let ids = Set(ViewRules.tasks(for: .open, in: all).map(\.id))

        #expect(ids == Set([new, unverified, active, waiting, parked].map(\.id)))
    }

    @Test("All open leaves out done tasks and subtasks")
    @MainActor func openViewExcludesDoneAndSubtasks() async throws {
        let store = try TestStore()
        let done = TaskItem(rawText: "Müll rausbringen")
        let parent = TaskItem(rawText: "Einkaufen")
        parent.status = .active
        store.context.insert(done)
        store.context.insert(parent)
        TaskActions.complete(done)
        let milk = try Subtasks.add("Milch", to: parent, in: store.context)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        let ids = ViewRules.tasks(for: .open, in: all).map(\.id)

        #expect(ids == [parent.id])
        #expect(!ids.contains(done.id))
        #expect(!ids.contains(milk.id))
    }

    @Test("All open puts urgent first, then important, then the older one; parked tasks sort along")
    @MainActor func openViewSortsUrgentFirst() async throws {
        let store = try TestStore()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        func task(_ text: String, _ urgency: Urgency?, _ importance: Importance? = nil, minute: Double) -> TaskItem {
            let task = TaskItem(rawText: text)
            task.status = .active
            task.urgency = urgency
            task.importance = importance
            task.capturedAt = base.addingTimeInterval(minute * 60)
            store.context.insert(task)
            return task
        }
        let low = task("niedrig", .low, minute: 0)
        let highLater = task("hoch später", .high, minute: 5)
        let none = task("ohne", nil, minute: 1)
        let medium = task("mittel", .medium, minute: 2)
        let parkedHighImportant = task("geparkt hoch", .high, .high, minute: 9)
        TaskActions.park(parkedHighImportant)
        let highEarlier = task("hoch früher", .high, minute: 3)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        let order = ViewRules.tasks(for: .open, in: all).map(\.id)

        #expect(order == [parkedHighImportant, highEarlier, highLater, medium, low, none].map(\.id))
    }

    @Test("All open is empty without tasks and never one of the upper start rows")
    @MainActor func openViewEmptyAndNotAStartRow() async throws {
        #expect(ViewRules.tasks(for: .open, in: []).isEmpty)
        let store = try TestStore()
        let parked = TaskItem(rawText: "Fahrrad verkaufen")
        store.context.insert(parked)
        TaskActions.park(parked)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(!ViewRules.startViews(in: all).contains(.open), "All open sits apart above Done")
    }

    @Test("All open is called „Alle offenen“ in German, shows a circle and says „Nichts mehr offen.“ when empty")
    func openViewTitleAndSymbol() throws {
        #expect(ViewKind.open.symbol == "circle")
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        let german = try #require(Bundle(path: path))
        #expect(german.localizedString(forKey: "All open", value: nil, table: nil) == "Alle offenen")
        #expect(german.localizedString(forKey: "Nothing left open.", value: nil, table: nil) == "Nichts mehr offen.")
    }

    @Test("The iPhone grid leaves out New and Quick, which have the bar and a chip, and always ends on All open and Done (#368)")
    @MainActor func compactGridViews() async throws {
        #expect(ViewRules.compactGridViews(in: []) == [.next, .due, .open, .done])

        let store = try TestStore()
        let parked = TaskItem(rawText: "Fahrrad verkaufen")
        store.context.insert(parked)
        TaskActions.park(parked)
        try store.context.save()
        let all = try store.context.fetch(FetchDescriptor<TaskItem>())

        #expect(ViewRules.compactGridViews(in: all) == [.next, .due, .parked, .open, .done])
    }
}
