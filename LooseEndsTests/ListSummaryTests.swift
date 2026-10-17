import Foundation
import Testing
@testable import LooseEnds

/// Its bundle has no `de` translations, so `String(localized:bundle:)` falls back to the English key.
private final class ListSummaryBundleMarker {}

/// The subtitle of a wide list (#477 Schnitt 1): "2 open · 20 min" — counted and added up, no model.
@Suite("List summary") struct ListSummaryTests {
    static let english = Bundle(for: ListSummaryBundleMarker.self)

    static func german() throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: "de", ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    /// Open tasks with the given durations (nil = no duration set).
    @MainActor static func tasks(_ durations: [DurationBucket?], in store: TestStore) -> [TaskItem] {
        durations.enumerated().map { index, duration in
            let task = TaskItem(rawText: "Aufgabe \(index)")
            task.duration = duration
            store.context.insert(task)
            return task
        }
    }

    @MainActor static func done(_ duration: DurationBucket?, in store: TestStore) -> TaskItem {
        let task = TaskItem(rawText: "Erledigt")
        task.duration = duration
        task.status = .done
        store.context.insert(task)
        return task
    }

    // MARK: - Rule

    @Test("Only open tasks count")
    @MainActor func countsOpenTasksOnly() throws {
        let store = try TestStore()
        let all = Self.tasks([nil, nil], in: store) + [Self.done(nil, in: store)]
        #expect(ListSummary.of(all).openCount == 2)
    }

    @Test("Durations add up by their bucket")
    @MainActor func sumsDurationBuckets() throws {
        let store = try TestStore()
        let summary = ListSummary.of(Self.tasks([.minutes5, .minutes15], in: store))
        #expect(summary.minutes == 20)
        #expect(summary.isAtLeast == false)
    }

    @Test("A task without a duration adds nothing but still counts as open")
    @MainActor func taskWithoutDurationAddsNothing() throws {
        let store = try TestStore()
        let summary = ListSummary.of(Self.tasks([nil, .minutes30], in: store))
        #expect(summary.minutes == 30)
        #expect(summary.openCount == 2)
    }

    @Test("Two hours and more counts as 120 and makes the sum a lower bound")
    @MainActor func twoHoursPlusIsALowerBound() throws {
        let store = try TestStore()
        let summary = ListSummary.of(Self.tasks([.hours2plus, .minutes30], in: store))
        #expect(summary.minutes == 150)
        #expect(summary.isAtLeast == true)
    }

    @Test("A done task's duration does not count")
    @MainActor func doneTaskDurationDoesNotCount() throws {
        let store = try TestStore()
        let summary = ListSummary.of([Self.done(.hour1, in: store)])
        #expect(summary.minutes == 0)
        #expect(summary.openCount == 0)
    }

    // MARK: - Text

    @Test("No open task, no subtitle")
    @MainActor func emptyListHasNoText() throws {
        let store = try TestStore()
        #expect(ListSummary.of([]).text(bundle: Self.english) == nil)
        #expect(ListSummary.of([Self.done(.minutes5, in: store)]).text(bundle: Self.english) == nil)
    }

    @Test("Without any duration only the count")
    @MainActor func textWithoutDurationIsOnlyTheCount() throws {
        let store = try TestStore()
        #expect(ListSummary.of(Self.tasks([nil, nil], in: store)).text(bundle: Self.english) == "2 open")
    }

    @Test("Under an hour in minutes")
    @MainActor func textUnderAnHourInMinutes() throws {
        let store = try TestStore()
        let text = ListSummary.of(Self.tasks([.minutes5, .minutes15], in: store)).text(bundle: Self.english)
        #expect(text == "2 open · 20 min")
    }

    @Test("From an hour in hours and minutes, a whole hour without minutes")
    @MainActor func textFromAnHourInHoursAndMinutes() throws {
        let store = try TestStore()
        let mixed = ListSummary.of(Self.tasks([.hour1, .minutes15, .minutes15], in: store)).text(bundle: Self.english)
        #expect(mixed == "3 open · 1 h 30 min")
        let whole = ListSummary.of(Self.tasks([.hour1], in: store)).text(bundle: Self.english)
        #expect(whole == "1 open · 1 h")
    }

    @Test("A lower bound says at least")
    @MainActor func textWithLowerBoundSaysAtLeast() throws {
        let store = try TestStore()
        let text = ListSummary.of(Self.tasks([.hours2plus, .minutes30], in: store)).text(bundle: Self.english)
        #expect(text == "2 open · at least 2 h 30 min")
    }

    @Test("German uses offen, Std. and Min.")
    @MainActor func germanTextUsesStdAndMin() throws {
        let store = try TestStore()
        let german = try Self.german()
        let short = ListSummary.of(Self.tasks([.minutes5, .minutes15], in: store)).text(bundle: german)
        #expect(short == "2 offen · 20 Min.")
        let long = ListSummary.of(Self.tasks([.hour1, .minutes30], in: store)).text(bundle: german)
        #expect(long == "2 offen · 1 Std. 30 Min.")
        let bound = ListSummary.of(Self.tasks([.hours2plus], in: store)).text(bundle: german)
        #expect(bound == "1 offen · mind. 2 Std.")
    }
}
