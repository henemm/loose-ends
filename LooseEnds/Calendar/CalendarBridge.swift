import CoreGraphics
import EventKit
import Foundation
import OSLog
import SwiftData

/// EventKit for `CalendarSync`: one event per task, in the app's own "Loose Ends" calendar (created
/// in the first account that allows it, #203) or in the calendar the task chose (#203 Teil C). In a
/// calendar the app did not create, it only ever touches events carrying a task's mark. Full access is
/// needed so it can refresh and remove its own events. Asks for access the first time a task wants to
/// be shown, and stays silent under tests, where a permission prompt would block the run.
@Observable
@MainActor
final class CalendarBridge {
    /// What went wrong on the last sync; cleared by the next one that succeeds.
    private(set) var problem: CalendarSync.Problem?
    /// Every writable calendar on this device, once a sync has run with access; empty after one failed.
    private(set) var calendars: [Target] = []
    /// The app's own calendar, the default for a task without a choice.
    private(set) var appCalendarID: String?
    /// This device's calendar for new events (#203 Teil C2), nil for "Loose Ends".
    private(set) var deviceDefault = CalendarSync.deviceDefault()

    struct Target: Identifiable {
        let id: String
        let account: String
        let title: String
        let color: CGColor
    }

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var storeChanges: Task<Void, Never>?
    private static let calendarKey = "calendarIdentifier"
    /// The calendars this device ever wrote an event into: where a deleted task's event is looked for.
    private static let writtenCalendarsKey = "calendarIdentifiersWritten"
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Calendar")

    /// The calendar UI test (#203) lets the bridge run against the simulator's calendar while the
    /// store stays in memory.
    private static var suppressed: Bool {
        ModelContainerFactory.isRunningTests
            || (ModelContainerFactory.isUITesting && !ProcessInfo.processInfo.arguments.contains("--ui-testing-calendar"))
    }

    init(container: ModelContainer) {
        self.container = container
        // Another device's event arrives through the calendar, not through a save here: the sync
        // after it finds the duplicates (#691). Its own commits come back too and change nothing.
        storeChanges = Task { [weak self, store] in
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged, object: store) {
                self?.syncSoon()
            }
        }
    }

    /// Where the task's event goes on this device: its chosen calendar, else the app's own. Nil before
    /// the first sync with access, and when the chosen calendar does not exist here.
    func target(for task: TaskItem) -> Target? {
        guard let appCalendarID else { return nil }
        guard let choice = CalendarSync.choice(for: task) else {
            return calendars.first { $0.id == appCalendarID }
        }
        guard let id = CalendarSync.resolve(choice, among: refs) else { return nil }
        return calendars.first { $0.id == id }
    }

    /// The task chose a calendar this device does not have (#203 Teil C): no event from here.
    func isMissing(_ task: TaskItem) -> Bool {
        guard appCalendarID != nil, let choice = CalendarSync.choice(for: task) else { return false }
        return CalendarSync.resolve(choice, among: refs) == nil
    }

    /// What a task switched on now takes along: the device default while this device has that
    /// calendar (or before a sync could tell), nil for "Loose Ends".
    var defaultForNewEvents: CalendarSync.Choice? {
        guard let deviceDefault, !calendars.isEmpty else { return deviceDefault }
        return CalendarSync.resolve(deviceDefault, among: refs) == nil ? nil : deviceDefault
    }

    /// The default as a calendar of this device; "Loose Ends" without one, nil when it is missing here.
    var defaultTarget: Target? {
        guard let deviceDefault else { return calendars.first { $0.id == appCalendarID } }
        guard let id = CalendarSync.resolve(deviceDefault, among: refs) else { return nil }
        return calendars.first { $0.id == id }
    }

    func setDeviceDefault(_ choice: CalendarSync.Choice?) {
        CalendarSync.setDeviceDefault(choice)
        deviceDefault = choice
    }

    private var refs: [CalendarSync.CalendarRef] {
        calendars.map { CalendarSync.CalendarRef(id: $0.id, account: $0.account, name: $0.title) }
    }

    /// A sync only when access is already granted: the settings show the calendars without ever
    /// asking for access (#203 Teil C2).
    func refreshIfAllowed() async {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        await sync()
    }

    /// Saves come in bursts; one sync shortly after the last.
    func syncSoon() {
        guard !Self.suppressed else { return }
        debounce?.cancel()
        debounce = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            await self?.sync()
        }
    }

    /// Brings the calendars in line with the tasks and writes the event ids back. A task deleted
    /// outright (not just switched off) leaves no `TaskItem` behind to ask for its event's removal —
    /// once access is already granted, every sync also checks the calendars for such orphans (#122),
    /// without ever requesting access on their account alone.
    func sync() async {
        guard !Self.suppressed else { return }
        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            let status = EKEventStore.authorizationStatus(for: .event)
            // Access taken away in Settings: say so at once, whatever note stood before (#203).
            if status != .fullAccess, status != .notDetermined {
                forgetCalendars()
                if tasks.contains(where: \.showInCalendar) { problem = .accessDenied }
                return
            }
            let quickChanges = CalendarSync.changes(in: tasks)
            guard !quickChanges.isEmpty || status == .fullAccess, await ensureAccess() else { return }
            let appCalendar = try appCalendar()
            calendars = Self.targets(store.calendars(for: .event).filter(Self.isWritable) + [appCalendar])
            appCalendarID = appCalendar.calendarIdentifier
            try apply(to: tasks, appCalendar: appCalendar)
            try store.commit()
            if context.hasChanges {
                try context.save()
            }
            problem = nil
        } catch {
            Self.logger.error("Calendar sync failed: \(error, privacy: .public)")
            problem = (error as? CalendarError) == .noWritableSource ? .noWritableSource : .syncFailed
            // No stale calendar row next to the note (#203).
            forgetCalendars()
        }
    }

    private func forgetCalendars() {
        calendars = []
        appCalendarID = nil
    }

    private func apply(to tasks: [TaskItem], appCalendar: EKCalendar) throws {
        let watched = watchedCalendars(appCalendar: appCalendar)
        let watchedIDs = Set(watched.map(\.calendarIdentifier))
        var unmarked: Set<String> = []
        var marked: [String: UUID] = [:]
        var markedByTask: [UUID: [EKEvent]] = [:]
        for event in events(in: watched) {
            guard let id = event.eventIdentifier else { continue }
            if let taskID = CalendarSync.taskID(fromMark: event.url) {
                marked[id] = taskID
                markedByTask[taskID, default: []].append(event)
            } else if event.calendar.calendarIdentifier == appCalendar.calendarIdentifier {
                unmarked.insert(id)
            }
        }
        // Unmarked events count only in the app's own calendar, as before the mark existed (#122).
        let changes = CalendarSync.changes(in: tasks, knownEventIDs: unmarked)
        let orphans = changes.removeOrphaned + CalendarSync.orphanedMarks(marked, taskIDs: Set(tasks.map(\.id)))
        for id in orphans {
            if let event = store.event(withIdentifier: id), watchedIDs.contains(event.calendar.calendarIdentifier) {
                try store.remove(event, span: .thisEvent, commit: false)
            }
        }
        for task in changes.remove {
            var gone = markedByTask[task.id] ?? []
            if let id = task.calendarEventID, let event = store.event(withIdentifier: id),
               watchedIDs.contains(event.calendar.calendarIdentifier) {
                gone.append(event)
            }
            try remove(gone)
            task.calendarEventID = nil
        }
        for task in changes.create + changes.update {
            guard let plan = CalendarSync.plan(for: task) else { continue }
            let own = task.calendarEventID.flatMap { store.event(withIdentifier: $0) }
            guard let destination = destination(for: task, appCalendar: appCalendar) else {
                // The chosen calendar is not on this device: no event from here (#203 Teil C).
                if let own { try remove([own]) }
                continue
            }
            // Its own event or one carrying its mark, here or written by another device that sees
            // the same calendar; anything of it left in another calendar goes (the choice changed).
            let candidates = [own].compactMap { $0 } + (markedByTask[task.id] ?? [])
            let isHere: (EKEvent) -> Bool = { $0.calendar.calendarIdentifier == destination.calendarIdentifier }
            try remove(candidates.filter { !isHere($0) })
            let here = Self.distinct(candidates.filter(isHere))
            // Two or more devices wrote one each before they saw the other's (#691): one stays.
            let gone = Set(CalendarSync.duplicates(among: here.map(Self.key)).map(\.local))
            try remove(here.filter { gone.contains($0.eventIdentifier ?? "") })
            let keep = here.first { !gone.contains($0.eventIdentifier ?? "") }
            let existing = keep
            if let existing, Self.matches(existing, plan, mark: CalendarSync.mark(for: task)) { continue }
            let event = existing ?? EKEvent(eventStore: store)
            event.calendar = destination
            event.title = plan.title
            event.startDate = plan.start
            event.endDate = plan.end
            event.isAllDay = plan.isAllDay
            event.notes = plan.notes
            event.url = CalendarSync.mark(for: task)
            try store.save(event, span: .thisEvent, commit: false)
            rememberWritten(destination)
            // An adopted event keeps the id its own device wrote; overwriting it would flip the field
            // between devices on every sync.
            let ownWentAsDuplicate = own.map { isHere($0) && $0.eventIdentifier != keep?.eventIdentifier } ?? false
            if existing == nil || (own != nil && !ownWentAsDuplicate), task.calendarEventID != event.eventIdentifier {
                task.calendarEventID = event.eventIdentifier
            }
        }
    }

    private func remove(_ events: [EKEvent]) throws {
        var seen: Set<String> = []
        for event in events where seen.insert(event.eventIdentifier ?? "").inserted {
            try store.remove(event, span: .thisEvent, commit: false)
        }
    }

    /// Its own event can also carry the mark: one entry per event id.
    private static func distinct(_ events: [EKEvent]) -> [EKEvent] {
        var seen: Set<String> = []
        return events.filter { seen.insert($0.eventIdentifier ?? "").inserted }
    }

    private static func key(_ event: EKEvent) -> CalendarSync.EventKey {
        CalendarSync.EventKey(local: event.eventIdentifier ?? "", shared: event.calendarItemExternalIdentifier)
    }

    /// The task's calendar on this device; nil when it chose one this device does not have.
    private func destination(for task: TaskItem, appCalendar: EKCalendar) -> EKCalendar? {
        guard let choice = CalendarSync.choice(for: task) else { return appCalendar }
        guard let id = CalendarSync.resolve(choice, among: refs) else { return nil }
        return store.calendar(withIdentifier: id)
    }

    /// The app's own calendar and every calendar this device wrote into that still exists.
    private func watchedCalendars(appCalendar: EKCalendar) -> [EKCalendar] {
        let written = UserDefaults.standard.stringArray(forKey: Self.writtenCalendarsKey) ?? []
        let others = written.filter { $0 != appCalendar.calendarIdentifier }.compactMap { store.calendar(withIdentifier: $0) }
        return [appCalendar] + others
    }

    private func rememberWritten(_ calendar: EKCalendar) {
        let defaults = UserDefaults.standard
        var written = defaults.stringArray(forKey: Self.writtenCalendarsKey) ?? []
        guard !written.contains(calendar.calendarIdentifier) else { return }
        written.append(calendar.calendarIdentifier)
        defaults.set(written, forKey: Self.writtenCalendarsKey)
    }

    /// Calendars an event can be written into: no subscriptions, no birthdays, nothing read-only.
    private static func isWritable(_ calendar: EKCalendar) -> Bool {
        calendar.allowsContentModifications && calendar.type != .subscription && calendar.type != .birthday
    }

    /// One entry per calendar, by account and then name.
    private static func targets(_ calendars: [EKCalendar]) -> [Target] {
        var seen: Set<String> = []
        return calendars
            .filter { seen.insert($0.calendarIdentifier).inserted }
            .map { Target(id: $0.calendarIdentifier, account: $0.source.title, title: $0.title, color: $0.cgColor) }
            .sorted { ($0.account, $0.title, $0.id) < ($1.account, $1.title, $1.id) }
    }

    private func ensureAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            clearAccessProblem()
            return true
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                if granted { clearAccessProblem() } else { problem = .accessDenied }
                return granted
            } catch {
                Self.logger.error("Calendar access request failed: \(error, privacy: .public)")
                problem = .accessDenied
                return false
            }
        default:
            problem = .accessDenied
            return false
        }
    }

    /// Only the access problem goes away with access; a failed sync stays until one succeeds.
    private func clearAccessProblem() {
        if problem == .accessDenied { problem = nil }
    }

    /// The app's own calendar, found by its remembered id or its title, else created.
    private func appCalendar() throws -> EKCalendar {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: Self.calendarKey), let known = store.calendar(withIdentifier: id) {
            return known
        }
        if let found = store.calendars(for: .event).first(where: { $0.title == CalendarSync.calendarTitle }) {
            defaults.set(found.calendarIdentifier, forKey: Self.calendarKey)
            return found
        }
        return try createCalendar()
    }

    /// Creates the app's calendar in the first account that accepts it, in `CalendarSync.sourceOrder`.
    /// An account that refuses (Google, #203) is logged and the next one tried.
    private func createCalendar() throws -> EKCalendar {
        let sources = store.sources
        let order = CalendarSync.sourceOrder(
            sources.map(Self.candidate),
            defaultSourceID: store.defaultCalendarForNewEvents?.source.sourceIdentifier
        )
        for id in order {
            guard let source = sources.first(where: { $0.sourceIdentifier == id }) else { continue }
            let calendar = EKCalendar(for: .event, eventStore: store)
            calendar.title = CalendarSync.calendarTitle
            calendar.source = source
            do {
                try store.saveCalendar(calendar, commit: true)
                UserDefaults.standard.set(calendar.calendarIdentifier, forKey: Self.calendarKey)
                return calendar
            } catch {
                Self.logger.error("Creating the calendar in \(source.title, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
        throw CalendarError.noWritableSource
    }

    private static func candidate(_ source: EKSource) -> CalendarSync.SourceCandidate {
        let kind: CalendarSync.SourceCandidate.Kind = switch source.sourceType {
        case .calDAV, .mobileMe: .calDAV
        case .local: .local
        case .exchange: .exchange
        case .subscribed: .subscribed
        case .birthdays: .birthdays
        @unknown default: .other
        }
        return CalendarSync.SourceCandidate(id: source.sourceIdentifier, title: source.title, kind: kind)
    }

    /// Every event in these calendars. EventKit refuses an unbounded range, so this looks a year
    /// either side of now — comfortably past any due date a personal task list actually carries (#122).
    private func events(in calendars: [EKCalendar]) -> [EKEvent] {
        let now = Date()
        let start = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let end = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
    }

    /// EventKit keeps whole seconds, so dates match within a second. An event without the mark is
    /// written again once, so it carries it from then on.
    private static func matches(_ event: EKEvent, _ plan: CalendarSync.EventPlan, mark: URL?) -> Bool {
        guard let start = event.startDate, let end = event.endDate else { return false }
        return event.title == plan.title
            && abs(start.timeIntervalSince(plan.start)) < 1
            && abs(end.timeIntervalSince(plan.end)) < 1
            && event.isAllDay == plan.isAllDay
            && (event.notes ?? "") == (plan.notes ?? "")
            && event.url == mark
    }

    enum CalendarError: Error, Equatable {
        case noWritableSource
    }
}
