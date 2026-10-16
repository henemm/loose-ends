// Siri over Apple's reminders app schema (#25 Schnitt 2a): the entities and enums the schema requires.
// Read-only: writing goes through `SiriCapture` only (the intent follows in Schnitt 2b). The domain exists
// from iOS/macOS 27 and not on watchOS; this folder compiles into the app target only (`project.yml`).
import AppIntents
import Foundation
import GeoToolbox
import SwiftData

@AppEnum(schema: .reminders.listType)
enum ListKind: String, AppEnum {
    case standard
    static let caseDisplayRepresentations: [ListKind: DisplayRepresentation] = [.standard: "Standard"]
}

/// A list is a project (ADR-8); tasks without a project live in the virtual inbox "Loose Ends".
@AppEntity(schema: .reminders.list)
struct ListEntity: AppEntity {
    static let inboxID = "inbox"
    static var inbox: ListEntity { ListEntity(id: inboxID, name: "Loose Ends") }
    static let defaultQuery = ListQuery()

    let id: String
    var name: String
    var type: ListKind
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: String, name: String) {
        self.id = id
        self.name = name
        self.type = .standard
    }

    init(project: Project) {
        self.init(id: project.id.uuidString, name: project.name)
    }

    /// The inbox and any project by id, archived ones included; unknown ids are left out.
    @MainActor
    static func entities(for ids: [String], in context: ModelContext) throws -> [ListEntity] {
        let projectIDs = ids.compactMap(UUID.init(uuidString:))
        let projects = try context.fetch(FetchDescriptor<Project>(predicate: #Predicate { projectIDs.contains($0.id) }))
        let byID = Dictionary(projects.map { ($0.id.uuidString, ListEntity(project: $0)) }) { first, _ in first }
        return ids.compactMap { $0 == inboxID ? inbox : byID[$0] }
    }

    /// The inbox first, then the projects that are not archived, by sort order.
    @MainActor
    static func suggested(in context: ModelContext) throws -> [ListEntity] {
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.archivedAt == nil }, sortBy: [SortDescriptor(\.sortOrder)]
        )
        return [inbox] + (try context.fetch(descriptor)).map(ListEntity.init(project:))
    }

    /// The suggested lists whose name contains `string`, case- and accent-insensitive (like `nameKey`).
    @MainActor
    static func matching(_ string: String, in context: ModelContext) throws -> [ListEntity] {
        let key = CatalogService.nameKey(string)
        return try suggested(in: context).filter { CatalogService.nameKey($0.name).contains(key) }
    }

    /// A string query lets Siri resolve a spoken list name ("in Garten").
    struct ListQuery: EntityStringQuery {
        func entities(matching string: String) async throws -> [ListEntity] {
            try await MainActor.run {
                let container = try ModelContainerFactory.make()
                return try ListEntity.matching(string, in: ModelContext(container))
            }
        }

        func entities(for identifiers: [String]) async throws -> [ListEntity] {
            try await MainActor.run {
                let container = try ModelContainerFactory.make()
                return try ListEntity.entities(for: identifiers, in: ModelContext(container))
            }
        }

        func suggestedEntities() async throws -> [ListEntity] {
            try await MainActor.run {
                let container = try ModelContainerFactory.make()
                return try ListEntity.suggested(in: ModelContext(container))
            }
        }
    }
}

/// Read-only view of a task for Siri.
@AppEntity(schema: .reminders.reminder)
struct ReminderEntity: AppEntity {
    static let defaultQuery = ReminderQuery()

    let id: UUID
    var title: String
    var list: ListEntity
    var isCompleted: Bool
    var creationDate: Date?
    var dueDate: DateComponents?
    // Required by the schema, not read in Schnitt 2a (Schnitt 3 fills them): always empty.
    var note: AttributedString?
    var tags: Set<String>
    var urls: [URL]
    var recurrence: Calendar.RecurrenceRule?
    var isFlagged: Bool?
    var completionDate: Date?
    var locationTrigger: LocationTriggerEntity?
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }

    init(task: TaskItem) {
        self.id = task.id
        self.title = task.displayTitle
        self.list = task.project.map(ListEntity.init(project:)) ?? .inbox
        self.isCompleted = task.status == .done
        self.creationDate = task.capturedAt
        let parts: Set<Calendar.Component> = task.dueHasTime
            ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day]
        self.dueDate = task.dueDate.map { Calendar.current.dateComponents(parts, from: $0) }
        self.tags = []
        self.urls = []
    }

    /// Tasks by id in every status; unknown ids are left out.
    @MainActor
    static func entities(for ids: [UUID], in context: ModelContext) throws -> [ReminderEntity] {
        let tasks = try context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { ids.contains($0.id) }))
        return tasks.map(ReminderEntity.init(task:))
    }

    struct ReminderQuery: EntityQuery {
        func entities(for identifiers: [UUID]) async throws -> [ReminderEntity] {
            try await MainActor.run {
                let container = try ModelContainerFactory.make()
                return try ReminderEntity.entities(for: identifiers, in: ModelContext(container))
            }
        }
    }
}

// Required by the schema. Loose Ends keeps neither location triggers nor sections as their own records,
// so the queries resolve nothing; Siri hands its values over with the reminder (`ReminderTranslation`).
@AppEnum(schema: .reminders.locationTriggerEvent)
enum LocationTriggerEvent: String, AppEnum {
    case arrive, depart
    static let caseDisplayRepresentations: [LocationTriggerEvent: DisplayRepresentation] = [
        .arrive: "Arrive", .depart: "Depart",
    ]
}

@AppEntity(schema: .reminders.locationTrigger)
struct LocationTriggerEntity: AppEntity {
    static let defaultQuery = LocationTriggerQuery()
    let id: String
    var place: PlaceDescriptor
    var event: LocationTriggerEvent
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(place.commonName ?? id)") }

    init(id: String, place: PlaceDescriptor, event: LocationTriggerEvent) {
        self.id = id
        self.place = place
        self.event = event
    }

    struct LocationTriggerQuery: EntityStringQuery {
        func entities(for identifiers: [String]) async throws -> [LocationTriggerEntity] { [] }
        func entities(matching string: String) async throws -> [LocationTriggerEntity] { [] }
    }
}

@AppEntity(schema: .reminders.section)
struct SectionEntity: AppEntity {
    static let defaultQuery = SectionQuery()
    let id: String
    var name: String
    var list: ListEntity
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(id: String, name: String, list: ListEntity) {
        self.id = id
        self.name = name
        self.list = list
    }

    struct SectionQuery: EntityStringQuery {
        func entities(for identifiers: [String]) async throws -> [SectionEntity] { [] }
        func entities(matching string: String) async throws -> [SectionEntity] { [] }
    }
}
