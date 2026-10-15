import Foundation
import OSLog
import SwiftData

enum SiriCaptureError: Error, Equatable {
    enum Unsupported: Hashable, Sendable { case section, images }

    case emptyTitle
    case multipleLinks(Int)
    case unknownTag(String)
    /// A tag `prepare` found was deleted before `commit`.
    case tagRemoved
    case unmappableRepeat(Set<SiriRepeatMapping.Unmappable>)
    case placeNotFound
    case invalidPlace
    case unsupported(Unsupported)
}

/// Siri's reminder onto one new task (#25 Schnitt 1). Two steps so an error never leaves a task:
/// `prepare` checks every value and writes nothing, `commit` writes the task and saves. Knows no
/// Siri types; the intent translates them into `Input` (Schnitt 2). Every value Siri hands over is
/// the user's, with the reason "Siri" (Henning, 2026-10-06).
enum SiriCapture {
    struct Coordinate: Equatable, Sendable {
        let latitude: Double
        let longitude: Double
    }

    struct Place: Sendable {
        var name: String?
        var address: String?
        var coordinate: Coordinate?
        var event: TaskPlace.Event
    }

    /// Looks up an address; nil means no hit. Injected: the real service comes with Schnitt 2.
    typealias Geocode = @Sendable (String) async throws -> Coordinate?

    struct Input: Sendable {
        var title: String
        var notes: String?
        var due: Date?
        var dueHasTime = false
        var listName: String?
        var recurrence: Calendar.RecurrenceRule?
        var place: Place?
        var urls: [URL] = []
        var isFlagged: Bool?
        var tags: [String] = []
        /// Reminders' section and attached images: no place on a task (F5).
        var section: String?
        var imageCount = 0

        init(title: String) { self.title = title }
    }

    /// Sendable, so it can leave `prepare` across isolation: contexts travel as their ids.
    struct Prepared: Sendable {
        let rawText: String
        let title: String
        let due: Date?
        let dueHasTime: Bool
        let listName: String?
        let repeatRule: RepeatRule?
        let place: TaskPlace?
        let url: URL?
        let flagged: Bool
        let contextIDs: [PersistentIdentifier]
    }

    static let reason = "Siri"

    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Siri")

    /// Reads only; throws before anything is written.
    @MainActor
    static func prepare(_ input: Input, in context: ModelContext, geocode: Geocode) async throws -> Prepared {
        let title = input.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw SiriCaptureError.emptyTitle }
        if let section = input.section, !section.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SiriCaptureError.unsupported(.section)
        }
        guard input.imageCount == 0 else { throw SiriCaptureError.unsupported(.images) }
        let fields = try resolveFields(input, in: context)
        var rule: RepeatRule?
        if let recurrence = input.recurrence {
            switch SiriRepeatMapping.map(recurrence) {
            case .rule(let mapped): rule = mapped
            case .unmappable(let problems): throw SiriCaptureError.unmappableRepeat(problems)
            }
        }
        var place: TaskPlace?
        if let siriPlace = input.place { place = try await resolvePlace(siriPlace, geocode: geocode) }
        let notes = input.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let list = input.listName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Prepared(
            rawText: notes.isEmpty ? title : title + "\n" + notes, title: title,
            due: input.due, dueHasTime: input.due != nil && input.dueHasTime,
            listName: list.isEmpty ? nil : list, repeatRule: rule, place: place,
            url: fields.url, flagged: fields.flagged, contextIDs: fields.contexts.map(\.persistentModelID)
        )
    }

    @MainActor
    private static func resolveFields(_ input: Input, in context: ModelContext) throws -> SiriFields.Resolved {
        do {
            return try SiriFields.resolve(
                SiriFields(urls: input.urls, isFlagged: input.isFlagged, tags: Set(input.tags)), in: context
            )
        } catch SiriFieldsError.multipleLinks(let count) {
            throw SiriCaptureError.multipleLinks(count)
        } catch SiriFieldsError.unknownTag(let name) {
            throw SiriCaptureError.unknownTag(name)
        }
    }

    /// A coordinate is taken as is; only an address without one is looked up, once.
    private static func resolvePlace(_ place: Place, geocode: Geocode) async throws -> TaskPlace {
        let address = place.address?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var coordinate = place.coordinate
        if coordinate == nil, !address.isEmpty {
            // No network or a failing lookup is the same answer to Siri: place not found (spec, risk).
            do { coordinate = try await geocode(address) } catch { throw SiriCaptureError.placeNotFound }
        }
        guard let coordinate else { throw SiriCaptureError.placeNotFound }
        let name = place.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let resolved = TaskPlace(
            name: name.isEmpty ? address : name,
            latitude: coordinate.latitude, longitude: coordinate.longitude, event: place.event
        ) else { throw SiriCaptureError.invalidPlace }
        return resolved
    }

    /// Writes the task: save, title, due date, project, repeat rule, place, link/flag/tags, save.
    /// `CaptureService.save` saves at once, so on any later error the task is taken out again and
    /// what this commit inserted (a new project, revisions) is discarded: no task is left behind.
    /// The context may be the app's: an object the caller inserted before is left alone. If
    /// `CaptureService.save` itself fails, the caller's unsaved inserts stay unsaved. Once it has
    /// succeeded it has saved the whole context, the caller's inserts with it; those are persisted
    /// from then on and stay.
    @MainActor
    @discardableResult
    static func commit(_ prepared: Prepared, in context: ModelContext, now: Date = Date()) throws -> TaskItem {
        let callersInserts = Set(context.insertedModelsArray.map(\.persistentModelID))
        var saved: TaskItem?
        do {
            let task = try CaptureService.save(prepared.rawText, via: .siri, in: context)
            saved = task
            try write(prepared, on: task, in: context, now: now)
            try context.save()
            return task
        } catch {
            discard(saved, keeping: callersInserts, in: context)
            throw error
        }
    }

    /// Not `rollback()`: with inserted models already linked to the task, SwiftData traps on the next
    /// save. Deleting an unsaved insert just drops it; the saved task is deleted and cascades. Only a
    /// saved task needs a save to leave the store; without one nothing is saved, so the caller's
    /// unsaved changes are not written behind its back. A failing clean-up save is logged, never
    /// thrown: the caller gets the error that made commit fail.
    @MainActor
    private static func discard(
        _ saved: TaskItem?, keeping callersInserts: Set<PersistentIdentifier>, in context: ModelContext
    ) {
        for model in context.insertedModelsArray where !callersInserts.contains(model.persistentModelID) {
            context.delete(model)
        }
        guard let saved else { return }
        context.delete(saved)
        do {
            try context.save()
        } catch {
            logger.error("Siri capture clean-up could not save: \(String(describing: error), privacy: .public)")
        }
    }

    @MainActor
    private static func write(_ prepared: Prepared, on task: TaskItem, in context: ModelContext, now: Date) throws {
        // F1: the title from Siri's title alone; the rule would pull the note in.
        task.title = TitleRule.title(from: prepared.title, reference: task.capturedAt)
        var written: [Revision?] = []
        if let due = prepared.due {
            written.append(RevisionService.set(
                .dueDate, to: due.ISO8601Format(), on: task, contexts: [], projects: [], now: now
            ))
            task.dueHasTime = prepared.dueHasTime
        }
        if let list = prepared.listName {
            let project = try project(named: list, in: context)
            written.append(RevisionService.set(
                .project, to: project.name, on: task, contexts: [], projects: [project], now: now
            ))
        }
        if let rule = prepared.repeatRule { written.append(SiriRepeatMapping.apply(rule, to: task, now: now)) }
        if let place = prepared.place { written.append(PlaceEditing.set(place, on: task, now: now)) }
        for revision in written.compactMap({ $0 }) { revision.reason = reason }
        let contexts = try contexts(prepared.contextIDs, in: context)
        SiriFields.apply(
            SiriFields.Resolved(url: prepared.url, flagged: prepared.flagged, contexts: contexts), to: task, now: now
        )
    }

    /// The tags `prepare` found, read from the store. `model(for:)` would hand back a deleted one as
    /// an invalid instance that traps on first access, so they are fetched; a missing one throws.
    @MainActor
    private static func contexts(_ ids: [PersistentIdentifier], in context: ModelContext) throws -> [TaskContext] {
        guard !ids.isEmpty else { return [] }
        let byID = Dictionary(
            try context.fetch(FetchDescriptor<TaskContext>()).map { ($0.persistentModelID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return try ids.map { id in
            guard let found = byID[id] else { throw SiriCaptureError.tagRemoved }
            return found
        }
    }

    /// F2: the project of that name, or a new one.
    @MainActor
    private static func project(named name: String, in context: ModelContext) throws -> Project {
        if let existing = try CatalogService.project(named: name, in: context) { return existing }
        let all = try context.fetch(FetchDescriptor<Project>())
        return try CatalogService.addProject(named: name, in: context, existing: all)
    }
}
