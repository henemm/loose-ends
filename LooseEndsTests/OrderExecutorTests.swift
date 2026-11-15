import Foundation
import SwiftData
import Testing
import XCTest
@testable import LooseEnds

/// Orders from Claude (#613 Schnitt 1, Weg B): capture, complete, set the due date. Each is a user change with
/// the reason "Claude"; an order whose expected state no longer holds is refused and leaves the store as it was.
@Suite("Orders from Claude") struct OrderExecutorTests {
    static let calendar = TranscriptCodecTests.calendar
    static let now = TranscriptCodecTests.now

    static func day(_ offset: Int, hour: Int = 9) -> Date { TranscriptCodecTests.day(offset, hour: hour) }

    @MainActor static func run(_ order: Order, in store: TestStore) throws -> OrderResult {
        try OrderExecutor.execute(order, in: store.context, now: now, calendar: calendar)
    }

    @MainActor static func insert(_ text: String, due: Date? = nil, in store: TestStore) throws -> TaskItem {
        let task = TranscriptCodecTests.task(text, due: due)
        store.context.insert(task)
        try store.context.save()
        return task
    }

    /// What a refusal must leave untouched (AC-7).
    struct Snapshot: Equatable {
        let tasks: Int
        let revisions: Int
        let completions: Int
        let fields: [String]

        @MainActor init(_ store: TestStore) throws {
            let tasks = try store.context.fetch(FetchDescriptor<TaskItem>())
            self.tasks = tasks.count
            revisions = try store.context.fetchCount(FetchDescriptor<Revision>())
            completions = try store.context.fetchCount(FetchDescriptor<CompletionRecord>())
            fields = tasks.map { "\($0.id) \($0.status) \($0.dueDate?.ISO8601Format() ?? "-") \($0.dueHasTime)" }.sorted()
        }
    }

    // MARK: AC-4

    @Test("Capture saves a task through the channel Claude and names it (AC-4)")
    @MainActor func captureSaves() throws {
        let store = try TestStore()
        let order = Order(id: UUID(), kind: .capture, text: "  Zahnarzt anrufen  ")

        let result = try Self.run(order, in: store)

        let tasks = try store.context.fetch(FetchDescriptor<TaskItem>())
        #expect(tasks.count == 1)
        let task = try #require(tasks.first)
        #expect(result == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))
        #expect(task.capturedVia == .claude)
        #expect(task.rawText == "Zahnarzt anrufen")
    }

    @Test("Empty or blank text is refused as invalid, nothing is saved (AC-4, AC-7)",
          arguments: ["", "   \n\t "])
    @MainActor func captureBlankIsInvalid(text: String) throws {
        let store = try TestStore()
        _ = try Self.insert("Schon da", in: store)
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: .capture, text: text)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .rejected, reason: .invalid))
        #expect(try Snapshot(store) == before)
    }

    // MARK: AC-5

    @Test("Complete with the expected status marks a one-off task done (AC-5)")
    @MainActor func completeOneOff() throws {
        let store = try TestStore()
        let task = try Self.insert("Rechnung bezahlen", in: store)
        let order = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .active)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))
        #expect(task.status == .done)
        #expect(task.completedAt == Self.now)
    }

    @Test("Complete rolls a repeating task forward with a completion record, as in the app (AC-5)")
    @MainActor func completeRepeating() throws {
        let store = try TestStore()
        let task = try Self.insert("Blumen gießen", due: Self.day(0), in: store)
        task.repeatRule = RepeatRule(frequency: .daily)
        try store.context.save()
        let order = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .active,
                          expectedDueDate: Self.day(0))

        let result = try Self.run(order, in: store)

        #expect(result.outcome == .done)
        #expect(task.status == .active)
        #expect(task.completions?.count == 1)
        #expect((task.dueDate ?? .distantPast) > Self.now)
    }

    // MARK: AC-6

    @Test("Set due writes a user revision with the reason Claude; a day-only date starts the day (AC-6)")
    @MainActor func setDueDayOnly() throws {
        let store = try TestStore()
        let task = try Self.insert("Angebot schreiben", in: store)
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: Self.day(2, hour: 15), hasTime: false)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))
        #expect(task.dueDate == Self.calendar.startOfDay(for: Self.day(2)))
        #expect(task.dueHasTime == false)
        let revisions = (task.revisions ?? []).filter { $0.field == .dueDate }
        #expect(revisions.count == 1)
        #expect(revisions.first?.author == .user)
        #expect(revisions.first?.reason == "Claude")
    }

    @Test("Set due with a time keeps the time (AC-6)")
    @MainActor func setDueWithTime() throws {
        let store = try TestStore()
        let task = try Self.insert("Steuer abgeben", in: store)
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: Self.day(1, hour: 14), hasTime: true)

        let result = try Self.run(order, in: store)

        #expect(result.outcome == .done)
        #expect(task.dueDate == Self.day(1, hour: 14))
        #expect(task.dueHasTime == true)
        #expect((task.revisions ?? []).filter { $0.field == .dueDate }.first?.reason == "Claude")
    }

    @Test("Set due without a date removes it, again as a revision (AC-6)")
    @MainActor func setDueRemoves() throws {
        let store = try TestStore()
        let task = try Self.insert("Paket abholen", due: Self.day(1, hour: 11), in: store)
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: nil, hasTime: false,
                          expectedDueDate: Self.day(1, hour: 11))

        let result = try Self.run(order, in: store)

        #expect(result.outcome == .done)
        #expect(task.dueDate == nil)
        #expect(task.dueHasTime == false)
        let revision = try #require((task.revisions ?? []).first { $0.field == .dueDate })
        #expect(revision.newValue == nil)
        #expect(revision.author == .user)
        #expect(revision.reason == "Claude")
    }

    @Test("An expected due date read from the transcript matches a stored date with fractions of a second (AC-6, AC-8)")
    @MainActor func expectedDueFromTranscriptMatches() throws {
        let store = try TestStore()
        let task = try Self.insert("Bericht schicken", due: Self.day(1, hour: 11).addingTimeInterval(0.375), in: store)
        let transcript = TranscriptCodec.transcript(of: [task], now: Self.now, calendar: Self.calendar)
        let read = try TranscriptCodec.decode(Transcript.self, from: try TranscriptCodec.encode(transcript))
        let entry = try #require(read.tasks.first)
        let order = Order(id: UUID(), kind: .setDue, taskID: entry.id, date: Self.day(3), hasTime: false,
                          expectedDueDate: entry.dueDate)

        let result = try Self.run(order, in: store)

        #expect(result.outcome == .done)
    }

    // MARK: AC-7

    @Test("A status that changed meanwhile makes the order stale, nothing changes (AC-7)")
    @MainActor func completeStale() throws {
        let store = try TestStore()
        let task = try Self.insert("Keller räumen", in: store)
        task.status = .parked
        try store.context.save()
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .active)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .rejected, reason: .stale, taskID: task.id))
        #expect(try Snapshot(store) == before)
    }

    @Test("A due date that changed meanwhile makes the order stale, nothing changes (AC-7)")
    @MainActor func setDueStale() throws {
        let store = try TestStore()
        let task = try Self.insert("Zahnarzt anrufen", due: Self.day(1, hour: 9), in: store)
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: Self.day(4), hasTime: false,
                          expectedDueDate: Self.day(2, hour: 9))

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .rejected, reason: .stale, taskID: task.id))
        #expect(try Snapshot(store) == before)
    }

    @Test("Set due on a done or removed task is stale, nothing changes (#613 C3a, AC-19, AC-20)",
          arguments: [TaskStatus.done, .removed])
    @MainActor func setDueOnClosedTaskIsStale(status: TaskStatus) throws {
        let store = try TestStore()
        let task = try Self.insert("Schon erledigt", due: Self.day(1, hour: 9), in: store)
        task.status = status
        try store.context.save()
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: Self.day(4), hasTime: false,
                          expectedDueDate: Self.day(1, hour: 9))

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .rejected, reason: .stale, taskID: task.id))
        #expect(try Snapshot(store) == before)
    }

    @Test("Set due on a parked task still sets it (#613 C3a, AC-21)")
    @MainActor func setDueOnParkedTask() throws {
        let store = try TestStore()
        let task = try Self.insert("Später", in: store)
        task.status = .parked
        try store.context.save()
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: Self.day(2), hasTime: false)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))
        #expect((task.revisions ?? []).first { $0.field == .dueDate }?.reason == "Claude")
    }

    @Test("Set due on the same instant with another hasTime is invalid, nothing changes (#777, AC-1, AC-2)",
          arguments: [(true, false), (false, true)])
    @MainActor func setDueSameInstantOtherHasTimeIsInvalid(has: Bool, order wants: Bool) throws {
        let store = try TestStore()
        let midnight = Self.calendar.startOfDay(for: Self.day(2))
        let task = try Self.insert("Mitternacht", due: midnight, in: store)
        task.dueHasTime = has
        try store.context.save()
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: midnight, hasTime: wants,
                          expectedDueDate: midnight)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .rejected, reason: .invalid, taskID: task.id))
        #expect(try Snapshot(store) == before)
        #expect(task.dueHasTime == has)
    }

    @Test("Set due on the same instant with the same hasTime changes nothing (#777, AC-3)", arguments: [true, false])
    @MainActor func setDueSameInstantSameHasTimeChangesNothing(hasTime: Bool) throws {
        let store = try TestStore()
        let midnight = Self.calendar.startOfDay(for: Self.day(2))
        let task = try Self.insert("Mitternacht", due: midnight, in: store)
        task.dueHasTime = hasTime
        try store.context.save()
        let revisions = try store.context.fetchCount(FetchDescriptor<Revision>())
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: midnight, hasTime: hasTime,
                          expectedDueDate: midnight)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))
        #expect(try store.context.fetchCount(FetchDescriptor<Revision>()) == revisions)
        #expect(task.dueDate == midnight)
        #expect(task.dueHasTime == hasTime)
    }

    @Test("Set due on another instant may change hasTime, with one revision (#777, AC-4)")
    @MainActor func setDueOtherInstantMayChangeHasTime() throws {
        let store = try TestStore()
        let midnight = Self.calendar.startOfDay(for: Self.day(2))
        let task = try Self.insert("Mitternacht", due: midnight, in: store)
        task.dueHasTime = true
        try store.context.save()
        let order = Order(id: UUID(), kind: .setDue, taskID: task.id, date: Self.day(3, hour: 15), hasTime: false,
                          expectedDueDate: midnight)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))
        #expect(task.dueHasTime == false)
        let revisions = (task.revisions ?? []).filter { $0.field == .dueDate }
        #expect(revisions.count == 1)
        #expect(revisions.first?.reason == "Claude")
    }

    @Test("An unknown task is missing, nothing changes (AC-7)", arguments: [Order.Kind.complete, .setDue])
    @MainActor func unknownTaskIsMissing(kind: Order.Kind) throws {
        let store = try TestStore()
        _ = try Self.insert("Schon da", in: store)
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: kind, taskID: UUID(), expectedStatus: .active, date: Self.day(1), hasTime: false)

        let result = try Self.run(order, in: store)

        #expect(result.outcome == .rejected)
        #expect(result.reason == .missing)
        #expect(try Snapshot(store) == before)
    }

    @Test("An order without its fields or of another version is invalid, nothing changes (AC-7)")
    @MainActor func incompleteOrderIsInvalid() throws {
        let store = try TestStore()
        let task = try Self.insert("Schon da", in: store)
        let before = try Snapshot(store)
        let orders = [
            Order(id: UUID(), kind: .complete, expectedStatus: .active),
            Order(id: UUID(), kind: .complete, taskID: task.id),
            Order(id: UUID(), kind: .setDue, date: Self.day(1), hasTime: false),
            Order(id: UUID(), kind: .capture),
            Order(version: 2, id: UUID(), kind: .capture, text: "Neue Version"),
        ]

        for order in orders {
            let result = try Self.run(order, in: store)
            #expect(result.outcome == .rejected, "\(order)")
            #expect(result.reason == .invalid, "\(order)")
        }
        #expect(try Snapshot(store) == before)
    }

    @Test("Complete without the due date the task has is stale; a repeating task does not roll (AC-7, AC-8)")
    @MainActor func completeWithoutExpectedDueIsStale() throws {
        let store = try TestStore()
        let task = try Self.insert("Blumen gießen", due: Self.day(0), in: store)
        task.repeatRule = RepeatRule(frequency: .daily)
        try store.context.save()
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .active)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .rejected, reason: .stale, taskID: task.id))
        #expect(try Snapshot(store) == before)

        let fitting = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .active,
                            expectedDueDate: Self.day(0))
        #expect(try Self.run(fitting, in: store).outcome == .done)
        #expect(try Self.run(fitting, in: store).reason == .stale)
        #expect(try store.context.fetchCount(FetchDescriptor<CompletionRecord>()) == 1)
    }

    @Test("Complete expecting a done or removed task is invalid, nothing changes (AC-7)",
          arguments: [TaskStatus.done, .removed])
    @MainActor func completeExpectingClosedIsInvalid(status: TaskStatus) throws {
        let store = try TestStore()
        let task = try Self.insert("Schon erledigt", in: store)
        task.status = status
        try store.context.save()
        let before = try Snapshot(store)
        let order = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: status)

        let result = try Self.run(order, in: store)

        #expect(result == OrderResult(orderID: order.id, outcome: .rejected, reason: .invalid))
        #expect(try Snapshot(store) == before)
    }

    // MARK: AC-8

    @Test("An order built from store A's transcript alone runs on store B; a second run is stale (AC-8)",
          arguments: [false, true])
    @MainActor func twoStoresThroughTheTranscript(repeating: Bool) throws {
        let storeA = try TestStore()
        let storeB = try TestStore()
        let id = UUID()
        let rankID = UUID()
        for store in [storeA, storeB] {
            let task = TranscriptCodecTests.task("Müll rausbringen", due: Self.day(0, hour: 18))
            task.id = id
            if repeating { task.repeatRule = RepeatRule(frequency: .daily) }
            let other = TranscriptCodecTests.task("Angebot schreiben", rank: 0)
            other.id = rankID
            store.context.insert(task)
            store.context.insert(other)
            try store.context.save()
        }

        let all = { (store: TestStore) in try store.context.fetch(FetchDescriptor<TaskItem>()) }
        let dataA = try TranscriptCodec.encode(TranscriptCodec.transcript(of: try all(storeA), now: Self.now, calendar: Self.calendar))
        let read = try TranscriptCodec.decode(Transcript.self, from: dataA)
        let entry = try #require(read.tasks.first { $0.id == id })
        #expect(read.now.today == [id])
        let order = Order(id: UUID(), kind: .complete, taskID: entry.id, expectedStatus: entry.status,
                          expectedDueDate: entry.dueDate)
        let sent = try TranscriptCodec.decode(Order.self, from: try TranscriptCodec.encode(order))

        let first = try OrderExecutor.execute(sent, in: storeB.context, now: Self.now, calendar: Self.calendar)
        #expect(first.outcome == .done)

        let afterB = TranscriptCodec.transcript(of: try all(storeB), now: Self.now, calendar: Self.calendar)
        #expect(afterB.nowCount == read.nowCount - 1)
        #expect(!afterB.now.today.contains(id))
        if !repeating { #expect(!afterB.tasks.map(\.id).contains(id)) }
        let completions = try storeB.context.fetchCount(FetchDescriptor<CompletionRecord>())
        let dueAfterFirst = try #require(try all(storeB).first { $0.id == id }).dueDate

        let second = try OrderExecutor.execute(sent, in: storeB.context, now: Self.now, calendar: Self.calendar)
        #expect(second == OrderResult(orderID: order.id, outcome: .rejected, reason: .stale, taskID: id))
        #expect(try storeB.context.fetchCount(FetchDescriptor<CompletionRecord>()) == completions)
        #expect(try #require(try all(storeB).first { $0.id == id }).dueDate == dueAfterFirst)
    }

    // MARK: #622 next up, park, add a subtask

    @Test("Set next puts a task at the end of Next up and takes it out again (#622)")
    @MainActor func setNextOnAndOff() throws {
        let store = try TestStore()
        let first = TranscriptCodecTests.task("Angebot schreiben", rank: 3)
        let task = TranscriptCodecTests.task("Steuer machen")
        store.context.insert(first)
        store.context.insert(task)
        try store.context.save()

        let on = Order(id: UUID(), kind: .setNext, taskID: task.id, expectedStatus: .active, on: true)
        #expect(try Self.run(on, in: store) == OrderResult(orderID: on.id, outcome: .done, taskID: task.id))
        #expect(task.nextRank == 4, "the end of the list, like the swipe")

        let off = Order(id: UUID(), kind: .setNext, taskID: task.id, expectedStatus: .active, on: false, expectedNextRank: 4)
        #expect(try Self.run(off, in: store) == OrderResult(orderID: off.id, outcome: .done, taskID: task.id))
        #expect(task.nextRank == nil)
    }

    @Test("Set next is stale when the rank moved, invalid when nothing would change or the task is parked (#622)")
    @MainActor func setNextRefusals() throws {
        let store = try TestStore()
        let ranked = TranscriptCodecTests.task("Angebot schreiben", rank: 2)
        let plain = TranscriptCodecTests.task("Steuer machen")
        let parked = TranscriptCodecTests.task("Keller räumen", status: .parked)
        [ranked, plain, parked].forEach(store.context.insert)
        try store.context.save()
        let before = try Snapshot(store)
        let ranks = [ranked.nextRank, plain.nextRank, parked.nextRank]

        let moved = Order(id: UUID(), kind: .setNext, taskID: ranked.id, expectedStatus: .active, on: false, expectedNextRank: 1)
        #expect(try Self.run(moved, in: store) == OrderResult(orderID: moved.id, outcome: .rejected, reason: .stale, taskID: ranked.id))
        let already = Order(id: UUID(), kind: .setNext, taskID: ranked.id, expectedStatus: .active, on: true, expectedNextRank: 2)
        #expect(try Self.run(already, in: store) == OrderResult(orderID: already.id, outcome: .rejected, reason: .invalid, taskID: ranked.id))
        let notThere = Order(id: UUID(), kind: .setNext, taskID: plain.id, expectedStatus: .active, on: false)
        #expect(try Self.run(notThere, in: store) == OrderResult(orderID: notThere.id, outcome: .rejected, reason: .invalid, taskID: plain.id))
        let onParked = Order(id: UUID(), kind: .setNext, taskID: parked.id, expectedStatus: .parked, on: true)
        #expect(try Self.run(onParked, in: store) == OrderResult(orderID: onParked.id, outcome: .rejected, reason: .invalid))
        let missing = Order(id: UUID(), kind: .setNext, taskID: UUID(), expectedStatus: .active, on: true)
        #expect(try Self.run(missing, in: store) == OrderResult(orderID: missing.id, outcome: .rejected, reason: .missing))
        let noFlag = Order(id: UUID(), kind: .setNext, taskID: plain.id, expectedStatus: .active)
        #expect(try Self.run(noFlag, in: store) == OrderResult(orderID: noFlag.id, outcome: .rejected, reason: .invalid))

        #expect(try Snapshot(store) == before)
        #expect([ranked.nextRank, plain.nextRank, parked.nextRank] == ranks)
    }

    @Test("Park parks an open task like the swipe: out of Next up, the Knäuel mark falls (#622)")
    @MainActor func parkParks() throws {
        let store = try TestStore()
        let task = TranscriptCodecTests.task("Steuer machen", rank: 1)
        task.knaeuelAt = Self.day(-1)
        store.context.insert(task)
        try store.context.save()
        let order = Order(id: UUID(), kind: .park, taskID: task.id, expectedStatus: .active)

        #expect(try Self.run(order, in: store) == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))

        #expect(task.status == .parked)
        #expect(task.parkedAt == Self.now)
        #expect(task.nextRank == nil)
        #expect(task.knaeuelAt == nil)
    }

    @Test("Park refuses a parked, done or changed task and leaves everything as it was (#622)")
    @MainActor func parkRefusals() throws {
        let store = try TestStore()
        let parked = TranscriptCodecTests.task("Keller räumen", status: .parked)
        let done = TranscriptCodecTests.task("Blumen gießen", status: .done)
        let changed = TranscriptCodecTests.task("Steuer machen")
        [parked, done, changed].forEach(store.context.insert)
        try store.context.save()
        let before = try Snapshot(store)

        let again = Order(id: UUID(), kind: .park, taskID: parked.id, expectedStatus: .parked)
        #expect(try Self.run(again, in: store) == OrderResult(orderID: again.id, outcome: .rejected, reason: .invalid))
        let closed = Order(id: UUID(), kind: .park, taskID: done.id, expectedStatus: .done)
        #expect(try Self.run(closed, in: store) == OrderResult(orderID: closed.id, outcome: .rejected, reason: .invalid))
        let stale = Order(id: UUID(), kind: .park, taskID: changed.id, expectedStatus: .unverified)
        #expect(try Self.run(stale, in: store) == OrderResult(orderID: stale.id, outcome: .rejected, reason: .stale, taskID: changed.id))
        let missing = Order(id: UUID(), kind: .park, taskID: UUID(), expectedStatus: .active)
        #expect(try Self.run(missing, in: store) == OrderResult(orderID: missing.id, outcome: .rejected, reason: .missing))

        #expect(try Snapshot(store) == before)
    }

    @Test("Add subtask adds the line as typed under a top-level task (#622)")
    @MainActor func addSubtaskAdds() throws {
        let store = try TestStore()
        let task = try Self.insert("Umzug planen", in: store)
        let order = Order(id: UUID(), kind: .addSubtask, text: "  Kartons besorgen ", taskID: task.id, expectedStatus: .active)

        #expect(try Self.run(order, in: store) == OrderResult(orderID: order.id, outcome: .done, taskID: task.id))

        let line = try #require(Subtasks.ordered(of: task).first)
        #expect(Subtasks.ordered(of: task).count == 1)
        #expect(line.rawText == "Kartons besorgen")
        #expect(line.title == "Kartons besorgen")
        #expect(line.parent?.id == task.id)
        #expect(line.status == .active)
    }

    @Test("Add subtask refuses an empty line, a subtask as parent, a parked parent and a stale status (#622)")
    @MainActor func addSubtaskRefusals() throws {
        let store = try TestStore()
        let task = try Self.insert("Umzug planen", in: store)
        let line = try Subtasks.add("Kartons", to: task, in: store.context, now: Self.now)
        let parked = TranscriptCodecTests.task("Keller räumen", status: .parked)
        store.context.insert(parked)
        try store.context.save()
        let before = try Snapshot(store)

        let empty = Order(id: UUID(), kind: .addSubtask, text: "   ", taskID: task.id, expectedStatus: .active)
        #expect(try Self.run(empty, in: store) == OrderResult(orderID: empty.id, outcome: .rejected, reason: .invalid, taskID: task.id))
        let noText = Order(id: UUID(), kind: .addSubtask, taskID: task.id, expectedStatus: .active)
        #expect(try Self.run(noText, in: store) == OrderResult(orderID: noText.id, outcome: .rejected, reason: .invalid))
        let nested = Order(id: UUID(), kind: .addSubtask, text: "Noch tiefer", taskID: line.id, expectedStatus: .active)
        #expect(try Self.run(nested, in: store) == OrderResult(orderID: nested.id, outcome: .rejected, reason: .invalid, taskID: line.id))
        let underParked = Order(id: UUID(), kind: .addSubtask, text: "Eins", taskID: parked.id, expectedStatus: .parked)
        #expect(try Self.run(underParked, in: store) == OrderResult(orderID: underParked.id, outcome: .rejected, reason: .invalid))
        let stale = Order(id: UUID(), kind: .addSubtask, text: "Eins", taskID: task.id, expectedStatus: .unverified)
        #expect(try Self.run(stale, in: store) == OrderResult(orderID: stale.id, outcome: .rejected, reason: .stale, taskID: task.id))
        let missing = Order(id: UUID(), kind: .addSubtask, text: "Eins", taskID: UUID(), expectedStatus: .active)
        #expect(try Self.run(missing, in: store) == OrderResult(orderID: missing.id, outcome: .rejected, reason: .missing))

        #expect(try Snapshot(store) == before)
        #expect(Subtasks.ordered(of: task).count == 1)
    }

    // MARK: AC-10

    /// Version 1, word for word in `docs/reference/claude-abschrift-vertrag.md`.
    static let orderFixture = """
    {
      "expectedDueDate": "2026-03-12T17:00:00Z",
      "expectedStatus": "active",
      "id": "0B7D5E3C-0000-4000-8000-000000000010",
      "kind": "complete",
      "taskID": "6F1C2B0A-0000-4000-8000-000000000001",
      "version": 1
    }
    """

    static let resultFixture = """
    {
      "orderID": "0B7D5E3C-0000-4000-8000-000000000010",
      "outcome": "rejected",
      "reason": "stale",
      "taskID": "6F1C2B0A-0000-4000-8000-000000000001"
    }
    """

    static let fixtureOrder = Order(
        id: UUID(uuidString: "0B7D5E3C-0000-4000-8000-000000000010")!, kind: .complete,
        taskID: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000001")!, expectedStatus: .active,
        expectedDueDate: ISO8601DateFormatter().date(from: "2026-03-12T17:00:00Z")!
    )

    static let fixtureResult = OrderResult(
        orderID: UUID(uuidString: "0B7D5E3C-0000-4000-8000-000000000010")!, outcome: .rejected, reason: .stale,
        taskID: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000001")!
    )

    @Test("Order and result meet their fixed examples both ways (AC-3, AC-10)")
    func orderAndResultFixtures() throws {
        #expect(try JSONEqual.same(try TranscriptCodec.encode(Self.fixtureOrder), Data(Self.orderFixture.utf8)))
        #expect(try TranscriptCodec.decode(Order.self, from: Data(Self.orderFixture.utf8)) == Self.fixtureOrder)
        #expect(try JSONEqual.same(try TranscriptCodec.encode(Self.fixtureResult), Data(Self.resultFixture.utf8)))
        #expect(try TranscriptCodec.decode(OrderResult.self, from: Data(Self.resultFixture.utf8)) == Self.fixtureResult)
    }

    @Test("The contract document carries the order and result examples word for word (AC-10)")
    func documentCarriesFixtures() throws {
        let document = try ContractDocument.text()
        #expect(document.contains(Self.orderFixture))
        #expect(document.contains(Self.resultFixture))
    }
}

/// #622 Schnitt 1: every order that changes a task leaves one user revision with the reason "Claude", and the side
/// revisions an action writes (the Knäuel mark falls) carry that reason too. XCTest, so the QA gate counts it.
/// The new fields are looked up by raw value, so the tests compile before `RevisedField` knows them.
@MainActor final class OrderExecutorRevisionTests: XCTestCase {
    private typealias Suite = OrderExecutorTests

    private func field(_ raw: String) throws -> RevisedField {
        try XCTUnwrap(RevisedField(rawValue: raw), "RevisedField has no case \(raw)")
    }

    private func revisions(_ raw: String, of task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.fieldRaw == raw }
    }

    private func assertByClaude(_ revision: Revision, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(revision.author, .user, file: file, line: line)
        XCTAssertEqual(revision.reason, OrderExecutor.reason, file: file, line: line)
    }

    // MARK: AC-2

    func testCompleteOneOffWritesOneStatusRevision() throws {
        let store = try TestStore()
        let task = try Suite.insert("Rechnung bezahlen", in: store)
        let order = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .active)

        XCTAssertEqual(try Suite.run(order, in: store).outcome, .done)

        let status = revisions("status", of: task)
        XCTAssertEqual(status.count, 1)
        let revision = try XCTUnwrap(status.first)
        XCTAssertEqual(revision.oldValue, TaskStatus.active.rawValue)
        XCTAssertEqual(revision.newValue, TaskStatus.done.rawValue)
        assertByClaude(revision)
    }

    // MARK: AC-3, AC-7

    func testCompleteRepeatingWritesStatusNotDueAndStampsTheKnaeuel() throws {
        let store = try TestStore()
        let task = try Suite.insert("Blumen gießen", due: Suite.day(0), in: store)
        task.repeatRule = RepeatRule(frequency: .daily)
        task.knaeuelAt = Suite.day(-1)
        let earlier = Revision(task: task, field: .title, oldValue: nil, newValue: "Blumen gießen", author: .user, reason: "Siri")
        task.revisions = (task.revisions ?? []) + [earlier]
        try store.context.save()
        let postponed = ViewRules.postponeCount(task)
        let order = Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .active,
                          expectedDueDate: Suite.day(0))

        XCTAssertEqual(try Suite.run(order, in: store).outcome, .done)

        XCTAssertTrue(revisions(RevisedField.dueDate.rawValue, of: task).isEmpty, "a round is no postponement")
        XCTAssertEqual(ViewRules.postponeCount(task), postponed)
        let status = revisions("status", of: task)
        XCTAssertEqual(status.count, 1)
        XCTAssertEqual(status.first?.newValue, TaskStatus.done.rawValue)
        status.first.map { assertByClaude($0) }
        let knaeuel = revisions(RevisedField.knaeuel.rawValue, of: task)
        XCTAssertEqual(knaeuel.count, 1)
        XCTAssertEqual(knaeuel.first?.reason, OrderExecutor.reason)
        XCTAssertEqual(earlier.reason, "Siri", "a reason that was there stays")
    }

    // MARK: AC-4

    func testSetNextWritesRankRevisionOnAndOff() throws {
        let store = try TestStore()
        let task = TranscriptCodecTests.task("Steuer machen")
        store.context.insert(task)
        try store.context.save()

        let on = Order(id: UUID(), kind: .setNext, taskID: task.id, expectedStatus: .active, on: true)
        XCTAssertEqual(try Suite.run(on, in: store).outcome, .done)
        let rank = try XCTUnwrap(task.nextRank)
        let off = Order(id: UUID(), kind: .setNext, taskID: task.id, expectedStatus: .active, on: false, expectedNextRank: rank)
        XCTAssertEqual(try Suite.run(off, in: store).outcome, .done)

        let ranks = revisions("nextRank", of: task).sorted { ($0.oldValue == nil ? 0 : 1) < ($1.oldValue == nil ? 0 : 1) }
        XCTAssertEqual(ranks.count, 2)
        guard ranks.count == 2 else { return }
        XCTAssertNil(ranks[0].oldValue)
        XCTAssertEqual(ranks[0].newValue, String(rank))
        XCTAssertEqual(ranks[1].oldValue, String(rank))
        XCTAssertNil(ranks[1].newValue)
        ranks.forEach { assertByClaude($0) }
    }

    // MARK: AC-5, AC-7

    func testParkWritesStatusAndStampsTheKnaeuel() throws {
        let store = try TestStore()
        let task = TranscriptCodecTests.task("Steuer machen", rank: 1)
        task.knaeuelAt = Suite.day(-1)
        store.context.insert(task)
        try store.context.save()
        let order = Order(id: UUID(), kind: .park, taskID: task.id, expectedStatus: .active)

        XCTAssertEqual(try Suite.run(order, in: store).outcome, .done)

        let status = revisions("status", of: task)
        XCTAssertEqual(status.count, 1)
        XCTAssertEqual(status.first?.oldValue, TaskStatus.active.rawValue)
        XCTAssertEqual(status.first?.newValue, TaskStatus.parked.rawValue)
        status.first.map { assertByClaude($0) }
        let knaeuel = revisions(RevisedField.knaeuel.rawValue, of: task)
        XCTAssertEqual(knaeuel.count, 1)
        knaeuel.first.map { assertByClaude($0) }
    }

    // MARK: AC-6

    func testAddSubtaskWritesRevisionOnTheParentAndCapturesViaClaude() throws {
        let store = try TestStore()
        let task = try Suite.insert("Umzug planen", in: store)
        let order = Order(id: UUID(), kind: .addSubtask, text: "  Kartons besorgen ", taskID: task.id, expectedStatus: .active)

        XCTAssertEqual(try Suite.run(order, in: store).outcome, .done)

        let line = try XCTUnwrap(Subtasks.ordered(of: task).first)
        XCTAssertEqual(line.capturedVia, .claude)
        let added = revisions("subtasks", of: task)
        XCTAssertEqual(added.count, 1)
        XCTAssertNil(added.first?.oldValue)
        XCTAssertEqual(added.first?.newValue, line.rawText)
        added.first.map { assertByClaude($0) }

        let byHand = try Subtasks.add("Klebeband", to: task, in: store.context, now: Suite.now)
        XCTAssertEqual(byHand.capturedVia, .app)
    }

    // MARK: AC-8

    func testSetDueUnchangedAndCaptureWritesNoRevision() throws {
        let store = try TestStore()
        let task = try Suite.insert("Angebot schreiben", in: store)
        let due = Order(id: UUID(), kind: .setDue, taskID: task.id, date: Suite.day(2, hour: 15), hasTime: true)
        XCTAssertEqual(try Suite.run(due, in: store).outcome, .done)
        XCTAssertEqual(task.revisions?.count, 1)
        XCTAssertEqual(task.revisions?.first?.fieldRaw, RevisedField.dueDate.rawValue)
        task.revisions?.first.map { assertByClaude($0) }

        let capture = Order(id: UUID(), kind: .capture, text: "Zahnarzt anrufen")
        let result = try Suite.run(capture, in: store)
        let captured = try XCTUnwrap(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == result.taskID })
        XCTAssertTrue((captured.revisions ?? []).isEmpty)
    }

    // MARK: AC-9

    func testRefusedOrdersLeaveNoRevision() throws {
        let store = try TestStore()
        let task = try Suite.insert("Steuer machen", in: store)
        let before = try Suite.Snapshot(store)
        let refused: [Order] = [
            Order(id: UUID(), kind: .complete, taskID: task.id, expectedStatus: .unverified),
            Order(id: UUID(), kind: .complete, taskID: UUID(), expectedStatus: .active),
            Order(id: UUID(), kind: .setNext, taskID: task.id, expectedStatus: .active, on: false),
            Order(id: UUID(), kind: .setNext, taskID: task.id, expectedStatus: .active, on: true, expectedNextRank: 9),
            Order(id: UUID(), kind: .park, taskID: task.id, expectedStatus: .unverified),
            Order(id: UUID(), kind: .park, taskID: UUID(), expectedStatus: .active),
            Order(id: UUID(), kind: .addSubtask, text: "  ", taskID: task.id, expectedStatus: .active),
            Order(id: UUID(), kind: .addSubtask, text: "Kartons", taskID: task.id, expectedStatus: .unverified),
        ]
        for order in refused {
            XCTAssertEqual(try Suite.run(order, in: store).outcome, .rejected, "\(order.kind)")
        }
        XCTAssertEqual(try Suite.Snapshot(store), before)
    }

    // MARK: AC-1, AC-10

    func testNewFieldsExistAndCannotBeReset() throws {
        let status = try field("status"), rank = try field("nextRank"), subtasks = try field("subtasks")
        XCTAssertEqual(Array(RevisedField.allCases.suffix(3)), [status, rank, subtasks])
        XCTAssertEqual(RevisedField.allCases.prefix(15).map(\.rawValue), [
            "title", "dueDate", "importance", "urgency", "duration", "energy", "contexts", "people", "project",
            "blockedBy", "repeatRule", "place", "notes", "knaeuel", "counts",
        ])

        let store = try TestStore()
        let task = TranscriptCodecTests.task("Steuer machen", rank: 1)
        task.knaeuelAt = Suite.day(-1)
        store.context.insert(task)
        try store.context.save()
        let park = Order(id: UUID(), kind: .park, taskID: task.id, expectedStatus: .active)
        XCTAssertEqual(try Suite.run(park, in: store).outcome, .done)

        XCTAssertTrue(RevisionService.automaticFields(on: task).isEmpty)
        let count = task.revisions?.count
        XCTAssertTrue(RevisionService.revertAll(on: task, contexts: [], projects: []).isEmpty)
        XCTAssertEqual(task.revisions?.count, count)
        for new in [status, rank, subtasks] {
            XCTAssertNil(RevisionService.origin(of: new, on: task), "\(new)")
        }

        FieldCodec.apply(TaskStatus.active.rawValue, to: status, of: task, as: .user, contexts: [], projects: [])
        FieldCodec.apply("7", to: rank, of: task, as: .user, contexts: [], projects: [])
        FieldCodec.apply("Kartons", to: subtasks, of: task, as: .user, contexts: [], projects: [])
        XCTAssertEqual(task.status, .parked)
        XCTAssertNil(task.nextRank)
        XCTAssertTrue(Subtasks.ordered(of: task).isEmpty)
    }

    // MARK: AC-11

    func testEncodeAndFormatting() throws {
        let status = try field("status"), rank = try field("nextRank"), subtasks = try field("subtasks")
        let task = TranscriptCodecTests.task("Steuer machen", rank: 4)
        XCTAssertEqual(FieldCodec.encode(status, of: task), TaskStatus.active.rawValue)
        XCTAssertEqual(FieldCodec.encode(rank, of: task), String(4.0))
        XCTAssertNil(FieldCodec.encode(subtasks, of: task))
        task.nextRank = nil
        XCTAssertNil(FieldCodec.encode(rank, of: task))

        XCTAssertEqual(FieldFormatting.label(status), String(localized: "Status"))
        XCTAssertEqual(FieldFormatting.label(rank), String(localized: "Next up"))
        XCTAssertEqual(FieldFormatting.label(subtasks), String(localized: "Subtask"))
        XCTAssertEqual(FieldFormatting.value(TaskStatus.done.rawValue, for: status), String(localized: "Done"))
        XCTAssertEqual(FieldFormatting.value(TaskStatus.parked.rawValue, for: status), String(localized: "Parked"))
        for open in [TaskStatus.active, .unverified, .unprocessed] {
            XCTAssertEqual(FieldFormatting.value(open.rawValue, for: status), String(localized: "Open"), "\(open)")
        }
        XCTAssertEqual(FieldFormatting.value("4.0", for: rank), String(localized: "Yes"))
        XCTAssertNil(FieldFormatting.value(nil, for: rank))
        XCTAssertEqual(FieldFormatting.value("Kartons besorgen", for: subtasks), "Kartons besorgen")

        let catalog = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("LooseEnds/Resources/Localizable.xcstrings")
        let strings = try XCTUnwrap(
            (try JSONSerialization.jsonObject(with: Data(contentsOf: catalog)) as? [String: Any])?["strings"] as? [String: Any]
        )
        for key in ["Status", "Next up", "Subtask", "Open", "Done", "Parked", "Yes"] {
            let entry = strings[key] as? [String: Any]
            let german = ((entry?["localizations"] as? [String: Any])?["de"] as? [String: Any])?["stringUnit"] as? [String: Any]
            XCTAssertNotNil(german?["value"] as? String, "no German for \(key)")
        }
    }
}

/// #932 Schnitt 1: Claude sets the title and the details of a task, at capture (`fields`) and afterwards (`update`). Every value
/// is a user revision with the reason "Claude"; every check runs before the first write. The orders are built from JSON, the way
/// they arrive, so the tests compile before `Order` knows `fields` and `update`. XCTest, so the QA gate counts it.
@MainActor final class OrderExecutorFieldsTests: XCTestCase {
    private typealias Suite = OrderExecutorTests

    /// Both new examples, word for word in `docs/reference/claude-abschrift-vertrag.md` (`jsonc` blocks).
    static let orderFieldsFixture = """
    {
      "fields": {
        "contexts": ["Garten"],
        "dueDate": "2026-03-14T08:00:00Z",
        "dueHasTime": true,
        "duration": "hour1",
        "energy": -1,
        "importance": "high",
        "notes": "Heckenschere beim Nachbarn holen",
        "project": "Haus",
        "title": "Hecke schneiden",
        "urgency": "low"
      },
      "id": "0B7D5E3C-0000-4000-8000-000000000020",
      "kind": "capture",
      "text": "Samstag früh die Hecke schneiden, Heckenschere beim Nachbarn holen",
      "version": 1
    }
    """

    static let orderUpdateFixture = """
    {
      "expectedContexts": ["Garten"],
      "expectedStatus": "active",
      "expectedTitle": "Hecke schneiden",
      "fields": {
        "contexts": ["Garten", "Haus"],
        "duration": "minutes30",
        "title": "Hecke und Rasen schneiden"
      },
      "id": "0B7D5E3C-0000-4000-8000-000000000021",
      "kind": "update",
      "taskID": "6F1C2B0A-0000-4000-8000-000000000001",
      "version": 1
    }
    """

    // MARK: Helpers

    /// An order as it arrives: JSON through the codec.
    private func order(_ json: [String: Any]) throws -> Order {
        var json = json
        json["version"] = json["version"] ?? 1
        json["id"] = json["id"] ?? UUID().uuidString
        let data = try JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])
        return try TranscriptCodec.decode(Order.self, from: data)
    }

    /// The catalogs: contexts Garten, Büro, Haus; projects Haus, Arbeit.
    private struct Catalog {
        let garden = TaskContext(name: "Garten", sortOrder: 0)
        let office = TaskContext(name: "Büro", sortOrder: 1)
        let home = TaskContext(name: "Haus", sortOrder: 2)
        let house = Project(name: "Haus", sortOrder: 0)
        let work = Project(name: "Arbeit", sortOrder: 1)

        @MainActor init(in store: TestStore) throws {
            for context in [garden, office, home] { store.context.insert(context) }
            for project in [house, work] { store.context.insert(project) }
            try store.context.save()
        }
    }

    /// A task with every field set; `expected` gives the transcript's view of it.
    private func fullTask(_ catalog: Catalog, in store: TestStore) throws -> TaskItem {
        let task = TranscriptCodecTests.task("Hecke schneiden", due: Suite.day(1, hour: 9))
        task.importance = .medium
        task.urgency = .medium
        task.duration = .minutes15
        task.energy = .neither
        task.contexts = [catalog.garden]
        task.project = catalog.house
        store.context.insert(task)
        try store.context.save()
        return task
    }

    private func expected(_ task: TaskItem) -> [String: Any] {
        var json: [String: Any] = ["taskID": task.id.uuidString, "expectedStatus": task.status.rawValue]
        json["expectedTitle"] = task.title
        json["expectedDueDate"] = task.dueDate?.ISO8601Format()
        let names = (task.contexts ?? []).map(\.name)
        if !names.isEmpty { json["expectedContexts"] = names }
        json["expectedProject"] = task.project?.name
        return json
    }

    private func update(_ task: TaskItem, _ fields: [String: Any], extra: [String: Any] = [:]) throws -> Order {
        var json = expected(task).merging(extra) { $1 }
        json["kind"] = "update"
        json["fields"] = fields
        return try order(json)
    }

    fileprivate static let fieldsOnTask: [RevisedField] = [
        .title, .notes, .dueDate, .importance, .urgency, .duration, .energy, .contexts, .project,
    ]

    /// Each field as `FieldCodec` encodes it, "-" for none.
    private func values(of task: TaskItem) -> [RevisedField: String] {
        Dictionary(uniqueKeysWithValues: Self.fieldsOnTask.map { ($0, FieldCodec.encode($0, of: task) ?? "-") })
    }

    /// Everything a refusal must leave as it was: tasks with every field, revisions, both catalogs.
    private struct Store: Equatable {
        let tasks: [String]
        let revisions: Int
        let contexts: [String]
        let projects: [String]

        @MainActor init(_ store: TestStore) throws {
            tasks = try store.context.fetch(FetchDescriptor<TaskItem>()).map { task in
                let fields = OrderExecutorFieldsTests.fieldsOnTask.map { FieldCodec.encode($0, of: task) ?? "-" }
                return "\(task.id) \(task.status) \(task.dueHasTime) " + fields.joined(separator: " | ")
            }.sorted()
            revisions = try store.context.fetchCount(FetchDescriptor<Revision>())
            contexts = try store.context.fetch(FetchDescriptor<TaskContext>()).map(\.name).sorted()
            projects = try store.context.fetch(FetchDescriptor<Project>()).map(\.name).sorted()
        }
    }

    private func revisions(_ field: RevisedField, of task: TaskItem) -> [Revision] {
        (task.revisions ?? []).filter { $0.fieldRaw == field.rawValue }
    }

    // MARK: AC-1

    func testContractExamplesDecodeEncodeAndStandInTheDocument() throws {
        let document = try ContractDocument.text()
        for fixture in [Self.orderFieldsFixture, Self.orderUpdateFixture] {
            let decoded = try TranscriptCodec.decode(Order.self, from: Data(fixture.utf8))
            XCTAssertTrue(try JSONEqual.same(try TranscriptCodec.encode(decoded), Data(fixture.utf8)),
                          "the order must keep every key of the example:\n\(fixture)")
            XCTAssertTrue(document.contains(fixture), "the contract must quote the example word for word")
        }
    }

    // MARK: AC-2

    func testCaptureWithEveryFieldSetsEachAsAClaudeRevision() throws {
        let store = try TestStore()
        let catalog = try Catalog(in: store)
        let text = "Samstag früh die Hecke schneiden"
        let fields: [String: Any] = [
            "title": "Hecke schneiden", "notes": "Heckenschere beim Nachbarn holen",
            "dueDate": Suite.day(2, hour: 8).ISO8601Format(), "dueHasTime": true,
            "importance": "high", "urgency": "low", "duration": "hour1", "energy": -1,
            "contexts": ["Garten", "Büro"], "project": "Haus",
        ]

        let result = try Suite.run(try order(["kind": "capture", "text": text, "fields": fields]), in: store)

        XCTAssertEqual(result.outcome, .done)
        let task = try XCTUnwrap(try store.context.fetch(FetchDescriptor<TaskItem>()).first { $0.id == result.taskID })
        XCTAssertEqual(task.rawText, text, "the raw text stays the user's words (ADR-3)")
        XCTAssertEqual(task.capturedVia, .claude)
        XCTAssertEqual(task.title, "Hecke schneiden")
        XCTAssertEqual(task.titleSourceRaw, FieldSource.user.rawValue)
        XCTAssertEqual(task.notes, "Heckenschere beim Nachbarn holen")
        XCTAssertEqual(task.dueDate, Suite.day(2, hour: 8))
        XCTAssertTrue(task.dueHasTime)
        XCTAssertEqual(task.importance, .high)
        XCTAssertEqual(task.urgency, .low)
        XCTAssertEqual(task.duration, .hour1)
        XCTAssertEqual(task.energy, .takesLittle)
        XCTAssertEqual(Set((task.contexts ?? []).map(\.name)), ["Garten", "Büro"])
        XCTAssertEqual(task.project?.persistentModelID, catalog.house.persistentModelID)
        for field in Self.fieldsOnTask {
            let written = revisions(field, of: task)
            XCTAssertEqual(written.count, 1, "\(field)")
            written.forEach { XCTAssertTrue(RevisionService.isByClaude($0), "\(field)") }
        }
        XCTAssertNotNil(RevisionService.lastClaudeChange(on: task))
    }

    // MARK: AC-3

    func testUpdateSetsOneFieldAsOneClaudeRevision() throws {
        let cases: [(RevisedField, String, Any)] = [
            (.title, "title", "Hecke und Rasen schneiden"),
            (.dueDate, "dueDate", Suite.day(3, hour: 15).ISO8601Format()),
            (.importance, "importance", "high"), (.urgency, "urgency", "low"), (.duration, "duration", "hour1"),
            (.energy, "energy", 2), (.contexts, "contexts", ["Büro"]), (.project, "project", "Arbeit"),
        ]
        for (field, key, value) in cases {
            let store = try TestStore()
            let catalog = try Catalog(in: store)
            let task = try fullTask(catalog, in: store)
            let before = values(of: task)
            var fields: [String: Any] = [key: value]
            if field == .dueDate { fields["dueHasTime"] = true }

            let result = try Suite.run(try update(task, fields), in: store)

            XCTAssertEqual(result.outcome, .done, "\(field)")
            XCTAssertEqual(result.taskID, task.id, "\(field)")
            XCTAssertEqual(task.revisions?.count, 1, "\(field): exactly one revision")
            let revision = try XCTUnwrap(revisions(field, of: task).first, "\(field)")
            XCTAssertTrue(RevisionService.isByClaude(revision), "\(field)")
            XCTAssertEqual(revision.oldValue ?? "-", before[field], "\(field)")
            XCTAssertEqual(revision.newValue ?? "-", values(of: task)[field], "\(field)")
            XCTAssertNotEqual(revision.oldValue, revision.newValue, "\(field)")
            var after = values(of: task)
            after[field] = before[field]
            XCTAssertEqual(after, before, "\(field): every other field stays")
        }
    }

    // MARK: AC-4

    func testUnchangedOrMissingFieldWritesNothingAndEmptyTagsClear() throws {
        let store = try TestStore()
        let catalog = try Catalog(in: store)
        let task = try fullTask(catalog, in: store)
        let before = values(of: task)

        let same = try Suite.run(try update(task, ["importance": "medium", "title": "Hecke schneiden"]), in: store)
        XCTAssertEqual(same.outcome, .done)
        XCTAssertTrue((task.revisions ?? []).isEmpty, "a value that already stands writes no revision")
        XCTAssertEqual(values(of: task), before)

        let clear = try Suite.run(try update(task, ["contexts": [String]()]), in: store)
        XCTAssertEqual(clear.outcome, .done)
        XCTAssertTrue((task.contexts ?? []).isEmpty)
        XCTAssertEqual(task.revisions?.count, 1)
        XCTAssertEqual(revisions(.contexts, of: task).count, 1)
        var after = values(of: task)
        after[.contexts] = before[.contexts]
        XCTAssertEqual(after, before, "fields the order leaves out stay")
    }

    // MARK: AC-5

    func testNamesResolveToTheCatalogAndNothingIsCreated() throws {
        let store = try TestStore()
        let catalog = try Catalog(in: store)
        let task = try fullTask(catalog, in: store)

        let result = try Suite.run(try update(task, ["contexts": ["buro", "GARTEN"], "project": "arbeit"]), in: store)

        XCTAssertEqual(result.outcome, .done)
        XCTAssertEqual(Set((task.contexts ?? []).map(\.persistentModelID)),
                       [catalog.office.persistentModelID, catalog.garden.persistentModelID])
        XCTAssertEqual(Set((task.contexts ?? []).map(\.name)), ["Büro", "Garten"], "the catalog's spelling")
        XCTAssertEqual(task.project?.persistentModelID, catalog.work.persistentModelID)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<TaskContext>()), 3)
        XCTAssertEqual(try store.context.fetchCount(FetchDescriptor<Project>()), 2)
    }

    // MARK: AC-6

    func testInvalidValuesAreRefusedWithoutAnyWrite() throws {
        let store = try TestStore()
        let catalog = try Catalog(in: store)
        let task = try fullTask(catalog, in: store)
        let before = try Store(store)
        let invalid: [(String, [String: Any], [String: Any])] = [
            ("unknown tag", ["contexts": ["Keller"]], [:]),
            ("unknown project", ["project": "Urlaub"], [:]),
            ("importance", ["importance": "huge"], [:]),
            ("urgency", ["urgency": "now"], [:]),
            ("duration", ["duration": "minutes45"], [:]),
            ("energy", ["energy": 4], [:]),
            ("blank title", ["title": "   "], [:]),
            ("notes on update", ["notes": "Heckenschere"], [:]),
            ("empty fields", [:], [:]),
            ("date without time flag", ["dueDate": Suite.day(3).ISO8601Format()], [:]),
            ("time flag without date", ["dueHasTime": true], [:]),
            ("done expected", ["importance": "high"], ["expectedStatus": "done"]),
            ("removed expected", ["importance": "high"], ["expectedStatus": "removed"]),
        ]
        for (name, fields, extra) in invalid {
            let result = try Suite.run(try update(task, fields, extra: extra), in: store)
            XCTAssertEqual(result.outcome, .rejected, name)
            XCTAssertEqual(result.reason, .invalid, name)
            XCTAssertEqual(result.taskID, task.id, name)
        }
        let noFields = try order(expected(task).merging(["kind": "update"]) { $1 })
        XCTAssertEqual(try Suite.run(noFields, in: store).reason, .invalid, "update without fields")
        XCTAssertEqual(try Store(store), before)

        let captures: [[String: Any]] = [
            ["contexts": ["Keller"]], ["project": "Urlaub"], ["importance": "huge"], ["energy": -4], ["title": ""],
            ["dueHasTime": false],
        ]
        for fields in captures {
            let result = try Suite.run(try order(["kind": "capture", "text": "Hecke schneiden", "fields": fields]), in: store)
            XCTAssertEqual(result.outcome, .rejected, "capture \(fields)")
            XCTAssertEqual(result.reason, .invalid, "capture \(fields)")
        }
        XCTAssertEqual(try Store(store), before, "a refused capture creates no task")
    }

    // MARK: AC-6 (#777)

    func testSameInstantOnlyChangingTheTimeFlagIsInvalid() throws {
        let store = try TestStore()
        let catalog = try Catalog(in: store)
        let task = try fullTask(catalog, in: store)
        let midnight = Suite.calendar.startOfDay(for: Suite.day(4))
        task.dueDate = midnight
        task.dueHasTime = true
        try store.context.save()
        let before = try Store(store)

        let result = try Suite.run(try update(task, ["dueDate": midnight.ISO8601Format(), "dueHasTime": false]), in: store)

        XCTAssertEqual(result, OrderResult(orderID: result.orderID, outcome: .rejected, reason: .invalid, taskID: task.id))
        XCTAssertEqual(try Store(store), before)
    }

    // MARK: AC-7

    func testChangedTaskIsStale() throws {
        let store = try TestStore()
        let catalog = try Catalog(in: store)
        let task = try fullTask(catalog, in: store)
        let before = try Store(store)
        let stale: [(String, [String: Any], [String: Any])] = [
            ("old title", ["title": "Neu"], ["expectedTitle": "Hecke"]),
            ("old tags", ["contexts": ["Büro"]], ["expectedContexts": ["Büro"]]),
            ("old project", ["project": "Arbeit"], ["expectedProject": "Arbeit"]),
            ("old date", ["dueDate": Suite.day(5).ISO8601Format(), "dueHasTime": true],
             ["expectedDueDate": Suite.day(2).ISO8601Format()]),
            ("old status", ["importance": "high"], ["expectedStatus": "unverified"]),
            ("parked meanwhile", ["importance": "high"], ["expectedStatus": "parked"]),
        ]
        for (name, fields, extra) in stale {
            let result = try Suite.run(try update(task, fields, extra: extra), in: store)
            XCTAssertEqual(result.outcome, .rejected, name)
            XCTAssertEqual(result.reason, .stale, name)
            XCTAssertEqual(result.taskID, task.id, name)
        }
        // A missing expected value means "had none", and the task has a title, tags, a project and a date now.
        let without: [(String, [String: Any])] = [
            ("expectedTitle", ["title": "Neu"]), ("expectedContexts", ["contexts": ["Büro"]]),
            ("expectedProject", ["project": "Arbeit"]),
            ("expectedDueDate", ["dueDate": Suite.day(5).ISO8601Format(), "dueHasTime": true]),
        ]
        for (key, fields) in without {
            var json = expected(task)
            json.removeValue(forKey: key)
            json["kind"] = "update"
            json["fields"] = fields
            XCTAssertEqual(try Suite.run(try order(json), in: store).reason, .stale, "without \(key)")
        }
        XCTAssertEqual(try Store(store), before)
    }

    // MARK: AC-7 (missing)

    func testUnknownTaskIsMissingAndNoTaskIDInvalid() throws {
        let store = try TestStore()
        let catalog = try Catalog(in: store)
        let task = try fullTask(catalog, in: store)
        let before = try Store(store)

        let missing = try Suite.run(try update(task, ["importance": "high"], extra: ["taskID": UUID().uuidString]), in: store)
        XCTAssertEqual(missing, OrderResult(orderID: missing.orderID, outcome: .rejected, reason: .missing))

        var json = expected(task)
        json.removeValue(forKey: "taskID")
        json["kind"] = "update"
        json["fields"] = ["importance": "high"]
        let noTask = try Suite.run(try order(json), in: store)
        XCTAssertEqual(noTask, OrderResult(orderID: noTask.orderID, outcome: .rejected, reason: .invalid))
        XCTAssertEqual(try Store(store), before)
    }
}
