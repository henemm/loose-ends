import XCTest

/// Smoke test for the first end-to-end path: capture a task, find it in "New".
/// Runs against an in-memory store (`--ui-testing`), so it never touches real data.
final class CaptureSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    /// Any element carrying the identifier, whatever control SwiftUI backs it with.
    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    func testCapturedTaskShowsUpInNew() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "Capture button missing on the start screen")
        captureButton.tap()

        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText("Rasenmäher Ölwechsel")

        let done = app.buttons["captureDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isEnabled, "Done must be enabled once there is text")
        done.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet should close after Done")

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "View list should show New")
        newRow.tap()

        let captured = app.staticTexts.matching(NSPredicate(format: "label == %@", "Rasenmäher Ölwechsel")).firstMatch
        XCTAssertTrue(captured.waitForExistence(timeout: 5), "Captured task should appear in New")
    }

    @MainActor
    func testDoneIsDisabledWhileEmptyAndCancelCloses() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()

        let done = app.buttons["captureDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertFalse(done.isEnabled, "Done must stay disabled without text")

        app.buttons["captureCancelButton"].tap()
        XCTAssertTrue(done.waitForNonExistence(timeout: 5), "Cancel should close the sheet")
    }
}
