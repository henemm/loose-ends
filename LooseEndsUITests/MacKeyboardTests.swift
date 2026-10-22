#if os(macOS)
import XCTest

/// #480 Schnitt 1 (Epic #467, board "Zeiger und Tastatur"): a list row is chosen with the arrow keys, Space
/// finishes it through the Undo window (#32), Delete asks first, and none of it touches a text field.
/// A click still opens the task and now also marks its row. The marked row exposes the selected trait on
/// the element that carries `taskRow_<id>`.
///
/// On the Mac the detail takes the list's place (one column, "Back" leads on), and the list has no text
/// field: the keys reach the list after a click on its paper, the text-focus case uses the capture field
/// that ⌘N opens.
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

    /// The task rows from one snapshot of the window, top to bottom (#631): identifier, frame and selection
    /// come from one read. Rows bound by index re-resolve per attribute, and a row that left between `exists`
    /// and `frame` (the completed row animating out while `waitForRows` polls) threw "Failed to get matching
    /// snapshot" instead of returning false (PR #628, run 39857377394).
    @MainActor
    private func taskRowSnapshots(in window: XCUIElement) -> [any XCUIElementSnapshot] {
        let root: any XCUIElementSnapshot
        do {
            root = try window.snapshot()
        } catch {
            XCTFail("No snapshot of the window: \(error)")
            return []
        }
        var rows: [any XCUIElementSnapshot] = []
        var pending = root.children
        while let next = pending.popLast() {
            if next.identifier.hasPrefix("taskRow_") { rows.append(next) }
            pending.append(contentsOf: next.children)
        }
        return rows.sorted { $0.frame.minY < $1.frame.minY }
    }

    /// The rows as elements, for clicks; each resolves by its identifier when it is used.
    @MainActor
    private func taskRows(in window: XCUIElement) -> [XCUIElement] {
        taskRowSnapshots(in: window).map { window.descendants(matching: .any).matching(identifier: $0.identifier).firstMatch }
    }

    @MainActor
    private func waitForRows(_ count: Int, in window: XCUIElement, timeout: TimeInterval = 10) -> [XCUIElement] {
        _ = waitUntil(timeout) { taskRowSnapshots(in: window).count == count }
        return taskRows(in: window)
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
    private func undoButtons(in scope: XCUIElement) -> XCUIElementQuery {
        scope.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "undoComplete_"))
    }

    /// A click opens the task: on the Mac the detail takes the list's place.
    @MainActor
    private func clickRow(_ row: XCUIElement, in window: XCUIElement) {
        row.click()
        XCTAssertTrue(macElement("detailRawTextMarker", in: window).waitForExistence(timeout: 10), "Detail did not open")
    }

    /// "Back" from the detail to the list: the toolbar button named so, else the first toolbar button.
    @MainActor
    private func goBack(in window: XCUIElement) {
        let named = window.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Back' OR identifier CONTAINS[c] 'Back'")).firstMatch
        let button = named.waitForExistence(timeout: 3) ? named : window.toolbars.buttons.firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "The detail shows no way back to the list")
        macShot(window, "mac-gallery-480-2-before-back")
        button.click()
        // The list is back when the detail's marker is gone, not merely when rows can be found.
        let gone = macElement("detailRawTextMarker", in: window).waitForNonExistence(timeout: 10)
        macShot(window, "mac-gallery-480-3-after-back")
        XCTAssertTrue(gone, "Back did not leave the detail (clicked: \(button.label) / \(button.identifier))")
        XCTAssertTrue(waitUntil(10) { !taskRows(in: window).isEmpty }, "The list did not come back")
    }

    /// Gives the list the keys the way a person does: a click on the paper below the last row.
    @MainActor
    private func focusList(_ rows: [XCUIElement], in window: XCUIElement) {
        guard let last = rows.last else { return XCTFail("No rows to focus") }
        let origin = window.coordinate(withNormalizedOffset: .zero)
        origin.withOffset(CGVector(dx: last.frame.midX - window.frame.minX, dy: last.frame.maxY - window.frame.minY + 80)).click()
    }

    @MainActor
    private func selectedRows(in window: XCUIElement) -> [String] {
        taskRowSnapshots(in: window).filter { $0.isSelected }.map { $0.identifier }
    }

    // MARK: - Arrows, Space

    @MainActor
    func testArrowsSelectAndSpaceCompletes() throws {
        let (app, window, rows) = openList()
        let ids = rows.map { id(of: $0) }
        focusList(rows, in: window)

        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[0]] }, "Down without a choice should take the first row, marked: \(selectedRows(in: window))")
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
        focusList(rows, in: window)
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Two downs should choose the second row, marked: \(selectedRows(in: window))")

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

    /// The list has no text field and the detail takes its place, so the text focus is the one ⌘N brings:
    /// with a row chosen, Delete goes to the capture field and touches no task.
    @MainActor
    func testTextFocusKeepsKeys() throws {
        let (app, window, rows) = openList()
        let ids = rows.map { id(of: $0) }
        focusList(rows, in: window)
        // The row is chosen first, so that a text field which lets the keys through would do harm.
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Two downs should choose the second row, marked: \(selectedRows(in: window))")

        app.typeKey("n", modifierFlags: .command)
        let field = macElement("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "⌘N opened no capture")
        field.typeText("a b")
        app.typeKey(.delete, modifierFlags: [])
        let value = (field.value as? String) ?? ""
        XCTAssertTrue(value.hasPrefix("a") && !value.contains("b"), "Delete should take the last letter out of the field, it holds \"\(value)\"")

        XCTAssertFalse(undoButtons(in: app).firstMatch.exists, "Space in a text field must not finish a task")
        XCTAssertFalse(macElement("confirmDeleteButton", in: app).exists, "Delete in a text field must not ask to delete a task")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Escape should close the capture")
        XCTAssertEqual(taskRows(in: window).count, 3, "No task should have gone")
        app.terminate()
    }

    // MARK: - Click

    @MainActor
    func testClickOpensAndMarks() throws {
        let (app, window, rows) = openList()
        let ids = rows.map { id(of: $0) }
        clickRow(rows[1], in: window)
        XCTAssertTrue(macElement("detailTitleField", in: window).waitForExistence(timeout: 5), "The click should still open the task")
        goBack(in: window)
        let marked = waitUntil { selectedRows(in: window) == [ids[1]] }
        if !marked {
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "mac-gallery-480-hierarchy-after-back"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        XCTAssertTrue(marked, "The opened row should be marked on the way back: \(selectedRows(in: window)) of \(taskRows(in: window).count) rows")
        app.terminate()
    }

    // MARK: - Shortcuts that stay (AC-8)

    @MainActor
    func testShortcutsAndContextMenu() throws {
        let (app, _, rows) = openList()

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
        focusList(rows, in: window)
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedRows(in: window) == [ids[1]] }, "Two downs should choose the second row")
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

    // MARK: - Start page (#480 Schnitt 2)

    /// A fresh app with `count` tasks due today, start page open. The "Now" rows come back top to bottom,
    /// at most five while the block is folded.
    @MainActor
    private func openStart(_ count: Int = 4, dark: Bool = false) -> (XCUIApplication, XCUIElement, [XCUIElement]) {
        let app = macLaunch(dark: dark)
        _ = macOpenMainWindowIfNeeded(app)
        XCTAssertTrue(macElement("startCaptureField", in: app).waitForExistence(timeout: 20), "No start page")
        for number in 1...count {
            macCapture("Heute Aufgabe \(number)", in: app)
        }
        let window = macMainWindow(of: app)
        let rows = waitForNowRows(min(count, 5), in: window)
        XCTAssertEqual(rows.count, min(count, 5), "Now should show the tasks due today")
        return (app, window, rows)
    }

    @MainActor
    private func nowRows(in window: XCUIElement) -> [XCUIElement] {
        window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "startNowRow_"))
            .allElementsBoundByIndex
            .filter { $0.exists }
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    @MainActor
    private func waitForNowRows(_ count: Int, in window: XCUIElement, timeout: TimeInterval = 10) -> [XCUIElement] {
        _ = waitUntil(timeout) { nowRows(in: window).count == count }
        return nowRows(in: window)
    }

    @MainActor
    private func selectedNowRows(in window: XCUIElement) -> [String] {
        nowRows(in: window).filter { $0.isSelected }.map { $0.identifier }
    }

    /// The task id behind a row, for the Undo button's identifier.
    private func taskID(_ rowID: String) -> String {
        String(rowID.dropFirst("startNowRow_".count))
    }

    /// Back to the start page through its sidebar entry; the start page is built anew.
    @MainActor
    private func backToStart(in window: XCUIElement) {
        let start = macElement("viewRow_start", in: window)
        XCTAssertTrue(start.waitForExistence(timeout: 5), "Sidebar shows no Start page")
        start.click()
        XCTAssertTrue(macElement("detailRawTextMarker", in: window).waitForNonExistence(timeout: 10), "Start page did not come back")
        XCTAssertTrue(waitUntil(10) { !nowRows(in: window).isEmpty }, "Now did not come back")
    }

    /// Chooses the row at `index` with the keys: a click on the paper below the rows, then Down.
    @MainActor
    private func chooseNow(_ index: Int, in app: XCUIApplication, window: XCUIElement) -> [String] {
        let rows = nowRows(in: window)
        let ids = rows.map(\.identifier)
        focusList(rows, in: window)
        for _ in 0...index {
            app.typeKey(.downArrow, modifierFlags: [])
        }
        XCTAssertTrue(waitUntil { selectedNowRows(in: window) == [ids[index]] },
                      "\(index + 1) downs should choose Now row \(index + 1), marked: \(selectedNowRows(in: window))")
        return ids
    }

    @MainActor
    func testStartArrowsSelectAndSpaceCompletes() throws {
        let (app, window, rows) = openStart()
        let ids = rows.map(\.identifier)
        clickRow(rows[0], in: window)
        backToStart(in: window)
        XCTAssertTrue(waitUntil { selectedNowRows(in: window) == [ids[0]] }, "The opened row should be marked")
        focusList(nowRows(in: window), in: window)

        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.upArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedNowRows(in: window) == [ids[1]] }, "Down down up should choose the second row, marked: \(selectedNowRows(in: window))")
        app.typeKey(.upArrow, modifierFlags: [])
        app.typeKey(.upArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedNowRows(in: window) == [ids[0]] }, "Up at the top should stay on the first row")
        app.typeKey(.downArrow, modifierFlags: [])

        app.typeKey(" ", modifierFlags: [])
        let undo = undoButtons(in: window).firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Space should start the Done window with Undo")
        XCTAssertEqual(undo.identifier, "undoComplete_" + taskID(ids[1]), "Undo should belong to the chosen row")
        app.typeKey(" ", modifierFlags: [])
        XCTAssertEqual(undoButtons(in: window).count, 1, "A second Space must not plan anything twice")
        macShot(window, "mac-gallery-480-s2-1-space-undo-window")

        let left = waitForNowRows(3, in: window, timeout: 12).map(\.identifier)
        XCTAssertEqual(left, [ids[0], ids[2], ids[3]], "Only the chosen task should be done; the others stay")
        app.terminate()
    }

    @MainActor
    func testStartMoreExtendsRows() throws {
        let (app, window, rows) = openStart(7)
        let ids = rows.map(\.identifier)
        focusList(rows, in: window)
        for _ in 0..<7 { app.typeKey(.downArrow, modifierFlags: []) }
        XCTAssertTrue(waitUntil { selectedNowRows(in: window) == [ids[4]] }, "Folded, Down should stop on row 5, marked: \(selectedNowRows(in: window))")

        let more = macElement("nowMore", in: window)
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Seven tasks should leave a more row")
        more.click()
        let all = waitForNowRows(7, in: window).map(\.identifier)
        XCTAssertEqual(all.count, 7, "More should show all seven")
        focusList(nowRows(in: window), in: window)
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(waitUntil { selectedNowRows(in: window) == [all[6]] }, "Unfolded, Down should reach row 7, marked: \(selectedNowRows(in: window))")
        app.terminate()
    }

    @MainActor
    func testStartDeleteAsksFirst() throws {
        let (app, window, _) = openStart()
        let ids = chooseNow(1, in: app, window: window)

        app.typeKey(.delete, modifierFlags: [])
        let confirm = macElement("confirmDeleteButton", in: app)
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete should ask \"Delete this task?\" first")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Escape should close the question")
        XCTAssertEqual(nowRows(in: window).count, 4, "Cancelling deletes nothing")

        app.typeKey(.delete, modifierFlags: [])
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete should ask again")
        confirm.click()
        let left = waitForNowRows(3, in: window).map(\.identifier)
        XCTAssertEqual(left, [ids[0], ids[2], ids[3]], "Only the chosen task should be deleted")
        app.terminate()
    }

    /// The writing line sits in the same list as Now: its keys stay in the field.
    @MainActor
    func testStartWritingLineKeepsKeys() throws {
        let (app, window, _) = openStart()
        let ids = chooseNow(1, in: app, window: window)

        let field = macElement("startCaptureField", in: window)
        field.click()
        field.typeText("a b")
        app.typeKey(.delete, modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        let value = (field.value as? String) ?? ""
        XCTAssertTrue(value.hasPrefix("a") && !value.contains("b"), "Delete should take the last letter out of the field, it holds \"\(value)\"")
        XCTAssertFalse(undoButtons(in: window).firstMatch.exists, "Space in the writing line must not finish a task")
        XCTAssertFalse(macElement("confirmDeleteButton", in: app).exists, "Delete in the writing line must not ask to delete a task")
        XCTAssertNotEqual(selectedNowRows(in: window), [ids[2]], "Down in the writing line must not move the choice")
        XCTAssertEqual(nowRows(in: window).count, 4, "No task should have gone")
        app.terminate()
    }

    @MainActor
    func testStartNewTaskShortcutFocusesWritingLine() throws {
        let (app, window, _) = openStart()
        _ = chooseNow(0, in: app, window: window)
        app.typeKey("n", modifierFlags: .command)
        app.typeKey("x", modifierFlags: [])
        let field = macElement("startCaptureField", in: window)
        XCTAssertTrue(waitUntil { ((field.value as? String) ?? "").contains("x") }, "⌘N should put the cursor in the writing line (#472)")
        XCTAssertFalse(undoButtons(in: window).firstMatch.exists, "Nothing should be finished")
        app.terminate()
    }

    @MainActor
    func testStartHasNoListFocusOnAppear() throws {
        let (app, window, _) = openStart()
        let open = macElement("viewRow_open", in: window)
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Sidebar shows no viewRow_open")
        open.click()
        XCTAssertTrue(waitUntil(10) { !taskRows(in: window).isEmpty }, "Loose ends did not open")
        backToStart(in: window)
        app.typeKey(" ", modifierFlags: [])
        app.typeKey(.downArrow, modifierFlags: [])
        XCTAssertTrue(selectedNowRows(in: window).isEmpty, "No row should be chosen when the start page appears")
        XCTAssertFalse(undoButtons(in: window).firstMatch.exists, "Space on a fresh start page must not finish a task")
        app.terminate()
    }

    @MainActor
    func testStartSelectionSurvivesDetail() throws {
        let (app, window, _) = openStart()
        let ids = chooseNow(2, in: app, window: window)
        let open = macElement("viewRow_open", in: window)
        XCTAssertTrue(open.waitForExistence(timeout: 10), "Sidebar shows no viewRow_open")
        open.click()
        XCTAssertTrue(waitUntil(10) { !taskRows(in: window).isEmpty }, "Loose ends did not open")
        backToStart(in: window)
        XCTAssertTrue(waitUntil { selectedNowRows(in: window) == [ids[2]] }, "The choice should survive leaving the start page, marked: \(selectedNowRows(in: window))")
        app.terminate()
    }

    @MainActor
    func testStartSelectionClearsWhenRowGoes() throws {
        let (app, window, _) = openStart()
        _ = chooseNow(1, in: app, window: window)
        app.typeKey(" ", modifierFlags: [])
        XCTAssertEqual(waitForNowRows(3, in: window, timeout: 12).count, 3, "The chosen task should be done")
        XCTAssertTrue(selectedNowRows(in: window).isEmpty, "No row should be chosen once the chosen one is gone")
        app.typeKey(" ", modifierFlags: [])
        XCTAssertFalse(undoButtons(in: window).firstMatch.waitForExistence(timeout: 2), "Space must not move on to another row")
        app.terminate()
    }

    @MainActor
    func testWindowMinimumSize() throws {
        let (app, window, _) = openStart(1)
        let before = window.frame.size
        // A drag at the bottom right corner left the window as it was in runs 39759219395 and
        // 39766895911, and no source says where XCUITest finds the grip. So the test tries the corner,
        // the right edge and the left edge, each pulled towards the middle, stops at the first that
        // changes the size, and keeps a note of every try for the run's attachments.
        var notes = ["screen \(XCUIScreen.main.screenshot().image.size), window \(window.frame)"]
        let middle = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let grips: [(String, CGVector, CGVector)] = [
            ("corner", CGVector(dx: 1, dy: 1), CGVector(dx: -3, dy: -3)),
            ("corner outside", CGVector(dx: 1, dy: 1), CGVector(dx: 3, dy: 3)),
            ("right edge", CGVector(dx: 1, dy: 0.5), CGVector(dx: -2, dy: 0)),
            ("left edge", CGVector(dx: 0, dy: 0.5), CGVector(dx: 2, dy: 0)),
        ]
        for (name, point, offset) in grips {
            let grip = window.coordinate(withNormalizedOffset: point).withOffset(offset)
            grip.press(forDuration: 0.6, thenDragTo: middle, withVelocity: .slow, thenHoldForDuration: 0.3)
            let changed = macWait(timeout: 2) { window.frame.size != before }
            notes.append("\(name): \(window.frame)")
            if changed { break }
        }
        let log = XCTAttachment(string: notes.joined(separator: "\n"))
        log.name = "mac-gallery-480-s2-window-drag"
        log.lifetime = .keepAlways
        add(log)
        macShot(window, "mac-gallery-480-s2-window-after-drag")
        let size = window.frame.size
        let trace = notes.joined(separator: " | ")
        XCTAssertGreaterThanOrEqual(size.width, 760, "The window should not get narrower than 760 pt, it is \(size); tries: \(trace)")
        XCTAssertGreaterThanOrEqual(size.height, 520, "The window should not get lower than 520 pt, it is \(size); tries: \(trace)")
        XCTAssertLessThan(size.width, before.width - 100, "The drag should have shrunk the window from \(before), it is \(size); tries: \(trace)")
        app.terminate()
    }

    @MainActor
    private func photographStartSelection(dark: Bool, name: String) {
        let (app, window, _) = openStart(dark: dark)
        let ids = chooseNow(1, in: app, window: window)
        let other = nowRows(in: window).first { $0.identifier == ids[3] }
        other?.hover()
        macShot(window, name)
        app.terminate()
    }

    @MainActor
    func testStartSelectionPhotoLight() throws {
        photographStartSelection(dark: false, name: "mac-gallery-480-start-selection-light")
    }

    @MainActor
    func testStartSelectionPhotoDark() throws {
        photographStartSelection(dark: true, name: "mac-gallery-480-start-selection-dark")
    }
}
#endif
