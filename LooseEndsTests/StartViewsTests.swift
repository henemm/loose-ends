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

    @Test("Daily and occasional views together cover every list view except Done")
    func everyViewHasAPlace() {
        let placed = Set(ViewRules.dailyViews + ViewRules.occasionalViews)
        let lists = Set(ViewKind.allCases).subtracting([.done, .context, .project])
        #expect(placed == lists)
    }
}
