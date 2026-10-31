import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// The transcript Claude reads (#613 Schnitt 1, Weg B): the open tasks and "Now" as the app computes it,
/// so Claude never shows another number than the app (#637). No raw text, no note, no attachment, no revision.
@Suite("Transcript for Claude") struct TranscriptCodecTests {
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

    static func task(_ text: String, due: Date? = nil, rank: Int? = nil, status: TaskStatus = .active) -> TaskItem {
        let task = TaskItem(rawText: text)
        task.title = text
        task.status = status
        task.dueDate = due
        task.dueHasTime = due != nil
        task.nextRank = rank.map(Double.init)
        return task
    }

    /// Every kind "Now" knows, plus what it leaves out.
    struct Mixed {
        let today = TranscriptCodecTests.task("Müll rausbringen", due: TranscriptCodecTests.day(0, hour: 18))
        let lined = TranscriptCodecTests.task("Angebot schreiben", rank: 0)
        let waiting = TranscriptCodecTests.task("Rechnung bezahlen", due: TranscriptCodecTests.day(-2))
        let knaeuel = TranscriptCodecTests.task("Steuer machen")
        let done = TranscriptCodecTests.task("Blumen gießen", status: .done)
        let parked = TranscriptCodecTests.task("Keller räumen", status: .parked)
        let later = TranscriptCodecTests.task("Zahnarzt anrufen", due: TranscriptCodecTests.day(5))

        var all: [TaskItem] { [today, lined, waiting, knaeuel, done, parked, later] }

        init() { knaeuel.knaeuelAt = TranscriptCodecTests.day(-1) }
    }

    static func json(_ transcript: Transcript) throws -> [String: Any] {
        let data = try TranscriptCodec.encode(transcript)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    // MARK: AC-1

    @Test("The JSON carries exactly the agreed keys, top level, Now and every task (AC-1)")
    @MainActor func carriesExactlyTheAgreedKeys() throws {
        let store = try TestStore()
        let mixed = Mixed()
        let garden = TaskContext(name: "Garten")
        let house = Project(name: "Haus")
        store.context.insert(garden)
        store.context.insert(house)
        mixed.all.forEach(store.context.insert)
        mixed.lined.contexts = [garden]
        mixed.lined.project = house
        mixed.lined.dueDate = Self.day(3)
        try store.context.save()

        let transcript = TranscriptCodec.transcript(of: mixed.all, now: Self.now, calendar: Self.calendar)
        let json = try Self.json(transcript)

        #expect(Set(json.keys) == ["version", "generatedAt", "nowCount", "now", "tasks"])
        let now = try #require(json["now"] as? [String: Any])
        #expect(Set(now.keys) == ["knaeuel", "today", "lined", "waiting"])
        let tasks = try #require(json["tasks"] as? [[String: Any]])
        let full = try #require(tasks.first { $0["id"] as? String == mixed.lined.id.uuidString })
        #expect(Set(full.keys) == [
            "id", "title", "status", "dueDate", "dueHasTime", "contexts", "project", "nextRank", "isKnaeuel",
        ])
        let allowed: Set<String> = [
            "id", "title", "status", "dueDate", "dueHasTime", "contexts", "project", "nextRank", "isKnaeuel",
        ]
        for task in tasks { #expect(Set(task.keys).isSubset(of: allowed)) }
        #expect(json["version"] as? Int == 1)
        #expect(full["contexts"] as? [String] == ["Garten"])
        #expect(full["project"] as? String == "Haus")
        #expect(full["status"] as? String == "active")
    }

    @Test("Completed and removed tasks stay out, parked ones are in; the Knäuel says so (AC-1)")
    @MainActor func onlyOpenTasks() throws {
        let store = try TestStore()
        let mixed = Mixed()
        let removed = Self.task("Weg damit", status: .removed)
        (mixed.all + [removed]).forEach(store.context.insert)

        let transcript = TranscriptCodec.transcript(of: mixed.all + [removed], now: Self.now, calendar: Self.calendar)
        let ids = Set(transcript.tasks.map(\.id))

        #expect(!ids.contains(mixed.done.id))
        #expect(!ids.contains(removed.id))
        #expect(ids == Set([mixed.today, mixed.lined, mixed.waiting, mixed.knaeuel, mixed.parked, mixed.later].map(\.id)))
        #expect(transcript.tasks.first { $0.id == mixed.knaeuel.id }?.isKnaeuel == true)
        #expect(transcript.tasks.first { $0.id == mixed.today.id }?.isKnaeuel == false)
        #expect(transcript.tasks.first { $0.id == mixed.parked.id }?.status == .parked)
    }

    @Test("Raw text and note never leave the device (AC-1)")
    @MainActor func noRawTextNoNote() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Zebrafink-4711 füttern bevor der Nachbar kommt")
        task.title = "Vogel füttern"
        task.status = .active
        task.notes = "Notizgeheimnis-0815"
        store.context.insert(task)

        let transcript = TranscriptCodec.transcript(of: [task], now: Self.now, calendar: Self.calendar)
        let text = try #require(String(data: try TranscriptCodec.encode(transcript), encoding: .utf8))

        #expect(text.contains("Vogel füttern"))
        #expect(!text.contains("Zebrafink-4711"))
        #expect(!text.contains("Notizgeheimnis-0815"))
        #expect(!text.contains("rawText"))
        #expect(!text.contains("notes"))
    }

    // MARK: AC-2

    @Test("Now and its number are ViewRules' own, in its order (AC-2)")
    @MainActor func nowIsViewRules() throws {
        let store = try TestStore()
        let mixed = Mixed()
        let second = Self.task("Mail an Steuerberater", rank: 1)
        let all = mixed.all + [second]
        all.forEach(store.context.insert)

        let transcript = TranscriptCodec.transcript(of: all, now: Self.now, calendar: Self.calendar)
        let expected = ViewRules.now(in: all, now: Self.now, calendar: Self.calendar)

        #expect(transcript.nowCount == ViewRules.nowCount(in: all, now: Self.now, calendar: Self.calendar))
        #expect(transcript.nowCount == 5, "Knäuel, today, two lined up, one waiting")
        #expect(transcript.now.knaeuel == mixed.knaeuel.id)
        #expect(transcript.now.today == expected.today.map(\.id))
        #expect(transcript.now.lined == expected.lined.map(\.id))
        #expect(transcript.now.lined == [mixed.lined.id, second.id])
        #expect(transcript.now.waiting == expected.waiting.map(\.id))
        #expect(transcript.now.waiting == [mixed.waiting.id])
        #expect(transcript.generatedAt == Self.now)
    }

    @Test("Without a Knäuel the key stays out of Now (AC-2)")
    @MainActor func noKnaeuel() throws {
        let store = try TestStore()
        let lined = Self.task("Angebot schreiben", rank: 0)
        store.context.insert(lined)

        let transcript = TranscriptCodec.transcript(of: [lined], now: Self.now, calendar: Self.calendar)
        let now = try #require(try Self.json(transcript)["now"] as? [String: Any])

        #expect(transcript.now.knaeuel == nil)
        #expect(Set(now.keys) == ["today", "lined", "waiting"])
        #expect(transcript.nowCount == 1)
    }

    // MARK: AC-3, AC-10

    /// Version 1, word for word in `docs/reference/claude-abschrift-vertrag.md`.
    static let fixture = """
    {
      "generatedAt": "2026-03-12T09:00:00Z",
      "now": {
        "knaeuel": "6F1C2B0A-0000-4000-8000-000000000003",
        "lined": ["6F1C2B0A-0000-4000-8000-000000000002"],
        "today": ["6F1C2B0A-0000-4000-8000-000000000001"],
        "waiting": []
      },
      "nowCount": 3,
      "tasks": [
        {
          "contexts": [],
          "dueDate": "2026-03-12T17:00:00Z",
          "dueHasTime": true,
          "id": "6F1C2B0A-0000-4000-8000-000000000001",
          "isKnaeuel": false,
          "status": "active",
          "title": "Müll rausbringen"
        },
        {
          "contexts": ["Computer"],
          "dueHasTime": false,
          "id": "6F1C2B0A-0000-4000-8000-000000000002",
          "isKnaeuel": false,
          "nextRank": 0,
          "project": "Haus",
          "status": "active",
          "title": "Angebot schreiben"
        },
        {
          "contexts": [],
          "dueHasTime": false,
          "id": "6F1C2B0A-0000-4000-8000-000000000003",
          "isKnaeuel": true,
          "status": "active",
          "title": "Steuer machen"
        }
      ],
      "version": 1
    }
    """

    static let fixtureTranscript = Transcript(
        version: 1,
        generatedAt: ISO8601DateFormatter().date(from: "2026-03-12T09:00:00Z")!,
        nowCount: 3,
        now: Transcript.Now(
            knaeuel: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000003")!,
            today: [UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000001")!],
            lined: [UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000002")!],
            waiting: []
        ),
        tasks: [
            Transcript.Entry(
                id: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000001")!, title: "Müll rausbringen", status: .active,
                dueDate: ISO8601DateFormatter().date(from: "2026-03-12T17:00:00Z")!, dueHasTime: true, contexts: [],
                project: nil, nextRank: nil, isKnaeuel: false
            ),
            Transcript.Entry(
                id: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000002")!, title: "Angebot schreiben", status: .active,
                dueDate: nil, dueHasTime: false, contexts: ["Computer"], project: "Haus", nextRank: 0, isKnaeuel: false
            ),
            Transcript.Entry(
                id: UUID(uuidString: "6F1C2B0A-0000-4000-8000-000000000003")!, title: "Steuer machen", status: .active,
                dueDate: nil, dueHasTime: false, contexts: [], project: nil, nextRank: nil, isKnaeuel: true
            ),
        ]
    )

    @Test("Encoding meets the fixed example, decoding gives it back, dates are ISO 8601 (AC-3)")
    func roundTripAgainstFixture() throws {
        let encoded = try TranscriptCodec.encode(Self.fixtureTranscript)
        let fixture = Data(Self.fixture.utf8)

        #expect(try JSONEqual.same(encoded, fixture))
        #expect(try TranscriptCodec.decode(Transcript.self, from: fixture) == Self.fixtureTranscript)
        #expect(try TranscriptCodec.decode(Transcript.self, from: encoded) == Self.fixtureTranscript)
        let text = try #require(String(data: encoded, encoding: .utf8))
        #expect(text.contains("\"2026-03-12T17:00:00Z\""))
    }

    @Test("A transcript built from the store survives the round trip (AC-3)")
    @MainActor func roundTripFromStore() throws {
        let store = try TestStore()
        let mixed = Mixed()
        mixed.all.forEach(store.context.insert)

        let transcript = TranscriptCodec.transcript(of: mixed.all, now: Self.now, calendar: Self.calendar)
        let decoded = try TranscriptCodec.decode(Transcript.self, from: try TranscriptCodec.encode(transcript))

        #expect(decoded == transcript)
    }

    @Test("The contract document carries the transcript example word for word (AC-10)")
    func documentCarriesFixture() throws {
        let document = try ContractDocument.text()
        #expect(document.contains(Self.fixture), "docs/reference/claude-abschrift-vertrag.md must quote the fixture")
    }
}

/// Two JSON documents mean the same: same keys, same values, whatever the spacing and key order.
enum JSONEqual {
    static func same(_ a: Data, _ b: Data) throws -> Bool {
        let left = try JSONSerialization.jsonObject(with: a) as? NSObject
        let right = try JSONSerialization.jsonObject(with: b) as? NSObject
        return left != nil && left == right
    }
}

/// `docs/reference/claude-abschrift-vertrag.md`, read relative to this file. A missing file fails the test, never skips it.
enum ContractDocument {
    static func text() throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/reference/claude-abschrift-vertrag.md")
        return try String(contentsOf: url, encoding: .utf8)
    }
}
