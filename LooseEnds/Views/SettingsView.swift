import SwiftUI

/// The settings (#311): for now one value, the time of day a task without a due time is reminded.
/// The same view in the sheet behind the gear (iPhone, iPad) and in the Mac settings window (⌘,).
struct SettingsView: View {
    /// Nil only in previews; the app always passes its notification center.
    let notifications: DueNotificationCenter?
    @State private var time: Date
    #if os(macOS)
    @State private var opensAtLogin = LoginItem.isEnabled
    #endif

    init(notifications: DueNotificationCenter?) {
        self.notifications = notifications
        let stored = notifications?.reminderTime ?? .standard
        _time = State(initialValue: Calendar.current.date(bySettingHour: stored.hour, minute: stored.minute, second: 0, of: Date()) ?? Date())
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
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onChange(of: time) { _, new in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: new)
            notifications?.reminderTime = DueReminders.Time(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
        }
    }
}
