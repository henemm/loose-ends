import Foundation
import Testing
@testable import LooseEnds

/// What the iPhone hands to the system and what it leaves alone (#226, Schnitt 2a). The system never says
/// whether a place notification was delivered, so a per-device handover list stands in for a delivered mark.
@Suite("PlaceDelivery (#226)") struct PlaceDeliveryTests {
    private let start = Date(timeIntervalSince1970: 1_790_000_000)

    private func place(_ name: String = "Bauhaus", latitude: Double = 53.55, event: TaskPlace.Event = .arrive) throws -> TaskPlace {
        try #require(TaskPlace(name: name, latitude: latitude, longitude: 9.93, event: event))
    }

    private func task(_ raw: String = "Dübel kaufen", minutesAfterStart: Double = 0) throws -> TaskItem {
        let task = TaskItem(rawText: raw)
        task.status = .active
        task.capturedAt = start.addingTimeInterval(minutesAfterStart * 60)
        task.place = try place()
        return task
    }

    private func diff(
        _ tasks: [TaskItem],
        handover: PlaceDelivery.Handover = .init(entries: []),
        pending: Set<String> = [],
        authorized: Bool = true
    ) -> PlaceDelivery.Changes {
        PlaceDelivery.diff(
            plan: PlaceReminders.plan(for: tasks),
            tasks: tasks,
            handover: handover,
            pending: pending,
            authorized: authorized
        )
    }

    private func id(_ task: TaskItem) -> String { PlaceReminders.identifierPrefix + task.id.uuidString }

    /// What the system holds after the first handover: the new list and the request, still open.
    private func handedOver(_ tasks: [TaskItem]) -> (handover: PlaceDelivery.Handover, pending: Set<String>) {
        let first = diff(tasks)
        return (first.handover, Set(first.add.map(\.identifier)))
    }

    @Test("A new task with a place is handed over and noted")
    @MainActor func newTaskIsHandedOver() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)

        let changes = diff([task])

        #expect(changes.add.map(\.identifier) == [id(task)])
        #expect(changes.remove.isEmpty)
        let entry = try #require(changes.handover.entries.first)
        #expect(changes.handover.entries.count == 1)
        #expect(entry.taskID == task.id)
        #expect(entry.title == task.displayTitle)
        #expect(!entry.fingerprint.isEmpty)
    }

    @Test("A second change to a task that already reminded does not remind again")
    @MainActor func secondChangeDoesNotRemindAgain() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)
        let first = handedOver([task])

        task.durationRaw = "15"
        let changes = diff([task], handover: first.handover, pending: [])

        #expect(changes.add.isEmpty)
        #expect(changes.handover == first.handover)
    }

    @Test("An open request stays untouched")
    @MainActor func openRequestStaysUntouched() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)
        let first = handedOver([task])

        let changes = diff([task], handover: first.handover, pending: first.pending)

        #expect(changes.add.isEmpty)
        #expect(changes.remove.isEmpty)
        #expect(changes.updateContent.isEmpty)
        #expect(changes.handover == first.handover)
    }

    @Test("A different place or event replaces the request, a different name too; a fired one is only handed over again")
    @MainActor func otherPlaceReplacesRequest() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)
        let first = handedOver([task])
        let oldFingerprint = try #require(first.handover.entries.first?.fingerprint)

        let others = [try place(latitude: 53.60), try place(event: .depart), try place("Hornbach")]
        for other in others {
            task.place = other
            let open = diff([task], handover: first.handover, pending: first.pending)
            #expect(open.remove == [id(task)])
            #expect(open.add.map(\.identifier) == [id(task)])
            #expect(open.handover.entries.first?.fingerprint != oldFingerprint)

            let fired = diff([task], handover: first.handover, pending: [])
            #expect(fired.remove.isEmpty)
            #expect(fired.add.map(\.identifier) == [id(task)])
        }
    }

    @Test("A repeating task is armed again once ticking it off has moved it on; a one-off ignores its due date")
    @MainActor func repeatingTaskIsArmedAgain() throws {
        let store = try TestStore()
        let repeating = try task("Müll rausbringen")
        repeating.repeatRule = RepeatRule(frequency: .weekly)
        repeating.dueDate = start
        let oneOff = try task("Dübel kaufen")
        oneOff.dueDate = start
        store.context.insert(repeating)
        store.context.insert(oneOff)
        let first = handedOver([repeating, oneOff])

        TaskActions.complete(repeating, now: start.addingTimeInterval(60))
        oneOff.dueDate = start.addingTimeInterval(86_400)
        let changes = diff([repeating, oneOff], handover: first.handover, pending: [])

        #expect(repeating.status == .active)
        #expect(changes.add.map(\.identifier) == [id(repeating)])
        #expect(changes.remove.isEmpty)
    }

    @Test("A task that drops out of the plan is withdrawn; one that comes back reminds again")
    @MainActor func droppedTaskIsWithdrawn() throws {
        let store = try TestStore()
        let task = try task()
        let other = try task("Anderes", minutesAfterStart: 1)
        store.context.insert(task)
        store.context.insert(other)
        let first = handedOver([task, other])

        let drops: [(String, () -> Void, () -> Void)] = [
            ("done", { TaskActions.complete(task) }, { TaskActions.restore(task) }),
            ("parked", { TaskActions.park(task) }, { TaskActions.restore(task) }),
        ]
        for (label, drop, back) in drops {
            drop()
            let changes = diff([task, other], handover: first.handover, pending: first.pending)
            #expect(changes.remove == [id(task)], "\(label)")
            #expect(changes.handover.entries.map(\.taskID) == [other.id], "\(label)")

            back()
            let returned = diff([task, other], handover: changes.handover, pending: first.pending.subtracting([id(task)]))
            #expect(returned.add.map(\.identifier) == [id(task)], "\(label)")
        }

        let savedPlace = task.place
        task.place = nil
        let withoutPlace = diff([task, other], handover: first.handover, pending: first.pending)
        #expect(withoutPlace.remove == [id(task)])
        task.place = savedPlace
    }

    @Test("Rank 21 drops out of the watched places, the entry and the request go with it")
    @MainActor func rankBeyondLimitIsWithdrawn() throws {
        let store = try TestStore()
        let tasks = try (0..<21).map { try task("Aufgabe \($0)", minutesAfterStart: Double(21 - $0)) }
        for task in tasks { store.context.insert(task) }
        let twenty = Array(tasks.prefix(20))
        let first = handedOver(twenty)
        let last = tasks[20]

        // The 21st is the oldest, so it ranks last. Take it in, push a newer one out.
        let newest = try task("Neueste", minutesAfterStart: 100)
        store.context.insert(newest)
        let all = tasks + [newest]
        let withLast = PlaceReminders.plan(for: all)
        #expect(withLast.unwatched.contains(last.id))

        let changes = diff(all, handover: first.handover, pending: first.pending)
        #expect(changes.add.map(\.identifier) == [id(newest)])
        #expect(changes.remove == [id(tasks[19])])
        #expect(!changes.handover.entries.contains { $0.taskID == tasks[19].id })
    }

    @Test("A changed title only replaces the content of an open request; a fired one is left alone")
    @MainActor func titleChangeOnlyReplacesContent() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)
        let first = handedOver([task])

        task.title = "Dübel und Schrauben kaufen"
        let open = diff([task], handover: first.handover, pending: first.pending)
        #expect(open.updateContent.map(\.identifier) == [id(task)])
        #expect(open.add.isEmpty)
        #expect(open.remove.isEmpty)
        #expect(open.handover.entries.first?.title == task.displayTitle)

        let fired = diff([task], handover: first.handover, pending: [])
        #expect(fired.updateContent.isEmpty)
        #expect(fired.add.isEmpty)
        #expect(fired.remove.isEmpty)
        #expect(fired.handover == first.handover)
    }

    @Test("Without authorization nothing is handed over or noted, so it arrives once granted; withdrawing still runs")
    @MainActor func withoutAuthorizationNothingIsNoted() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)

        let denied = diff([task], authorized: false)
        #expect(denied.add.isEmpty)
        #expect(denied.updateContent.isEmpty)
        #expect(denied.handover.entries.isEmpty)

        let granted = diff([task], handover: denied.handover, authorized: true)
        #expect(granted.add.map(\.identifier) == [id(task)])

        let first = handedOver([task])
        TaskActions.complete(task)
        let withdrawn = diff([task], handover: first.handover, pending: first.pending, authorized: false)
        #expect(withdrawn.remove == [id(task)])
    }

    @Test("Identifiers keep the place_ prefix and the task id")
    @MainActor func identifiersKeepPrefix() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)
        let first = handedOver([task])
        TaskActions.park(task)

        let added = diff([try self.task("Neu", minutesAfterStart: 5)]).add
        let removed = diff([task], handover: first.handover, pending: first.pending).remove

        #expect(added.allSatisfy { $0.identifier.hasPrefix("place_") })
        #expect(removed == ["place_" + task.id.uuidString])
    }

    @Test("Orphaned place requests disappear, other kinds are never touched")
    @MainActor func orphanedRequestsDisappear() throws {
        let orphan = "place_" + UUID().uuidString
        let due = "due_" + UUID().uuidString

        let changes = diff([], pending: [orphan, due])

        #expect(changes.remove == [orphan])
    }

    @Test("A reinstall with an empty list does not create the request twice")
    @MainActor func reinstallDoesNotDoubleRequest() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)

        let kept = diff([task], pending: [id(task)])
        #expect(kept.add.isEmpty)
        #expect(kept.handover.entries.map(\.taskID) == [task.id])

        let missing = diff([task], pending: [])
        #expect(missing.add.map(\.identifier) == [id(task)])
    }

    @Test("The same input yields the same changes whatever the order, and the list encodes byte-identical")
    @MainActor func resultIsStable() throws {
        let store = try TestStore()
        let tasks = try (0..<5).map { try task("Aufgabe \($0)", minutesAfterStart: Double($0)) }
        for task in tasks { store.context.insert(task) }
        let orphan = "place_" + UUID().uuidString

        let forward = diff(tasks, pending: [orphan])
        let again = diff(tasks, pending: [orphan])
        let reversed = diff(tasks.reversed(), pending: [orphan])

        #expect(forward == again)
        #expect(forward == reversed)
        #expect(forward.add.map(\.identifier) == forward.add.map(\.identifier).sorted())
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(forward.handover) == (try encoder.encode(reversed.handover)))
    }

    @Test("The fingerprint ignores the sixth decimal and cannot be fooled by a separator in the name")
    @MainActor func fingerprintHasNoCollision() throws {
        let store = try TestStore()
        let task = try task()
        store.context.insert(task)

        func fingerprint(_ place: TaskPlace) -> String {
            let reminder = PlaceReminders.Reminder(taskID: task.id, title: "x", place: place)
            return PlaceDelivery.fingerprint(of: reminder, in: task)
        }

        let base = try place(latitude: 53.550001)
        let near = try place(latitude: 53.550004)
        #expect(fingerprint(base) == fingerprint(near))

        let tricky = try place("arrive|53.55000|9.93000|-|Bauhaus")
        #expect(fingerprint(tricky) != fingerprint(try place("Bauhaus")))
        #expect(fingerprint(try place("Bauhaus")) != fingerprint(try place("Bauhaus", event: .depart)))
    }
}
