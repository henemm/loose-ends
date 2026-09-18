#!/usr/bin/env swift
//
// Exports the real FocusBlox task history into the JSON shape described in
// docs/project/02-datenmodell-und-ansichten.md ("Lernkorpus aus FocusBlox").
// Reads the SwiftData sqlite store directly (read-only) so this script has no
// dependency on the FocusBlox Xcode project.
//
// Usage: swift scripts/export-focusblox-corpus.swift [--store <path>] [--out <path>]
//
// The output contains real personal task titles — never commit it. It is written
// to docs/reference/focusblox-corpus.json by default, which is gitignored.

import Foundation
import SQLite3

// MARK: - CLI arguments

func argValue(_ flag: String, default defaultValue: String) -> String {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return defaultValue }
    return args[index + 1]
}

let defaultStorePath = NSString(string:
    "~/Library/Group Containers/group.com.henning.focusblox/Library/Application Support/default.store"
).expandingTildeInPath
let storePath = argValue("--store", default: defaultStorePath)
let outPath = argValue("--out", default: "docs/reference/focusblox-corpus.json")

// MARK: - Output shape (matches the mapping table in 02-datenmodell-und-ansichten.md)

struct RepeatRuleExport: Codable {
    var frequency: String
    var interval: Int
    var weekdays: [Int]?
}

struct CorpusTask: Codable {
    var id: String
    var rawText: String
    var title: String
    var contexts: [String]
    var importance: String?
    var urgency: String?
    var durationBucket: String?
    var energy: String?
    var dueDate: Date?
    var capturedAt: Date
    var completedAt: Date?
    var blockedBy: String?
    var isCompleted: Bool
    var repeatRule: RepeatRuleExport?
}

// MARK: - Blob decoding (SwiftData stores [String]/[Int] as NSKeyedArchiver blobs)

func decodeStringArray(_ data: Data?) -> [String] {
    guard let data, let array = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSString.self, from: data) else {
        return []
    }
    return array as [String]
}

func decodeIntArray(_ data: Data?) -> [Int]? {
    guard let data, let array = try? NSKeyedUnarchiver.unarchivedArrayOfObjects(ofClass: NSNumber.self, from: data) else {
        return nil
    }
    return array.map { $0.intValue }
}

// MARK: - Field mapping

func mapImportance(_ value: Int?) -> String? {
    switch value {
    case 1: return "low"
    case 2: return "medium"
    case 3: return "high"
    default: return nil
    }
}

func mapUrgency(_ value: String?) -> String? {
    switch value {
    case "urgent": return "high"
    case "not_urgent": return "low"
    default: return nil
    }
}

func mapEnergy(_ value: String?) -> String? {
    switch value {
    case "high", "low": return value
    default: return nil
    }
}

func mapDurationBucket(_ minutes: Int?) -> String? {
    guard let minutes else { return nil }
    if minutes <= 5 { return "minutes5" }
    if minutes <= 15 { return "minutes15" }
    if minutes <= 30 { return "minutes30" }
    if minutes <= 60 { return "hour1" }
    return "hours2plus"
}

/// FocusBlox weekdays: 1=Mon...7=Sun. Loose Ends (Calendar numbering): 1=Sun...7=Sat.
func mapWeekdays(_ focusBloxDays: [Int]?) -> [Int]? {
    guard let focusBloxDays, !focusBloxDays.isEmpty else { return nil }
    return focusBloxDays.map { $0 == 7 ? 1 : $0 + 1 }
}

/// "custom" encodes its base frequency in recurrenceMonthDay (1001=daily, 1002=weekly, 1003=monthly, 1004=yearly) —
/// see FocusBlox's RecurrenceService.nextDueDate(pattern:).
func mapRepeatRule(pattern: String, weekdays: [Int]?, monthDay: Int?, interval: Int?) -> RepeatRuleExport? {
    let step = max(interval ?? 1, 1)
    switch pattern {
    case "daily":
        return RepeatRuleExport(frequency: "daily", interval: step, weekdays: nil)
    case "weekly":
        return RepeatRuleExport(frequency: "weekly", interval: 1, weekdays: mapWeekdays(weekdays))
    case "biweekly":
        return RepeatRuleExport(frequency: "weekly", interval: 2, weekdays: mapWeekdays(weekdays))
    case "monthly":
        return RepeatRuleExport(frequency: "monthly", interval: step, weekdays: nil)
    case "yearly":
        return RepeatRuleExport(frequency: "yearly", interval: step, weekdays: nil)
    case "custom":
        switch monthDay {
        case 1001: return RepeatRuleExport(frequency: "daily", interval: step, weekdays: nil)
        case 1002: return RepeatRuleExport(frequency: "weekly", interval: step, weekdays: mapWeekdays(weekdays))
        case 1003: return RepeatRuleExport(frequency: "monthly", interval: step, weekdays: nil)
        case 1004: return RepeatRuleExport(frequency: "yearly", interval: step, weekdays: nil)
        default: return nil
        }
    default:
        return nil // "none" and anything unrecognized
    }
}

// MARK: - Read the store

func openStore(at path: String) -> OpaquePointer {
    var db: OpaquePointer?
    guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
        FileHandle.standardError.write("Could not open store at \(path)\n".data(using: .utf8)!)
        exit(1)
    }
    return db
}

let db = openStore(at: storePath)
let sql = """
    SELECT ZUUID, ZTITLE, ZTAGS, ZIMPORTANCE, ZURGENCY, ZESTIMATEDDURATION, ZAIENERGYLEVEL,
           ZDUEDATE, ZCREATEDAT, ZCOMPLETEDAT, ZBLOCKERTASKID, ZISCOMPLETED,
           ZRECURRENCEPATTERN, ZRECURRENCEWEEKDAYS, ZRECURRENCEMONTHDAY, ZRECURRENCEINTERVAL
    FROM ZLOCALTASK
    """

var stmt: OpaquePointer?
guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
    FileHandle.standardError.write("Query failed: \(String(cString: sqlite3_errmsg(db)))\n".data(using: .utf8)!)
    exit(1)
}
defer { sqlite3_finalize(stmt) }

func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
    sqlite3_column_text(stmt, index).map { String(cString: $0) }
}

func columnBlob(_ stmt: OpaquePointer?, _ index: Int32) -> Data? {
    guard let ptr = sqlite3_column_blob(stmt, index) else { return nil }
    let length = sqlite3_column_bytes(stmt, index)
    return Data(bytes: ptr, count: Int(length))
}

func columnDate(_ stmt: OpaquePointer?, _ index: Int32) -> Date? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
    return Date(timeIntervalSinceReferenceDate: sqlite3_column_double(stmt, index))
}

func columnOptionalInt(_ stmt: OpaquePointer?, _ index: Int32) -> Int? {
    guard sqlite3_column_type(stmt, index) != SQLITE_NULL else { return nil }
    return Int(sqlite3_column_int64(stmt, index))
}

var tasks: [CorpusTask] = []
while sqlite3_step(stmt) == SQLITE_ROW {
    let uuidData = columnBlob(stmt, 0) ?? Data()
    let uuidString = uuidData.count == 16
        ? UUID(uuid: uuidData.withUnsafeBytes { $0.load(as: uuid_t.self) }).uuidString
        : UUID().uuidString
    let title = columnText(stmt, 1) ?? ""
    let pattern = columnText(stmt, 12) ?? "none"

    let task = CorpusTask(
        id: uuidString,
        rawText: title,
        title: title,
        contexts: decodeStringArray(columnBlob(stmt, 2)),
        importance: mapImportance(columnOptionalInt(stmt, 3)),
        urgency: mapUrgency(columnText(stmt, 4)),
        durationBucket: mapDurationBucket(columnOptionalInt(stmt, 5)),
        energy: mapEnergy(columnText(stmt, 6)),
        dueDate: columnDate(stmt, 7),
        capturedAt: columnDate(stmt, 8) ?? Date(),
        completedAt: columnDate(stmt, 9),
        blockedBy: columnText(stmt, 10),
        isCompleted: columnOptionalInt(stmt, 11) == 1,
        repeatRule: mapRepeatRule(
            pattern: pattern,
            weekdays: decodeIntArray(columnBlob(stmt, 13)),
            monthDay: columnOptionalInt(stmt, 14),
            interval: columnOptionalInt(stmt, 15)
        )
    )
    tasks.append(task)
}
sqlite3_close(db)

// MARK: - Write JSON

let encoder = JSONEncoder()
encoder.dateEncodingStrategy = .iso8601
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
let jsonData = try encoder.encode(tasks)

let outURL = URL(fileURLWithPath: outPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try jsonData.write(to: outURL)

print("Exported \(tasks.count) tasks to \(outPath)")
