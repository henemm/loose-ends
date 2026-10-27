import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Subtasks in the lists (#565, Henning 2026-10-20, concept D): a subtask stands outside its task
/// only with something of its own. Its own date puts it wherever a dated task stands: "Due", "Now",
/// the badge, the start headline, "Loose ends" and the Mac's "Next days" (Henning, 2026-10-21: moved
/// to tomorrow, it had vanished until its day); its own tag in that tag's list. Lined up as next, with a
/// duration, repeating or parked it stands in "Next up", "Now", "Quick", "Repeating" and "Parked" too
/// (Henning, 2026-10-27: a subtask lined up as next did not show in "Now"). Only "New", "Old" and
/// "Done" stay top level.
@Suite("Subtasks in the lists") struct SubtaskListsTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, 10:00 in Berlin.
    static let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 10))!

    static func day(_ offset: Int, hour: Int = 9) -> Date {
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: DateComponents(day: offset, hour: hour), to: start)!
    }

    @MainActor static func task(_ text: String, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.title = text
        task.status = .active
        store.context.insert(task)
        return task
    }

    @Test("A subtask with its own date today stands in Due, Due today, Now and the badge; one without stays out")
    @MainActor func ownDateLists() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let dated = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        dated.dueDate = Self.day(0, hour: 15)
        dated.dueHasTime = true
        let bare = try Subtasks.add("Kisten packen", to: parent, in: store.context, now: Self.day(-1))
        let all = [parent, dated, bare]

        let due = ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(due == [dated.id])
        #expect(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [dated.id])
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).today.map(\.id) == [dated.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 1)
    }

    @Test("A done subtask with a date stays out, as a done task does")
    @MainActor func doneSubtaskStaysOut() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let sub = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        sub.dueDate = Self.day(0)
        Subtasks.toggle(sub, now: Self.now)
        let all = [parent, sub]

        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).isEmpty)
        #expect(ViewRules.dueToday(in: all, now: Self.now, calendar: Self.calendar).isEmpty)
    }

    @Test("A subtask with its own tag stands in that tag's list; one without stays out")
    @MainActor func ownTagLists() async throws {
        let store = try TestStore()
        let phone = TaskContext(name: "Telefon", sortOrder: 0)
        store.context.insert(phone)
        let parent = Self.task("Umzug", in: store)
        let tagged = try Subtasks.add("Vermieter anrufen", to: parent, in: store.context)
        tagged.contexts = [phone]
        let bare = try Subtasks.add("Kisten packen", to: parent, in: store.context)
        let all = [parent, tagged, bare]

        #expect(ViewRules.tasks(inContext: phone, in: all).map(\.id) == [tagged.id])
    }

    @Test("New, Old and Done keep to top-level tasks, whatever a subtask carries")
    @MainActor func topLevelViewsStay() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        parent.capturedAt = Self.day(-60)
        let sub = try Subtasks.add("Vermieter anrufen", to: parent, in: store.context, now: Self.day(-60))
        sub.status = .unverified
        Subtasks.toggle(sub, now: Self.now)
        let all = [parent, sub]

        for kind in [ViewKind.new, .old, .done] {
            #expect(!ViewRules.tasks(for: kind, in: all, now: Self.now, calendar: Self.calendar).contains { $0.id == sub.id },
                    "\(kind) should keep to top-level tasks")
        }
    }

    @Test("A subtask lined up as next stands in Next up, in Now, in the badge and in the widget's list (Henning, 2026-10-27)")
    @MainActor func nextUpSubtaskStandsInNow() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let sub = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        let bare = try Subtasks.add("Kisten packen", to: parent, in: store.context, now: Self.day(-1))
        TaskActions.toggleNext(sub, among: [parent, sub, bare])
        let all = [parent, sub, bare]

        #expect(ViewRules.tasks(for: .next, in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [sub.id])
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).all.map(\.id) == [sub.id])
        #expect(ViewRules.badgeCount(in: all, now: Self.now, calendar: Self.calendar) == 1)
        #expect(ViewRules.nextRanks(in: all)[sub.id] == 1, "the star with its number stands on the line too")
    }

    @Test("A subtask lined up as next and due today stands once in Now, a done or parked one not at all")
    @MainActor func nextUpSubtaskOnceOrNot() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let both = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        both.dueDate = Self.day(0, hour: 15)
        both.nextRank = 1
        let done = try Subtasks.add("Schlüssel abgeben", to: parent, in: store.context, now: Self.day(-1))
        done.nextRank = 2
        Subtasks.toggle(done, now: Self.now)
        let parked = try Subtasks.add("Keller räumen", to: parent, in: store.context, now: Self.day(-1))
        parked.nextRank = 3
        TaskActions.park(parked, now: Self.now)
        let all = [parent, both, done, parked]

        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).all.map(\.id) == [both.id])
        #expect(ViewRules.tasks(for: .next, in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [both.id])
    }

    @Test("A subtask with its own duration stands in Quick, a repeating one in Repeating, a parked one in Parked")
    @MainActor func ownAttributesStandInTheirViews() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let quick = try Subtasks.add("Vermieter anrufen", to: parent, in: store.context, now: Self.day(-1))
        quick.duration = .minutes5
        let long = try Subtasks.add("Wohnung streichen", to: parent, in: store.context, now: Self.day(-1))
        long.duration = .hours2plus
        let repeating = try Subtasks.add("Pflanzen gießen", to: parent, in: store.context, now: Self.day(-1))
        repeating.repeatRule = RepeatRule(frequency: .weekly, interval: 1)
        repeating.dueDate = Self.day(3)
        let parked = try Subtasks.add("Keller räumen", to: parent, in: store.context, now: Self.day(-1))
        TaskActions.park(parked, now: Self.now)
        let all = [parent, quick, long, repeating, parked]

        func ids(_ kind: ViewKind) -> [UUID] {
            ViewRules.tasks(for: kind, in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        }
        #expect(ids(.quick) == [quick.id])
        #expect(ids(.repeating) == [repeating.id])
        #expect(ids(.parked) == [parked.id])
    }

    @Test("A subtask's own project is not read: it stands in its task's project block only, folded under it")
    @MainActor func projectStaysWithTask() async throws {
        let store = try TestStore()
        let project = Project(name: "Haushalt", sortOrder: 0)
        store.context.insert(project)
        let parent = Self.task("Umzug", in: store)
        parent.project = project
        let sub = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        let all = [parent, sub]

        #expect(sub.project?.id == project.id)
        #expect(ViewRules.tasks(inProject: project, in: all, now: Self.now, calendar: Self.calendar).map(\.id) == [parent.id])
    }

    @Test("Moved to tomorrow, a dated subtask stands in Loose ends among the dated and in the Mac's Next days (#565)")
    @MainActor func tomorrowStaysVisible() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let undated = Self.task("Keller aufräumen", in: store)
        let tomorrow = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        tomorrow.dueDate = Self.day(1)
        let bare = try Subtasks.add("Kisten packen", to: parent, in: store.context, now: Self.day(-1))
        let done = try Subtasks.add("Schlüssel abgeben", to: parent, in: store.context, now: Self.day(-1))
        done.dueDate = Self.day(1)
        Subtasks.toggle(done, now: Self.now)
        let all = [parent, undated, tomorrow, bare, done]

        // Not due yet: out of Due and Now, as a task due tomorrow is.
        #expect(ViewRules.tasks(for: .due, in: all, now: Self.now, calendar: Self.calendar).isEmpty)
        #expect(ViewRules.now(in: all, now: Self.now, calendar: Self.calendar).all.isEmpty)
        // Loose ends: the undated tasks, then the line dated tomorrow under "Later" (#657); the bare and the done line out.
        let open = ViewRules.tasks(for: .open, in: all, now: Self.now, calendar: Self.calendar).map(\.id)
        #expect(open.last == tomorrow.id)
        #expect(Set(open) == [tomorrow.id, parent.id, undated.id])
        // Next days on the Mac: the tile for tomorrow counts the line.
        let days = SideColumn.days(in: all, now: Self.now, calendar: Self.calendar)
        #expect(days.map(\.count) == [0, 1, 0, 0, 0])
    }

    @Test("The start headline counts a subtask due today by its own date")
    @MainActor func headlineCountsSubtask() async throws {
        let store = try TestStore()
        let parent = Self.task("Umzug", in: store)
        let sub = try Subtasks.add("Kartons holen", to: parent, in: store.context, now: Self.day(-1))
        sub.dueDate = Self.day(0, hour: 0)
        let headline = StartHeadline.of([parent, sub], now: Self.now, calendar: Self.calendar)
        #expect(headline == .dueToday(title: "Kartons holen", count: 1))
    }
}
