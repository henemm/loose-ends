import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The start screen's headline (#426): one fact a day, from 16:00 a look back at what got done.
@Suite("Start headline") struct StartHeadlineTests {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    /// Thursday, 12 March 2026, in Berlin.
    static func at(_ hour: Int, minute: Int = 0, day: Int = 0) -> Date {
        let base = calendar.date(from: DateComponents(year: 2026, month: 3, day: 12))!
        return calendar.date(byAdding: DateComponents(day: day, hour: hour, minute: minute), to: base)!
    }

    @MainActor static func task(_ title: String, due: Date? = nil, timed: Bool = false, status: TaskStatus = .active,
                                capturedDaysAgo: Int = 0, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: title)
        task.title = title
        task.status = status
        task.dueDate = due
        task.dueHasTime = timed
        task.capturedAt = at(8, day: -capturedDaysAgo)
        store.context.insert(task)
        return task
    }

    @MainActor static func done(_ title: String, at date: Date, in store: TestStore) -> TaskItem {
        let task = task(title, status: .done, in: store)
        task.completedAt = date
        return task
    }

    static func headline(_ all: [TaskItem], _ now: Date) -> StartHeadline {
        StartHeadline.of(all, now: now, calendar: calendar)
    }

    // MARK: - A, A+

    @Test("From 16:00 with something done today, the look back wins over time pressure")
    @MainActor func lookBack() async throws {
        let store = try TestStore()
        let first = Self.done("Steuerbescheid prüfen", at: Self.at(11), in: store)
        let second = Self.done("Mama zurückrufen", at: Self.at(15), in: store)
        let missed = Self.task("Zahnarzt", due: Self.at(9), timed: true, in: store)

        let result = Self.headline([first, second, missed], Self.at(16, minute: 30))
        #expect(result == .doneToday(count: 2, titles: ["Mama zurückrufen", "Steuerbescheid prüfen"], next: nil))
    }

    @Test("Before 16:00 the look back waits; the time pressure speaks")
    @MainActor func noLookBackBeforeFour() async throws {
        let store = try TestStore()
        let done = Self.done("Steuerbescheid prüfen", at: Self.at(9), in: store)
        let ahead = Self.task("Anna abholen", due: Self.at(17), timed: true, in: store)

        #expect(Self.headline([done, ahead], Self.at(15, minute: 59)) == .upcoming(title: "Anna abholen", at: Self.at(17), count: 1))
    }

    @Test("A+: a fixed time within two hours follows the look back; a later one does not")
    @MainActor func lookBackWithNext() async throws {
        let store = try TestStore()
        let done = Self.done("Steuerbescheid prüfen", at: Self.at(12), in: store)
        let soon = Self.task("Anna abholen", due: Self.at(18), timed: true, in: store)
        let late = Self.task("Kino", due: Self.at(21), timed: true, in: store)

        let result = Self.headline([done, soon, late], Self.at(16, minute: 30))
        #expect(result == .doneToday(count: 1, titles: ["Steuerbescheid prüfen"],
                                     next: .init(title: "Anna abholen", at: Self.at(18))))
        #expect(Self.headline([done, late], Self.at(16, minute: 30))
                == .doneToday(count: 1, titles: ["Steuerbescheid prüfen"], next: nil))
    }

    @Test("Without anything done, the afternoon never talks about it; the ladder goes on")
    @MainActor func nothingDoneNoBlame() async throws {
        let store = try TestStore()
        let open = Self.task("Steuerbescheid prüfen", in: store)
        #expect(Self.headline([open], Self.at(20)) == .calm)
    }

    @Test("A repeating task counts through its completion record")
    @MainActor func repeatingCounts() async throws {
        let store = try TestStore()
        let gym = Self.task("Sport", due: Self.at(0, day: 1), in: store)
        gym.repeatRule = RepeatRule(frequency: .daily)
        gym.completions = [CompletionRecord(task: gym, completedAt: Self.at(10), dueDateAtCompletion: Self.at(0))]

        #expect(Self.headline([gym], Self.at(17)) == .doneToday(count: 1, titles: ["Sport"], next: nil))
    }

    @Test("A title longer than 32 characters is not quoted")
    @MainActor func longTitle() async throws {
        let store = try TestStore()
        let done = Self.done("Steuerunterlagen für das Finanzamt zusammensuchen", at: Self.at(10), in: store)
        #expect(Self.headline([done], Self.at(17)) == .doneToday(count: 1, titles: [nil], next: nil))
    }

    // MARK: - 1, 2

    @Test("A fixed time that has passed today comes before one still ahead")
    @MainActor func missedThenUpcoming() async throws {
        let store = try TestStore()
        let missed = Self.task("Zahnarzt", due: Self.at(9), timed: true, in: store)
        let ahead = Self.task("Steuerbescheid", due: Self.at(12), timed: true, in: store)

        #expect(Self.headline([missed, ahead], Self.at(10)) == .missed(title: "Zahnarzt", at: Self.at(9)))
        missed.status = .done
        #expect(Self.headline([missed, ahead], Self.at(10)) == .upcoming(title: "Steuerbescheid", at: Self.at(12), count: 1))
    }

    // MARK: - 3 to 8

    @Test("Each quiet rung on its own: waiting, pile, old, yesterday")
    @MainActor func quietRungs() async throws {
        let store = try TestStore()
        let carried = Self.task("Mama zurückrufen", due: Self.at(0, day: -3), in: store)
        #expect(Self.headline([carried], Self.at(10)) == .waiting(title: "Mama zurückrufen", days: 3))

        let garden = TaskContext(name: "Garten")
        store.context.insert(garden)
        let pile = (1...4).map { Self.task("Beet \($0)", in: store) }
        pile.forEach { $0.contexts = [garden] }
        #expect(Self.headline(pile, Self.at(10)) == .pile(label: "Garten", count: 4))

        let old = (1...3).map { Self.task("Alt \($0)", capturedDaysAgo: 40, in: store) }
        #expect(Self.headline(old, Self.at(10)) == .old(count: 3))

        let yesterday = Self.done("Steuer", at: Self.at(18, day: -1), in: store)
        let open = Self.task("Offen", in: store)
        #expect(Self.headline([yesterday, open], Self.at(10)) == .doneYesterday(count: 1))
    }

    @Test("Several quiet rungs take turns from one day to the next")
    @MainActor func quietRotates() async throws {
        let store = try TestStore()
        let carried = Self.task("Mama zurückrufen", due: Self.at(0, day: -3), in: store)
        let old = (1...3).map { Self.task("Alt \($0)", capturedDaysAgo: 40, in: store) }
        let all = [carried] + old

        let today = Self.headline(all, Self.at(10))
        // The next day the carried task is one day older; the kind of rung must change.
        let tomorrow = Self.headline(all, Self.at(10, day: 1))
        let kinds = [today, tomorrow].map { headline -> String in
            if case .waiting = headline { return "waiting" }
            if case .old = headline { return "old" }
            return "other"
        }
        #expect(Set(kinds) == ["waiting", "old"])
    }

    @Test("Calm with open tasks and nothing standing out; all tied up with nothing open")
    @MainActor func calmAndAllDone() async throws {
        let store = try TestStore()
        #expect(Self.headline([], Self.at(10)) == .allDone)
        let open = Self.task("Steuer", in: store)
        #expect(Self.headline([open], Self.at(10)) == .calm)
    }

    // MARK: - Words

    @Test("German sentences: spelled-out numbers, capital first letter")
    func germanWords() {
        let de = Locale(identifier: "de_DE")
        #expect(StartHeadlineText.word(4, locale: de) == "vier")
        #expect(StartHeadlineText.word(48, locale: de) == 48.formatted())
        let sentence = StartHeadlineText.sentence(.old(count: 3), locale: de)
        #expect(sentence.first?.isUppercase == true)
    }
}
