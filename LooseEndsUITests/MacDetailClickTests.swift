#if os(macOS)
import XCTest

/// #544 (Henning, 2026-10-18, Mac): a click on Note, "Add a subtask", "Add more" and the File button
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

    @MainActor
    private func dismissPicker(in app: XCUIApplication) {
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.waitForExistence(timeout: 3) {
            cancel.click()
        } else {
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    @MainActor
    func testNoteSubtaskAndSupplementTakeAClick() throws {
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
        XCTAssertTrue(noteText.label.contains("Matte"), "Note was \(noteText.label)")
        subtask.typeText("Mäher tanken\n")
        let line = window.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subtaskRow_"))
            .firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Return should list the subtask")
        XCTAssertTrue(line.label.contains("Mäher"), "Subtask row was \(line.label)")
        macShot(window, "mac-gallery-544-2-subtask-added")

        // Add more: a click focuses the field, the rules read the duration while typing.
        let supplement = reveal("supplementField", in: window)
        supplement.click()
        XCTAssertTrue(hasKeyboardFocus(supplement), "A click on Add more should focus its field")
        supplement.typeText("eine Stunde")
        XCTAssertTrue(macElement("supplementRead_duration", in: window).waitForExistence(timeout: 5),
                      "Add more should read the duration")
        macShot(window, "mac-gallery-544-3-supplement-read")
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
