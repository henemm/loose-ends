import OSLog
import SwiftData
import SwiftUI

/// "Place" in the detail (#241, Schnitt 3a): one row with the place, arrive or leave, a grey line
/// that says when it reminds, and a note when it cannot. Tapping the row asks the detail for the
/// place search; swiping removes it. Every change is a user revision (`PlaceEditing`). Schnitt 3b adds
/// two notes: "location off" when the permission is refused, and "already here" when a fix taken on
/// appear (never asking for the permission) puts the device at an arrive place.
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
    @State private var permission: PlaceNotifications.Permission = .notDetermined
    /// One reading per place and appearance; nil without permission, without a place or on error.
    @State private var fix: LocationFix?
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
        .task(id: task.place) { await readLocation() }
    }

    /// Reads the permission, and for an arrive place with a granted permission one fix. Never asks.
    private func readLocation() async {
        fix = nil
        guard let location = CurrentLocation.current else { return }
        permission = location.permission
        guard let place = task.place, place.event == .arrive,
              permission == .whenInUse || permission == .always else { return }
        do {
            fix = try await location.currentFix()
        } catch is CancellationError {
            return
        } catch {
            Self.logger.error("Reading the location for the place note failed: \(error, privacy: .public)")
        }
    }

    @ViewBuilder
    private var footer: some View {
        if let place = task.place {
            VStack(alignment: .leading, spacing: 4) {
                Text(place.event == .arrive ? "Reminds you when you arrive." : "Reminds you when you leave.")
                    .accessibilityIdentifier("placeEventNote")
                switch PlaceEditing.note(for: task, among: allTasks, isMac: Self.isMac, permission: permission) {
                case .notWatched: Text("Not watched right now: more than 20 places are open.")
                case .locationOff:
                    Text("Location is off in Settings. The place is saved but won't remind you.")
                        .accessibilityIdentifier("placeLocationOffNote")
                case .macOnly: Text("Reminds you on iPhone and Watch.")
                case nil:
                    if PlaceEditing.showsAlreadyThere(place, permission: permission, fix: fix) {
                        Text("You're already here. Reminds you the next time you arrive.")
                            .accessibilityIdentifier("placeAlreadyHereNote")
                    }
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
/// of quiet and from two characters on, so typing does not fire a request per key. Above the field
/// (#241, Schnitt 3b): "Current location" (not on the Mac), home and work. An empty slot opens the
/// same search to define it, which saves the slot and sets no place.
struct PlaceSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let choose: (PlaceHit) -> Void

    @State private var query = ""
    @FocusState private var searchFocused: Bool
    @State private var hits: [PlaceHit] = []
    /// The query the current hits answer; "No places found." only shows once the search came back.
    @State private var answered = ""
    @State private var failed = false
    /// The slot the search defines; nil while the search picks the task's place.
    @State private var defining: SavedPlaces.Slot?
    @State private var locating = false
    @State private var locationStatus: LocationStatus?
    private let search = PlaceSearch.current
    private let saved = SavedPlacesStore.shared
    private let location = CurrentLocation.current

    private enum LocationStatus { case refused, unavailable }

    private static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }
    private static let logger = Logger(subsystem: "com.henning.looseends", category: "Place")

    var body: some View {
        NavigationStack {
            List {
                if defining == nil {
                    Section { shortcutRows }
                }
                // A plain field, not `.searchable`: it stays visible and focused from the start, and
                // UI tests find it by identifier on every OS layout of the search bar.
                TextField("Address or name", text: $query)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("placeSearchField")
                ForEach(hits) { hit in
                    Button {
                        pick(hit)
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
            .navigationTitle(defining.map(Self.definingTitle) ?? String(localized: "Place"))
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

    @ViewBuilder
    private var shortcutRows: some View {
        if let location, PlaceEditing.offersCurrentLocation(isMac: Self.isMac) {
            Button {
                Task { await useCurrentLocation(location) }
            } label: {
                Label("Current location", systemImage: "location")
            }
            .disabled(locating)
            .accessibilityIdentifier("currentLocationRow")
            if let locationStatus {
                Text(locationStatus == .refused ? "Location is off in Settings" : "No location found")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("currentLocationStatus")
            }
        }
        ForEach(SavedPlaces.Slot.allCases, id: \.self) { slot in
            savedRow(slot)
        }
    }

    private func savedRow(_ slot: SavedPlaces.Slot) -> some View {
        let spot = saved.places.spot(slot)
        let title = Self.title(slot)
        let detail = spot?.name ?? String(localized: "Not set yet")
        return Button {
            if let spot {
                pick(PlaceHit(id: slot.rawValue, name: spot.name, locality: nil,
                              latitude: spot.latitude, longitude: spot.longitude))
            } else {
                startDefining(slot)
            }
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: slot == .home ? "house" : "briefcase")
            }
        }
        .swipeActions(edge: .trailing) {
            if spot != nil {
                Button("Remove", systemImage: "trash", role: .destructive) { saved.set(slot, to: nil) }
                Button("Change", systemImage: "pencil") { startDefining(slot) }
            }
        }
        .accessibilityLabel("\(title), \(detail)")
        .accessibilityIdentifier("savedPlaceRow_\(slot.rawValue)")
    }

    private static func title(_ slot: SavedPlaces.Slot) -> String {
        switch slot {
        case .home: String(localized: "Saved place home", defaultValue: "Home")
        case .work: String(localized: "Saved place work", defaultValue: "Work")
        }
    }

    private static func definingTitle(_ slot: SavedPlaces.Slot) -> String {
        switch slot {
        case .home: String(localized: "Set home")
        case .work: String(localized: "Set work")
        }
    }

    private func startDefining(_ slot: SavedPlaces.Slot) {
        defining = slot
        query = ""
        searchFocused = true
    }

    /// A hit sets the task's place and closes, or, while defining, saves the slot and stays open.
    private func pick(_ hit: PlaceHit) {
        guard let slot = defining else {
            choose(hit)
            dismiss()
            return
        }
        if let spot = SavedPlaces.Spot(name: hit.placeName, latitude: hit.latitude, longitude: hit.longitude) {
            saved.set(slot, to: spot)
        }
        defining = nil
        query = ""
    }

    /// Asks once while undecided, then one fix. A refusal or a failed lookup stays in the sheet as a
    /// grey line, no dialog; the failure itself is logged by the lookup.
    private func useCurrentLocation(_ location: any CurrentLocating) async {
        locating = true
        locationStatus = nil
        let outcome = await CurrentLocationLookup.run(location)
        switch outcome {
        case .fix(let fix):
            let name = await location.placeName(for: fix) ?? CurrentLocation.fallbackName
            locating = false
            choose(PlaceHit(id: "current", name: name, locality: nil, latitude: fix.latitude, longitude: fix.longitude))
            dismiss()
        case .refused:
            locating = false
            locationStatus = .refused
        case .unavailable:
            locating = false
            locationStatus = .unavailable
        }
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
