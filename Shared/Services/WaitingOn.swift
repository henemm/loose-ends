import Foundation

/// "Waiting on" set by hand (#251, design decision on #27): a reference to another full task, not a
/// subtask. Linking and loosening only touch the connection — both tasks stay. Every change is a
/// user `Revision` on `blockedBy`. Pure over the model objects; the caller saves.
enum WaitingOn {
    /// The tasks `task` waits on: open ones first in title order, then the done ones, which stay
    /// visible greyed out (#27: "danach … grau abgehakt").
    static func blockers(of task: TaskItem) -> [TaskItem] {
        (task.blockedBy ?? []).sorted { lhs, rhs in
            if lhs.isOpen != rhs.isOpen { return lhs.isOpen }
            return lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
        }
    }

    /// The name after "Waiting on:" in the list row (#27): the first open blocker, cut to a few words
    /// so the other traits still fit on the line; "+1" for each further open one. Nil when nothing
    /// is open any more — then the task no longer waits.
    static func rowLabel(for task: TaskItem, maxLength: Int = 24) -> String? {
        let open = blockers(of: task).filter(\.isOpen)
        guard let first = open.first else { return nil }
        var name = first.displayTitle
        if name.count > maxLength {
            name = String(name.prefix(maxLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return open.count > 1 ? "\(name) +\(open.count - 1)" : name
    }

    /// What "Choose a task" offers: open top-level tasks, not the task itself, not one it already
    /// waits on, and none that waits on it — directly or further down the chain — since linking
    /// such a task would make both wait on each other forever. A query filters by title and raw
    /// text, case- and accent-insensitive.
    static func candidates(for task: TaskItem, among all: [TaskItem], matching query: String = "") -> [TaskItem] {
        let linked = Set((task.blockedBy ?? []).map(\.id))
        let waiting = waitingChain(on: task)
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return all
            .filter { $0.parent == nil && $0.isOpen && $0.id != task.id }
            .filter { !linked.contains($0.id) && !waiting.contains($0.id) }
            .filter { needle.isEmpty || matches($0, needle) }
            .sorted { $0.capturedAt > $1.capturedAt }
    }

    /// Links `blocker` to `task`. Returns nil when nothing changed or the link would close a loop.
    @discardableResult
    static func link(_ blocker: TaskItem, to task: TaskItem, now: Date = Date()) -> Revision? {
        guard blocker.id != task.id,
              !(task.blockedBy ?? []).contains(where: { $0.id == blocker.id }),
              !waitingChain(on: task).contains(blocker.id) else { return nil }
        return change(task, to: (task.blockedBy ?? []) + [blocker], now: now)
    }

    /// "Loosen" (#27): only the connection goes, both tasks stay.
    @discardableResult
    static func loosen(_ blocker: TaskItem, from task: TaskItem, now: Date = Date()) -> Revision? {
        let remaining = (task.blockedBy ?? []).filter { $0.id != blocker.id }
        guard remaining.count != (task.blockedBy ?? []).count else { return nil }
        return change(task, to: remaining, now: now)
    }

    /// The tasks that wait on `task`, also through other tasks: linking any of them as a blocker
    /// of `task` would close a loop.
    static func waitingChain(on task: TaskItem) -> Set<UUID> {
        var seen = Set<UUID>()
        var queue = task.blocks ?? []
        while let next = queue.popLast() {
            guard seen.insert(next.id).inserted else { continue }
            queue += next.blocks ?? []
        }
        return seen
    }

    /// The revision carries the titles, not the ids `FieldCodec` uses: the "Changes" sheet shows
    /// them as they are, and a user revision is never reset, so nothing has to resolve them.
    /// Sorted, because a to-many relationship has no order: after a save SwiftData may hand the
    /// blockers back in any order, and the same set must always read the same.
    private static func change(_ task: TaskItem, to blockers: [TaskItem], now: Date) -> Revision {
        let before = titles(task.blockedBy ?? [])
        let revision = Revision(task: task, field: .blockedBy, oldValue: before, newValue: titles(blockers), author: .user)
        revision.createdAt = now
        task.revisions = (task.revisions ?? []) + [revision]
        task.blockedBy = blockers
        return revision
    }

    private static func titles(_ tasks: [TaskItem]) -> String? {
        tasks.isEmpty ? nil : FieldCodec.encode(tasks.map(\.displayTitle).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
    }

    private static func matches(_ task: TaskItem, _ needle: String) -> Bool {
        [task.displayTitle, task.rawText].contains {
            $0.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}
