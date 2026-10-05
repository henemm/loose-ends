import XCTest

/// #28: in a project, a task's subtasks are folded; the arrow folds them out indented below it,
/// and a tap on a line checks it off. Runs against the in-memory store of `--ui-testing`.
final class ProjectSubtasksTests: XCTestCase {
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
    private func first(prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    @MainActor
    private func back(in app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
    }

    @MainActor
    func testSubtasksFoldOutInTheProjectAndCheckOff() throws {
        let app = launch()

        // A project to put the task in.
        let newProject = element("newProjectButton", in: app)
        XCTAssertTrue(newProject.waitForExistence(timeout: 10))
        newProject.tap()
        let nameField = app.textFields.firstMatch
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Haus")
        let add = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "nameSaveButton", "Add"))
            .firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(first(prefix: "projectRow_", in: app).waitForExistence(timeout: 5), "The project should be listed")

        // A task with one subtask.
        app.buttons["captureButton"].tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Keller entrümpeln")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = first(prefix: "taskRow_", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let subtaskField = element("subtaskTextField", in: app)
        if !subtaskField.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(subtaskField.waitForExistence(timeout: 5), "Detail should offer a subtask field")
        subtaskField.tap()
        subtaskField.typeText("Regal abbauen")
        app.buttons["subtaskAddButton"].tap()
        XCTAssertTrue(first(prefix: "subtaskRow_", in: app).waitForExistence(timeout: 5), "The subtask should be listed")

        // Into the project: empty fields wait behind "Add detail" (#187).
        app.swipeDown()
        let projectField = element("field_project", in: app)
        if !projectField.waitForExistence(timeout: 2) {
            let addDetail = element("addDetailRow", in: app)
            if !addDetail.waitForExistence(timeout: 2) { app.swipeDown() }
            XCTAssertTrue(addDetail.waitForExistence(timeout: 5), "Detail should offer Add detail")
            addDetail.tap()
        }
        XCTAssertTrue(projectField.waitForExistence(timeout: 5), "Detail should list Project")
        projectField.tap()
        let haus = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Haus")).firstMatch
        XCTAssertTrue(haus.waitForExistence(timeout: 5), "The editor should offer the project")
        haus.tap()

        back(in: app)   // editor → detail
        back(in: app)   // detail → New
        back(in: app)   // New → start screen
        let projectRow = first(prefix: "projectRow_", in: app)
        XCTAssertTrue(projectRow.waitForExistence(timeout: 5))
        projectRow.tap()

        // Folded, then folded out, then checked off, then folded again.
        XCTAssertTrue(first(prefix: "taskRow_", in: app).waitForExistence(timeout: 5), "The task should be in the project")
        let line = first(prefix: "projectSubtask_", in: app)
        XCTAssertFalse(line.exists, "Subtasks start folded")
        let disclosure = first(prefix: "disclosure_", in: app)
        XCTAssertTrue(disclosure.waitForExistence(timeout: 5), "A task with subtasks carries the arrow")
        disclosure.tap()
        XCTAssertTrue(line.waitForExistence(timeout: 5), "The arrow should fold the subtask out")
        XCTAssertTrue(line.label.contains("Regal abbauen"), "Line label was \(line.label)")

        line.tap()
        let checked = NSPredicate(format: "value == %@", "Completed")
        let expectation = XCTNSPredicateExpectation(predicate: checked, object: line)
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed,
                       "A tap should check the subtask off, value was \(String(describing: line.value))")

        disclosure.tap()
        XCTAssertTrue(line.waitForNonExistence(timeout: 5), "The arrow should fold the subtask in again")
    }
}
