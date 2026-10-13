import SwiftUI

/// The settings (#311): the time of day a task without a due time is reminded, and where new calendar
/// events on this device go (#203 Teil C2).
/// The same view in the sheet behind the gear (iPhone, iPad) and in the Mac settings window (⌘,).
struct SettingsView: View {
    /// Nil only in previews; the app always passes its notification center.
    let notifications: DueNotificationCenter?
    @Environment(CalendarBridge.self) private var calendar: CalendarBridge?
    @State private var time: Date
    /// The calendar picker for new events (#203 Teil C2) is open.
    @State private var choosesCalendar = false
    #if os(macOS)
    @State private var opensAtLogin = LoginItem.isEnabled
    #endif

    init(notifications: DueNotificationCenter?) {
        self.notifications = notifications
        let stored = notifications?.reminderTime ?? .standard
        _time = State(initialValue: Calendar.current.date(bySettingHour: stored.hour, minute: stored.minute, second: 0, of: Date()) ?? Date())
    }

    /// One line for the sync state (#377), plain words, no code.
    private func cloudState(_ state: CloudSyncSummary.State) -> LocalizedStringResource {
        switch state {
        case .neverContacted: return "No contact yet"
        case .running: return "Syncing …"
        case .failed(let kind, let error): return "\(kindName(kind)) failed: \(error)"
        case .ok(let date): return "In sync, \(date.formatted(date: .abbreviated, time: .shortened))"
        }
    }

    private func kindName(_ kind: CloudSyncEventKind) -> String {
        switch kind {
        case .setup: return String(localized: "Setup")
        case .import: return String(localized: "Import")
        case .export: return String(localized: "Export")
        }
    }

    @ViewBuilder
    private func cloudRow(_ title: LocalizedStringKey, _ event: CloudSyncEvent?) -> some View {
        LabeledContent(title) {
            if let event, let ended = event.endedAt {
                Text(ended.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(event.failed ? .red : .secondary)
            } else if event != nil {
                Text("Running …").foregroundStyle(.secondary)
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        Form {
            Section {
                DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("reminderTimePicker")
            } header: {
                Text("Notifications")
            } footer: {
                Text("A task without a due time is reminded on its day at this time. A task with a due time is reminded at that time.")
            }
            calendarSection
            Section {
                let sync = CloudSyncStatus.shared.summary
                LabeledContent("Status") { Text(cloudState(sync.state)) }
                    .accessibilityIdentifier("cloudSyncStatus")
                cloudRow("Last import", sync.latest(.import))
                cloudRow("Last export", sync.latest(.export))
            } header: {
                Text("iCloud")
            } footer: {
                Text("What this device's sync with iCloud reports. \"No contact yet\" after a minute means the app never reached iCloud here.")
            }
            #if os(macOS)
            Section {
                Toggle("Open at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, on in
                        guard on != LoginItem.isEnabled else { return }
                        LoginItem.setEnabled(on)
                        opensAtLogin = LoginItem.isEnabled
                    }
                    .accessibilityIdentifier("openAtLoginToggle")
            } header: {
                Text("Menu bar")
            } footer: {
                Text("Then capturing from the menu bar is ready right after you log in, without a window.")
            }
            #endif
            Section("About") {
                LabeledContent("Version", value: AppVersion.text())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("appVersionRow")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        // Only refreshes the calendar list when access is already there; never asks for it.
        .task { await calendar?.refreshIfAllowed() }
        .sheet(isPresented: $choosesCalendar) {
            if let calendar {
                CalendarPickerSheet(calendars: calendar.calendars, defaultID: calendar.appCalendarID,
                                    selectedID: calendar.defaultTarget?.id) { picked in
                    calendar.setDeviceDefault(picked)
                }
            }
        }
        .onChange(of: time) { _, new in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: new)
            notifications?.reminderTime = DueReminders.Time(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
        }
    }

    /// Where new events on this device go (#203 Teil C2). Without calendar access the list is unknown,
    /// so the row waits until a task is in the calendar.
    @ViewBuilder private var calendarSection: some View {
        let ready = calendar?.appCalendarID != nil
        let target = calendar?.defaultTarget
        Section {
            Button { choosesCalendar = true } label: {
                HStack {
                    Text("New events in").foregroundStyle(.primary)
                    Spacer()
                    if let target {
                        Image(systemName: "circle.fill")
                            .imageScale(.small)
                            .foregroundStyle(Color(cgColor: target.color))
                            .accessibilityHidden(true)
                    }
                    Text(target?.title ?? calendar?.deviceDefault?.name ?? CalendarSync.calendarTitle)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.forward")
                        .imageScale(.small)
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
            .disabled(!ready)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("defaultCalendarRow")
        } header: {
            Text("Calendar")
        } footer: {
            if !ready {
                Text("Available once a task is in the calendar.")
            } else if target == nil {
                Text("Not on this device. New events go to “Loose Ends”.")
            } else {
                Text("Applies to this device only. A task keeps the calendar it gets when you switch it on.")
            }
        }
    }
}
