import OSLog
import SwiftData
import SwiftUI

/// "Place" in the detail (#241, Schnitt 3a): one row with the place, arrive or leave, a grey line
/// that says when it reminds, and a note when it cannot. Tapping the row searches for a place;
/// swiping removes it. Every change is a user revision (`PlaceEditing`). Reminding itself comes
/// with Schnitt 4; "current location", home and work with Schnitt 3b.
struct PlaceSection: View {
    @Environment(\.modelContext) private var modelContext
    /// Every task, for the 20-place ranking behind the "not watched" note.
    @Query private var allTasks: [TaskItem]
    let task: TaskItem

    @State private var searching = false
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Detail")

    private static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    var body: some View {
        Section {
            if let place = task.place {
                Button { searching = true } label: {
                    Label(place.name, systemImage: "mappin.and.ellipse")
                        .lineLimit(2)
                }
                .swipeActions(edge: .trailing) {
                    Button("Remove", systemImage: "trash", role: .destructive) { remove() }
                        .accessibilityIdentifier("removePlaceButton")
                }
                .accessibilityIdentifier("placeRow")
                Picker("Remind", selection: eventBinding(place)) {
                    Text("Arrive").tag(TaskPlace.Event.arrive)
                    Text("Leave").tag(TaskPlace.Event.depart)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("placeEventPicker")
            } else {
                Button("Add place", systemImage: "mappin.and.ellipse") { searching = true }
                    .accessibilityIdentifier("addPlaceButton")
            }
        } header: {
            Text("Place")
        } footer: {
            footer
        }
        .sheet(isPresented: $searching) {
            PlaceSearchSheet { hit in
                guard let place = hit.place(task.place?.event ?? .arrive) else { return }
                PlaceEditing.set(place, on: task)
                save("place")
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let place = task.place {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.event == .arrive ? "Reminds you when you arrive." : "Reminds you when you leave.")
                    .accessibilityIdentifier("placeEventNote")
                switch PlaceEditing.note(for: task, among: allTasks, isMac: Self.isMac) {
                case .notWatched: Text("Not watched right now: more than 20 places are open.")
                case .macOnly: Text("Reminds you on iPhone and Watch.")
                case nil: EmptyView()
                }
            }
        }
    }

    private func eventBinding(_ place: TaskPlace) -> Binding<TaskPlace.Event> {
        Binding(get: { task.place?.event ?? place.event }, set: { event in
            guard PlaceEditing.setEvent(event, on: task) != nil else { return }
            save("place event")
        })
    }

    private func remove() {
        guard PlaceEditing.remove(from: task) != nil else { return }
        save("remove place")
    }

    private func save(_ what: String) {
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Saving \(what, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}

/// Search for an address or a business; one tap sets it and closes the sheet. Searches after 0.3 s
/// of quiet and from two characters on, so typing does not fire a request per key.
private struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let choose: (PlaceHit) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var hits: [PlaceHit] = []
    /// The query the current hits answer; "No places found." only shows once the search came back.
    @State private var answered = ""
    @State private var failed = false
    private let search = PlaceSearch.current
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Place")

    var body: some View {
        NavigationStack {
            List {
                // A plain field, not `.searchable`: it stays visible and focused from the start, and
                // UI tests find it by identifier on every OS layout of the search bar.
                TextField("Address or name", text: $query)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("placeSearchField")
                ForEach(hits) { hit in
                    Button {
                        choose(hit)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hit.name)
                                .foregroundStyle(.primary)
                            if let locality = hit.locality {
                                Text(locality)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("placeHit_\(hit.id)")
                }
                if failed || (hits.isEmpty && !answered.isEmpty && answered == query.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    Text("No places found.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("placeSearchEmpty")
                }
            }
            .onAppear { searchFocused = true }
            .task(id: query) { await run(query) }
            .navigationTitle("Place")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("placeSearchCancel")
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 380, minHeight: 360)
        #endif
    }

    private func run(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            hits = []
            answered = ""
            failed = false
            return
        }
        do {
            try await Task.sleep(for: .milliseconds(300))
        } catch {
            return   // the next keystroke cancelled this search
        }
        do {
            hits = try await search.places(matching: trimmed)
            answered = trimmed
            failed = false
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("Place search failed: \(error, privacy: .public)")
            hits = []
            answered = trimmed
            failed = true
        }
    }
}
