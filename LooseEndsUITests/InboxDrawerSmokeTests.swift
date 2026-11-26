import XCTest

/// The writing line on the iPhone start screen (#601, form 2; without "New" since #1000): Return makes a task at
/// once, the drawer shows this sitting's rows above the line; a tap beside the line folds the drawer, and the
/// tasks stand in their lists. Runs against an in-memory store (`--ui-testing`).
final class InboxDrawerSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + LaunchLanguage.arguments
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func rows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'drawerRow_'"))
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// No "New" any more (#1000, ADR-22): no head above the rows, no number; a typed task stands in its list at once.
    @MainActor
    private func assertNoNew(_ app: XCUIApplication, _ moment: String) {
        XCTAssertFalse(element("inboxBar", in: app).exists, "\(moment): no New above the line (#1000)")
        let lookOver = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", LaunchLanguage.phrase("lookOver"))).firstMatch
        XCTAssertFalse(lookOver.exists, "\(moment): nothing to look over any more (#1000)")
    }

    @MainActor
    func testReturnOpensTheDrawerAndATapBesideFoldsIt() throws {
        let app = launch()
        let line = element("startCaptureField", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 10), "The start screen shows no writing line")
        assertNoNew(app, "Before typing")
        // The question shows before the line is used (#693): without it the empty line read as a divider.
        XCTAssertEqual(line.placeholderValue, LaunchLanguage.phrase("question"), "The unused line should ask")
        shot(app, "1000-1-leer")

        line.tap()
        line.typeText("Reifen wechseln am Freitag\n")
        let first = rows(in: app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Return should put the task into the drawer")
        XCTAssertTrue(first.label.contains("Reifen wechseln"), "The drawer row shows the sorted title, got \(first.label)")
        XCTAssertLessThan(first.frame.minY, line.frame.minY, "The row of this sitting stands above the line")
        assertNoNew(app, "After the first Return")
        XCTAssertTrue(line.exists, "The line stays as the drawer's last row")
        shot(app, "1000-2-erste-zeile")

        line.typeText("Mama heute anrufen\n")
        XCTAssertTrue(rows(in: app).count == 2 || rows(in: app).element(boundBy: 1).waitForExistence(timeout: 10), "The second task should follow the first")
        assertNoNew(app, "After the second Return")
        shot(app, "1000-3-zwei-zeilen")

        // A tap on the sentence of the day ends the entry: the drawer folds, the line stays.
        let header = element("startHeader", in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        header.tap()
        XCTAssertTrue(first.waitForNonExistence(timeout: 10), "Ending the entry should fold the drawer")
        XCTAssertTrue(line.exists, "The line stays after folding")
        assertNoNew(app, "After folding")

        // The one said for today stands under "Now" at once.
        let now = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'nowRow_' AND label CONTAINS 'Mama'")).firstMatch
        XCTAssertTrue(now.waitForExistence(timeout: 10), "A task said for today stands under Now at once")
        XCTAssertFalse(element("viewRow_new", in: app).exists, "The index lists no New (#1000)")
        shot(app, "1000-4-zugeklappt")

        // Both stand in "Loose ends" at once, nothing to confirm.
        let open = element("viewRow_open", in: app)
        XCTAssertTrue(open.waitForExistence(timeout: 5), "The index lists Loose ends")
        open.tap()
        let listed = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS 'Reifen wechseln'")).firstMatch
        XCTAssertTrue(listed.waitForExistence(timeout: 10), "Loose ends should list the typed task at once")
        shot(app, "1000-5-lose-enden")
    }

    /// #950: a task typed into the line keeps its own words as title. The model is off under `--ui-testing`, so this
    /// proves the line's path up to the stored task; the channel itself is proven by `KeyboardTitleTests`.
    @MainActor
    func testTypedLineKeepsItsWordingAsTitle() throws {
        let app = launch()
        let line = element("startCaptureField", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 10), "The start screen shows no writing line")
        line.tap()
        line.typeText("Angebot für die Gartenhütte bei Müller einholen\n")

        let first = rows(in: app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Return should put the task into the drawer")
        XCTAssertTrue(first.label.contains("Angebot für die Gartenhütte bei Müller einholen"),
                      "The drawer row should show the typed words, got \(first.label)")
        shot(app, "950-zeile-getippt")
    }
}
