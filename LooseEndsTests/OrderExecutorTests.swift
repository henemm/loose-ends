import Foundation
import SwiftData
import Testing
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
