#if os(macOS)
import XCTest

/// #544 (Henning, 2026-10-18 and 2026-10-19, TestFlight builds 87 and 89 on the Mac): in the detail, title,
/// subtasks, File and Photo do not answer. The first version of this test was green while Henning's app
/// failed, for three reasons this version removes:
/// 1. The CI app ran without the App Sandbox (ad hoc, entitlements stripped). The job now signs it with
///    the sandbox entitlements of the real app (`scripts/mac_ci_entitlements.py`).
/// 2. It clicked the centre of each field after scrolling and with the focus already in the detail. Each
///    test now starts the app afresh and clicks where a person reads the words, at the leading edge.
/// 3. It opened the detail from New only. It now opens it from Loose ends, the list Henning works in.
/// Runs in the CI job "Mac Gallery (macOS)"; its pictures leave as `mac-gallery-544-*`.
final class MacDetailClickTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// XCUITest's private flag, the same on iOS and the Mac: whether the element takes typing now.
    @MainActor
    private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    /// A fresh app with one task, its detail open from Loose ends.
    @MainActor
    private func openDetail(_ text: String) -> (XCUIApplication, XCUIElement) {
        let app = macLaunch(dark: false)
        let window = macOpenDetail(of: text, in: app, list: "viewRow_open")
        return (app, window)
    }

    /// The detail's own scroll view, not the sidebar's: the one holding the title field.
    @MainActor
    private func detailScroll(in window: XCUIElement) -> XCUIElement {
        window.scrollViews.containing(.any, identifier: "detailTitleField").firstMatch
    }

    /// Scrolls the detail until the element is in reach; the Mac does not scroll for a click by itself.
    @MainActor
    private func reveal(_ id: String, in window: XCUIElement) -> XCUIElement {
        let target = macElement(id, in: window)
        let scroll = detailScroll(in: window)
        for _ in 0..<8 where !(target.exists && target.isHittable) {
            if scroll.exists { scroll.scroll(byDeltaX: 0, deltaY: -200) }
            RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        }
        XCTAssertTrue(target.waitForExistence(timeout: 5), "Detail shows no \(id)")
        XCTAssertTrue(target.isHittable, "\(id) stays out of reach after scrolling")
        return target
    }

    /// Where a person clicks into a text field: on its words at the leading edge, not the centre of
    /// its accessibility frame, which can sit right of what one sees.
    @MainActor
    private func clickWords(of field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.06, dy: 0.5)).click()
    }

    // MARK: - Pickers

    /// A system picker in front of the window: a sheet or dialog of the app. In the sandbox the open
    /// panel is drawn by a system service but still hangs as a sheet on the app's window. Asking XCUITest
    /// for that service as an app of its own throws when it does not run (run 39209916143).
    @MainActor
    private func pickerCount(_ app: XCUIApplication) -> Int {
        app.sheets.count + app.dialogs.count
    }

    @MainActor
    private func waitForPicker(_ shown: Bool, baseline: Int, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (pickerCount(app) > baseline) == shown { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return (pickerCount(app) > baseline) == shown
    }

    /// Cancel inside the sheet or dialog itself: `app.buttons["Cancel"]` finds the Touch Bar's first,
    /// which XCUITest cannot click (run 39148286538). Without one, Escape closes the panel.
    @MainActor
    private func dismissPicker(in app: XCUIApplication) {
        for container in [app.sheets.firstMatch, app.dialogs.firstMatch] where container.exists {
            let cancel = container.buttons["Cancel"].firstMatch
            if cancel.exists && cancel.isHittable {
                cancel.click()
                return
            }
        }
        app.typeKey(.escape, modifierFlags: [])
    }

    /// Words on screen, wherever the Mac keeps them: a selectable `Text` reports an empty label and
    /// carries its words as value, or as its own static text (run 39148286538).
    @MainActor
    private func shows(_ words: String, in window: XCUIElement) -> Bool {
        window.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words))
            .firstMatch
            .waitForExistence(timeout: 5)
    }

    // MARK: - Tests

    @MainActor
    func testTitleTakesAClickAndKeepsTheNewWords() throws {
        let (app, window) = openDetail("Rasen mähen")
        let title = macElement("detailTitleField", in: window)
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Detail shows no title field")
        clickWords(of: title)
        XCTAssertTrue(hasKeyboardFocus(title), "A click on the title should put the cursor there")
        title.typeKey("a", modifierFlags: .command)
        title.typeText("Rasen mähen am Samstag\n")
        macShot(window, "mac-gallery-544-1-title-typed")

        // Saved, not only typed: the "Said" line appears only once the stored title differs from the
        // raw text. (Clicking "Loose ends" again does not leave the detail while that row stays selected,
        // run 39209916143.)
        XCTAssertTrue(macElement("detailRawText", in: window).waitForExistence(timeout: 5),
                      "The new title should be stored: the said line shows only when the title differs")
        XCTAssertTrue(shows("Samstag", in: window), "The title should hold the typed words")
        app.terminate()
    }

    @MainActor
    func testNoteTakesAClickAndIsSaved() throws {
        let (app, window) = openDetail("Schlüssel abholen")
        let note = reveal("noteField", in: window)
        clickWords(of: note)
        XCTAssertTrue(hasKeyboardFocus(note), "A click on Note should put the cursor there")
        note.typeText("liegt unter der Matte")
        // Leaving the field writes the note: the title takes the focus.
        clickWords(of: macElement("detailTitleField", in: window))
        XCTAssertTrue(macElement("noteText", in: window).waitForExistence(timeout: 5), "Leaving the note should show it as text")
        XCTAssertTrue(shows("Matte", in: window), "The note at rest should hold the typed words")
        macShot(window, "mac-gallery-544-2-note-saved")
        app.terminate()
    }

    @MainActor
    func testSubtaskIsAddedByClickAndCheckedByClick() throws {
        let (app, window) = openDetail("Einkaufen")
        let field = reveal("subtaskTextField", in: window)
        clickWords(of: field)
        XCTAssertTrue(hasKeyboardFocus(field), "A click on Add a subtask should put the cursor there")
        field.typeText("Milch\n")
        let line = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subtaskRow_"))
            .firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Return should list the subtask")
        XCTAssertTrue(line.label.contains("Milch"), "Subtask row was \(line.label)")

        // The footer reads "0 of 1 done" as soon as the line exists; only "1 of 1" proves the click.
        // A Mac `Text` may carry its words as value with an empty label (run 39209916143).
        line.click()
        let checked = NSPredicate(format: "label CONTAINS '1 of 1' OR value CONTAINS '1 of 1'")
        let progress = window.descendants(matching: .any).matching(checked).firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "A click on the subtask should check it off: 1 of 1 done")
        macShot(window, "mac-gallery-544-3-subtask-checked")
        app.terminate()
    }

    @MainActor
    func testFileOpensTheOpenPanel() throws {
        let (app, window) = openDetail("Vertrag ablegen")
        let file = reveal("addFileButton", in: window)
        let baseline = pickerCount(app)
        file.click()
        XCTAssertTrue(waitForPicker(true, baseline: baseline, in: app, timeout: 15), "File should open the open panel")
        macShot(window, "mac-gallery-544-4-file-panel")
        dismissPicker(in: app)
        XCTAssertTrue(waitForPicker(false, baseline: baseline, in: app, timeout: 10), "Cancel should close the open panel")
        app.terminate()
    }

    @MainActor
    func testPhotoOpensThePhotoPicker() throws {
        let (app, window) = openDetail("Foto vom Zähler")
        let photo = reveal("addPhotoButton", in: window)
        let baseline = pickerCount(app)
        photo.click()
        XCTAssertTrue(waitForPicker(true, baseline: baseline, in: app, timeout: 15), "Photo should open the photo picker")
        macShot(window, "mac-gallery-544-5-photo-picker")
        dismissPicker(in: app)
        app.terminate()
    }
}
#endif
