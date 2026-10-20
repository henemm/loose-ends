import SwiftUI

/// Settings, "Fields" (#538, rule 7): one page, the detail's order, one switch per field. Off means not
/// offered; what a task already carries it shows anyway. Tags and Projects steer the start page's
/// groups too. The choice goes to every device through the iCloud key-value store.
struct FieldSettingsView: View {
    @Environment(FieldSettingsStore.self) private var store: FieldSettingsStore?

    private var settings: DetailFieldSettings { store?.settings ?? .standard }

    var body: some View {
        Form {
            ForEach(DetailField.Group.allCases, id: \.self) { group in
                Section {
                    if group == .what {
                        LabeledContent("Title, Said") { Text("always").foregroundStyle(.secondary) }
                    }
                    ForEach(DetailField.allCases.filter { $0.group == group }, id: \.self) { field in
                        row(field)
                    }
                } header: {
                    Text(Self.groupTitle(group))
                } footer: {
                    if group == .connection {
                        Text("Fields that are off are not offered when filling in a task. What a task already holds stays visible.")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Fields")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibilityIdentifier("fieldSettings")
    }

    @ViewBuilder
    private func row(_ field: DetailField) -> some View {
        if field.isFixed {
            LabeledContent(Self.title(field)) { Text("always").foregroundStyle(.secondary) }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Toggle(Self.title(field), isOn: Binding(
                    get: { settings.isOn(field) },
                    set: { store?.set(field, on: $0) }
                ))
                .accessibilityIdentifier("fieldSwitch_\(field.rawValue)")
                if let note = Self.note(field) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func groupTitle(_ group: DetailField.Group) -> String {
        switch group {
        case .what: String(localized: "What")
        case .when: String(localized: "When")
        case .weight: String(localized: "Weight")
        case .filing: String(localized: "Filing")
        case .connection: String(localized: "Connection")
        }
    }

    /// The word in the detail's line (#538, draft): one of a kind, so "+ Attachment", "+ Subtask",
    /// "+ Project"; the settings name the field as a whole.
    static func word(_ field: DetailField) -> String {
        switch field {
        case .attachments: String(localized: "Attachment")
        case .subtasks: String(localized: "Subtask")
        case .project: String(localized: "Project")
        default: title(field)
        }
    }

    /// The field's name in the settings.
    static func title(_ field: DetailField) -> String {
        switch field {
        case .notes: String(localized: "Note")
        case .attachments: String(localized: "Attachments")
        case .dueDate: String(localized: "Due")
        case .repeatRule: String(localized: "Repeat")
        case .calendar: String(localized: "Calendar")
        case .place: String(localized: "Place")
        case .importance: String(localized: "Importance")
        case .urgency: String(localized: "Urgency")
        case .duration: String(localized: "Duration")
        case .energy: String(localized: "Energy")
        case .contexts: String(localized: "Tags")
        case .project: String(localized: "Projects")
        case .subtasks: String(localized: "Subtasks")
        case .waitingOn: String(localized: "Waiting on")
        }
    }

    private static func note(_ field: DetailField) -> String? {
        switch field {
        case .calendar: String(localized: "Once the task has a due date.")
        case .place: String(localized: "Reminds you when you arrive or leave.")
        case .importance, .urgency: String(localized: "The rules read it from your words even when off.")
        case .contexts, .project: String(localized: "Also the group on the start page.")
        case .waitingOn: String(localized: "A task that has to be done first.")
        default: nil
        }
    }
}
