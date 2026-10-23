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

    @Test("A title longer than 32 characters is cut after a whole word, never left out (#585)")
    @MainActor func longTitle() async throws {
        let store = try TestStore()
        let done = Self.done("Steuerunterlagen für das Finanzamt zusammensuchen", at: Self.at(10), in: store)
        #expect(Self.headline([done], Self.at(17))
                == .doneToday(count: 1, titles: ["Steuerunterlagen für das …"], next: nil))
        #expect(StartHeadline.short("Sommer gegen Winterklamotten umräumen") == "Sommer gegen Winterklamotten …")
        #expect(StartHeadline.short("Zweiunddreißig Zeichen lang hier") == "Zweiunddreißig Zeichen lang hier")
        // A first word longer than the limit is cut in the middle; the sentence still names something.
        #expect(StartHeadline.short("Donaudampfschifffahrtsgesellschaftskapitän anrufen")
                == "Donaudampfschifffahrtsgesellsc …")
    }

    // MARK: - 1, 2

    @Test("A fixed time that has passed today comes before one still ahead")
    @MainActor func missedThenUpcoming() async throws {
        let store = try TestStore()
        let missed = Self.task("Zahnarzt", due: Self.at(9), timed: true, in: store)
        let ahead = Self.task("Steuerbescheid", due: Self.at(12), timed: true, in: store)

        #expect(Self.headline([missed, ahead], Self.at(10)) == .missed(title: "Zahnarzt", at: Self.at(9), count: 1))
        missed.status = .done
        #expect(Self.headline([missed, ahead], Self.at(10)) == .upcoming(title: "Steuerbescheid", at: Self.at(12), count: 1))
    }

    @Test("Two fixed times passed: the count and the latest time; the sentence names it (#585)")
    @MainActor func twoMissed() async throws {
        let store = try TestStore()
        let early = Self.task("Rechnung für Senger überweisen", due: Self.at(10), timed: true, in: store)
        let late = Self.task("Sommer gegen Winterklamotten umräumen", due: Self.at(11), timed: true, in: store)

        let result = Self.headline([late, early], Self.at(11, minute: 54))
        #expect(result == .missed(title: "Sommer gegen Winterklamotten …", at: Self.at(11), count: 2))
        // `String(localized:)` speaks the process language (English on CI); only the number word
        // follows `locale`, so the sentence is checked by its parts.
        let de = Locale(identifier: "de_DE")
        let two = StartHeadlineText.sentence(result, locale: de)
        #expect(two.hasPrefix("Zwei "))
        #expect(!two.contains("Sommer"))
        let one = StartHeadlineText.sentence(Self.headline([late], Self.at(11, minute: 54)), locale: de)
        #expect(one.hasPrefix("Sommer gegen Winterklamotten … "))
    }

    @Test("2b: a day-only date today speaks before the quiet rungs; a time of day still wins")
    @MainActor func dueTodayWithoutTime() async throws {
        let store = try TestStore()
        let one = Self.task("Arzttermin", due: Self.at(0), in: store)
        let yesterday = Self.done("Steuer", at: Self.at(18, day: -1), in: store)
        #expect(Self.headline([one, yesterday], Self.at(7)) == .dueToday(title: "Arzttermin", count: 1))

        let two = Self.task("Fußnagel", due: Self.at(0), in: store)
        #expect(Self.headline([one, two], Self.at(7)) == .dueToday(title: "Arzttermin", count: 2))

        let timed = Self.task("Anna abholen", due: Self.at(17), timed: true, in: store)
        #expect(Self.headline([one, timed], Self.at(7)) == .upcoming(title: "Anna abholen", at: Self.at(17), count: 1))
        #expect(Self.headline([one], Self.at(7, day: 1)) != .dueToday(title: "Arzttermin", count: 1))
    }

    // MARK: - 3

    @Test("3: one deadline from an earlier day is named, several are counted (#633)")
    @MainActor func needsNewDate() async throws {
        let store = try TestStore()
        let yesterday = Self.task("Mama zurückrufen", due: Self.at(0, day: -1), in: store)
        #expect(Self.headline([yesterday], Self.at(10)) == .needsNewDate(title: "Mama zurückrufen", count: 1))

        // A time from yesterday and a day-only date three days back: the oldest first.
        let timed = Self.task("Rechnung bezahlen", due: Self.at(15, day: -1), timed: true, in: store)
        let older = Self.task("Fahrrad flicken", due: Self.at(0, day: -3), in: store)
        #expect(Self.headline([yesterday, timed, older], Self.at(10)) == .needsNewDate(title: "Fahrrad flicken", count: 3))

        let de = Locale(identifier: "de_DE")
        #expect(StartHeadlineText.sentence(.needsNewDate(title: "Fahrrad flicken", count: 3), locale: de).hasPrefix("Drei "))
        #expect(StartHeadlineText.sentence(.needsNewDate(title: "Fahrrad flicken", count: 1), locale: de).hasPrefix("Fahrrad flicken "))
    }

    @Test("3 comes after today's rungs and before the quiet ones; calm never hides it (#633)")
    @MainActor func needsNewDateRank() async throws {
        let store = try TestStore()
        let leftover = Self.task("Mama zurückrufen", due: Self.at(0, day: -1), in: store)
        let today = Self.task("Arzttermin", due: Self.at(0), in: store)
        let ahead = Self.task("Anna abholen", due: Self.at(17), timed: true, in: store)
        #expect(Self.headline([leftover, today, ahead], Self.at(10)) == .upcoming(title: "Anna abholen", at: Self.at(17), count: 1))
        #expect(Self.headline([leftover, today], Self.at(10)) == .dueToday(title: "Arzttermin", count: 1))

        let old = (1...3).map { Self.task("Alt \($0)", capturedDaysAgo: 40, in: store) }
        let doneYesterday = Self.done("Steuer", at: Self.at(18, day: -1), in: store)
        #expect(Self.headline([leftover, doneYesterday] + old, Self.at(10)) == .needsNewDate(title: "Mama zurückrufen", count: 1))

        // A parked task needs no new date; then the ladder goes on to calm.
        leftover.status = .parked
        let open = Self.task("Steuer", in: store)
        #expect(Self.headline([leftover, open], Self.at(10)) == .calm)
    }

    // MARK: - 4 to 8

    @Test("Each quiet rung on its own: pile, old, yesterday")
    @MainActor func quietRungs() async throws {
        let store = try TestStore()
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
        let garden = TaskContext(name: "Garten")
        store.context.insert(garden)
        let old = (1...4).map { Self.task("Alt \($0)", capturedDaysAgo: 40, in: store) }
        old.forEach { $0.contexts = [garden] }

        let today = Self.headline(old, Self.at(10))
        let tomorrow = Self.headline(old, Self.at(10, day: 1))
        let kinds = [today, tomorrow].map { headline -> String in
            if case .pile = headline { return "pile" }
            if case .old = headline { return "old" }
            return "other"
        }
        #expect(Set(kinds) == ["pile", "old"])
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
