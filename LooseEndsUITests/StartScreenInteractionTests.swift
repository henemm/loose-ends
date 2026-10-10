import XCTest

/// The start screen's "Next up" preview acts like the list (#303): swipe right is Done with Undo,
/// the long-press menu holds the rest. Runs against an in-memory store (`--ui-testing`).
final class StartScreenInteractionTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The long Done window keeps Undo on screen for a slow runner (#172).
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-long-done-window", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func firstElement(prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    /// One captured task, lined up in Next up from the New list, then back on the start screen.
    @MainActor
    private func captureAndLineUp(_ text: String, in app: XCUIApplication) {
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText(text)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no New")
        newRow.tap()
        let row = firstElement(prefix: "taskRow_", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        row.swipeLeft()
        let nextUp = app.buttons["Next up"]
        XCTAssertTrue(nextUp.waitForExistence(timeout: 5), "Swipe left offers no Next up")
        nextUp.tap()
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
    }

    @MainActor
    func testPreviewRowSwipesToDoneAndBack() throws {
        let app = launch()
        captureAndLineUp("Rechnung bezahlen", in: app)

        let preview = firstElement(prefix: "nextUpPreview_", in: app)
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Start screen shows no Next up preview")
        preview.swipeRight()
        let complete = app.buttons["Complete"]
        if complete.waitForExistence(timeout: 2) { complete.tap() }

        let undo = firstElement(prefix: "undoComplete_", in: app)
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Swipe right on the start screen should start Done with Undo")
        undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5), "Undo should take the Done back")
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "The task stays in the preview after Undo")
    }

    @MainActor
    func testPreviewRowHasLongPressMenu() throws {
        let app = launch()
        captureAndLineUp("Auto waschen", in: app)

        let preview = firstElement(prefix: "nextUpPreview_", in: app)
        XCTAssertTrue(preview.waitForExistence(timeout: 5), "Start screen shows no Next up preview")
        let remove = app.buttons["Remove from Next up"]
        // A slow runner can miss the first press (#114).
        for duration in [1.2, 2.0, 3.0] where !remove.exists {
            preview.press(forDuration: duration)
            _ = remove.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(remove.exists, "Long press on the start screen should open the task menu")
        XCTAssertTrue(app.buttons["Park"].exists, "The menu should offer Park")
        remove.tap()
        XCTAssertTrue(preview.waitForNonExistence(timeout: 5), "Removed from Next up, the task leaves the preview")
    }
}
