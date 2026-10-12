import SwiftUI

/// The task's own calendar (#203 Teil C): every writable calendar on this device, by account, with the
/// app's own "Loose Ends" on top as the default. Tapping picks and closes.
struct CalendarPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let calendars: [CalendarBridge.Target]
    /// The app's own calendar: picking it means "no choice", the default.
    let defaultID: String?
    let selectedID: String?
    let onPick: (CalendarSync.Choice?) -> Void

    var body: some View {
        NavigationStack {
            List {
                if let standard = calendars.first(where: { $0.id == defaultID }) {
                    Section {
                        row(standard, detail: Text("Default")) { onPick(nil) }
                    }
                }
                ForEach(accounts, id: \.self) { account in
                    Section(account) {
                        ForEach(calendars.filter { $0.account == account && $0.id != defaultID }) { target in
                            row(target, detail: nil) {
                                onPick(CalendarSync.Choice(account: target.account, name: target.title))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calendar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("calendarPickerCancel")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 360, minHeight: 420)
        #endif
    }

    /// Accounts in the order the calendars come, each once, without one holding only the default.
    private var accounts: [String] {
        var seen: Set<String> = []
        return calendars.filter { $0.id != defaultID }.map(\.account).filter { seen.insert($0).inserted }
    }

    private func row(_ target: CalendarBridge.Target, detail: Text?, pick: @escaping () -> Void) -> some View {
        Button {
            pick()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "circle.fill")
                    .imageScale(.small)
                    .foregroundStyle(Color(cgColor: target.color))
                    .accessibilityHidden(true)
                Text(target.title).foregroundStyle(.primary)
                if let detail { detail.foregroundStyle(.secondary) }
                Spacer()
                if target.id == selectedID {
                    Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                }
            }
        }
        .accessibilityIdentifier("calendarPick_\(target.title)")
        .accessibilityAddTraits(target.id == selectedID ? .isSelected : [])
    }
}
