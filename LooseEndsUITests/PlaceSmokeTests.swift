import XCTest

/// A place set by hand in the detail (#241, Schnitt 3a): search, choose, switch to leave, see the
/// sign in the list, remove. Under `--ui-testing` the search answers with fixed hits, so the test
/// needs neither network nor Apple's search service.
final class PlaceSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Scrolls the detail until the element shows; the place section sits below the calendar.
    @MainActor
    private func reveal(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let target = element(id, in: app)
        for _ in 0..<3 where !target.waitForExistence(timeout: 2) { app.swipeUp() }
        return target
    }

    @MainActor
    func testSetSwitchAndRemovePlace() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let capture = app.buttons["captureButton"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Dübel und Schrauben kaufen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        // The place is offered as a word in the line below the fields (#538).
        let add = reveal("field_place", in: app)
        XCTAssertTrue(add.exists, "Detail should offer Place")
        add.tap()

        let search = element("placeSearchField", in: app)
        if !search.waitForExistence(timeout: 5) { shot(app, "0-no-search-field") }
        XCTAssertTrue(search.exists, "The place sheet should open with a search field. Screen: \(app.debugDescription.prefix(2500))")
        search.tap()
        search.typeText("Bau")
        let hit = element("placeHit_altona", in: app)
        XCTAssertTrue(hit.waitForExistence(timeout: 5), "The search should list Bauhaus, Hamburg-Altona")
        shot(app, "1-place-search")
        hit.tap()

        let placeRow = reveal("placeRow", in: app)
        XCTAssertTrue(placeRow.exists, "The place row should show the chosen place")
        XCTAssertTrue(placeRow.label.contains("Bauhaus, Hamburg-Altona"), "Place row was \(placeRow.label)")
        let note = reveal("placeEventNote", in: app)
        XCTAssertTrue(note.label.contains("arrive"), "A new place reminds on arrival, note was \(note.label)")

        app.buttons["Leave"].firstMatch.tap()
        XCTAssertTrue(
            NSPredicate(format: "label CONTAINS 'leave'").evaluate(with: reveal("placeEventNote", in: app)),
            "Switching to Leave should change the note"
        )
        shot(app, "2-place-detail")

        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Bauhaus"), "The list row should carry the place, was \(row.label)")
        shot(app, "3-list-with-place")

        row.tap()
        let placeAgain = reveal("placeRow", in: app)
        XCTAssertTrue(placeAgain.exists)
        placeAgain.swipeLeft()
        // A swipe action may carry its label instead of its identifier.
        var remove = element("removePlaceButton", in: app)
        if !remove.waitForExistence(timeout: 2) { remove = app.buttons["Remove"].firstMatch }
        XCTAssertTrue(remove.waitForExistence(timeout: 3), "Swiping the place row should offer Remove")
        remove.tap()
        XCTAssertTrue(reveal("field_place", in: app).exists, "After removing, the word Place should be back")
    }

    // MARK: Schnitt 3b (#241): current location, home and work, the two notes

    /// Captures a task, opens its detail and the place sheet. `extra` carries the fixed location of the run:
    /// default is a granted permission and a fix far from Altona; `--ui-testing-location-here` puts the fix on
    /// the Altona hit; `--ui-testing-location-refused` refuses the permission.
    @MainActor
    private func openPlaceSheet(_ app: XCUIApplication, extra: [String] = []) {
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        let capture = app.buttons["captureButton"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Dübel und Schrauben kaufen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let add = reveal("field_place", in: app)
        XCTAssertTrue(add.exists, "Detail should offer Place")
        add.tap()
        XCTAssertTrue(element("placeSearchField", in: app).waitForExistence(timeout: 5), "The place sheet should open")
    }

    @MainActor
    private func chooseAltonaHit(_ app: XCUIApplication) {
        let search = element("placeSearchField", in: app)
        search.tap()
        search.typeText("Bau")
        let hit = element("placeHit_altona", in: app)
        XCTAssertTrue(hit.waitForExistence(timeout: 5), "The search should list Bauhaus, Hamburg-Altona")
        hit.tap()
    }

    /// AC-1: one tap on "Current location" sets the place and closes the sheet.
    @MainActor
    func testCurrentLocationSetsPlaceAndClosesSheet() throws {
        let app = XCUIApplication()
        openPlaceSheet(app)
        let current = element("currentLocationRow", in: app)
        XCTAssertTrue(current.waitForExistence(timeout: 5), "The sheet should offer Current location on iPhone and iPad")
        shot(app, "10-sheet-with-rows")
        current.tap()
        XCTAssertTrue(element("placeSearchField", in: app).waitForNonExistence(timeout: 5), "The sheet should close")
        let placeRow = reveal("placeRow", in: app)
        XCTAssertTrue(placeRow.exists, "The place row should show the current location")
        XCTAssertTrue(placeRow.label.contains("Current location"), "Place row was \(placeRow.label)")
        // The current location is where the device stands, so it is already there: next arrival (spec, AC-8).
        XCTAssertTrue(reveal("placeAlreadyHereNote", in: app).exists, "Standing at the current location says so")
        shot(app, "11-current-location-set")
    }

    /// AC-2: a refused permission keeps the sheet open, names the cause, sets nothing, shows no dialog.
    @MainActor
    func testCurrentLocationRefusedKeepsSheetOpen() throws {
        let app = XCUIApplication()
        openPlaceSheet(app, extra: ["--ui-testing-location-refused"])
        let current = element("currentLocationRow", in: app)
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        current.tap()
        let status = element("currentLocationStatus", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 5), "The row should name the cause")
        XCTAssertTrue(status.label.contains("Location is off"), "Status was \(status.label)")
        XCTAssertTrue(element("placeSearchField", in: app).exists, "The sheet should stay open")
        XCTAssertFalse(app.alerts.firstMatch.exists, "No dialog")
        shot(app, "12-current-location-refused")
        app.buttons["placeSearchCancel"].tap()
        XCTAssertFalse(element("placeRow", in: app).exists, "No place was set")
    }

    /// AC-3 and AC-4: define home from the search, then one tap on it sets the place.
    @MainActor
    func testHomeCanBeDefinedFromSearch() throws {
        let app = XCUIApplication()
        openPlaceSheet(app)
        let home = element("savedPlaceRow_home", in: app)
        XCTAssertTrue(home.waitForExistence(timeout: 5))
        XCTAssertTrue(home.label.contains("Not set yet"), "Home starts undefined, was \(home.label)")
        home.tap()
        chooseAltonaHit(app)
        let defined = element("savedPlaceRow_home", in: app)
        XCTAssertTrue(defined.waitForExistence(timeout: 5), "Back in the sheet after defining")
        XCTAssertTrue(defined.label.contains("Bauhaus, Hamburg-Altona"), "Home row was \(defined.label)")
        XCTAssertTrue(element("placeSearchField", in: app).exists, "Defining a slot does not close the sheet")
        app.buttons["placeSearchCancel"].tap()
        XCTAssertFalse(element("placeRow", in: app).exists, "Defining home gives the task no place")
        shot(app, "13-home-defined")
    }

    @MainActor
    func testHomeRowSetsPlaceWithOneTap() throws {
        let app = XCUIApplication()
        openPlaceSheet(app)
        element("savedPlaceRow_home", in: app).tap()
        chooseAltonaHit(app)
        let defined = element("savedPlaceRow_home", in: app)
        XCTAssertTrue(defined.waitForExistence(timeout: 5))
        defined.tap()
        XCTAssertTrue(element("placeSearchField", in: app).waitForNonExistence(timeout: 5), "The sheet should close")
        let placeRow = reveal("placeRow", in: app)
        XCTAssertTrue(placeRow.label.contains("Bauhaus, Hamburg-Altona"), "Place row was \(placeRow.label)")
    }

    /// AC-5: a refused permission with a place shows the grey note under the place row.
    @MainActor
    func testLocationOffNoteWithRefusedPermission() throws {
        let app = XCUIApplication()
        openPlaceSheet(app, extra: ["--ui-testing-location-refused"])
        chooseAltonaHit(app)
        let note = reveal("placeLocationOffNote", in: app)
        XCTAssertTrue(note.exists, "A refused permission should be named under the place")
        XCTAssertTrue(note.label.contains("Location is off"), "Note was \(note.label)")
        shot(app, "14-location-off")
    }

    /// AC-6: standing at the place says "next time you arrive"; standing elsewhere says nothing.
    @MainActor
    func testAlreadyHereNoteOnlyAtThePlace() throws {
        let here = XCUIApplication()
        openPlaceSheet(here, extra: ["--ui-testing-location-here"])
        chooseAltonaHit(here)
        let note = reveal("placeAlreadyHereNote", in: here)
        XCTAssertTrue(note.exists, "Standing at the place should say so")
        XCTAssertTrue(note.label.contains("already here"), "Note was \(note.label)")
        XCTAssertFalse(element("placeLocationOffNote", in: here).exists)
        shot(here, "15-already-here")
        here.terminate()

        let away = XCUIApplication()
        openPlaceSheet(away)
        chooseAltonaHit(away)
        XCTAssertTrue(reveal("placeRow", in: away).exists)
        XCTAssertFalse(element("placeAlreadyHereNote", in: away).waitForExistence(timeout: 2), "Standing elsewhere says nothing")
    }
}
