import Foundation
import SwiftData
import Testing
@testable import LooseEnds

/// What a task offers (#538): five groups, one order, a section only with content, everything empty in
/// one word line, dependent fields wait, off is not offered but never hidden.
@Suite("Detail fields (#538)") struct DetailFieldsTests {
    @Test("The order is the groups' order: What, When, Weight, Filing, Connection")
    func order() {
        #expect(DetailField.allCases.map(\.group) == [.what, .what, .when, .when, .when, .when,
                                                       .weight, .weight, .weight, .weight, .filing, .filing,
                                                       .connection, .connection, .drive, .drive])
        #expect(DetailField.allCases.first == .notes)
        #expect(DetailField.allCases.last == .counts)
    }

    @Test("The standard: on only Note, Attachments, Calendar, Duration and Tags; Due is fixed and always on")
    func standard() {
        let standard = DetailFieldSettings.standard
        #expect(standard.on == [.notes, .attachments, .calendar, .duration, .contexts])
        for field in [DetailField.importance, .urgency, .energy, .repeatRule, .place, .project, .subtasks, .waitingOn, .knaeuel, .counts] {
            #expect(!standard.isOn(field), "\(field) is off by default")
        }
        #expect(standard.isOn(.dueDate), "fixed")
        #expect(!DetailField.switchable.contains(.dueDate))
        #expect(DetailFieldSettings.everything.on == Set(DetailField.switchable))
    }

    @Test("Stored as the names that are on; nothing stored is the standard, an unknown name is ignored")
    func stored() {
        #expect(DetailFieldSettings(stored: nil) == .standard)
        #expect(DetailFieldSettings(stored: []).on.isEmpty)
        let read = DetailFieldSettings(stored: ["project", "dueDate", "unicorn", "notes"])
        #expect(read.on == [.project, .notes], "dueDate is fixed, unicorn unknown")
        #expect(read.stored == ["notes", "project"])
        let roundTrip = DetailFieldSettings(stored: DetailFieldSettings.standard.stored)
        #expect(roundTrip == .standard)
        #expect(DetailFieldSettings.standard.setting(.project, on: true).on.contains(.project))
        #expect(!DetailFieldSettings.standard.setting(.notes, on: false).on.contains(.notes))
        #expect(DetailFieldSettings.standard.setting(.dueDate, on: false).isOn(.dueDate), "fixed stays")
    }

    @Test("A new task without a date offers, with the standard, Note, Attachment, Due, Duration and Tags, in four groups")
    func newTaskStandard() {
        let offered = DetailFields.offered(settings: .standard, carried: [], hasDueDate: false, topLevel: true)
        #expect(offered == [[.notes, .attachments], [.dueDate], [.duration], [.contexts]])
    }

    @Test("With a date the calendar joins When; repeat too once it is on; subtasks and waiting on only at the top level")
    func dependencies() {
        let standard = DetailFields.offered(settings: .standard, carried: [.dueDate], hasDueDate: true, topLevel: true)
        #expect(standard == [[.notes, .attachments], [.calendar], [.duration], [.contexts]])
        let everything = DetailFields.offered(settings: .everything, carried: [.dueDate], hasDueDate: true, topLevel: true)
        #expect(everything == [[.notes, .attachments], [.repeatRule, .calendar, .place],
                               [.importance, .urgency, .duration, .energy], [.contexts, .project], [.subtasks, .waitingOn],
                               [.knaeuel, .counts]])
        let subtask = DetailFields.offered(settings: .everything, carried: [], hasDueDate: false, topLevel: false)
        #expect(subtask.last == [.contexts, .project], "no Connection and no Drive on a subtask (#643)")
        #expect(subtask[1] == [.dueDate, .place], "no repeat and no calendar without a date")
    }

    @Test("What is set leaves the line; a full task with the standard offers nothing")
    func carriedLeavesTheLine() {
        let full: Set<DetailField> = [.notes, .attachments, .dueDate, .calendar, .duration, .contexts]
        #expect(DetailFields.offered(settings: .standard, carried: full, hasDueDate: true, topLevel: true).isEmpty)
    }

    @Test("Carried: what the task has, whatever the switches say")
    @MainActor func carried() async throws {
        let store = try TestStore()
        let task = TaskItem(rawText: "Steuerunterlagen an Frau Berger schicken")
        task.status = .active
        store.context.insert(task)
        #expect(DetailFields.carried(by: task).isEmpty)

        task.notes = "Belege im Ordner"
        task.dueDate = Date()
        task.showInCalendar = true
        task.importance = .high
        task.duration = .minutes30
        let project = Project(name: "Steuer 2026")
        store.context.insert(project)
        task.project = project
        let sub = TaskItem(rawText: "Belege heraussuchen")
        sub.parent = task
        store.context.insert(sub)
        let blocker = TaskItem(rawText: "Antwort von Frau Berger")
        store.context.insert(blocker)
        task.blockedBy = [blocker]

        task.knaeuelAt = Date()
        task.countsAt = Date()

        let carried = DetailFields.carried(by: task)
        #expect(carried == [.notes, .dueDate, .calendar, .importance, .duration, .project, .subtasks, .waitingOn, .knaeuel, .counts])
        // Off in the standard, carried anyway: importance, project, subtasks and waiting on stay out of the line
        // because they are set, not because they are off (rule 5).
        let offered = DetailFields.offered(settings: .standard, for: task)
        #expect(offered == [[.attachments], [.contexts]])
    }
}

/// The store behind the settings page (#538, rule 7): defaults, iCloud, the UI tests' everything.
@Suite("Field settings store (#538)") struct FieldSettingsStoreTests {
    @MainActor
    final class Cloud: FieldSettingsCloud {
        var offeredFields: [String]?
        func setOfferedFields(_ fields: [String]) { offeredFields = fields }
    }

    @MainActor
    private func fixture() throws -> (store: FieldSettingsStore, defaults: UserDefaults, cloud: Cloud) {
        let defaults = try #require(UserDefaults(suiteName: "FieldSettingsStoreTests-\(UUID().uuidString)"))
        let cloud = Cloud()
        return (FieldSettingsStore(defaults: defaults, cloud: cloud), defaults, cloud)
    }

    @Test("Nothing stored is the standard; a switch writes the defaults and iCloud")
    @MainActor func switchWrites() throws {
        let (store, defaults, cloud) = try fixture()
        #expect(store.settings == .standard)
        store.set(.project, on: true)
        #expect(store.settings.isOn(.project))
        #expect(defaults.stringArray(forKey: FieldSettingsStore.key)?.contains("project") == true)
        #expect(cloud.offeredFields?.contains("project") == true)
        store.set(.dueDate, on: false)
        #expect(store.settings.isOn(.dueDate), "fixed, no switch")
    }

    @Test("Another device's choice is taken over; the same choice again changes nothing")
    @MainActor func takesTheCloud() throws {
        let (store, defaults, cloud) = try fixture()
        cloud.offeredFields = ["notes", "energy"]
        #expect(store.takeCloud())
        #expect(store.settings.on == [.notes, .energy])
        #expect(defaults.stringArray(forKey: FieldSettingsStore.key) == ["notes", "energy"])
        #expect(store.takeCloud() == false)
        let fresh = FieldSettingsStore(defaults: defaults, cloud: cloud)
        #expect(fresh.settings.on == [.notes, .energy], "read back from the defaults")
    }

    @Test("Only the UI test process runs with every switch on; the unit tests see the standard")
    @MainActor func uiTestsEverything() {
        #expect(!ModelContainerFactory.isUITesting)
        #expect(FieldSettingsStore.forApp(arguments: ["--ui-testing"]).settings == .standard)
        #expect(FieldSettingsStore.standardArgument == "--ui-testing-fields-standard")
    }
}
