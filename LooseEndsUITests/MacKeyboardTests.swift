#if os(macOS)
import XCTest

/// #480 Schnitt 1 (Epic #467, board "Zeiger und Tastatur"): a list row is chosen with the arrow keys, Space
/// finishes it through the Undo window (#32), Delete asks first, and none of it touches a text field.
/// A click still opens the task and now also marks its row. The marked row exposes the selected trait on
/// the element that carries `taskRow_<id>`.
///
/// The list has no search field; the text-focus case uses the detail's title field, which stands beside
/// the list in the same window.
/// Runs in the CI job "Mac Gallery (macOS)", in the sandbox of the real app, next to `MacDetailClickTests`;
/// its pictures leave as `mac-gallery-480-*`.
final class MacKeyboardTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// A fresh app with three tasks, Loose ends open. Rows come back top to bottom.
    @MainActor
    private func openList(dark: Bool = false) -> (XCUIApplication, XCUIElement, [XCUIElement]) {
        let app = macLaunch(dark: dark)
        _ = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        for text in ["Rasen mähen", "Schlüssel abholen", "Vertrag ablegen"] {
            macCapture(text, in: app)
        }
        let window = macMainWindow(of: app)
        let listRow = macElement("viewRow_open", in: window)
        XCTAssertTrue(listRow.waitForExistence(timeout: 10), "Sidebar shows no viewRow_open")
        listRow.click()
        let rows = waitForRows(3, in: window)
        XCTAssertEqual(rows.count, 3, "Loose ends should list the three captured tasks")
        return (app, window, rows)
    }

    @MainActor
    private func taskRows(in window: XCUIElement) -> [XCUIElement] {
        window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .allElementsBoundByIndex
            .filter { $0.exists }
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    @MainActor
    private func waitForRows(_ count: Int, in window: XCUIElement, timeout: TimeInterval = 10) -> [XCUIElement] {
        let deadline = Date().addingTimeInterval(timeout)
        var rows = taskRows(in: window)
        while rows.count != count, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
            rows = taskRows(in: window)
        }
        return rows
    }

    @MainActor
    private func waitUntil(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }

    @MainActor
    private func id(of row: XCUIElement) -> String { row.identifier }

    @MainActor
    private func undoButtons(in window: XCUIElement) -> XCUIElementQuery {
        window.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "undoComplete_"))
    }

    /// A click opens the task in the detail and marks its row; the list keeps the keys from there.
    @MainActor
    private func clickRow(_ row: XCUIElement, in window: XCUIElement) {
        row.click()
        XCTAssertTrue(macElement("detailRawTextMarker", in: window).waitForExistence(timeout: 10), "Detail did not open")
    }

    @MainActor
    private func selectedRows(in window: XCUIElement) -> [String] {
        taskRows(in: window).filter { $0.isSelected }.map { $0.identifier }
    }

    // MARK: - Arrows, Space

    @MainActor
    func testArrowsSelectAndSpaceCompletes() throws {
        let (app, window, rows) = openList()
        let ids = rows.map { id(of: $0) }
        clickRow(rows[0], in: window)
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[0]] }, "A click should mark the row it opens")

        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Down should choose the second row, marked: \(selectedRows(in: window))")
        app.typeKey(.upArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[0]] }, "Up should go back to the first row")
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Down should choose the second row again")

        app.typeKey(" ", modifierFlags: [])
        let undo = undoButtons(in: window).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Space should start the Done window with Undo")
        XCTAssertEqual(undo.identifier, "undoComplete_" + String(ids[1].dropFirst("taskRow_".count)), "Undo should belong to the chosen row")
        macShot(window, "mac-gallery-480-1-space-undo-window")

        let left = waitForRows(2, in: window, timeout: 12).map { id(of: $0) }
        XCTAssertEqual(left, [ids[0], ids[2]], "Only the chosen task should be done; the others stay")
        app.terminate()
    }

    // MARK: - Delete

    @MainActor
    func testDeleteAsksFirst() throws {
        let (app, window, rows) = openList()
        let ids = rows.map { id(of: $0) }
        clickRow(rows[0], in: window)
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Down should choose the second row")

        app.typeKey(.delete, modifierFlags: [])
        let confirm = macElement("confirmDeleteButton", in: app)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete should ask \"Delete this task?\" first")
        XCTAssertEqual(taskRows(in: window).count, 3, "Nothing is deleted before the answer")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Escape should close the question")
        XCTAssertEqual(taskRows(in: window).count, 3, "Cancelling deletes nothing")

        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete should ask again")
        confirm.click()
        let left = waitForRows(2, in: window).map { id(of: $0) }
        XCTAssertEqual(left, [ids[0], ids[2]], "Only the chosen task should be deleted")
        app.terminate()
    }

    // MARK: - Text focus

    @MainActor
    func testTextFocusKeepsKeys() throws {
        let (app, window, rows) = openList()
        let ids = rows.map { id(of: $0) }
        clickRow(rows[0], in: window)
        // The row is chosen first, so that a text field which lets the keys through would do harm.
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Down should choose the second row")

        let title = macElement("detailTitleField", in: window)
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Detail shows no title field")
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5)).click()
        title.typeKey(" ", modifierFlags: [])
        title.typeKey(.delete, modifierFlags: [])
        title.typeKey(.delete, modifierFlags: [])

        XCTAssertFalse(undoButtons(in: window).firstMatch.waitForExistence(timeout: 2), "Space in a text field must not finish a task")
        XCTAssertFalse(macElement("confirmDeleteButton", in: app).exists, "Delete in a text field must not ask to delete a task")
        XCTAssertEqual(taskRows(in: window).count, 3, "No task should have gone")
        app.terminate()
    }

    // MARK: - Click

    @MainActor
    func testClickOpensAndMarks() throws {
        let (app, window, rows) = openList()
        let ids = rows.map { id(of: $0) }
        clickRow(rows[1], in: window)
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "The clicked row should be marked: \(selectedRows(in: window))")
        XCTAssertTrue(macElement("detailTitleField", in: window).waitForExistence(timeout: 5), "The click should still open the task")
        app.terminate()
    }

    // MARK: - Shortcuts that stay (AC-8)

    @MainActor
    func testShortcutsAndContextMenu() throws {
        let (app, window, rows) = openList()

        // ⌘N from a list opens the capture sheet (on the start page it goes into the field).
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(macElement("captureTextField", in: app).waitForExistence(timeout: 10), "⌘N opened no capture")
        app.typeKey(.escape, modifierFlags: [])

        // ⌘, opens the settings window.
        app.typeKey(",", modifierFlags: .command)
        let settings = app.windows.containing(.any, identifier: "reminderTimePicker").firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 10), "⌘, opened no settings window")
        app.typeKey("w", modifierFlags: .command)

        // The right click shows the row's menu, the same entries as on the iPhone.
        rows[0].rightClick()
        XCTAssertTrue(app.menuItems["Delete"].firstMatch.waitForExistence(timeout: 5)
                      || macElement("menuDelete", in: app).waitForExistence(timeout: 5),
                      "Right click should show the row's menu with Delete")
        app.typeKey(.escape, modifierFlags: [])
        app.terminate()
    }

    // MARK: - Pictures (AC-3)

    @MainActor
    private func photographSelection(dark: Bool, name: String) {
        let (app, window, rows) = openList(dark: dark)
        let ids = rows.map { id(of: $0) }
        clickRow(rows[0], in: window)
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Down should choose the second row")
        macShot(window, name)
        app.terminate()
    }

    @MainActor
    func testSelectionPhotoLight() throws {
        photographSelection(dark: false, name: "mac-gallery-480-selection-light")
    }

    @MainActor
    func testSelectionPhotoDark() throws {
        photographSelection(dark: true, name: "mac-gallery-480-selection-dark")
    }
}
#endif
