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

    @Test("A task's calendar choice needs both names, and choosing nil goes back to the default (#203 Teil C)")
    @MainActor func choiceRoundTrip() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zahnarzt anrufen")
        store.context.insert(task)
        #expect(CalendarSync.choice(for: task) == nil)

        let privat = CalendarSync.Choice(account: "iCloud", name: "Privat")
        CalendarSync.choose(privat, for: task)
        #expect(task.calendarAccount == "iCloud")
        #expect(task.calendarName == "Privat")
        #expect(CalendarSync.choice(for: task) == privat)

        task.calendarAccount = nil
        #expect(CalendarSync.choice(for: task) == nil, "one name alone is no choice")

        CalendarSync.choose(nil, for: task)
        #expect(task.calendarAccount == nil && task.calendarName == nil)
    }

    @Test("A choice resolves by account and name, picks the smallest id of two alike, and is nil when missing (#203 Teil C)")
    func resolveByNames() {
        let calendars = [
            CalendarSync.CalendarRef(id: "c", account: "iCloud", name: "Privat"),
            CalendarSync.CalendarRef(id: "b", account: "henning@gmail.com", name: "Privat"),
            CalendarSync.CalendarRef(id: "a", account: "iCloud", name: "Privat"),
        ]
        #expect(CalendarSync.resolve(.init(account: "iCloud", name: "Privat"), among: calendars) == "a")
        #expect(CalendarSync.resolve(.init(account: "henning@gmail.com", name: "Privat"), among: calendars) == "b")
        #expect(CalendarSync.resolve(.init(account: "iCloud", name: "Arbeit"), among: calendars) == nil)
        #expect(CalendarSync.resolve(.init(account: "Exchange", name: "Privat"), among: calendars) == nil)
    }

    @Test("The mark names its task and nothing else (#203 Teil C)")
    @MainActor func markRoundTrip() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zahnarzt anrufen")
        store.context.insert(task)
        let mark = try #require(CalendarSync.mark(for: task))
        #expect(CalendarSync.taskID(fromMark: mark) == task.id)
        #expect(CalendarSync.taskID(fromMark: nil) == nil)
        #expect(CalendarSync.taskID(fromMark: URL(string: "https://example.com/task/\(task.id.uuidString)")) == nil)
        #expect(CalendarSync.taskID(fromMark: URL(string: "looseends://task/kein-id")) == nil)
    }

    @Test("Only marked events of a deleted task are orphans; another device's event of a living task stays (#203 Teil C)")
    func orphanedMarksOnlyForGoneTasks() {
        let living = UUID()
        let gone = UUID()
        let marked = ["e1": living, "e2": gone, "e3": living]
        #expect(CalendarSync.orphanedMarks(marked, taskIDs: [living]) == ["e2"])
        #expect(CalendarSync.orphanedMarks(marked, taskIDs: [living, gone]).isEmpty)
    }

    @Test("Of one task's events in one calendar, every device keeps the one with the smallest shared id (#691)")
    func duplicatesAreTheSameOnEveryDevice() {
        // The same three events, each device with its own local ids and its own order.
        let iPhone = [
            CalendarSync.EventKey(local: "p-1", shared: "C"),
            CalendarSync.EventKey(local: "p-2", shared: "A"),
            CalendarSync.EventKey(local: "p-3", shared: "B"),
        ]
        let mac = [
            CalendarSync.EventKey(local: "m-9", shared: "B"),
            CalendarSync.EventKey(local: "m-1", shared: "C"),
            CalendarSync.EventKey(local: "m-5", shared: "A"),
        ]
        #expect(Set(CalendarSync.duplicates(among: iPhone).compactMap(\.shared)) == ["B", "C"])
        #expect(Set(CalendarSync.duplicates(among: mac).compactMap(\.shared)) == ["B", "C"])
        #expect(CalendarSync.duplicates(among: [iPhone[0]]).isEmpty, "a single event stays")
        #expect(CalendarSync.duplicates(among: []).isEmpty)
    }

    @Test("Without a shared id on every event nothing goes, so no two devices remove each other's (#691)")
    func noDuplicatesWithoutSharedIDs() {
        let events = [
            CalendarSync.EventKey(local: "a", shared: "A"),
            CalendarSync.EventKey(local: "b", shared: nil),
        ]
        #expect(CalendarSync.duplicates(among: events).isEmpty)
    }

    @Test("Only the device that wrote a task's event writes it again; another waits for it to arrive (#691)")
    func onlyTheWriterWritesNew() {
        #expect(CalendarSync.writesNew(eventID: nil, writtenHere: []), "no event yet: this device writes it")
        #expect(CalendarSync.writesNew(eventID: "mine", writtenHere: ["mine"]), "its own event is gone: again")
        #expect(!CalendarSync.writesNew(eventID: "theirs", writtenHere: ["mine"]), "another device's: wait")
    }

    @Test("A calendar missing on this device is the note, after the due date and any sync problem (#203 Teil C)")
    @MainActor func noteForMissingCalendar() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zahnarzt anrufen")
        task.status = .active
        task.showInCalendar = true
        store.context.insert(task)
        CalendarSync.choose(.init(account: "henning@gmail.com", name: "Familie"), for: task)
        #expect(CalendarSync.note(for: task, problem: nil, missing: true) == .needsDueDate)

        task.dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(CalendarSync.note(for: task, problem: nil, missing: true) == .calendarMissing("Familie"))
        #expect(CalendarSync.note(for: task, problem: .accessDenied, missing: true) == .accessOff)
        #expect(CalendarSync.note(for: task, problem: nil, missing: false) == nil)

        CalendarSync.choose(nil, for: task)
        #expect(CalendarSync.note(for: task, problem: nil, missing: true) == nil, "the default is never missing")
    }

    @Test("The device default round-trips through the settings, nil goes back to Loose Ends (#203 Teil C2)")
    func deviceDefaultRoundTrip() throws {
        let suite = "CalendarSyncTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(CalendarSync.deviceDefault(in: defaults) == nil)

        let familie = CalendarSync.Choice(account: "iCloud", name: "Familie")
        CalendarSync.setDeviceDefault(familie, in: defaults)
        #expect(CalendarSync.deviceDefault(in: defaults) == familie)

        CalendarSync.setDeviceDefault(nil, in: defaults)
        #expect(CalendarSync.deviceDefault(in: defaults) == nil)
    }

    @Test("Switching on takes the device default along, but never over the task's own choice (#203 Teil C2)")
    @MainActor func switchOnTakesDefault() async throws {
        let store = try TestStore()
        let familie = CalendarSync.Choice(account: "iCloud", name: "Familie")
        let arbeit = CalendarSync.Choice(account: "Exchange", name: "Arbeit")

        let plain = TaskItem(rawText: "Zahnarzt anrufen")
        let chosen = TaskItem(rawText: "Steuer abgeben")
        let standard = TaskItem(rawText: "Rasen mähen")
        for task in [plain, chosen, standard] { store.context.insert(task) }
        CalendarSync.choose(arbeit, for: chosen)

        CalendarSync.switchOn(plain, deviceDefault: familie)
        CalendarSync.switchOn(chosen, deviceDefault: familie)
        CalendarSync.switchOn(standard, deviceDefault: nil)

        #expect(plain.showInCalendar && chosen.showInCalendar && standard.showInCalendar)
        #expect(CalendarSync.choice(for: plain) == familie)
        #expect(CalendarSync.choice(for: chosen) == arbeit)
        #expect(CalendarSync.choice(for: standard) == nil, "Loose Ends stays without a choice")
    }
}
