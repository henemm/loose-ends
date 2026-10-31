import Foundation

/// What Claude reads (#613, Weg B): every task not completed and "Now" as the device computes it, so
/// Claude never shows another number than the app (#637). Version 1 of the contract in
/// `docs/reference/claude-abschrift-vertrag.md`. No raw text, note, attachment or revision leaves the device.
struct Transcript: Codable, Equatable, Sendable {
    var version: Int
    var generatedAt: Date
    var nowCount: Int
    var now: Now
    var tasks: [Entry]

    /// `ViewRules.now` as task ids, in its order; the Knäuel only while there is one.
    struct Now: Codable, Equatable, Sendable {
        var knaeuel: UUID?
        var today: [UUID]
        var lined: [UUID]
        var waiting: [UUID]
    }

    /// One task, only the fields the contract names.
    struct Entry: Codable, Equatable, Sendable {
        var id: UUID
        var title: String
        var status: TaskStatus
        var dueDate: Date?
        var dueHasTime: Bool
        var contexts: [String]
        var project: String?
        var nextRank: Double?
        var isKnaeuel: Bool
    }
}

/// Builds the transcript from the store's tasks and moves the contract's types through JSON. Pure:
/// no network, no file, nothing written to the store.
enum TranscriptCodec {
    static let version = 1

    static func transcript(of all: [TaskItem], now: Date, calendar: Calendar) -> Transcript {
        let rows = ViewRules.now(in: all, now: now, calendar: calendar)
        return Transcript(
            version: version,
            generatedAt: now,
            nowCount: rows.count,
            now: Transcript.Now(
                knaeuel: rows.knaeuel?.id,
                today: rows.today.map(\.id),
                lined: rows.lined.map(\.id),
                waiting: rows.waiting.map(\.id)
            ),
            tasks: all.filter { $0.status != .done && $0.status != .removed }.map(entry)
        )
    }

    static func entry(_ task: TaskItem) -> Transcript.Entry {
        Transcript.Entry(
            id: task.id,
            title: task.title ?? "",
            status: task.status,
            dueDate: task.dueDate,
            dueHasTime: task.dueHasTime,
            // To-many has no order in SwiftData; sorted, so two devices write the same list.
            contexts: (task.contexts ?? []).map(\.name).sorted(),
            project: task.project?.name,
            nextRank: task.nextRank,
            isKnaeuel: task.isKnaeuel
        )
    }

    /// ISO 8601 dates in whole seconds, like `FieldCodec`; keys sorted so the text is stable.
    static func encode<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
}
