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

        let add = reveal("addPlaceButton", in: app)
        XCTAssertTrue(add.exists, "Detail should offer Add place")
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
        let note = element("placeEventNote", in: app)
        XCTAssertTrue(note.label.contains("arrive"), "A new place reminds on arrival, note was \(note.label)")

        app.buttons["Leave"].firstMatch.tap()
        XCTAssertTrue(
            NSPredicate(format: "label CONTAINS 'leave'").evaluate(with: element("placeEventNote", in: app)),
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
        XCTAssertTrue(reveal("addPlaceButton", in: app).exists, "After removing, Add place should be back")
    }
}
