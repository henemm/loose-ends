import XCTest

/// Das Knäuel and the beads (#643, #645): one task marked from the long-press menu stands under the
/// date; a second one asks first; completing it takes the row away. A counting task shows the bead
/// and, once completed, the week's string; the sixth mark is not offered. Runs against the in-memory
/// store (`--ui-testing`), where every field is on.
final class DriveSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func elements(prefix: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }

    /// The beads close the start page under the contents (#677): scroll down until `id` stands there.
    @MainActor
    private func scrolledTo(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let target = element(id, in: app)
        for _ in 0..<6 {
            if target.waitForExistence(timeout: 2), target.isHittable { break }
            app.swipeUp()
        }
        return target
    }

    /// Captures one task; it lands in "New".
    @MainActor
    private func capture(_ text: String, in app: XCUIApplication) {
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText(text)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")
    }

    /// Holds the row in "New" whose title contains `title` until the menu shows `menuID`. A slow
    /// runner can miss the first press (#114), so it tries longer presses.
    @MainActor
    @discardableResult
    private func holdRow(titled title: String, until menuID: String, in app: XCUIApplication) -> XCUIElement {
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "taskRow_", title))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no row for \(title)")
        let entry = element(menuID, in: app)
        for duration in [1.2, 2.0, 3.0] where !entry.exists {
            row.press(forDuration: duration)
            _ = entry.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(entry.exists, "The long-press menu of \(title) shows no \(menuID)")
        return entry
    }

    @MainActor
    private func openNew(in app: XCUIApplication) {
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no New")
        newRow.tap()
    }

    @MainActor
    private func back(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
    }

    /// Set from the menu, the task stands under the date; a second one asks and takes the mark; swipe
    /// right completes it and the row goes.
    @MainActor
    func testKnaeuelUnderTheDateMovesWithAQuestionAndGoesWhenDone() throws {
        let app = launch()
        capture("Steuerberater anrufen", in: app)
        capture("Hecke schneiden", in: app)

        openNew(in: app)
        holdRow(titled: "Steuerberater", until: "menuKnaeuel", in: app).tap()
        back(in: app)

        let rows = elements(prefix: "knaeuelRow_", in: app)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "The Knäuel does not stand under the date")
        XCTAssertTrue(element("knaeuelHead", in: app).exists, "Date and row should stand as the Knäuel's head (#644)")
        XCTAssertTrue(rows.firstMatch.label.contains("Steuerberater"), "Wrong task under the date: \(rows.firstMatch.label)")
        XCTAssertEqual(rows.count, 1)
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "nowRow_", "Steuerberater"))
            .firstMatch.exists, "Now must not show the Knäuel again")

        // The second task asks first and then takes the mark.
        openNew(in: app)
        holdRow(titled: "Hecke", until: "menuKnaeuel", in: app).tap()
        let move = element("confirmKnaeuelMove", in: app)
        XCTAssertTrue(move.waitForExistence(timeout: 5), "No question before the Knäuel moves")
        move.tap()
        back(in: app)
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5), "No Knäuel under the date after the move")
        XCTAssertTrue(rows.firstMatch.label.contains("Hecke"), "The Knäuel did not move: \(rows.firstMatch.label)")
        XCTAssertEqual(rows.count, 1)

        // Swipe right completes it; after the Done window the row is gone.
        rows.firstMatch.swipeRight()
        let complete = app.buttons["Complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "Swipe right offers no Complete")
        complete.tap()
        XCTAssertTrue(rows.firstMatch.waitForNonExistence(timeout: 10), "The completed Knäuel still stands under the date")
        // The moment (#644) keeps the head for 1.1 s, then the knot's date line stands alone.
        XCTAssertTrue(element("knaeuelHead", in: app).waitForNonExistence(timeout: 10), "The head should go after the moment")
        XCTAssertTrue(element("startHeader", in: app).exists)
    }

    /// "Für die Perlen" (#647, #655): written in Settings › Fields, the sentence stands on the start page
    /// under the string, once the string has a bead; a tap on it opens the field there.
    @MainActor
    func testRewardWrittenInSettingsShowsOnTheStartPage() throws {
        let app = launch()
        // One bead first: without it the sentence stays in Settings (Henning, build 110).
        capture("Apfel kaufen", in: app)
        openNew(in: app)
        holdRow(titled: "Apfel", until: "menuCounts", in: app).tap()
        holdRow(titled: "Apfel", until: "menuDone", in: app).tap()
        back(in: app)
        XCTAssertTrue(scrolledTo("weekString", in: app).exists, "No string with the bead")

        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
        app.buttons["settingsButton"].tap()
        let fieldsRow = element("fieldsRow", in: app)
        for _ in 0..<4 where !(fieldsRow.exists && fieldsRow.isHittable) { app.swipeUp() }
        XCTAssertTrue(fieldsRow.waitForExistence(timeout: 5), "Settings should offer Fields")
        fieldsRow.tap()
        let field = element("rewardField", in: app)
        for _ in 0..<6 where !(field.exists && field.isHittable) { app.swipeUp() }
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Fields should hold the Dafür field under Counts")
        field.tap()
        field.typeText("Samstag Kino\n")

        app.navigationBars.buttons.firstMatch.tap()
        let done = app.buttons["settingsDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        let line = scrolledTo("rewardLine", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 5), "The start page should show the sentence under the string")
        XCTAssertTrue(line.label.contains("Samstag Kino"), "Wrong sentence: \(line.label)")
        line.tap()
        XCTAssertTrue(element("rewardField", in: app).waitForExistence(timeout: 5), "A tap should put the cursor into the sentence")
    }

    /// "Counts" from the menu shows the bead in the row; with five open counting tasks the sixth sees
    /// "Counts (5 of 5)" grey; completing a counting task puts its bead on the week's string under "Now".
    @MainActor
    func testCountsShowsTheBeadAndTheWeekString() throws {
        let app = launch()
        let titles = ["Apfel", "Birne", "Kirsche", "Dattel", "Erdbeere", "Feige"]
        for title in titles {
            capture("\(title) kaufen", in: app)
        }
        openNew(in: app)
        for title in titles.prefix(5) {
            holdRow(titled: title, until: "menuCounts", in: app).tap()
            XCTAssertTrue(elements(prefix: "countsMarker_", in: app).firstMatch.waitForExistence(timeout: 5), "No bead in the row of \(title)")
        }
        XCTAssertEqual(elements(prefix: "countsMarker_", in: app).count, 5)

        // The sixth: the entry stands grey as "Counts (5 of 5)"; Complete in the same menu closes it
        // without a bead, since Feige does not count.
        let full = holdRow(titled: "Feige", until: "menuCountsFull", in: app)
        XCTAssertFalse(full.isEnabled, "The sixth mark must not be possible")
        XCTAssertFalse(element("menuCounts", in: app).exists)
        element("menuDone", in: app).tap()

        // Complete a counting task from the menu: the bead appears on the week's string.
        holdRow(titled: "Apfel", until: "menuDone", in: app).tap()
        back(in: app)
        let string = scrolledTo("weekString", in: app)
        XCTAssertTrue(string.exists, "No week string at the end of the start page")
        XCTAssertTrue(string.label.hasPrefix("1 of 5"), "Wrong beads: \(string.label)")
    }
}
