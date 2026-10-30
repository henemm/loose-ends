import XCTest

/// #742 Schnitt 1: the App Store pictures for iPhone and iPad, German and light, portrait. The whole
/// screen with its status bar (`XCUIScreen.main`), five attachments `store-<nn>-<name>`;
/// `./scripts/sim.sh store-screenshots` sets the status bar, exports them and checks the sizes.
/// The tasks are made up and live only in memory (`--ui-testing`). Helpers copied from `DesignGalleryTests`.
final class StoreScreenshotsTests: XCTestCase {
    private static let tasks = [
        "Steuerbescheid heute prüfen",
        "Anna heute wegen Sonntag anrufen",
        "Blumen heute gießen",
        "Rasen mähen",
    ]
    private static let typed = "Fahrrad zur Inspektion bringen"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(de)", "-AppleLocale", "de_DE",
            "-contextsEmptiedByUser", "NO",
            "-startShowsProjects", "NO", "-startShowsContexts", "NO",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func rows(_ prefix: String, containing text: String? = nil, in app: XCUIApplication) -> XCUIElementQuery {
        let predicate = text.map { NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", prefix, $0) }
            ?? NSPredicate(format: "identifier BEGINSWITH %@", prefix)
        return app.descendants(matching: .any).matching(predicate)
    }

    @MainActor
    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "store-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Opens the capture sheet and types; `photograph` takes the picture before "Fertig".
    @MainActor
    private func capture(_ text: String, in app: XCUIApplication, photograph: String? = nil) {
        // iPad portrait: the sidebar's button (compact start branch) comes first, the start page's lies under it.
        let captureButton = element("captureButton", in: app)
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        // A regular width (iPad) focuses the start page's writing line instead of opening the sheet.
        let line = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'startCaptureField' AND hasKeyboardFocus == true")).firstMatch
        if !field.waitForExistence(timeout: 5), line.exists {
            app.typeText(text)
            if let photograph {
                putKeyboardAway(in: app)
                shot(photograph)
            }
            // Put away, the keyboard took the focus along; the typed words stay in the line.
            let typed = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'startCaptureField' AND value == %@", text)).firstMatch
            if !line.exists, typed.exists { typed.tap() }
            app.typeText("\n")   // what was kept is checked later: rows in Jetzt and Neu
            return
        }
        XCTAssertTrue(field.exists, "Capture sheet did not open")
        field.tap()
        field.typeText(text)
        let done = element("captureDoneButton", in: app)
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        if let photograph { shot(photograph) }
        done.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")
    }

    /// The detail as after sorting (F004, Henning 2026-10-30): duration and a tag set by hand, then "Passt".
    /// No model, no stub; opened from "Fällig", the detail shows no review note.
    @MainActor
    private func fillDetail(in app: XCUIApplication) {
        let duration = element("field_duration", in: app)
        XCTAssertTrue(duration.waitForExistence(timeout: 5), "Detail offers no duration")
        duration.tap()
        let thirty = app.buttons.matching(NSPredicate(format: "label == %@", "30 Min.")).firstMatch
        XCTAssertTrue(thirty.waitForExistence(timeout: 5), "Duration editor offers no 30 Min.")
        thirty.tap()   // a single choice closes the editor by itself (#482)

        let tags = element("field_contexts", in: app)
        XCTAssertTrue(tags.waitForExistence(timeout: 5), "Detail offers no tags")
        tags.tap()
        let computer = app.buttons.matching(NSPredicate(format: "label == %@", "Computer")).firstMatch
        XCTAssertTrue(computer.waitForExistence(timeout: 5), "Tags editor offers no Computer")
        if !computer.isSelected { computer.tap() }
        let back = app.navigationBars.buttons
            .matching(NSPredicate(format: "identifier == 'BackButton' OR label IN {'Zurück', 'Back'}")).firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "Tags editor has no back button")
        back.tap()

        // "Passt" vouches for the title; the task stays in "Jetzt", so the detail stays open.
        let confirm = element("detailConfirmButton", in: app)
        if confirm.waitForExistence(timeout: 3) { confirm.tap() }
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Passt stays in the bar")
        XCTAssertFalse(element("reviewNote", in: app).exists, "The detail shows the review note")
        XCTAssertTrue(tags.waitForExistence(timeout: 5) && tags.label.contains("Computer"), "Tag not set: \(tags.label)")
        XCTAssertTrue(duration.label.contains("30"), "Duration not set: \(duration.label)")
    }

    /// The iPad's writing line keeps its focus after Return. Its keyboard sometimes stands over the page and
    /// sometimes waits below the screen (then it exists, but its frame starts under the window). Only a keyboard
    /// on the screen is put away, with its own key; a picture with a keyboard fails the test.
    @MainActor
    private func putKeyboardAway(in app: XCUIApplication) {
        let keyboard = app.keyboards.firstMatch
        _ = keyboard.waitForExistence(timeout: 1)
        let onScreen = { keyboard.exists && keyboard.frame.minY < app.frame.maxY - 1 }
        let hide = keyboard.buttons
            .matching(NSPredicate(format: "label CONTAINS[c] 'ausblenden' OR label CONTAINS[c] 'dismiss'")).firstMatch
        for _ in 0..<3 where onScreen() && hide.exists {
            hide.tap()
            _ = keyboard.waitForNonExistence(timeout: 2)
        }
        XCTAssertFalse(onScreen(), "A keyboard covers the picture (frame \(keyboard.frame))")
    }

    /// Back until the start's "Neu" row can be tapped: two steps on the iPhone (detail, list), one on the
    /// iPad, where the detail replaces the list and the first button brings the sidebar back.
    @MainActor
    private func backToStart(in app: XCUIApplication) {
        let newRow = element("viewRow_new", in: app)
        for _ in 0..<3 where !(newRow.exists && newRow.isHittable) {
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
            back.tap()
            _ = newRow.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(newRow.isHittable, "Not back on the start screen")
    }

    /// Completes a "Jetzt" row from its long-press menu ("Erledigt" alone also names the view row);
    /// the three-second undo window has to run out before the row leaves.
    @MainActor
    private func complete(_ text: String, in app: XCUIApplication) {
        let row = rows("nowRow_", containing: text, in: app).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Jetzt shows no \(text)")
        let done = element("menuDone", in: app)
        // A slow runner can miss the first press (#114).
        for duration in [1.2, 2.0, 3.0] where !done.exists {
            row.press(forDuration: duration)
            _ = done.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(done.exists, "Long press opened no menu with Erledigt")
        done.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 15), "\(text) did not leave Jetzt")
    }

    @MainActor
    func testPhotographStoreScreens() throws {
        let app = launch()
        for text in Self.tasks {
            capture(text, in: app)
        }
        complete("Blumen", in: app)
        capture(Self.typed, in: app, photograph: "02-erfassen")

        let nowRows = rows("nowRow_", in: app)
        XCTAssertTrue(nowRows.firstMatch.waitForExistence(timeout: 15), "Jetzt shows no row")
        XCTAssertGreaterThanOrEqual(nowRows.count, 2, "Jetzt should show at least two rows")
        putKeyboardAway(in: app)
        shot("01-start")

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no Neu")
        newRow.tap()
        let taskRows = rows("taskRow_", in: app)
        XCTAssertTrue(taskRows.firstMatch.waitForExistence(timeout: 10), "Neu shows no task")
        XCTAssertGreaterThanOrEqual(taskRows.count, 2, "Neu should show at least two tasks")
        shot("03-neu")

        // From "Fällig", not from "Neu": only the "Neu" list opens a detail for review, with the grey
        // "Noch nicht sortiert" note (TaskListView `reviewing: kind == .new`, F004). A "Jetzt" row of the
        // iPad's sidebar would stay selected in the picture, white on a frame.
        backToStart(in: app)
        let dueRow = element("viewRow_due", in: app)
        XCTAssertTrue(dueRow.waitForExistence(timeout: 5), "Start screen shows no Fällig")
        dueRow.tap()
        let taxRow = rows("taskRow_", containing: "Steuerbescheid", in: app).firstMatch
        XCTAssertTrue(taxRow.waitForExistence(timeout: 10), "Fällig shows no Steuerbescheid")
        taxRow.tap()
        XCTAssertTrue(element("detailRawTextMarker", in: app).waitForExistence(timeout: 5), "Detail did not open")
        XCTAssertTrue(element("field_dueDate", in: app).waitForExistence(timeout: 5), "Detail shows no due date")
        fillDetail(in: app)
        shot("04-detail")
        backToStart(in: app)

        let doneRow = element("viewRow_done", in: app)
        for _ in 0..<3 where !doneRow.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(doneRow.waitForExistence(timeout: 5), "Start screen shows no Erledigt")
        doneRow.tap()
        XCTAssertTrue(rows("taskRow_", in: app).firstMatch.waitForExistence(timeout: 10), "Erledigt is empty")
        shot("05-erledigt")
    }
}
