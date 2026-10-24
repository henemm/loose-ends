import OSLog
import SwiftData
import SwiftUI

/// "Place" in the detail (#241, Schnitt 3a): one row with the place, arrive or leave, a grey line
/// that says when it reminds, and a note when it cannot. Tapping the row asks the detail for the
/// place search; swiping removes it. Every change is a user revision (`PlaceEditing`). The sheet
/// offers "Current location" on iPhone and iPad (#241 3b-1); home and work come with Schnitt 3b-2.
struct PlaceSection: View {
    @Environment(\.modelContext) private var modelContext
    /// Every task, for the 20-place ranking behind the "not watched" note.
    @Query private var storedTasks: [TaskItem]
    /// Filtered here, not in `@Query`: a predicate there is rebuilt on every init and kept the
    /// detail from settling after a field tap (#605).
    private var allTasks: [TaskItem] { storedTasks.filter(\.isPresent) }
    let task: TaskItem
    /// The detail presents the search sheet; this section only asks for it.
    @Binding var searching: Bool
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
            Text("Place").captionHead()
        } footer: {
            footer
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let place = task.place {
            VStack(alignment: .leading, spacing: 4) {
                // "Next time": iOS does not remind a place you are already at (measured 2026-10-08, #241).
                Text(place.event == .arrive ? "Reminds you the next time you arrive." : "Reminds you when you leave.")
                    .accessibilityIdentifier("placeEventNote")
                switch note {
                case .locationOff: Text("Location is off in Settings. The place is saved but does not remind you.")
                case .preciseOff: Text("Precise location is off. The place is saved but does not remind you.")
                case .notWatched: Text("Not watched right now: more than 20 places are open.")
                case .macOnly: Text("Reminds you on iPhone and Watch.")
                case nil: EmptyView()
                }
            }
        }
    }

    private var note: PlaceEditing.Note? {
        #if os(iOS)
        PlaceEditing.note(
            for: task, among: allTasks, isMac: false,
            permission: CurrentPlace.permission, fullAccuracy: CurrentPlace.fullAccuracy
        )
        #else
        PlaceEditing.note(for: task, among: allTasks, isMac: Self.isMac)
        #endif
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
struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let choose: (PlaceHit) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var hits: [PlaceHit] = []
    /// The query the current hits answer; "No places found." only shows once the search came back.
    @State private var answered = ""
    @State private var failed = false
    #if os(iOS)
    @State private var locating = false
    @State private var locateFailure: CurrentPlace.Failure?
    #endif
    private let search = PlaceSearch.current
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Place")

    var body: some View {
        NavigationStack {
            List {
                #if os(iOS)
                currentLocationRow
                #endif
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

    #if os(iOS)
    /// Above the search: the place where one stands, in one tap. A failure stays in the sheet, so
    /// the search remains at hand.
    @ViewBuilder
    private var currentLocationRow: some View {
        Button {
            Task { await locate() }
        } label: {
            HStack {
                Label("Current location", systemImage: "location")
                if locating {
                    Spacer()
                    ProgressView()
                }
            }
        }
        .disabled(locating)
        .accessibilityIdentifier("currentLocationButton")
        if let locateFailure {
            Group {
                switch locateFailure {
                case .locationOff: Text("Location is off.")
                case .preciseOff: Text("Precise location is off.")
                case .notFound: Text("Location not found.")
                }
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("currentLocationNote")
        }
    }

    private func locate() async {
        locating = true
        locateFailure = nil
        defer { locating = false }
        do {
            let hit = try await CurrentPlace.locate()
            choose(hit)
            dismiss()
        } catch let failure as CurrentPlace.Failure {
            Self.logger.notice("Current location not set: \(String(describing: failure), privacy: .public)")
            locateFailure = failure
        } catch {
            Self.logger.error("Current location failed: \(error, privacy: .public)")
            locateFailure = .notFound
        }
    }
    #endif

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
