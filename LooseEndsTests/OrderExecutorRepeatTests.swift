import Foundation
import SwiftData
import XCTest
@testable import LooseEnds

/// A repetition and a link in Claude's orders (#938 Schnitt 1): `fields.repeat` becomes the task's `RepeatRule` with its
/// anchor and one user revision with the reason "Claude"; `fields.link` on a capture becomes `sourceURL`. Orders arrive
/// as JSON through the codec, so the tests speak only the contract's keys.
@MainActor final class OrderExecutorRepeatTests: XCTestCase {
    private typealias Suite = OrderExecutorTests

    /// Word for word in `docs/reference/claude-abschrift-vertrag.md` (`jsonc` block).
    static let orderRepeatFixture = """
    {
      "fields": {
        "dueDate": "2026-03-14T06:30:00Z",
        "dueHasTime": true,
        "link": "https://www.example.org/praxis/termine",
        "repeat": {
          "basis": "fromDueDate",
          "frequency": "weekly",
          "interval": 26
        },
        "title": "Zahnarzt Kontrolle"
      },
      "id": "0B7D5E3C-0000-4000-8000-000000000022",
      "kind": "capture",
      "text": "Alle 26 Wochen Zahnarzt Kontrolle",
      "version": 1
    }
    """

    // MARK: Helpers

    private var calendar: Calendar { Suite.calendar }

    /// An order as it arrives: JSON through the codec.
    private func order(_ json: [String: Any]) throws -> Order {
        var json = json
        json["version"] = json["version"] ?? 1
        json["id"] = json["id"] ?? UUID().uuidString
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        return try TranscriptCodec.decode(Order.self, from: data)
    }

    private func capture(_ text: String, _ fields: [String: Any]) throws -> Order {
        try order(["kind": "capture", "text": text, "fields": fields])
    }

    /// An update with the transcript's view of the task as it stands.
    private func update(_ task: TaskItem, _ fields: [String: Any], extra: [String: Any] = [:]) throws -> Order {
        var json: [String: Any] = ["kind": "update", "taskID": task.id.uuidString, "expectedStatus": task.status.rawValue,
                                   "expectedTitle": task.title as Any, "fields": fields]
        json["expectedDueDate"] = task.dueDate?.ISO8601Format()
        return try order(json.merging(extra) { $1 })
    }

    private func created(_ result: OrderResult, in store: TestStore) throws -> TaskItem {
        XCTAssertEqual(result.outcome, .done, "\(result)")
        return try XCTUnwrap(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == result.taskID })
    }

    private func revisions(_ field: RevisedField, of task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.fieldRaw == field.rawValue }
    }

    /// 2026-03-12 is a Thursday; `day(offset, hour:minute:)` in Berlin.
    private func day(_ offset: Int, hour: Int = 9, minute: Int = 0) -> Date {
        Suite.day(offset, hour: hour).addingTimeInterval(TimeInterval(minute * 60))
    }

    /// Everything a refusal must leave as it was: each task with rule, link and due date, revisions, completions.
    private struct Store: Equatable {
        let tasks: [String]
        let revisions: Int
        let completions: Int

        @MainActor init(_ store: TestStore) throws {
            tasks = try store.context.fetch(FetchDescriptor<TaskItem>()).map { task in
                let rule = FieldCodec.encode(.repeatRule, of: task) ?? "-"
                let due = task.dueDate?.ISO8601Format() ?? "-"
                return "\(task.id) \(task.status) \(due) \(task.dueHasTime) \(task.importanceRaw ?? "-") "
                    + "\(task.sourceURL?.absoluteString ?? "-") \(rule)"
            }.sorted()
            revisions = try store.context.fetchCount(FetchDescriptor<Revision>())
            completions = try store.context.fetchCount(FetchDescriptor<CompletionRecord>())
        }
    }

    // MARK: AC-1

    func testContractExampleRepeatAndLinkRoundTrips() throws {
        let decoded = try TranscriptCodec.decode(Order.self, from: Data(Self.orderRepeatFixture.utf8))
        let encoded = try TranscriptCodec.encode(decoded)
        XCTAssertTrue(try JSONEqual.same(encoded, Data(Self.orderRepeatFixture.utf8)),
                      "the order must keep repeat and link:\n\(String(decoding: encoded, as: UTF8.self))")
        let again = try TranscriptCodec.decode(Order.self, from: encoded)
        XCTAssertEqual(again, decoded, "decode, encode, decode gives the same order")
        XCTAssertEqual(decoded.kind, .capture)
        XCTAssertEqual(decoded.fields?.title, "Zahnarzt Kontrolle")
        XCTAssertTrue(try ContractDocument.text().contains(Self.orderRepeatFixture),
                      "the contract must quote the example word for word")
    }

    // MARK: AC-2

    func testCaptureWithRepeatCreatesRuleWithAnchorAndRevision() throws {
        let store = try TestStore()
        let due = day(2, hour: 7, minute: 30)
        let text = "Montags und mittwochs Blumen gießen"
        let fields: [String: Any] = [
            "dueDate": due.ISO8601Format(), "dueHasTime": true,
            "repeat": ["frequency": "weekly", "weekdays": [4, 2]],
        ]

        let task = try created(try Suite.run(try capture(text, fields), in: store), in: store)

        XCTAssertEqual(task.rawText, text, "the raw text stays the user's words (ADR-3)")
        let rule = try XCTUnwrap(task.repeatRule)
        XCTAssertEqual(rule.frequency, .weekly)
        XCTAssertEqual(rule.interval, 1, "standard interval")
        XCTAssertEqual(rule.weekdays, [2, 4], "sorted")
        XCTAssertEqual(rule.basis, .fromDueDate, "standard basis")
        XCTAssertEqual(rule.hour, 7)
        XCTAssertEqual(rule.minute, 30)
        XCTAssertEqual(rule.anchor, due)
        XCTAssertEqual(task.dueDate, due)
        let written = revisions(.repeatRule, of: task)
        XCTAssertEqual(written.count, 1)
        let revision = try XCTUnwrap(written.first)
        XCTAssertEqual(revision.author, .user)
        XCTAssertEqual(revision.reason, "Claude")
        XCTAssertTrue(RevisionService.isByClaude(revision))
        XCTAssertEqual(revision.newValue, FieldCodec.encode(rule))
        XCTAssertNotNil(RevisionService.lastClaudeChange(on: task))
    }

    // MARK: AC-3

    func testCaptureWithRepeatWithoutDueDateSetsFirstDueDate() throws {
        let store = try TestStore()
        let fields: [String: Any] = ["repeat": ["frequency": "weekly", "interval": 2, "basis": "fromCompletion"]]

        let task = try created(try Suite.run(try capture("Fenster putzen", fields), in: store), in: store)

        let rule = try XCTUnwrap(task.repeatRule)
        XCTAssertEqual(rule.interval, 2)
        XCTAssertEqual(rule.basis, .fromCompletion)
        XCTAssertNil(rule.hour)
        let first = RepeatRule(frequency: .weekly, interval: 2, basis: .fromCompletion)
            .firstDueDate(now: Suite.now, calendar: calendar)
        XCTAssertEqual(task.dueDate, first)
        XCTAssertEqual(rule.anchor, first)
        XCTAssertFalse(task.dueHasTime, "a rule without a time dates the day")
        XCTAssertEqual(revisions(.dueDate, of: task).count, 1)
        XCTAssertEqual(revisions(.repeatRule, of: task).count, 1)
        for revision in task.revisions ?? [] { XCTAssertTrue(RevisionService.isByClaude(revision), "\(revision.fieldRaw)") }
    }

    // MARK: AC-4

    func testRepeatTimeComesOnlyFromDueDateWithTime() throws {
        let store = try TestStore()
        let dayOnly: [String: Any] = [
            "dueDate": day(3).ISO8601Format(), "dueHasTime": false, "repeat": ["frequency": "daily"],
        ]
        let plain = try created(try Suite.run(try capture("Um 8 Uhr Vitamine nehmen", dayOnly), in: store), in: store)
        XCTAssertNotNil(plain.repeatRule)
        XCTAssertNil(plain.repeatRule?.hour, "no time from the raw text, only from the order's date")
        XCTAssertNil(plain.repeatRule?.minute)
        XCTAssertFalse(plain.dueHasTime)
        XCTAssertEqual(plain.repeatRule?.anchor, calendar.startOfDay(for: day(3)))

        let timed: [String: Any] = [
            "dueDate": day(3, hour: 20, minute: 15).ISO8601Format(), "dueHasTime": true, "repeat": ["frequency": "daily"],
        ]
        let evening = try created(try Suite.run(try capture("Vitamine nehmen", timed), in: store), in: store)
        XCTAssertEqual(evening.repeatRule?.hour, 20)
        XCTAssertEqual(evening.repeatRule?.minute, 15)
    }

    // MARK: AC-5

    func testUpdateReplacesRuleKeepsAnchorUnlessDueDateComes() throws {
        let store = try TestStore()
        let anchor = day(1, hour: 18)
        let task = try Suite.insert("Müll rausbringen", due: day(2, hour: 18), in: store)
        task.repeatRule = RepeatRule(frequency: .weekly, hour: 18, minute: 0, anchor: anchor)
        try store.context.save()

        let monthly = try Suite.run(try update(task, ["repeat": ["frequency": "monthly"]]), in: store)
        XCTAssertEqual(monthly.outcome, .done, "\(monthly)")
        XCTAssertEqual(task.repeatRule?.frequency, .monthly)
        XCTAssertEqual(task.repeatRule?.anchor, anchor, "the series keeps its day")
        XCTAssertEqual(task.repeatRule?.hour, 18, "the old time stays")
        XCTAssertEqual(task.repeatRule?.minute, 0)
        XCTAssertEqual(task.dueDate, day(2, hour: 18), "the due date stays")
        XCTAssertEqual(revisions(.repeatRule, of: task).count, 1)

        let moved = day(10, hour: 8, minute: 45)
        let yearly = try Suite.run(try update(task, [
            "repeat": ["frequency": "yearly"], "dueDate": moved.ISO8601Format(), "dueHasTime": true,
        ]), in: store)
        XCTAssertEqual(yearly.outcome, .done, "\(yearly)")
        XCTAssertEqual(task.repeatRule?.frequency, .yearly)
        XCTAssertEqual(task.repeatRule?.anchor, moved, "a date in the same order sets the anchor")
        XCTAssertEqual(task.repeatRule?.hour, 8)
        XCTAssertEqual(task.repeatRule?.minute, 45)
        XCTAssertEqual(task.dueDate, moved)
        XCTAssertEqual(revisions(.repeatRule, of: task).count, 2)
        XCTAssertEqual(revisions(.dueDate, of: task).count, 1)
    }

    func testUpdateAddsRuleToTaskWithDueDateAnchorsOnIt() throws {
        let store = try TestStore()
        let due = day(3, hour: 9)
        let task = try Suite.insert("Steuer vorbereiten", due: due, in: store)

        let result = try Suite.run(try update(task, ["repeat": ["frequency": "monthly", "interval": 3]]), in: store)

        XCTAssertEqual(result, OrderResult(orderID: result.orderID, outcome: .done, taskID: task.id))
        XCTAssertEqual(task.repeatRule?.frequency, .monthly)
        XCTAssertEqual(task.repeatRule?.interval, 3)
        XCTAssertEqual(task.repeatRule?.anchor, due)
        XCTAssertNil(task.repeatRule?.hour, "the time comes only from a date in the order")
        XCTAssertEqual(task.dueDate, due, "the due date stays")
        XCTAssertEqual(task.revisions?.count, 1, "exactly one revision")
        XCTAssertEqual(revisions(.repeatRule, of: task).count, 1)
    }

    // MARK: AC-6

    func testUpdateWithRepeatChecksOnlyStatus() throws {
        let store = try TestStore()
        let task = try Suite.insert("Rasen mähen", due: day(1), in: store)
        let rule: [String: Any] = ["frequency": "weekly"]
        // The transcript showed another title, other tags and another date: none of them is the expected state here.
        let old: [String: Any] = [
            "expectedTitle": "Rasen", "expectedContexts": ["Garten"], "expectedProject": "Haus",
            "expectedDueDate": day(5).ISO8601Format(),
        ]
        let done = try Suite.run(try update(task, ["repeat": rule], extra: old), in: store)
        XCTAssertEqual(done, OrderResult(orderID: done.orderID, outcome: .done, taskID: task.id))
        XCTAssertEqual(task.repeatRule?.frequency, .weekly)

        let before = try Store(store)
        for status in ["done", "removed"] {
            let result = try Suite.run(try update(task, ["repeat": ["frequency": "daily"]],
                                                  extra: ["expectedStatus": status]), in: store)
            XCTAssertEqual(result, OrderResult(orderID: result.orderID, outcome: .rejected, reason: .invalid, taskID: task.id),
                           status)
        }
        let parked = try Suite.run(try update(task, ["repeat": ["frequency": "daily"]],
                                              extra: ["expectedStatus": "parked"]), in: store)
        XCTAssertEqual(parked.reason, .stale, "the task is open, the transcript showed it parked")
        let missing = try Suite.run(try update(task, ["repeat": ["frequency": "daily"]],
                                               extra: ["taskID": UUID().uuidString]), in: store)
        XCTAssertEqual(missing, OrderResult(orderID: missing.orderID, outcome: .rejected, reason: .missing))
        XCTAssertEqual(try Store(store), before)
    }

    // MARK: AC-7

    func testSameRuleWritesNoRevision() throws {
        let store = try TestStore()
        let due = day(2, hour: 9)
        let task = try Suite.insert("Yoga", due: due, in: store)
        let rule = RepeatRule(frequency: .weekly, interval: 2, weekdays: [2, 4], anchor: due)
        task.repeatRule = rule
        try store.context.save()

        let changed = try Suite.run(try update(task, ["repeat": ["frequency": "weekly", "interval": 3, "weekdays": [2, 4]]]),
                                    in: store)
        XCTAssertEqual(changed.outcome, .done, "\(changed)")
        XCTAssertEqual(revisions(.repeatRule, of: task).count, 1, "another interval is a change")
        let standing = try XCTUnwrap(task.repeatRule)
        XCTAssertEqual(standing.interval, 3)
        XCTAssertEqual(standing.anchor, rule.anchor)

        let result = try Suite.run(try update(task, [
            "repeat": ["frequency": "weekly", "interval": 3, "weekdays": [4, 2, 4], "basis": "fromDueDate"],
            "importance": "high",
        ]), in: store)

        XCTAssertEqual(result.outcome, .done, "\(result)")
        XCTAssertEqual(task.importance, .high, "the order ran")
        XCTAssertEqual(task.repeatRule, standing, "the same rule, anchor included")
        XCTAssertEqual(revisions(.repeatRule, of: task).count, 1, "a rule that already stands writes no revision")
    }

    // MARK: AC-8

    func testMalformedRepeatAndLinkAreInvalidWithoutWriting() throws {
        let store = try TestStore()
        let task = try Suite.insert("Rasen mähen", due: day(1), in: store)
        let before = try Store(store)
        let bad: [(String, [String: Any])] = [
            ("unknown frequency", ["repeat": ["frequency": "hourly"]]),
            ("unknown basis", ["repeat": ["frequency": "daily", "basis": "fromStart"]]),
            ("interval 0", ["repeat": ["frequency": "daily", "interval": 0]]),
            ("interval 53", ["repeat": ["frequency": "weekly", "interval": 53]]),
            ("weekdays on daily", ["repeat": ["frequency": "daily", "weekdays": [2]]]),
            ("empty weekdays", ["repeat": ["frequency": "weekly", "weekdays": [Int]()]]),
            ("weekday 0", ["repeat": ["frequency": "weekly", "weekdays": [0, 2]]]),
            ("weekday 8", ["repeat": ["frequency": "weekly", "weekdays": [8]]]),
        ]
        for (name, fields) in bad {
            // With a valid field beside it: without the check the order would run and write the importance.
            let refused = try Suite.run(try update(task, fields.merging(["importance": "high"]) { $1 }), in: store)
            XCTAssertEqual(refused, OrderResult(orderID: refused.orderID, outcome: .rejected, reason: .invalid,
                                                taskID: task.id), "update: \(name)")
            let captured = try Suite.run(try capture("Rasen mähen", fields), in: store)
            XCTAssertEqual(captured, OrderResult(orderID: captured.orderID, outcome: .rejected, reason: .invalid),
                           "capture: \(name)")
        }
        let links = ["www.example.org/termine", "ftp://example.org/termine", "https://", "https:///termine", "mailto:a@b.de"]
        for link in links {
            let captured = try Suite.run(try capture("Termin buchen", ["link": link]), in: store)
            XCTAssertEqual(captured, OrderResult(orderID: captured.orderID, outcome: .rejected, reason: .invalid),
                           "capture link \(link)")
        }
        let linkOnUpdate = try Suite.run(try update(task, ["link": "https://example.org", "importance": "high"]), in: store)
        XCTAssertEqual(linkOnUpdate, OrderResult(orderID: linkOnUpdate.orderID, outcome: .rejected, reason: .invalid,
                                                 taskID: task.id), "link on update")
        XCTAssertEqual(try Store(store), before, "nothing written, no task created")
    }

    // MARK: AC-9

    func testCaptureLinkSetsSourceURLWithoutRevision() throws {
        let store = try TestStore()
        let text = "Termin beim Zahnarzt buchen"
        let link = "https://www.example.org/praxis/termine"

        let task = try created(try Suite.run(try capture(text, ["link": link, "title": "Zahnarzt buchen"]), in: store),
                               in: store)

        XCTAssertEqual(task.sourceURL, URL(string: link))
        XCTAssertEqual(task.rawText, text, "the link stays out of the raw text (ADR-3)")
        XCTAssertEqual(task.revisions?.count, 1, "only the title's revision, none for the link")
        XCTAssertEqual(revisions(.title, of: task).count, 1)

        let alone = try created(try Suite.run(try capture("Rechnung prüfen", ["link": "http://example.org/r/1"]), in: store),
                                in: store)
        XCTAssertEqual(alone.sourceURL, URL(string: "http://example.org/r/1"), "a link alone is a valid fields")
        XCTAssertTrue((alone.revisions ?? []).isEmpty)
    }

    // MARK: AC-10

    func testFamilyRhythmsCaptureAsWeeklyInterval() throws {
        let store = try TestStore()
        let cases: [(String, Date, Bool, [String: Any], RepeatRule.Frequency, Int, Int?)] = [
            ("Zahnarzt Kontrolle", day(5, hour: 18), true, ["frequency": "weekly", "interval": 26], .weekly, 26, 18),
            ("Heizung warten lassen", day(9, hour: 10), true, ["frequency": "weekly", "interval": 52], .weekly, 52, 10),
            ("Abends Tabletten nehmen", day(0, hour: 20), true, ["frequency": "daily"], .daily, 1, 20),
            ("Geburtstag Oma", day(30), false, ["frequency": "yearly"], .yearly, 1, nil),
        ]
        for (text, due, hasTime, rule, frequency, interval, hour) in cases {
            let fields: [String: Any] = ["dueDate": due.ISO8601Format(), "dueHasTime": hasTime, "repeat": rule]
            let task = try created(try Suite.run(try capture(text, fields), in: store), in: store)
            let made = try XCTUnwrap(task.repeatRule, text)
            XCTAssertEqual(made.frequency, frequency, text)
            XCTAssertEqual(made.interval, interval, text)
            XCTAssertNil(made.weekdays, text)
            XCTAssertEqual(made.hour, hour, text)
            XCTAssertEqual(made.anchor, hasTime ? due : calendar.startOfDay(for: due), text)
        }
    }

    func testCompletingRollsForwardFromAnchor() throws {
        let store = try TestStore()
        let due = day(0, hour: 9)
        let fields: [String: Any] = [
            "dueDate": due.ISO8601Format(), "dueHasTime": true, "repeat": ["frequency": "weekly", "interval": 26],
        ]
        let task = try created(try Suite.run(try capture("Zahnarzt Kontrolle", fields), in: store), in: store)

        TaskActions.complete(task, now: Suite.now, calendar: calendar)

        XCTAssertNotEqual(task.status, .done, "a repeating task does not end")
        XCTAssertEqual(task.completions?.count, 1)
        XCTAssertEqual(task.dueDate, day(26 * 7, hour: 9), "26 weeks on, same time")
        XCTAssertEqual(task.repeatRule?.anchor, task.dueDate, "the anchor follows")
    }

    // MARK: AC-11

    func testOrdersWithoutRepeatOrLinkBehaveAsBefore() throws {
        let store = try TestStore()
        let plain = try created(try Suite.run(try capture("Brief schreiben", ["title": "Brief"]), in: store), in: store)
        XCTAssertNil(plain.repeatRule)
        XCTAssertNil(plain.sourceURL)

        let rule = RepeatRule(frequency: .weekly, anchor: day(1))
        let source = URL(string: "https://www.example.org/quelle")
        let task = try Suite.insert("Blumen gießen", due: day(1), in: store)
        task.repeatRule = rule
        task.sourceURL = source
        try store.context.save()

        XCTAssertEqual(try Suite.run(try update(task, ["importance": "high"]), in: store).outcome, .done)
        let setDue = Order(id: UUID(), kind: .setDue, taskID: task.id, date: day(2), hasTime: true, expectedDueDate: day(1))
        XCTAssertEqual(try Suite.run(setDue, in: store).outcome, .done)
        XCTAssertEqual(task.repeatRule, rule, "update and setDue leave the rule")
        XCTAssertEqual(task.sourceURL, source, "and the link")
        XCTAssertTrue(revisions(.repeatRule, of: task).isEmpty)
    }
}
