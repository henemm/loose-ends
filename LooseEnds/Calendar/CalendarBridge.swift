import CoreGraphics
import EventKit
import Foundation
import OSLog
import SwiftData

/// EventKit for `CalendarSync`: one event per task in the app's own "Loose Ends" calendar, created
/// in the first account that allows it (#203). The app never reads or touches other calendars;
/// full access is only needed so it can refresh and remove its own events. Asks for access the
/// first time a task wants to be shown, and stays silent under tests, where a permission prompt
/// would block the run.
@Observable
@MainActor
final class CalendarBridge {
    /// What went wrong on the last sync; cleared by the next one that succeeds.
    private(set) var problem: CalendarSync.Problem?
    /// The calendar events go to, once a sync has found or created it.
    private(set) var target: Target?

    struct Target {
        let title: String
        let color: CGColor
    }

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var debounce: Task<Void, Never>?
    private static let calendarKey = "calendarIdentifier"
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Calendar")

    /// The calendar UI test (#203) lets the bridge run against the simulator's calendar while the
    /// store stays in memory.
    private static var suppressed: Bool {
        ModelContainerFactory.isRunningTests
            || (ModelContainerFactory.isUITesting && !ProcessInfo.processInfo.arguments.contains("--ui-testing-calendar"))
    }

    init(container: ModelContainer) {
        self.container = container
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

    /// Brings the app's calendar in line with the tasks and writes the event ids back. A task
    /// deleted outright (not just switched off) leaves no `TaskItem` behind to ask for its event's
    /// removal — once access is already granted, every sync also checks the calendar itself for
    /// such orphans (#122), without ever requesting access on their account alone.
    func sync() async {
        guard !Self.suppressed else { return }
        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            let alreadyAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
            let quickChanges = CalendarSync.changes(in: tasks)
            guard !quickChanges.isEmpty || alreadyAuthorized, await ensureAccess() else { return }
            let calendar = try appCalendar()
            target = Target(title: calendar.title, color: calendar.cgColor)
            let changes = CalendarSync.changes(in: tasks, knownEventIDs: knownEventIDs(in: calendar))

            for id in changes.removeOrphaned {
                if let event = store.event(withIdentifier: id), event.calendar == calendar {
                    try store.remove(event, span: .thisEvent, commit: false)
                }
            }
            for task in changes.remove {
                if let id = task.calendarEventID, let event = store.event(withIdentifier: id), event.calendar == calendar {
                    try store.remove(event, span: .thisEvent, commit: false)
                }
                task.calendarEventID = nil
            }
            for task in changes.create + changes.update {
                guard let plan = CalendarSync.plan(for: task) else { continue }
                let existing = task.calendarEventID.flatMap { store.event(withIdentifier: $0) }
                if let existing, Self.matches(existing, plan) { continue }
                let event = existing ?? EKEvent(eventStore: store)
                event.calendar = calendar
                event.title = plan.title
                event.startDate = plan.start
                event.endDate = plan.end
                event.isAllDay = plan.isAllDay
                event.notes = plan.notes
                try store.save(event, span: .thisEvent, commit: false)
                if task.calendarEventID != event.eventIdentifier {
                    task.calendarEventID = event.eventIdentifier
                }
            }
            try store.commit()
            if context.hasChanges {
                try context.save()
            }
            problem = nil
        } catch {
            Self.logger.error("Calendar sync failed: \(error, privacy: .public)")
            problem = (error as? CalendarError) == .noWritableSource ? .noWritableSource : .syncFailed
        }
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

    /// The ids of every event already sitting in the app's own calendar, so a task deleted outright
    /// (not just switched off) still gets its leftover event found (#122). EventKit refuses an
    /// unbounded range, so this looks a year either side of now — comfortably past any due date a
    /// personal task list actually carries.
    private func knownEventIDs(in calendar: EKCalendar) -> Set<String> {
        let now = Date()
        let start = Calendar.current.date(byAdding: .year, value: -1, to: now) ?? now
        let end = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        return Set(store.events(matching: predicate).compactMap(\.eventIdentifier))
    }

    /// EventKit keeps whole seconds, so dates match within a second.
    private static func matches(_ event: EKEvent, _ plan: CalendarSync.EventPlan) -> Bool {
        guard let start = event.startDate, let end = event.endDate else { return false }
        return event.title == plan.title
            && abs(start.timeIntervalSince(plan.start)) < 1
            && abs(end.timeIntervalSince(plan.end)) < 1
            && event.isAllDay == plan.isAllDay
            && (event.notes ?? "") == (plan.notes ?? "")
    }

    enum CalendarError: Error, Equatable {
        case noWritableSource
    }
}
