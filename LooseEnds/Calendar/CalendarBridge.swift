import EventKit
import Foundation
import OSLog
import SwiftData

/// EventKit for `CalendarSync`: one event per task in the app's own "Loose Ends" calendar. The
/// app never reads or touches other calendars; full access is only needed so it can refresh and
/// remove its own events. Asks for access the first time a task wants to be shown, and stays
/// silent under tests, where a permission prompt would block the run.
@Observable
@MainActor
final class CalendarBridge {
    private(set) var accessDenied = false

    @ObservationIgnored private let container: ModelContainer
    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var debounce: Task<Void, Never>?
    private static let calendarKey = "calendarIdentifier"
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Calendar")

    private static var suppressed: Bool {
        ModelContainerFactory.isRunningTests || ModelContainerFactory.isUITesting
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

    /// Brings the app's calendar in line with the tasks and writes the event ids back.
    func sync() async {
        guard !Self.suppressed else { return }
        let context = container.mainContext
        do {
            let tasks = try context.fetch(FetchDescriptor<TaskItem>())
            let changes = CalendarSync.changes(in: tasks)
            guard !changes.isEmpty, await ensureAccess() else { return }
            let calendar = try appCalendar()

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
        } catch {
            Self.logger.error("Calendar sync failed: \(error, privacy: .public)")
        }
    }

    private func ensureAccess() async -> Bool {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            accessDenied = false
            return true
        case .notDetermined:
            do {
                let granted = try await store.requestFullAccessToEvents()
                accessDenied = !granted
                return granted
            } catch {
                Self.logger.error("Calendar access request failed: \(error, privacy: .public)")
                accessDenied = true
                return false
            }
        default:
            accessDenied = true
            return false
        }
    }

    /// The app's own calendar, found by its remembered id or its title, else created next to the
    /// user's default calendar.
    private func appCalendar() throws -> EKCalendar {
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: Self.calendarKey), let known = store.calendar(withIdentifier: id) {
            return known
        }
        if let found = store.calendars(for: .event).first(where: { $0.title == CalendarSync.calendarTitle }) {
            defaults.set(found.calendarIdentifier, forKey: Self.calendarKey)
            return found
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = CalendarSync.calendarTitle
        guard let source = store.defaultCalendarForNewEvents?.source
                ?? store.sources.first(where: { $0.sourceType == .calDAV })
                ?? store.sources.first(where: { $0.sourceType == .local }) else {
            throw CalendarError.noSource
        }
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        defaults.set(calendar.calendarIdentifier, forKey: Self.calendarKey)
        return calendar
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

    enum CalendarError: Error {
        case noSource
    }
}
