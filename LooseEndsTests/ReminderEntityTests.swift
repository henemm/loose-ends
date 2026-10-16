import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Siri's read-only view of lists and tasks (#25 Schnitt 2a). Every test holds its own `TestStore`.
@Suite("Reminders-Entitäten (#25 Schnitt 2a)")
@MainActor
struct ReminderEntityTests {
    private let calendar = Calendar.current

    // MARK: AC-8

    @Test("Erinnerung aus Aufgabe: Kennung, Titel, Liste, Fälligkeit mit Uhrzeit (AC-8)")
    func entityFromTask() throws {
        let store = try TestStore()
        let project = Project(name: "Büro")
        store.context.insert(project)
        let task = TaskItem(rawText: "Steuer abgeben")
        task.title = "Steuer abgeben"
        task.project = project
        task.dueDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 20, hour: 9, minute: 30))
        task.dueHasTime = true
        store.context.insert(task)
        try store.context.save()

        let entity = ReminderEntity(task: task)
        #expect(entity.id == task.id)
        #expect(entity.title == "Steuer abgeben")
        #expect(entity.list.name == "Büro")
        #expect(entity.list.id == project.id.uuidString)
        #expect(entity.isCompleted == false)
        #expect(entity.dueDate?.year == 2026)
        #expect(entity.dueDate?.month == 10)
        #expect(entity.dueDate?.day == 20)
        #expect(entity.dueDate?.hour == 9)
        #expect(entity.dueDate?.minute == 30)

        task.dueHasTime = false
        #expect(ReminderEntity(task: task).dueDate?.hour == nil)
        task.dueDate = nil
        #expect(ReminderEntity(task: task).dueDate == nil)
    }

    @Test("Aufgabe ohne Projekt liegt in der Eingangsliste „Loose Ends“ (AC-8)")
    func taskWithoutProjectIsInInbox() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Milch")
        store.context.insert(task)
        try store.context.save()

        let entity = ReminderEntity(task: task)
        #expect(entity.list.id == ListEntity.inboxID)
        #expect(entity.list.name == "Loose Ends")
    }

    @Test("Listen nach Kennung: Eingang, aktives und archiviertes Projekt, Unbekanntes fehlt (AC-8)")
    func listEntitiesForIDs() throws {
        let store = try TestStore()
        let active = Project(name: "Büro")
        let archived = Project(name: "Alt")
        archived.archivedAt = Date()
        store.context.insert(active)
        store.context.insert(archived)
        try store.context.save()

        let found = try ListEntity.entities(
            for: [ListEntity.inboxID, active.id.uuidString, archived.id.uuidString, UUID().uuidString, "kein-uuid"],
            in: store.context
        )
        #expect(found.map(\.name) == ["Loose Ends", "Büro", "Alt"])
    }

    @Test("Vorschläge: Eingang zuerst, dann nicht archivierte Projekte nach sortOrder (AC-8)")
    func suggestedListsInboxFirst() throws {
        let store = try TestStore()
        let second = Project(name: "Zweites", sortOrder: 2)
        let first = Project(name: "Erstes", sortOrder: 1)
        let archived = Project(name: "Alt", sortOrder: 0)
        archived.archivedAt = Date()
        for project in [second, first, archived] { store.context.insert(project) }
        try store.context.save()

        let names = try ListEntity.suggested(in: store.context).map(\.name)
        #expect(names == ["Loose Ends", "Erstes", "Zweites"])
    }

    @Test("Namenssuche ignoriert Groß/Klein und Akzente (AC-8)")
    func listStringSearchIgnoresCaseAndAccents() throws {
        let store = try TestStore()
        store.context.insert(Project(name: "Büro"))
        store.context.insert(Project(name: "Garten", sortOrder: 1))
        try store.context.save()

        #expect(try ListEntity.matching("buro", in: store.context).map(\.name) == ["Büro"])
        #expect(try ListEntity.matching("BÜRO", in: store.context).map(\.name) == ["Büro"])
        #expect(try ListEntity.matching("loose", in: store.context).map(\.name) == ["Loose Ends"])
        #expect(try ListEntity.matching("nichts", in: store.context).isEmpty)
    }

    @Test("Erinnerungen nach Kennung kommen in jedem Status, Unbekanntes fehlt (AC-8)")
    func reminderEntitiesByIDIncludeDone() throws {
        let store = try TestStore()
        let open = TaskItem(rawText: "offen")
        let done = TaskItem(rawText: "erledigt")
        done.status = .done
        store.context.insert(open)
        store.context.insert(done)
        try store.context.save()

        let found = try ReminderEntity.entities(for: [open.id, done.id, UUID()], in: store.context)
        #expect(Set(found.map(\.id)) == [open.id, done.id])
        #expect(found.first { $0.id == done.id }?.isCompleted == true)
    }

    @Test("Ortsauslöser und Abschnitte löst keine Query auf (AC-8)")
    func locationTriggerAndSectionQueriesResolveNothing() async throws {
        #expect(try await LocationTriggerEntity.LocationTriggerQuery().entities(for: ["x"]).isEmpty)
        #expect(try await LocationTriggerEntity.LocationTriggerQuery().entities(matching: "x").isEmpty)
        #expect(try await SectionEntity.SectionQuery().entities(for: ["x"]).isEmpty)
        #expect(try await SectionEntity.SectionQuery().entities(matching: "x").isEmpty)
    }
}
