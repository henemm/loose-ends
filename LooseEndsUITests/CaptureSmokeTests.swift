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
    func testTaskDetailShowsRawText() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Dachrinne reinigen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()

        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Dachrinne reinigen")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Task row should be listed in New")
        row.tap()

        let rawText = element("detailRawText", in: app)
        XCTAssertTrue(rawText.waitForExistence(timeout: 5), "Detail should show the raw text")
        XCTAssertEqual(rawText.label, "Dachrinne reinigen")
        let titleField = element("detailTitleField", in: app)
        XCTAssertTrue(titleField.exists, "Detail should offer the title field")
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

    @MainActor
    func testDoneFromMenuEmptiesNew() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Fenster putzen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()

        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Fenster putzen")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Task row should be listed in New")
        row.press(forDuration: 1.0)

        let done = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDone", "Complete"))
            .firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Long press should open the menu with Complete")
        done.tap()

        XCTAssertTrue(element("emptyViewLabel", in: app).waitForExistence(timeout: 5), "New should be empty after Done")
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "The finished task should leave New")
    }

    @MainActor
    func testNewProjectAppearsOnStartScreen() throws {
        let app = launch()

        let newProject = element("newProjectButton", in: app)
        XCTAssertTrue(newProject.waitForExistence(timeout: 10), "Start screen should offer New project")
        newProject.tap()

        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5), "Name alert did not open")
        nameField.tap()
        nameField.typeText("Haus")

        let add = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "nameSaveButton", "Add"))
            .firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let projectRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "projectRow_"))
            .firstMatch
        XCTAssertTrue(projectRow.waitForExistence(timeout: 5), "The new project should be listed")
        XCTAssertTrue(projectRow.label.contains("Haus"), "Row label was \(projectRow.label)")
    }

    @MainActor
    func testImportanceEditorUpdatesDetail() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Reifen wechseln")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Reifen wechseln")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let importanceRow = element("field_importance", in: app)
        XCTAssertTrue(importanceRow.waitForExistence(timeout: 5), "Detail should list Importance")
        importanceRow.tap()

        let high = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "High")).firstMatch
        XCTAssertTrue(high.waitForExistence(timeout: 5), "Editor should offer High")
        high.tap()

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()

        XCTAssertTrue(importanceRow.waitForExistence(timeout: 5))
        XCTAssertTrue(importanceRow.label.contains("High"), "Row label was \(importanceRow.label)")
    }
}
