import XCTest

/// The writing line under "New" on the iPhone start screen (#601, form 2): Return makes a task at
/// once and opens the button into a drawer that shows it; a tap beside the line folds the drawer,
/// the number keeps counting. Runs against an in-memory store (`--ui-testing`).
final class InboxDrawerSmokeTests: XCTestCase {
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

    @MainActor
    func testReturnOpensTheDrawerAndATapBesideFoldsIt() throws {
        let app = launch()
        let line = element("startCaptureField", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 10), "The start screen shows no writing line")
        XCTAssertFalse(element("inboxBar", in: app).exists, "Nothing to look over yet, so no New in the margin")
        // Calm until used (#677): just the line, the question only once the cursor is in it.
        XCTAssertTrue((line.placeholderValue ?? "").isEmpty, "The unused line should show no question, got \(line.placeholderValue ?? "")")
        shot(app, "601-1-leer")

        line.tap()
        let asking = expectation(for: NSPredicate(format: "placeholderValue == %@", "What should I remember?"), evaluatedWith: line)
        XCTAssertEqual(XCTWaiter.wait(for: [asking], timeout: 5), .completed, "With the cursor in it the line should ask")
        line.typeText("Reifen wechseln am Freitag\n")
        let first = rows(in: app).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Return should put the task into the drawer")
        XCTAssertTrue(first.label.contains("Reifen wechseln"), "The drawer row shows the sorted title, got \(first.label)")
        let head = element("inboxBar", in: app)
        XCTAssertTrue(head.waitForExistence(timeout: 5), "New should stand in the line's margin")
        XCTAssertTrue(head.label.contains("1 to look over"), "New counts the task at once, got \(head.label)")
        XCTAssertTrue(line.exists, "The line stays as the drawer's last row")
        shot(app, "601-2-erste-zeile-in-der-schublade")

        line.typeText("Mama anrufen\n")
        XCTAssertTrue(rows(in: app).count == 2 || rows(in: app).element(boundBy: 1).waitForExistence(timeout: 10), "The second task should follow the first")
        XCTAssertTrue(head.label.contains("2 to look over"), "New counts both, got \(head.label)")
        shot(app, "601-3-zwei-zeilen")

        // A tap on the sentence of the day ends the entry: the drawer folds, the number stays.
        let header = element("startHeader", in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        header.tap()
        XCTAssertTrue(first.waitForNonExistence(timeout: 10), "Ending the entry should fold the drawer")
        XCTAssertTrue(head.label.contains("2 to look over"), "The number keeps counting after folding, got \(head.label)")
        XCTAssertTrue(line.exists, "The line stays after folding")
        shot(app, "601-4-zugeklappt")

        // The tasks wait in New like everything new.
        head.tap()
        let listed = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS 'Reifen wechseln'")).firstMatch
        XCTAssertTrue(listed.waitForExistence(timeout: 10), "New should list the typed task")
    }
}
