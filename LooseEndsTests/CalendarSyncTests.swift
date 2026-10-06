import Foundation
import SwiftData
import Testing
@testable import LooseEnds

@Suite("Show in calendar") struct CalendarSyncTests {
    private func berlin() throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        return calendar
    }

    @Test("Only an open task with the switch on and a due date gets an event")
    @MainActor func planRequiresSwitchDueAndOpen() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zahnarzt anrufen")
        task.status = .active
        store.context.insert(task)
        #expect(CalendarSync.plan(for: task) == nil, "switch off")

        task.showInCalendar = true
        #expect(CalendarSync.plan(for: task) == nil, "no due date")

        task.dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(CalendarSync.plan(for: task) != nil)

        task.status = .done
        #expect(CalendarSync.plan(for: task) == nil, "done tasks leave the calendar")
        task.status = .parked
        #expect(CalendarSync.plan(for: task) == nil, "parked tasks leave the calendar")
    }

    @Test("A due time gives a block as long as the duration, a bare day gives an all-day event")
    @MainActor func timedAndAllDay() async throws {
        let store = try TestStore()
        let calendar = try berlin()
        let task = TaskItem(rawText: "Zahnarzt anrufen")
        task.status = .active
        task.title = "Zahnarzt"
        task.showInCalendar = true
        store.context.insert(task)
        let at = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 14, minute: 30)))

        task.dueDate = at
        task.dueHasTime = true
        task.duration = .minutes30
        let timed = try #require(CalendarSync.plan(for: task, calendar: calendar))
        #expect(timed.title == "Zahnarzt")
        #expect(timed.notes == "Zahnarzt anrufen")
        #expect(timed.start == at)
        #expect(timed.end == at.addingTimeInterval(30 * 60))
        #expect(timed.isAllDay == false)

        task.dueHasTime = false
        let allDay = try #require(CalendarSync.plan(for: task, calendar: calendar))
        #expect(allDay.isAllDay)
        #expect(allDay.start == calendar.startOfDay(for: at))
        #expect(allDay.end == calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: at)))

        #expect(CalendarSync.length(of: nil) == 60)
        #expect(CalendarSync.length(of: .minutes5) == 15)
        #expect(CalendarSync.length(of: .hours2plus) == 120)
    }

    @Test("Changes sort tasks into create, update and remove, and are empty while nobody asks")
    @MainActor func changes() async throws {
        let store = try TestStore()
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        let quiet = TaskItem(rawText: "Ohne Schalter"); quiet.status = .active; quiet.dueDate = due
        let fresh = TaskItem(rawText: "Neu im Kalender"); fresh.status = .active; fresh.dueDate = due; fresh.showInCalendar = true
        let known = TaskItem(rawText: "Schon drin"); known.status = .active; known.dueDate = due; known.showInCalendar = true; known.calendarEventID = "evt-1"
        let gone = TaskItem(rawText: "Erledigt"); gone.status = .done; gone.dueDate = due; gone.showInCalendar = true; gone.calendarEventID = "evt-2"
        for item in [quiet, fresh, known, gone] { store.context.insert(item) }

        #expect(CalendarSync.changes(in: [quiet]).isEmpty)
        let changes = CalendarSync.changes(in: [quiet, fresh, known, gone])
        #expect(changes.create.map(\.rawText) == ["Neu im Kalender"])
        #expect(changes.update.map(\.rawText) == ["Schon drin"])
        #expect(changes.remove.map(\.rawText) == ["Erledigt"])
        #expect(changes.removeOrphaned.isEmpty)
    }

    @Test("A deleted task's event has no task left to carry it, but still counts as an orphan (#122)")
    @MainActor func orphanedEvents() async throws {
        let store = try TestStore()
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        let known = TaskItem(rawText: "Schon drin"); known.status = .active; known.dueDate = due; known.showInCalendar = true; known.calendarEventID = "evt-1"
        let switchedOff = TaskItem(rawText: "Erledigt"); switchedOff.status = .done; switchedOff.dueDate = due; switchedOff.showInCalendar = true; switchedOff.calendarEventID = "evt-2"
        for item in [known, switchedOff] { store.context.insert(item) }

        // "evt-3" belongs to a task that no longer exists at all — deleted outright, not completed.
        let changes = CalendarSync.changes(in: [known, switchedOff], knownEventIDs: ["evt-1", "evt-2", "evt-3"])
        #expect(changes.removeOrphaned == ["evt-3"], "Only the event with no task left at all is an orphan")
        #expect(changes.remove.map(\.rawText) == ["Erledigt"], "A task that still exists keeps its own removal path")
    }

    // MARK: Where the app's own calendar is created (#203)

    private typealias Source = CalendarSync.SourceCandidate

    @Test("Google as the default does not win over iCloud: iCloud first, Google after it (#203)")
    func iCloudBeforeGoogleDefault() {
        let sources = [
            Source(id: "google", title: "henning@gmail.com", kind: .calDAV),
            Source(id: "icloud", title: "iCloud", kind: .calDAV),
            Source(id: "holidays", title: "Abonniert", kind: .subscribed),
        ]
        #expect(CalendarSync.sourceOrder(sources, defaultSourceID: "google") == ["icloud", "google"])
    }

    @Test("Only the device itself: the local source (#203)")
    func onlyLocal() {
        let sources = [Source(id: "local", title: "Auf meinem iPhone", kind: .local)]
        #expect(CalendarSync.sourceOrder(sources, defaultSourceID: "local") == ["local"])
    }

    @Test("Exchange, subscriptions and birthdays never host the app's calendar (#203)")
    func refusedKindsNeverTried() {
        let sources = [
            Source(id: "work", title: "Exchange", kind: .exchange),
            Source(id: "holidays", title: "Abonniert", kind: .subscribed),
            Source(id: "birthdays", title: "Andere", kind: .birthdays),
        ]
        #expect(CalendarSync.sourceOrder(sources, defaultSourceID: "work").isEmpty)
    }

    @Test("Every source is tried at most once, local comes before a foreign CalDAV default (#203)")
    func eachSourceOnceLocalBeforeForeignDefault() {
        let iCloudDefault = [
            Source(id: "icloud", title: "iCloud", kind: .calDAV),
            Source(id: "local", title: "Auf meinem iPhone", kind: .local),
        ]
        #expect(CalendarSync.sourceOrder(iCloudDefault, defaultSourceID: "icloud") == ["icloud", "local"])

        let googleDefault = [
            Source(id: "other", title: "Fastmail", kind: .calDAV),
            Source(id: "google", title: "henning@gmail.com", kind: .calDAV),
            Source(id: "local", title: "Auf meinem iPhone", kind: .local),
        ]
        #expect(CalendarSync.sourceOrder(googleDefault, defaultSourceID: "google") == ["local", "google", "other"])
    }

    @Test("The note under the switch says why nothing shows, and is silent while all is well (#203)")
    @MainActor func noteUnderTheSwitch() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zahnarzt anrufen")
        task.status = .active
        store.context.insert(task)
        #expect(CalendarSync.note(for: task, problem: .noWritableSource) == nil, "switch off: silent")

        task.showInCalendar = true
        #expect(CalendarSync.note(for: task, problem: nil) == .needsDueDate)

        task.dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(CalendarSync.note(for: task, problem: nil) == nil)
        #expect(CalendarSync.note(for: task, problem: .accessDenied) == .accessOff)
        #expect(CalendarSync.note(for: task, problem: .noWritableSource) == .noWritableSource)
        #expect(CalendarSync.note(for: task, problem: .syncFailed) == .syncFailed)
    }
}
