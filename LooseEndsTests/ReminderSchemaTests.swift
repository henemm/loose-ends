import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// Siri über das Reminders-App-Schema, Schnitt 1 (#25): Was Siri strukturiert liefert, wird ohne Modell
/// auf eine Aufgabe abgebildet. Jeder Test hält seinen eigenen Speicher (`TestStore`), denn unter Tests
/// liefert `ModelContainerFactory.make()` jedes Mal einen anderen (siehe `IntentExecutionTests`).
@MainActor
@Suite("Reminders-Schema: Erfassung")
struct ReminderCaptureTests {
    private let calendar = Calendar.current

    @Test("Siris Titel wird Rohtext und Titel, Kanal Siri, noch unbearbeitet")
    func titleBecomesRawText() throws {
        let store = try TestStore()

        let task = try ReminderMapping.capture(
            title: "Milch kaufen", note: nil, dueDate: nil, listID: nil, in: store.context
        )

        #expect(task.rawText == "Milch kaufen")
        #expect(task.capturedVia == .siri)
        #expect(task.title == "Milch kaufen")
        #expect(task.status == .unprocessed)
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).map(\.id) == [task.id])
    }

    @Test("Eine Notiz steht im Rohtext nach einem Zeilenumbruch, aber nicht im Titel")
    func noteGoesToRawTextNotTitle() throws {
        let store = try TestStore()

        let task = try ReminderMapping.capture(
            title: "Milch kaufen", note: "Hafermilch, 2 Liter", dueDate: nil, listID: nil, in: store.context
        )

        #expect(task.rawText == "Milch kaufen\nHafermilch, 2 Liter")
        #expect(task.title == "Milch kaufen")
    }

    @Test("Ein leerer Titel wird abgelehnt, es entsteht keine Aufgabe")
    func blankTitleIsRejected() throws {
        let store = try TestStore()

        #expect(throws: CaptureError.emptyText) {
            try ReminderMapping.capture(title: "   ", note: nil, dueDate: nil, listID: nil, in: store.context)
        }
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).isEmpty)
    }

    @Test("Ein Datum ohne Uhrzeit wird ein ganztägiges Fälligkeitsdatum mit KI-Marker")
    func dateWithoutTime() throws {
        let store = try TestStore()
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6)))

        let task = try ReminderMapping.capture(
            title: "Milch kaufen", note: nil, dueDate: DateComponents(year: 2026, month: 10, day: 6),
            listID: nil, in: store.context
        )

        #expect(task.dueDate == expected)
        #expect(task.dueHasTime == false)
        #expect(task.dueSourceRaw == FieldSource.ai.rawValue)
        #expect(task.dueConfidence == 1.0)
    }

    @Test("Ein Datum mit Stunde trägt die Uhrzeit, eine fehlende Minute zählt als 0")
    func dateWithTime() throws {
        let store = try TestStore()
        let halfPastThree = try #require(calendar.date(
            from: DateComponents(year: 2026, month: 10, day: 6, hour: 15, minute: 30)
        ))
        let nine = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 9, minute: 0)))

        let withMinute = try ReminderMapping.capture(
            title: "Zahnarzt", note: nil,
            dueDate: DateComponents(year: 2026, month: 10, day: 6, hour: 15, minute: 30),
            listID: nil, in: store.context
        )
        let withoutMinute = try ReminderMapping.capture(
            title: "Bäcker", note: nil, dueDate: DateComponents(year: 2026, month: 10, day: 6, hour: 9),
            listID: nil, in: store.context
        )

        #expect(withMinute.dueDate == halfPastThree)
        #expect(withMinute.dueHasTime)
        #expect(withoutMinute.dueDate == nine)
        #expect(withoutMinute.dueHasTime)
    }

    @Test("Unvollständige Datumsangaben ergeben kein Datum und keine Revision", arguments: [
        DateComponents(hour: 15),
        DateComponents(month: 10, day: 6),
        DateComponents(),
    ])
    func incompleteDateIsIgnored(components: DateComponents) throws {
        let store = try TestStore()

        let task = try ReminderMapping.capture(
            title: "Milch kaufen", note: nil, dueDate: components, listID: nil, in: store.context
        )

        #expect(task.dueDate == nil)
        #expect(task.dueHasTime == false)
        #expect(task.dueSourceRaw == nil)
        #expect((task.revisions ?? []).isEmpty)
    }

    @Test("Siris Datum hinterlässt genau eine KI-Revision mit Grund „Siri“")
    func dateLeavesOneRevision() throws {
        let store = try TestStore()
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6)))

        let task = try ReminderMapping.capture(
            title: "Milch kaufen", note: nil, dueDate: DateComponents(year: 2026, month: 10, day: 6),
            listID: nil, in: store.context
        )

        let revisions = task.revisions ?? []
        #expect(revisions.count == 1)
        let revision = try #require(revisions.first)
        #expect(revision.field == .dueDate)
        #expect(revision.oldValue == nil)
        #expect(revision.newValue == expected.ISO8601Format())
        #expect(revision.author == .ai)
        #expect(revision.reason == "Siri")
    }

    @Test("Die Liste mit der ID eines Projekts legt die Aufgabe in dieses Projekt")
    func listIDPicksProject() throws {
        let store = try TestStore()
        let garden = Project(name: "Garten")
        store.context.insert(garden)
        try store.context.save()

        let task = try ReminderMapping.capture(
            title: "Hecke schneiden", note: nil, dueDate: nil, listID: garden.id.uuidString, in: store.context
        )

        #expect(task.project?.id == garden.id)
    }

    @Test("Eingangsliste oder keine Liste: kein Projekt", arguments: [ListEntity.inboxID, nil] as [String?])
    func inboxMeansNoProject(listID: String?) throws {
        let store = try TestStore()
        store.context.insert(Project(name: "Garten"))
        try store.context.save()

        let task = try ReminderMapping.capture(
            title: "Milch kaufen", note: nil, dueDate: nil, listID: listID, in: store.context
        )

        #expect(task.project == nil)
    }

    @Test("Eine unbekannte Liste führt in die Eingangsliste, ohne neues Projekt", arguments: [
        UUID().uuidString, "Einkauf",
    ])
    func unknownListFallsBackToInbox(listID: String) throws {
        let store = try TestStore()
        store.context.insert(Project(name: "Garten"))
        try store.context.save()

        let task = try ReminderMapping.capture(
            title: "Milch kaufen", note: nil, dueDate: nil, listID: listID, in: store.context
        )

        #expect(task.project == nil)
        #expect(try store.context.fetch(FetchDescriptor<TaskItem>()).count == 1)
        #expect(try store.context.fetch(FetchDescriptor<Project>()).count == 1)
    }

    @Test("Der Regelschritt im ersten Lauf lässt Siris Datum stehen", arguments: [
        "Milch kaufen", "Zahnarzt am Freitag",
    ])
    func ruleStepKeepsSiriDate(title: String) async throws {
        let store = try TestStore()
        let expected = try #require(calendar.date(from: DateComponents(year: 2026, month: 10, day: 6)))
        let task = try ReminderMapping.capture(
            title: title, note: nil, dueDate: DateComponents(year: 2026, month: 10, day: 6),
            listID: nil, in: store.context
        )

        // Ein Enricher ohne Ergebnis: Es läuft nur der Regelschritt des Nachzügler-Laufs.
        let coordinator = EnrichmentCoordinator(enricher: StubEnricher(), container: store.container)
        await coordinator.processPending()

        #expect(task.dueDate == expected)
        #expect(task.dueSourceRaw == FieldSource.ai.rawValue)
        #expect((task.revisions ?? []).filter { $0.field == .dueDate }.count == 1)
    }

    @Test("Bisherige Aufrufe von CaptureService.save verhalten sich unverändert")
    func existingSaveIsUnchanged() throws {
        let store = try TestStore()

        let task = try CaptureService.save("Rasen mähen", via: .app, in: store.context)

        #expect(task.title == "Rasen mähen")
        #expect(task.dueDate == nil)
        #expect((task.revisions ?? []).isEmpty)
        #expect(task.project == nil)
    }
}

@MainActor
@Suite("Reminders-Schema: Entities und Queries")
struct ReminderEntityTests {
    private let calendar = Calendar.current

    @Test("Eine Aufgabe ohne Projekt wird eine Erinnerung in der Eingangsliste")
    func entityFromTaskWithoutProject() throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "zahnarzt anrufen bitte", capturedVia: .siri)
        task.title = "Zahnarzt anrufen"
        task.dueDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6, hour: 15, minute: 30))
        task.dueHasTime = true
        store.context.insert(task)
        try store.context.save()

        let entity = ReminderEntity(task: task)

        #expect(entity.id == task.id)
        #expect(entity.title == task.displayTitle)
        #expect(entity.list.id == ListEntity.inboxID)
        #expect(entity.list.name == "Loose Ends")
        #expect(entity.isCompleted == false)
        #expect(entity.creationDate == task.capturedAt)
        #expect(entity.dueDate?.year == 2026)
        #expect(entity.dueDate?.month == 10)
        #expect(entity.dueDate?.day == 6)
        #expect(entity.dueDate?.hour == 15)
        #expect(entity.dueDate?.minute == 30)
    }

    @Test("Ein ganztägiges Datum trägt nur Jahr, Monat und Tag; ein Projekt wird die Liste")
    func entityFromTaskInProject() throws {
        let store = try TestStore()
        let garden = Project(name: "Garten")
        let task = TaskItem(rawText: "Hecke schneiden")
        task.project = garden
        task.dueDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 6))
        task.dueHasTime = false
        store.context.insert(garden)
        store.context.insert(task)
        try store.context.save()

        let entity = ReminderEntity(task: task)

        #expect(entity.list.id == garden.id.uuidString)
        #expect(entity.list.name == "Garten")
        #expect(entity.dueDate?.day == 6)
        #expect(entity.dueDate?.hour == nil)
        #expect(entity.dueDate?.minute == nil)
    }

    @Test("Erledigt heißt abgeschlossen, geparkt und aktiv nicht", arguments: [
        (TaskStatus.done, true), (.parked, false), (.active, false),
    ])
    func completionFollowsStatus(status: TaskStatus, completed: Bool) throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Milch kaufen")
        task.status = status
        store.context.insert(task)
        try store.context.save()

        #expect(ReminderEntity(task: task).isCompleted == completed)
    }

    @Test("Die Query löst auch erledigte und geparkte Aufgaben auf")
    func queryResolvesEveryStatus() throws {
        let store = try TestStore()
        let tasks = [TaskStatus.active, .done, .parked, .unprocessed].map { status in
            let task = TaskItem(rawText: "Aufgabe \(status.rawValue)")
            task.status = status
            store.context.insert(task)
            return task
        }
        try store.context.save()

        let entities = try ReminderEntity.entities(for: tasks.map(\.id), in: store.context)

        #expect(Set(entities.map(\.id)) == Set(tasks.map(\.id)))
    }

    @Test("Unbekannte IDs lässt die Query aus")
    func queryOmitsUnknownIDs() throws {
        let store = try TestStore()
        let first = TaskItem(rawText: "Milch kaufen")
        let second = TaskItem(rawText: "Rasen mähen")
        store.context.insert(first)
        store.context.insert(second)
        try store.context.save()

        let entities = try ReminderEntity.entities(for: [first.id, UUID(), second.id], in: store.context)

        #expect(Set(entities.map(\.id)) == [first.id, second.id])
    }

    @Test("Listen-Vorschläge: Eingangsliste zuerst, dann nur nicht archivierte Projekte")
    func listQuery() throws {
        let store = try TestStore()
        let garden = Project(name: "Garten", sortOrder: 1)
        let old = Project(name: "Umzug", sortOrder: 0)
        old.archivedAt = Date()
        store.context.insert(garden)
        store.context.insert(old)
        try store.context.save()

        let suggested = try ListEntity.suggested(in: store.context)
        #expect(suggested.map(\.id) == [ListEntity.inboxID, garden.id.uuidString])

        let archived = try ListEntity.entities(for: [old.id.uuidString], in: store.context)
        #expect(archived.map(\.name) == ["Umzug"])
        #expect(try ListEntity.entities(for: [UUID().uuidString], in: store.context).isEmpty)
        #expect(try ListEntity.entities(for: [ListEntity.inboxID], in: store.context).map(\.name) == ["Loose Ends"])
    }
}
