import SwiftUI

/// The settings (#311): the time of day a task without a due time is reminded, the evening and morning
/// notifications around the loose ends (#414, #518), whether this device mirrors
/// with iCloud (#377), and where new calendar events on this device go (#203 Teil C2).
/// The same view in the sheet behind the gear (iPhone, iPad) and in the Mac settings window (⌘,).
struct SettingsView: View {
    /// Nil only in previews; the app always passes its notification center.
    let notifications: DueNotificationCenter?
    @Environment(CalendarBridge.self) private var calendar: CalendarBridge?
    @State private var time: Date
    @State private var carryMode: CarryReminders.Mode
    @State private var eveningTime: Date
    @State private var morningTime: Date
    /// The calendar picker for new events (#203 Teil C2) is open.
    @State private var choosesCalendar = false
    #if os(macOS)
    @State private var opensAtLogin = LoginItem.isEnabled
    #endif

    init(notifications: DueNotificationCenter?) {
        self.notifications = notifications
        let stored = notifications?.reminderTime ?? .standard
        _time = State(initialValue: Calendar.current.date(bySettingHour: stored.hour, minute: stored.minute, second: 0, of: Date()) ?? Date())
        _carryMode = State(initialValue: notifications?.carryMode ?? .standard)
        let evening = notifications?.eveningTime ?? CarryReminders.eveningStandard
        _eveningTime = State(initialValue: Calendar.current.date(bySettingHour: evening.hour, minute: evening.minute, second: 0, of: Date()) ?? Date())
        let morning = notifications?.morningTime ?? CarryReminders.morningStandard
        _morningTime = State(initialValue: Calendar.current.date(bySettingHour: morning.hour, minute: morning.minute, second: 0, of: Date()) ?? Date())
    }

    var body: some View {
        container {
            #if os(macOS)
            // On the Mac the iCloud row stands on top without a head of its own (#478).
            syncSection
            #endif
            group("Notifications", hint: Text("A task without a due time is reminded on its day at this time. A task with a due time is reminded at that time.")) {
                DatePicker("Reminder time", selection: $time, displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("reminderTimePicker")
            }
            group("Loose ends", hint: Text("In the evening, what needs a new date comes in one notification. In the morning, one invites you to look at your loose ends; at the reminder time it also names what is due today.")) {
                // Two notifications, each on its own (#518, Henning 2026-10-17).
                Toggle("Evening: plan new dates", isOn: Binding(
                    get: { carryMode.remindsEvening },
                    set: { carryMode = CarryReminders.Mode(morning: carryMode.remindsMorning, evening: $0) }
                ))
                .accessibilityIdentifier("eveningToggle")
                if carryMode.remindsEvening {
                    DatePicker("Evening time", selection: $eveningTime, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("eveningTimePicker")
                }
                Toggle("Morning: look at loose ends", isOn: Binding(
                    get: { carryMode.remindsMorning },
                    set: { carryMode = CarryReminders.Mode(morning: $0, evening: carryMode.remindsEvening) }
                ))
                .accessibilityIdentifier("morningToggle")
                if carryMode.remindsMorning {
                    DatePicker("Morning time", selection: $morningTime, displayedComponents: .hourAndMinute)
                        .accessibilityIdentifier("morningTimePicker")
                }
            }
            #if os(iOS)
            syncSection
            #endif
            calendarSection
            #if os(macOS)
            group("Menu bar", hint: Text("Then capturing from the menu bar is ready right after you log in, without a window.")) {
                Toggle("Open at login", isOn: $opensAtLogin)
                    .onChange(of: opensAtLogin) { _, on in
                        guard on != LoginItem.isEnabled else { return }
                        LoginItem.setEnabled(on)
                        opensAtLogin = LoginItem.isEnabled
                    }
                    .accessibilityIdentifier("openAtLoginToggle")
            }
            #endif
            group("About", hint: nil) {
                LabeledContent("Version", value: AppVersion.text())
                    .textSelection(.enabled)
                    .accessibilityIdentifier("appVersionRow")
            }
        }
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
        .onChange(of: carryMode) { _, new in
            notifications?.carryMode = new
        }
        .onChange(of: morningTime) { _, new in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: new)
            notifications?.morningTime = DueReminders.Time(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
        }
        .onChange(of: eveningTime) { _, new in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: new)
            notifications?.eveningTime = DueReminders.Time(hour: parts.hour ?? 20, minute: parts.minute ?? 0)
        }
        .onChange(of: time) { _, new in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: new)
            notifications?.reminderTime = DueReminders.Time(hour: parts.hour ?? 9, minute: parts.minute ?? 0)
        }
    }

    /// iPhone and iPad: the grouped form, unchanged. Mac (#478): a plain list on paper with hairlines,
    /// like the detail (#477). The rows are the same in both.
    @ViewBuilder
    private func container(@ViewBuilder _ sections: () -> some View) -> some View {
        #if os(macOS)
        List(content: sections)
            .listStyle(.plain)
            // Outside a form the Mac draws a bezel around text fields, a checkbox for a toggle and a
            // push button for the calendar row.
            .textFieldStyle(.plain)
            .toggleStyle(.switch)
            .buttonStyle(.plain)
            .font(.system(size: 14))
            // The hint lines are lower than a row; `group` keeps the rows at 40 pt or more.
            .environment(\.defaultMinListRowHeight, 0)
            .paperGround()
        #else
        Form(content: sections)
            .formStyle(.grouped)
        #endif
    }

    /// One section. iPhone and iPad: head and footer of the form. Mac: a small grey head in capitals
    /// and the hint as its own grey 12 pt line right under the rows, without a hairline between them
    /// (a plain list does not set a footer close under the row). Without a title the Mac shows no head.
    @ViewBuilder
    private func group(_ title: LocalizedStringKey?, hint: Text?, @ViewBuilder rows: () -> some View) -> some View {
        #if os(macOS)
        let content = Group {
            Group(content: rows)
                .frame(minHeight: 40 - Paper.wideRowInsets.top - Paper.wideRowInsets.bottom)
                .listRowInsets(Paper.wideRowInsets)
                .listRowBackground(Paper.ground)
            if let hint {
                hint
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowInsets(EdgeInsets(top: 0, leading: Paper.wideRowInsets.leading,
                                              bottom: Paper.wideRowInsets.bottom, trailing: Paper.wideRowInsets.trailing))
                    .listRowSeparator(.hidden, edges: .top)
                    .listRowBackground(Paper.ground)
            }
        }
        if let title {
            Section { content } header: { Text(title).captionHead() }
        } else {
            Section { content }
        }
        #else
        Section {
            rows()
        } header: {
            if let title { Text(title) }
        } footer: {
            if let hint { hint }
        }
        #endif
    }

    /// Whether this device mirrors with iCloud (#377). Every decision comes from `SyncStatus.summary`.
    private var syncSection: some View {
        #if os(macOS)
        let title: LocalizedStringKey? = nil
        #else
        let title: LocalizedStringKey? = "iCloud"
        #endif
        return group(title, hint: SyncStatus.summary(for: SyncStatus.shared.state, now: .now).detail.map { Text($0) }) {
            syncRow
        }
    }

    /// Only the row needs the clock ("n min ago"); the section stays a direct child of the form.
    private var syncRow: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let summary = SyncStatus.summary(for: SyncStatus.shared.state, now: context.date)
            HStack {
                Text("iCloud sync")
                Spacer()
                Label(syncValue(summary), systemImage: summary.symbol)
                    .foregroundStyle(summary.role == .accent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("iCloud sync"))
            .accessibilityValue(Text(syncValue(summary)))
            .accessibilityIdentifier("iCloudSyncRow")
        }
    }

    private func syncValue(_ summary: SyncStatus.Summary) -> String {
        switch summary.headline {
        case .waiting: return String(localized: "Waiting for iCloud")
        case .disturbed: return String(localized: "Disturbed")
        case .localOnly: return String(localized: "This device only")
        case .active:
            let activity = switch summary.activity {
            case .setup?: String(localized: "Set up")
            case .imported?: String(localized: "Received")
            case .exported?, nil: String(localized: "Sent")
            }
            let minutes = summary.ageMinutes ?? 0
            return minutes == 0
                ? String(localized: "Active · \(activity), just now")
                : String(localized: "Active · \(activity), \(minutes) min ago")
        }
    }

    /// Where new events on this device go (#203 Teil C2). Without calendar access the list is unknown,
    /// so the row waits until a task is in the calendar.
    @ViewBuilder private var calendarSection: some View {
        let ready = calendar?.appCalendarID != nil
        let target = calendar?.defaultTarget
        group("Calendar", hint: calendarHint(ready: ready, target: target)) {
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
        }
    }

    private func calendarHint(ready: Bool, target: CalendarBridge.Target?) -> Text {
        if !ready {
            Text("Available once a task is in the calendar.")
        } else if target == nil {
            Text("Not on this device. New events go to “Loose Ends”.")
        } else {
            Text("Applies to this device only. A task keeps the calendar it gets when you switch it on.")
        }
    }
}
