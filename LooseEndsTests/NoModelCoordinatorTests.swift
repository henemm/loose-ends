import Foundation
import SwiftData
import XCTest
@testable import LooseEnds

/// #982 Schnitt 1 (ADR-22): the on-device model is out of the product path. The pipeline is the one
/// the app runs: `CaptureService.save` sets the title by `TitleRule`, `EnrichmentCoordinator` runs the
/// rules and nothing else. RED before the change: `EnrichmentCoordinator(container:)` does not exist.
@MainActor
final class NoModelCoordinatorTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    override func tearDown() async throws {
        store = nil
    }

    private var context: ModelContext { store.context }

    /// AC-7: the only way to build the coordinator takes no model.
    private func coordinator() -> EnrichmentCoordinator {
        EnrichmentCoordinator(container: store.container)
    }

    private func revisions(_ task: TaskItem, _ field: RevisedField? = nil) -> [Revision] {
        (task.revisions ?? []).filter { field == nil || $0.field == field }
    }

    // MARK: - Test 1 (AC-1)

    func testCaptureKeepsTheSpokenTitleAndNoDuration() async throws {
        let task = try CaptureService.save("Vor Konzert", via: .app, in: context)

        await coordinator().processPending()

        XCTAssertEqual(task.title, "Vor Konzert", "der Titel kommt aus TitleRule, nichts dazuerfunden")
        XCTAssertNil(task.duration, "ohne genannte Dauer bleibt sie leer")
        XCTAssertTrue(revisions(task).allSatisfy { $0.author != .ai }, "keine KI-Revision")
        XCTAssertNil(task.processedAt, "das Modell lief nicht")
        XCTAssertNotNil(task.rulesAppliedAt, "der Regelschritt lief")
    }

    // MARK: - Test 2 (AC-2)

    func testNamedDurationAndRecognitionStillWork() async throws {
        let named = try CaptureService.save("Vor Konzert 20 Minuten", via: .app, in: context)
        await coordinator().processPending()

        XCTAssertEqual(named.duration, .minutes30, "20 Minuten → Eimer 30 min")
        XCTAssertEqual(revisions(named, .duration).map(\.author), [.rule])
        XCTAssertTrue(revisions(named).allSatisfy { $0.author != .ai })

        let earlier = TaskItem(rawText: "Steuer machen")
        earlier.duration = .hour1
        earlier.durationSourceRaw = FieldSource.user.rawValue
        earlier.revisions = [Revision(task: earlier, field: .duration, oldValue: nil,
                                      newValue: DurationBucket.hour1.rawValue, author: .user, reason: "Nutzer")]
        earlier.rulesAppliedAt = Date()
        context.insert(earlier)
        try context.save()

        let again = try CaptureService.save("Steuer machen", via: .app, in: context)
        await coordinator().processPending()

        XCTAssertEqual(again.duration, .hour1, "die Wiedererkennung übernimmt die Dauer der früheren Aufgabe")
        XCTAssertEqual(revisions(again, .duration).last?.author, .rule)
    }

    // MARK: - Test 3 (AC-3)

    func testATaskWhoseRulesRanIsNotTouchedAgain() async throws {
        let task = try CaptureService.save("Vor Konzert 20 Minuten", via: .app, in: context)
        await coordinator().processPending()
        let marker = try XCTUnwrap(task.rulesAppliedAt)
        let count = revisions(task).count

        // The user clears the duration without a revision path the rule would respect: the pass must
        // not come back to this task at all, so nothing is written again.
        task.duration = nil
        task.durationSourceRaw = nil
        try context.save()
        await coordinator().processPending()

        XCTAssertEqual(task.rulesAppliedAt, marker, "der Vermerk bleibt, die Aufgabe wird nicht erneut genommen")
        XCTAssertEqual(revisions(task).count, count, "keine neue Revision")
        XCTAssertNil(task.duration)
    }

    // MARK: - Test 4 (AC-4)

    func testATaskTheModelSawBefore144GetsNoLateRuleDuration() async throws {
        let task = TaskItem(rawText: "Bericht lesen 20 Minuten")
        task.title = "Bericht lesen"
        task.status = .active
        task.processedAt = Date(timeIntervalSinceNow: -86_400)
        context.insert(task)
        try context.save()

        await coordinator().processPending()

        XCTAssertTrue(revisions(task, .duration).isEmpty, "kein nachträglicher Regelwert")
        XCTAssertNil(task.rulesAppliedAt, "die Aufgabe wird vom Nachzügler nicht genommen")
    }

    // MARK: - Test 5 (AC-5)

    func testReanalysisKeepsOldAIValuesAndRespectsTheUser() async throws {
        let plain = aiDurationTask(rawText: "Garage aufräumen")
        let named = aiDurationTask(rawText: "Garage aufräumen 20 Minuten")
        let touched = aiDurationTask(rawText: "Keller aufräumen 20 Minuten")
        touched.revisions = (touched.revisions ?? []) + [Revision(task: touched, field: .duration,
            oldValue: DurationBucket.minutes15.rawValue, newValue: DurationBucket.hours2plus.rawValue,
            author: .user, reason: "Nutzer")]
        touched.duration = .hours2plus
        touched.durationSourceRaw = FieldSource.user.rawValue
        try context.save()
        let coordinator = coordinator()

        guard case .finished = await coordinator.reanalyze(plain) else { return XCTFail("kein Ergebnis") }
        XCTAssertEqual(plain.duration, .minutes15, "der alte KI-Wert bleibt")
        XCTAssertEqual(revisions(plain, .duration).map(\.author), [.ai])

        _ = await coordinator.reanalyze(named)
        XCTAssertEqual(named.duration, .minutes30, "die Regel findet die genannte Dauer")
        XCTAssertEqual(revisions(named, .duration).map(\.author), [.ai, .rule], "die KI-Revision bleibt erhalten")

        _ = await coordinator.reanalyze(touched)
        XCTAssertEqual(touched.duration, .hours2plus, "der Nutzerwert bleibt")
        XCTAssertEqual(revisions(touched, .duration).last?.author, .user)
    }

    private func aiDurationTask(rawText: String) -> TaskItem {
        let task = TaskItem(rawText: rawText)
        task.title = rawText
        task.status = .active
        task.processedAt = Date(timeIntervalSinceNow: -86_400)
        task.rulesAppliedAt = Date(timeIntervalSinceNow: -86_400)
        task.duration = .minutes15
        task.durationSourceRaw = FieldSource.ai.rawValue
        task.revisions = [Revision(task: task, field: .duration, oldValue: nil,
                                   newValue: DurationBucket.minutes15.rawValue, author: .ai, reason: nil)]
        context.insert(task)
        return task
    }

    // MARK: - Test 6 (AC-6)

    func testReanalysisCountsTheChangedFieldsOnly() async throws {
        let task = try CaptureService.save("Vor Konzert 20 Minuten", via: .app, in: context)
        let coordinator = coordinator()
        await coordinator.processPending()
        task.duration = nil
        task.durationSourceRaw = nil
        task.revisions = (task.revisions ?? []).filter { $0.field != .duration }
        try context.save()

        let first = await coordinator.reanalyze(task)
        let second = await coordinator.reanalyze(task)

        XCTAssertEqual(first, .finished(changed: 1))
        XCTAssertEqual(second, .finished(changed: 0), "derselbe Befund schreibt nichts noch einmal")
    }

    // MARK: - Test 7 (AC-7) is `coordinator()` above: it compiles only without an enricher.

    func testTheCoordinatorIsBuiltWithoutAModel() {
        let built: EnrichmentCoordinator = EnrichmentCoordinator(container: store.container, savedPlaces: { .empty })
        XCTAssertNotNil(built)
    }

    // MARK: - Test 8 (AC-8)

    func testTheRealAppPassesNoModelReasonToTheOnboarding() {
        XCTAssertNil(ContentView.onboardingModelReason(arguments: [], isUITesting: false))
        XCTAssertNil(ContentView.onboardingModelReason(
            arguments: ["--ui-testing-model-reason=deviceNotEligible"], isUITesting: false),
            "ohne Testmodus zählt das Argument nicht")
        XCTAssertNil(ContentView.onboardingModelReason(arguments: ["--ui-testing"], isUITesting: true))
        XCTAssertEqual(ContentView.onboardingModelReason(
            arguments: ["--ui-testing", "--ui-testing-model-reason=modelNotReady"], isUITesting: true), "modelNotReady")
    }

    // MARK: - Test 9 (AC-10)

    func testSubtasksStillGetTheirTwoRules() async throws {
        let parent = try CaptureService.save("Umzug planen", via: .app, in: context)
        await coordinator().processPending()
        let line = try Subtasks.add("Kartons kaufen morgen", to: parent, in: context)
        try context.save()

        await coordinator().processPending()
        XCTAssertNotNil(line.rulesAppliedAt, "der Regelschritt der Teilaufgabe lief")
        XCTAssertNotNil(line.dueDate, "„morgen“ setzt die Fälligkeit")
        XCTAssertNil(line.processedAt)

        let result = await coordinator().reanalyze(line)
        XCTAssertEqual(result, .finished(changed: 0))
    }

    // MARK: - Test 10 (AC-10)

    func testTheMenuBarCapturePathRunsTheRuleStep() async throws {
        // The panel saves through `CaptureService` and then calls `processPending` (MenuBarCapture).
        let task = try CaptureService.save("Steuer heute erledigen", via: .keyboard, in: context)
        await coordinator().processPending()

        XCTAssertNotNil(task.rulesAppliedAt)
        XCTAssertNotNil(task.dueDate, "„heute“ setzt die Fälligkeit")
        XCTAssertNil(task.processedAt)
    }
}
