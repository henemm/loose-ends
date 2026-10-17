import Foundation

/// What the wide start page's right column shows (#473, draft "Main"): three small blocks, no new
/// model field. Pure over the tasks; the view only draws.
enum SideColumn {
    static let quickLimit = 3
    static let recentLimit = 3
    static let dayCount = 5

    /// "Quick": the same set as the Quick view (open, not blocked, 15 minutes at most), the first
    /// three by urgency then importance.
    static func quick(in all: [TaskItem]) -> [TaskItem] {
        Array(ViewRules.tasks(for: .quick, in: all).prefix(quickLimit))
    }

    /// "Recently captured": the last three open top-level tasks, newest first.
    static func recent(in all: [TaskItem]) -> [TaskItem] {
        Array(
            all.filter { $0.parent == nil && $0.isOpen }
                .sorted { $0.capturedAt > $1.capturedAt }
                .prefix(recentLimit)
        )
    }

    struct Day: Equatable {
        let date: Date
        let count: Int
        let isToday: Bool
    }

    /// "Next days": five tiles from today with the number of open, unblocked top-level tasks due
    /// that day. What is left from earlier days waits in the "Loose ends" card and is not today's (#518).
    static func days(in all: [TaskItem], now: Date = Date(), calendar: Calendar = .current) -> [Day] {
        let today = calendar.startOfDay(for: now)
        let open = all.filter { $0.parent == nil && $0.isOpen && !$0.isBlocked }
        return (0..<dayCount).compactMap { offset in
            guard let start = calendar.date(byAdding: .day, value: offset, to: today),
                  let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let count = open.filter { task in
                guard let due = task.dueDate else { return false }
                return due >= start && due < end
            }.count
            return Day(date: start, count: count, isToday: offset == 0)
        }
    }
}
