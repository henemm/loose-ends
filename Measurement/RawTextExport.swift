import Foundation
import SQLite3

/// #88 Schnitt B1b: turns the app's SwiftData store into `docs/reference/loose-ends-rawtexts.json`, the file
/// `RawSentenceColumn` reads. Pure translation: the store is opened read only, the user's own revisions on title
/// and duration are the truth, nothing is measured here. No `import LooseEnds` and nothing from `Shared/`: the
/// script `scripts/export-loose-ends-rawtexts.swift` builds this file alone with `swiftc`. Messages carry kinds,
/// paths and counts, never a sentence.
enum RawTextExport {
    /// `FieldSource.user`, `RevisedField.title`, `RevisedField.duration`; the tests seed through the model with
    /// those enums, so a renamed case turns them red.
    static let userAuthor = "user"
    static let titleField = "title"
    static let durationField = "duration"

    /// Table and column names SwiftData gives `TaskItem` and `Revision` (read off a throwaway store).
    static let taskTable = "ZTASKITEM"
    static let taskColumns = ["Z_PK", "ZRAWTEXT", "ZCAPTUREDAT", "ZTITLE"]
    static let revisionTable = "ZREVISION"
    static let revisionColumns = ["ZTASK", "ZFIELDRAW", "ZOLDVALUE", "ZNEWVALUE", "ZAUTHORRAW", "ZCREATEDAT"]

    /// One line of the output; the same keys as `RawSentenceColumn.Sentence`, without `lang`.
    struct Row: Encodable, Equatable, Sendable {
        var id: String
        var rawText: String
        var titleBefore: String
        var titleUser: String?
        var durationUser: String?
        var capturedAt: String
    }

    enum Failure: Error, Equatable, Sendable {
        case storeMissing(path: String)
        case notADatabase(path: String)
        case tableMissing(table: String, path: String)
        case columnMissing(table: String, column: String, path: String)
        case readFailed(code: Int32, path: String)
        case noTasks(path: String)
        case targetRefused(path: String)
        case writeFailed(path: String)
        case scriptPathRelative(path: String)

        /// German, kind and path only.
        var message: String {
            switch self {
            case .storeMissing(let path): "Speicher fehlt: \(path)"
            case .notADatabase(let path): "Keine SQLite-Datenbank: \(path)"
            case .tableMissing(let table, let path): "Tabelle \(table) fehlt in \(path)"
            case .columnMissing(let table, let column, let path): "Spalte \(column) fehlt in Tabelle \(table) von \(path)"
            case .readFailed(let code, let path) where code == SQLITE_CANTOPEN:
                "Lesen fehlgeschlagen (SQLite-Code \(code), Speicher ohne Nebendateien -wal/-shm; App laufen lassen): \(path)"
            case .readFailed(let code, let path): "Lesen fehlgeschlagen (SQLite-Code \(code)): \(path)"
            case .noTasks(let path): "Keine Aufgaben im Speicher: \(path)"
            case .targetRefused(let path): "Ziel verweigert, nur docs/reference/ oder außerhalb des Repos: \(path)"
            case .writeFailed(let path): "Schreiben fehlgeschlagen: \(path)"
            case .scriptPathRelative(let path):
                "Skriptpfad relativ, Repo-Stamm unbestimmt; mit absolutem Skriptpfad bauen (\"$PWD/scripts/…\"): \(path)"
            }
        }
    }

    // MARK: - Reading

    private struct StoredTask {
        var key: Int64
        var rawText: String
        var capturedAt: Double
        var title: String?
    }

    private struct Edit {
        var task: Int64
        var field: String
        var old: String?
        var new: String?
        var createdAt: Double
        var order: Int
    }

    /// Opens the store read only and returns one row per task, ordered by capture time, ids "1", "2", ….
    static func sentences(fromStoreAt store: URL) throws -> [Row] {
        guard FileManager.default.fileExists(atPath: store.path) else { throw Failure.storeMissing(path: store.path) }
        let database = try Database(url: store)
        defer { database.close() }
        try database.requireColumns(taskColumns, in: taskTable)
        try database.requireColumns(revisionColumns, in: revisionTable)
        let tasks = try readTasks(database)
        let edits = try readUserEdits(database)
        let ordered = tasks.sorted { ($0.capturedAt, $0.key) < ($1.capturedAt, $1.key) }
        return ordered.enumerated().map { index, task in
            row(for: task, number: index + 1, edits: edits[task.key] ?? [])
        }
    }

    private static func readTasks(_ database: Database) throws -> [StoredTask] {
        try database.query("SELECT Z_PK, ZRAWTEXT, ZCAPTUREDAT, ZTITLE FROM \(taskTable)") { statement in
            StoredTask(key: sqlite3_column_int64(statement, 0), rawText: Database.text(statement, 1) ?? "",
                 capturedAt: sqlite3_column_double(statement, 2), title: Database.text(statement, 3))
        }
    }

    /// The user's revisions on title and duration, grouped by task and sorted by `createdAt` (ties: row order).
    private static func readUserEdits(_ database: Database) throws -> [Int64: [Edit]] {
        let sql = "SELECT ZTASK, ZFIELDRAW, ZOLDVALUE, ZNEWVALUE, ZAUTHORRAW, ZCREATEDAT FROM \(revisionTable) ORDER BY Z_PK"
        var position = 0
        let all: [Edit?] = try database.query(sql) { statement in
            position += 1
            guard Database.text(statement, 4) == userAuthor, sqlite3_column_type(statement, 0) != SQLITE_NULL else { return nil }
            return Edit(task: sqlite3_column_int64(statement, 0), field: Database.text(statement, 1) ?? "",
                        old: Database.text(statement, 2), new: Database.text(statement, 3),
                        createdAt: sqlite3_column_double(statement, 5), order: position)
        }
        let grouped = Dictionary(grouping: all.compactMap { $0 }, by: \.task)
        return grouped.mapValues { $0.sorted { ($0.createdAt, $0.order) < ($1.createdAt, $1.order) } }
    }

    private static func row(for task: StoredTask, number: Int, edits: [Edit]) -> Row {
        let titles = edits.filter { $0.field == titleField }
        let durations = edits.filter { $0.field == durationField }
        let before = titles.first.map { $0.old ?? "" } ?? (task.title ?? "")
        let duration = durations.last?.new.flatMap { $0.isEmpty ? nil : $0 }
        let captured = Date(timeIntervalSinceReferenceDate: task.capturedAt).formatted(.iso8601)
        return Row(id: String(number), rawText: task.rawText, titleBefore: before,
                   titleUser: titles.last.map { $0.new ?? "" }, durationUser: duration, capturedAt: captured)
    }

    // MARK: - Writing

    static func encode(_ rows: [Row]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(rows)
    }

    /// The repo root from the script's own `#filePath`: two levels up (file -> scripts -> root). A relative
    /// `#filePath` (script built with a relative path) would be resolved against the working directory at run time,
    /// and the guard would protect whatever folder the script is started from; so it is refused (#88 F001, round 2).
    static func root(fromScriptPath path: String) throws -> URL {
        guard path.hasPrefix("/") else { throw Failure.scriptPathRelative(path: path) }
        return URL(fileURLWithPath: path).deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Allowed: below `root/docs/reference/`, or anywhere outside `root`. Both paths are resolved through the
    /// file system first (symlinks anywhere, `root` itself included, and `..` after a symlink), then compared.
    /// A target that resolves to `docs/reference` itself (e.g. `docs/reference/missing/..`) is not below it: refused.
    static func checkTarget(_ out: URL, root: URL) throws {
        let target = physical(out.path, keepingLast: true)
        let base = physical(root.path, keepingLast: false)
        let reference = base + ["docs", "reference"]
        let insideRoot = target.starts(with: base)
        let insideReference = target.count > reference.count && target.starts(with: reference)
        if insideRoot && !insideReference { throw Failure.targetRefused(path: out.path) }
    }

    /// The longest existing prefix of `path` resolved by `realpath` (every symlink, `..` taken physically), the
    /// components that do not exist yet appended (`.` and `..` taken lexically, they cannot be symlinks). No
    /// `standardizedFileURL`: it drops `/private` only from paths that exist, so `/tmp` would get two spellings.
    /// With `keepingLast` a plain last component (not `.` or `..`) is kept as is: the atomic write replaces a file
    /// there, never writes through it. The path is split into components once and every loop step moves one of them
    /// from `existing` to `rest`, so the loop ends at "/" at the latest (#88 F002: `deletingLastPathComponent` on a
    /// trailing `..` appended `/..` instead of shortening, and the loop never ended).
    private static func physical(_ path: String, keepingLast: Bool) -> [String] {
        var existing = URL(fileURLWithPath: path).pathComponents
        var rest: [String] = []
        if keepingLast, existing.count > 1, let last = existing.last, last != ".", last != ".." {
            rest.append(existing.removeLast())
        }
        while existing.count > 1 {
            if let resolved = resolved(NSString.path(withComponents: existing)) {
                return appendingLexically(rest, to: resolved)
            }
            rest.insert(existing.removeLast(), at: 0)
        }
        return appendingLexically(rest, to: ["/"])
    }

    /// `realpath` as components; nil if the path does not resolve (missing, not a folder, no access).
    private static func resolved(_ path: String) -> [String]? {
        guard let real = realpath(path, nil) else { return nil }
        defer { free(real) }
        return URL(fileURLWithPath: String(cString: real)).pathComponents
    }

    private static func appendingLexically(_ rest: [String], to base: [String]) -> [String] {
        var components = base
        for part in rest where part != "." && part != "" {
            if part == ".." { if components.count > 1 { components.removeLast() } } else { components.append(part) }
        }
        return components
    }

    /// Counts only: "N Sätze, davon M mit Titelkorrektur, K mit Dauer".
    static func summary(_ rows: [Row]) -> String {
        let titles = rows.filter { row in
            guard let user = row.titleUser, !user.isEmpty else { return false }
            return user != row.titleBefore
        }.count
        let durations = rows.filter { $0.durationUser != nil }.count
        return "\(rows.count) Sätze, davon \(titles) mit Titelkorrektur, \(durations) mit Dauer"
    }

    /// Checks the target, reads, and writes the file only at the end, atomically; on any failure the target is
    /// left as it was. Returns the summary.
    static func run(store: URL, out: URL, root: URL) throws -> String {
        try checkTarget(out, root: root)
        let rows = try sentences(fromStoreAt: store)
        guard !rows.isEmpty else { throw Failure.noTasks(path: store.path) }
        let data = try encode(rows)
        do {
            try data.write(to: out, options: .atomic)
        } catch {
            throw Failure.writeFailed(path: out.path)
        }
        return summary(rows)
    }
}

/// A read-only SQLite connection, closed by its owner.
private final class Database {
    private let handle: OpaquePointer
    private let path: String

    init(url: URL) throws {
        var pointer: OpaquePointer?
        let code = sqlite3_open_v2(url.path, &pointer, SQLITE_OPEN_READONLY, nil)
        guard code == SQLITE_OK, let pointer else {
            sqlite3_close(pointer)
            throw Database.failure(code, path: url.path)
        }
        handle = pointer
        path = url.path
        // Another connection (the app, or a container that is just closing) may hold a lock for a moment.
        sqlite3_busy_timeout(pointer, 5_000)
    }

    func close() { sqlite3_close(handle) }

    static func failure(_ code: Int32, path: String) -> RawTextExport.Failure {
        code == SQLITE_NOTADB ? .notADatabase(path: path) : .readFailed(code: code, path: path)
    }

    static func text(_ statement: OpaquePointer, _ column: Int32) -> String? {
        sqlite3_column_text(statement, column).map { String(cString: $0) }
    }

    /// Runs `sql` and maps every row; an unreadable file surfaces here as `notADatabase`.
    func query<T>(_ sql: String, _ map: (OpaquePointer) throws -> T) throws -> [T] {
        var statement: OpaquePointer?
        let prepared = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        guard prepared == SQLITE_OK, let statement else { throw Database.failure(prepared, path: path) }
        var result: [T] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE { return result }
            guard step == SQLITE_ROW else { throw Database.failure(step, path: path) }
            result.append(try map(statement))
        }
    }

    /// `PRAGMA table_info` names the columns; no row means the table is missing.
    func requireColumns(_ columns: [String], in table: String) throws {
        let present = Set(try query("PRAGMA table_info(\(table))") { Database.text($0, 1) ?? "" })
        guard !present.isEmpty else { throw RawTextExport.Failure.tableMissing(table: table, path: path) }
        for column in columns where !present.contains(column) {
            throw RawTextExport.Failure.columnMissing(table: table, column: column, path: path)
        }
    }
}
