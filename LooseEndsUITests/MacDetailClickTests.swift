#if os(macOS)
import XCTest

/// #544 (Henning, 2026-10-18, Mac): a click on Note, "Add a subtask", "Add more" (removed in #560) and the File button
/// in the detail did nothing. The gallery (#511) only photographs; this test clicks. Runs in the CI
/// job "Mac Gallery (macOS)" next to `MacGalleryTests`; its pictures leave as `mac-gallery-544-*`.
/// Written before the fix, so the first run shows red where the Mac really does not answer.
final class MacDetailClickTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// XCUITest's private flag, the same on iOS and the Mac: whether the element takes typing now.
    @MainActor
    private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    /// The detail's own scroll view, not the sidebar's: the one holding the title field.
    @MainActor
    private func detailScroll(in window: XCUIElement) -> XCUIElement {
        window.scrollViews.containing(.any, identifier: "detailTitleField").firstMatch
    }

    /// Scrolls the detail until the element can be clicked; the Mac does not scroll for a click by itself.
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

    /// A system picker in front of the window: the open panel or the photo picker. Both come as a
    /// sheet of the window or a dialog of the app; the count before the click is the baseline.
    @MainActor
    private func pickerCount(_ app: XCUIApplication) -> Int {
        app.sheets.count + app.dialogs.count
    }

    @MainActor
    private func waitForPicker(above baseline: Int, in app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pickerCount(app) > baseline { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return pickerCount(app) > baseline
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

    /// The text of the note at rest, wherever the Mac keeps it: a selectable `Text` reports an
    /// empty label and carries its words as value, or as its own static text (run 39148286538).
    @MainActor
    private func showsText(_ words: String, in window: XCUIElement) -> Bool {
        let holder = window.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", words, words))
            .firstMatch
        return holder.waitForExistence(timeout: 5)
    }

    @MainActor
    func testNoteAndSubtaskTakeAClick() throws {
        let app = macLaunch(dark: false)
        let window = macOpenDetail(of: "Rasen mähen", in: app)

        // Note: a click focuses the field, typing lands, leaving the field writes it.
        let note = reveal("noteField", in: window)
        note.click()
        XCTAssertTrue(hasKeyboardFocus(note), "A click on Note should focus its field")
        note.typeText("Schlüssel liegt unter der Matte")
        macShot(window, "mac-gallery-544-1-note-typed")

        // Subtask: the next click moves the focus there, which commits the note; Return adds the line.
        let subtask = reveal("subtaskTextField", in: window)
        subtask.click()
        XCTAssertTrue(hasKeyboardFocus(subtask), "A click on Add a subtask should focus its field")
        let noteText = macElement("noteText", in: window)
        XCTAssertTrue(noteText.waitForExistence(timeout: 5), "Leaving the note should show it as text")
        XCTAssertTrue(showsText("Matte", in: window), "The note at rest should hold the typed words")
        subtask.typeText("Mäher tanken\n")
        let line = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subtaskRow_"))
            .firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Return should list the subtask")
        XCTAssertTrue(line.label.contains("Mäher"), "Subtask row was \(line.label)")
        macShot(window, "mac-gallery-544-2-subtask-added")
        app.terminate()
    }

    @MainActor
    func testFileAndPhotoButtonsOpenTheirPickers() throws {
        let app = macLaunch(dark: false)
        let window = macOpenDetail(of: "Vertrag ablegen", in: app)

        let file = reveal("addFileButton", in: window)
        let baseline = pickerCount(app)
        file.click()
        XCTAssertTrue(waitForPicker(above: baseline, in: app), "File should open the open panel")
        macShot(window, "mac-gallery-544-4-file-panel")
        dismissPicker(in: app)
        XCTAssertTrue(waitForPickerGone(to: baseline, in: app), "Cancel should close the open panel")

        let photo = reveal("addPhotoButton", in: window)
        photo.click()
        XCTAssertTrue(waitForPicker(above: baseline, in: app), "Photo should open the photo picker")
        macShot(window, "mac-gallery-544-5-photo-picker")
        dismissPicker(in: app)
        app.terminate()
    }

    @MainActor
    private func waitForPickerGone(to baseline: Int, in app: XCUIApplication, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pickerCount(app) <= baseline { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        return pickerCount(app) <= baseline
    }
}
#endif
