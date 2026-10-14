import Foundation
import Testing
import UserNotifications
@testable import LooseEnds

/// The pure decisions behind the place notification (#240, Schnitt 1): both button rows, when to ask for
/// the permission, what a shown or answered place notification changes, one reconcile at a time.
@Suite("PlaceNotifications (#240)") struct PlaceNotificationsTests {
    private func openTask(_ raw: String = "Dübel kaufen") throws -> TaskItem {
        let task = TaskItem(rawText: raw)
        task.status = .active
        task.place = TaskPlace(name: "Bauhaus", latitude: 53.55, longitude: 9.93, event: .arrive)
        return task
    }

    private func respond(
        identifier: String, action: String? = nil, taskID: String?, tasks: [TaskItem]
    ) -> Bool {
        PlaceNotifications.respond(
            identifier: identifier, actionRaw: action, taskID: taskID,
            in: tasks, contexts: [], projects: []
        )
    }

    private func placeID(_ task: TaskItem) -> String { PlaceReminders.identifierPrefix + task.id.uuidString }
    private func dueID(_ task: TaskItem) -> String { DueReminders.identifierPrefix + task.id.uuidString }

    // MARK: AC-1

    @Test("The due buttons survive: DUE keeps all three, PLACE gets only Complete and Next up")
    func categoriesCarryBothRows() throws {
        let categories = NotificationCategories.all()
        #expect(categories.count == 2)
        let due = try #require(categories.first { $0.identifier == "DUE" })
        let place = try #require(categories.first { $0.identifier == "PLACE" })
        #expect(due.actions.map(\.identifier).sorted() == ["DUE_DONE", "DUE_NEXT", "DUE_TOMORROW"])
        #expect(place.actions.map(\.identifier).sorted() == ["DUE_DONE", "DUE_NEXT"])
    }

    // MARK: AC-2

    @Test("Only while-using or always with full accuracy counts as permitted")
    func authorizationDecision() {
        typealias P = PlaceNotifications
        #expect(P.isAuthorized(.whenInUse, fullAccuracy: true))
        #expect(P.isAuthorized(.always, fullAccuracy: true))
        #expect(!P.isAuthorized(.whenInUse, fullAccuracy: false))
        #expect(!P.isAuthorized(.always, fullAccuracy: false))
        for permission in [P.Permission.refused, .notDetermined] {
            #expect(!P.isAuthorized(permission, fullAccuracy: true))
            #expect(!P.isAuthorized(permission, fullAccuracy: false))
        }
    }

    // MARK: AC-3

    @Test("Asking needs undecided, a watched place, never asked before, and the foreground")
    func askingDecision() {
        typealias P = PlaceNotifications
        #expect(P.shouldRequestAuthorization(.notDetermined, hasWatched: true, alreadyAsked: false, isActive: true))
        #expect(!P.shouldRequestAuthorization(.notDetermined, hasWatched: false, alreadyAsked: false, isActive: true))
        #expect(!P.shouldRequestAuthorization(.notDetermined, hasWatched: true, alreadyAsked: true, isActive: true))
        #expect(!P.shouldRequestAuthorization(.notDetermined, hasWatched: true, alreadyAsked: false, isActive: false))
        for decided in [P.Permission.whenInUse, .always, .refused] {
            #expect(!P.shouldRequestAuthorization(decided, hasWatched: true, alreadyAsked: false, isActive: true))
        }
    }

    // MARK: AC-4

    @Test("Tapping a place notification marks the task, so it leaves the plan")
    @MainActor func tapMarksTask() throws {
        let store = try TestStore()
        let task = try openTask()
        store.context.insert(task)
        #expect(PlaceReminders.plan(for: [task]).watched.count == 1)

        let changed = respond(identifier: placeID(task), taskID: task.id.uuidString, tasks: [task])

        #expect(changed)
        #expect(task.placeRemindedAt != nil)
        #expect(PlaceReminders.plan(for: [task]).watched.isEmpty)
    }

    @Test("Complete on a place notification marks the task and completes it")
    @MainActor func completeMarksAndCompletes() throws {
        let store = try TestStore()
        let task = try openTask()
        store.context.insert(task)

        let changed = respond(identifier: placeID(task), action: "DUE_DONE", taskID: task.id.uuidString, tasks: [task])

        #expect(changed)
        #expect(task.placeRemindedAt != nil)
        #expect(task.status == .done)
    }

    @Test("Next up on a place notification marks the task and puts it next")
    @MainActor func nextMarksAndRanks() throws {
        let store = try TestStore()
        let task = try openTask()
        store.context.insert(task)

        let changed = respond(identifier: placeID(task), action: "DUE_NEXT", taskID: task.id.uuidString, tasks: [task])

        #expect(changed)
        #expect(task.placeRemindedAt != nil)
        #expect(task.nextRank != nil)
    }

    @Test("A due notification never sets the place mark")
    @MainActor func dueDoesNotMark() throws {
        let store = try TestStore()
        let task = try openTask()
        store.context.insert(task)

        _ = respond(identifier: dueID(task), taskID: task.id.uuidString, tasks: [task])

        #expect(task.placeRemindedAt == nil)
    }

    @Test("A broken, missing or unknown task id changes nothing")
    @MainActor func badTaskIDChangesNothing() throws {
        let store = try TestStore()
        let task = try openTask()
        store.context.insert(task)

        #expect(!respond(identifier: placeID(task), taskID: "kein-uuid", tasks: [task]))
        #expect(!respond(identifier: placeID(task), taskID: nil, tasks: [task]))
        #expect(!respond(identifier: placeID(task), taskID: UUID().uuidString, tasks: [task]))
        #expect(task.placeRemindedAt == nil)
    }

    @Test("An unknown action on a due notification changes nothing; on a place notification only the mark is set")
    @MainActor func unknownAction() throws {
        let store = try TestStore()
        let task = try openTask()
        store.context.insert(task)

        #expect(!respond(identifier: dueID(task), action: "DUE_SOMETHING", taskID: task.id.uuidString, tasks: [task]))
        #expect(task.placeRemindedAt == nil)

        #expect(respond(identifier: placeID(task), action: "DUE_SOMETHING", taskID: task.id.uuidString, tasks: [task]))
        #expect(task.placeRemindedAt != nil)
        #expect(task.status == .active)
        #expect(task.nextRank == nil)
    }

    @Test("Planning alone never sets the mark")
    @MainActor func planDoesNotMark() throws {
        let store = try TestStore()
        let task = try openTask()
        store.context.insert(task)

        _ = PlaceReminders.plan(for: [task])

        #expect(task.placeRemindedAt == nil)
    }

    // MARK: AC-5

    @Test("The place reconcile sees only place_ identifiers")
    func prefixFilter() {
        let id = UUID().uuidString
        let kept = PlaceNotifications.pendingPlaceIdentifiers(["due_" + id, "place_" + id, "other_" + id])
        #expect(kept == ["place_" + id])
    }

    // MARK: AC-6

    @Test("Silent under unit tests; under UI tests only with the places argument")
    func silence() {
        typealias P = PlaceNotifications
        #expect(P.isSilent(runningTests: true, uiTesting: false, arguments: []))
        #expect(P.isSilent(runningTests: true, uiTesting: false, arguments: [P.testArgument]))
        #expect(P.isSilent(runningTests: false, uiTesting: true, arguments: []))
        #expect(!P.isSilent(runningTests: false, uiTesting: true, arguments: [P.testArgument]))
        #expect(!P.isSilent(runningTests: false, uiTesting: false, arguments: []))
    }

    // MARK: AC-7

    @Test("Triggers during a run cause exactly one rerun")
    func gateOneRerun() {
        let gate = ReconcileGate()
        #expect(gate.begin())
        #expect(!gate.begin())
        #expect(!gate.begin())
        #expect(gate.end())          // exactly one rerun for the two triggers
        #expect(gate.begin())        // free again
        #expect(!gate.end())         // no trigger meanwhile, no rerun
    }
}
