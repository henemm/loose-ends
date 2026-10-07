import Foundation
import Testing
@testable import LooseEnds

/// Which places the iPhone watches (#226, Schnitt 1): open tasks only, ranked, at most 20, the rest named.
@Suite("PlaceReminders (#226)") struct PlaceRemindersTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func place(_ name: String = "Bauhaus") throws -> TaskPlace {
        try #require(TaskPlace(name: name, latitude: 53.55, longitude: 9.93, event: .arrive))
    }

    private func task(_ raw: String, status: TaskStatus = .active, minutesAfterStart: Double = 0, withPlace: Bool = true) throws -> TaskItem {
        let task = TaskItem(rawText: raw)
        task.status = status
        task.capturedAt = start.addingTimeInterval(minutesAfterStart * 60)
        if withPlace { task.place = try place() }
        return task
    }

    @Test("Only open tasks with a place remind: unprocessed, unverified and active, not parked or completed")
    @MainActor func onlyOpenTasks() throws {
        let store = try TestStore()
        let tasks = [
            try task("neu", status: .unprocessed),
            try task("ungeprüft", status: .unverified),
            try task("aktiv", status: .active),
            try task("geparkt", status: .parked),
            try task("erledigt", status: .done),
            try task("ohne Ort", withPlace: false),
        ]
        for task in tasks { store.context.insert(task) }

        let plan = PlaceReminders.plan(for: tasks)

        #expect(Set(plan.watched.map(\.title)) == ["neu", "ungeprüft", "aktiv"])
        #expect(plan.unwatched.isEmpty)
        let active = try #require(plan.watched.first { $0.title == "aktiv" })
        let expected = try place()
        #expect(active.place == expected)
        #expect(active.identifier == "place_" + tasks[2].id.uuidString)
    }

    @Test("Next up first by its order, then by due date, then the newest")
    @MainActor func ranking() throws {
        let store = try TestStore()
        let old = try task("alt", minutesAfterStart: 0)
        let new = try task("neu", minutesAfterStart: 10)
        let dueLater = try task("später fällig")
        dueLater.dueDate = start.addingTimeInterval(7200)
        let dueSoon = try task("bald fällig")
        dueSoon.dueDate = start.addingTimeInterval(3600)
        let nextSecond = try task("als nächstes 2")
        nextSecond.nextRank = 2
        let nextFirst = try task("als nächstes 1")
        nextFirst.nextRank = 1
        nextFirst.dueDate = start.addingTimeInterval(99_999)
        let tasks = [old, new, dueLater, dueSoon, nextSecond, nextFirst]
        for task in tasks { store.context.insert(task) }

        let titles = PlaceReminders.plan(for: tasks).watched.map(\.title)

        #expect(titles == ["als nächstes 1", "als nächstes 2", "bald fällig", "später fällig", "neu", "alt"])
    }

    @Test("A full tie is broken by the id, so every run yields the same list")
    @MainActor func stable() throws {
        let store = try TestStore()
        let tasks = try (0..<6).map { try task("gleich \($0)") }
        for task in tasks { store.context.insert(task) }

        let first = PlaceReminders.plan(for: tasks)
        let second = PlaceReminders.plan(for: Array(tasks.reversed()))

        #expect(first == second)
        #expect(first.watched.map(\.taskID) == tasks.map(\.id).sorted { $0.uuidString < $1.uuidString })
    }

    @Test("25 open places: the 20 ranked highest are watched, the other 5 are named")
    @MainActor func limit() throws {
        let store = try TestStore()
        let tasks = try (0..<25).map { try task("Aufgabe \($0)", minutesAfterStart: Double($0)) }
        for task in tasks { store.context.insert(task) }

        let plan = PlaceReminders.plan(for: tasks)

        #expect(PlaceReminders.limit == 20)
        #expect(plan.watched.count == 20)
        #expect(plan.watched.first?.title == "Aufgabe 24")
        #expect(Set(plan.unwatched) == Set(tasks[0..<5].map(\.id)))
    }

    @Test("A repeating task is back in the plan after it is completed")
    @MainActor func repeating() throws {
        let store = try TestStore()
        let weekly = try task("Pfand wegbringen")
        weekly.repeatRule = RepeatRule(frequency: .weekly)
        weekly.dueDate = start
        let once = try task("Einmal")
        store.context.insert(weekly)
        store.context.insert(once)

        TaskActions.complete(weekly, now: start)
        TaskActions.complete(once, now: start)

        #expect(PlaceReminders.plan(for: [weekly, once]).watched.map(\.title) == ["Pfand wegbringen"])
    }

    // MARK: - Reminded once (#226, Schnitt 4)

    @Test("A place that reminded is in no later plan, neither watched nor named")
    @MainActor func remindedLeavesThePlan() throws {
        let store = try TestStore()
        let reminded = try task("schon erinnert")
        let waiting = try task("wartet")
        store.context.insert(reminded)
        store.context.insert(waiting)

        #expect(PlaceReminders.markDelivered(taskID: reminded.id, in: [reminded, waiting], now: start))

        let plan = PlaceReminders.plan(for: [reminded, waiting])
        #expect(plan.watched.map(\.title) == ["wartet"])
        #expect(plan.unwatched.isEmpty)
    }

    @Test("Marking twice keeps the first time; an unknown task reports false")
    @MainActor func markDeliveredIsIdempotent() throws {
        let store = try TestStore()
        let item = try task("Dübel")
        store.context.insert(item)
        let later = start.addingTimeInterval(600)

        #expect(PlaceReminders.markDelivered(taskID: item.id, in: [item], now: start))
        #expect(PlaceReminders.markDelivered(taskID: item.id, in: [item], now: later))
        #expect(item.placeRemindedAt == start)
        #expect(PlaceReminders.markDelivered(taskID: UUID(), in: [item], now: start) == false)
    }

    @Test("A repeating task that reminded is armed again when it is completed, a one-off stays out")
    @MainActor func completionArmsARepeatAgain() throws {
        let store = try TestStore()
        let weekly = try task("Pfand wegbringen")
        weekly.repeatRule = RepeatRule(frequency: .weekly)
        weekly.dueDate = start
        let once = try task("Einmal")
        store.context.insert(weekly)
        store.context.insert(once)
        PlaceReminders.markDelivered(taskID: weekly.id, in: [weekly, once], now: start)
        PlaceReminders.markDelivered(taskID: once.id, in: [weekly, once], now: start)
        #expect(PlaceReminders.plan(for: [weekly, once]).watched.isEmpty)

        TaskActions.complete(weekly, now: start)
        TaskActions.complete(once, now: start)

        #expect(weekly.placeRemindedAt == nil)
        #expect(PlaceReminders.plan(for: [weekly, once]).watched.map(\.title) == ["Pfand wegbringen"])
    }

    @Test("A changed place is a new reminder; parking does not arm it")
    @MainActor func newPlaceArmsAgain() throws {
        let store = try TestStore()
        let item = try task("Dübel")
        store.context.insert(item)
        PlaceReminders.markDelivered(taskID: item.id, in: [item], now: start)
        let elsewhere = try #require(TaskPlace(name: "Baumarkt Nord", latitude: 53.6, longitude: 10.0, event: .depart))

        TaskActions.park(item, now: start)
        #expect(item.placeRemindedAt == start)

        RevisionService.set(.place, to: FieldCodec.encode(elsewhere), on: item, contexts: [], projects: [])
        #expect(item.placeRemindedAt == nil)
        TaskActions.activate(item)
        #expect(PlaceReminders.plan(for: [item]).watched.map(\.title) == ["Dübel"])
    }
}
