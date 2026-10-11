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

    /// In New the check means "looked over" (#318): swipe right never completes there, it offers
    /// "Looks right" for what the AI sorted and nothing for a task that needs a look. Done stays
    /// in the long-press menu. Without Apple Intelligence (the simulator) every new task needs a
    /// look, so the swipe shows nothing; with it, "Looks right". Never "Complete".
    @MainActor
    func testSwipeRightInNewNeverCompletes() throws {
        let app = launch()
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText("Rechnung bezahlen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no New")
        newRow.tap()
        let row = firstElement(prefix: "taskRow_", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        row.swipeRight()
        XCTAssertFalse(app.buttons["Complete"].waitForExistence(timeout: 2), "Swipe right in New must not offer Done")
        XCTAssertFalse(firstElement(prefix: "undoComplete_", in: app).exists, "Swipe right in New must not start Done")
        // With Apple Intelligence a full swipe may already have confirmed the task out of New.
        guard row.exists else { return }

        // Done is still there, one long press away.
        row.press(forDuration: 1.2)
        XCTAssertTrue(element("menuDone", in: app).waitForExistence(timeout: 5), "The long-press menu in New should still offer Done")
    }

    /// A task under "Needs a look" leaves New with "Looks right" in its detail (#318): opening
    /// alone kept an unchecked title in New until it was edited.
    @MainActor
    func testLooksRightInDetailTakesTheTaskOutOfNew() throws {
        let app = launch()
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText("Dachrinne reinigen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no New")
        newRow.tap()
        let row = firstElement(prefix: "taskRow_", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        let id = row.identifier
        row.tap()
        let confirm = element("detailConfirmButton", in: app)
        // With Apple Intelligence the task may already be sorted; then opening was enough.
        guard confirm.waitForExistence(timeout: 5) else { return }
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Looks right should go once the task is confirmed")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
        XCTAssertTrue(element(id, in: app).waitForNonExistence(timeout: 5), "The confirmed task should leave New")
    }

    /// What is due today stands on the start screen under "Next up" (#299). The rule step reads
    /// "heute" without Apple Intelligence, so this holds in the simulator too.
    @MainActor
    func testDueTodayShowsOnTheStartScreen() throws {
        let app = launch()
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText("Heute die Rechnung bezahlen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")

        let due = firstElement(prefix: "dueTodayPreview_", in: app)
        XCTAssertTrue(due.waitForExistence(timeout: 15), "A task due today should show on the start screen")
        XCTAssertTrue(due.label.contains("Rechnung"), "Row label was \(due.label)")
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

    // MARK: - All open (#319)

    /// Without the long Done window: a completed task really leaves the open lists after three seconds.
    @MainActor
    private func launchWithShortDoneWindow() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func capture(_ text: String, in app: XCUIApplication) {
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText(text)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")
    }

    /// Captures one task, opens New (where it is the only one), long-presses it and picks a menu
    /// entry; waits until the task has left New, then goes back to the start screen.
    @MainActor
    private func captureAndPick(_ text: String, _ entry: (XCUIApplication) -> XCUIElement, in app: XCUIApplication) {
        capture(text, in: app)
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no New")
        newRow.tap()
        let row = firstElement(prefix: "taskRow_", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        let item = entry(app)
        // A slow runner can miss the first press (#114).
        for duration in [1.2, 2.0, 3.0] where !item.exists {
            row.press(forDuration: duration)
            _ = item.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(item.exists, "The long-press menu lacks the entry")
        item.tap()
        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "The task should leave New")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
    }

    /// The bottom rows start out of sight on an iPhone (#180): swipe up until the row can be tapped.
    @MainActor
    private func scrollTo(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let row = element(id, in: app)
        for _ in 0..<4 where !(row.waitForExistence(timeout: 2) && row.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Start screen shows no \(id)")
        return row
    }

    /// Rows of the open list; a parked one says "Parked" (the moon) in its combined label.
    /// Buttons only: the list's link cell and its text both carry the row's identifier, so
    /// `.any` would count every row twice.
    @MainActor
    private func taskRows(in app: XCUIApplication, parkedOnly: Bool = false) -> XCUIElementQuery {
        let format = parkedOnly ? "identifier BEGINSWITH 'taskRow_' AND label CONTAINS 'Parked'" : "identifier BEGINSWITH 'taskRow_'"
        return app.buttons.matching(NSPredicate(format: format))
    }

    /// The moon glyph itself (`parkedMarker_<uuid>`): it stays its own image inside the combined row.
    @MainActor
    private func parkedMarkers(in app: XCUIApplication) -> XCUIElementQuery {
        app.images.matching(NSPredicate(format: "identifier BEGINSWITH 'parkedMarker_'"))
    }

    /// The row count as the badge shows it, read from the combined row ("All open, 2").
    private func badgeNumbers(of row: XCUIElement) -> [String] {
        "\(row.label) \(row.value as? String ?? "")"
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
    }

    @MainActor
    func testOpenRowShowsOpenAndParkedButNotDone() throws {
        let app = launchWithShortDoneWindow()
        captureAndPick("Müll rausbringen", { self.element("menuDone", in: $0) }, in: app)
        captureAndPick("Fahrrad verkaufen", { $0.buttons["Park"] }, in: app)
        capture("Rechnung bezahlen", in: app)

        let openRow = scrollTo("viewRow_open", in: app)
        let doneRow = scrollTo("viewRow_done", in: app)
        XCTAssertTrue(openRow.isHittable && doneRow.isHittable, "Both rows should be on screen together")
        XCTAssertLessThan(openRow.frame.minY, doneRow.frame.minY, "All open sits right above Completed")
        XCTAssertEqual(badgeNumbers(of: openRow), ["2"], "The count should match the list: one new, one parked")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Start screen with All open"
        shot.lifetime = .keepAlways
        add(shot)

        openRow.tap()
        XCTAssertTrue(app.navigationBars["All open"].waitForExistence(timeout: 5), "All open did not open")
        XCTAssertTrue(taskRows(in: app).firstMatch.waitForExistence(timeout: 5), "All open shows no task")
        XCTAssertEqual(taskRows(in: app).count, 2, "The new and the parked task, not the completed one")
        XCTAssertEqual(taskRows(in: app, parkedOnly: true).count, 1, "Only the parked task carries the moon")
        let parkedId = taskRows(in: app, parkedOnly: true).firstMatch.identifier.replacingOccurrences(of: "taskRow_", with: "")
        XCTAssertEqual(parkedMarkers(in: app).count, 1, "All open shows exactly one moon glyph")
        XCTAssertEqual(parkedMarkers(in: app).firstMatch.identifier, "parkedMarker_\(parkedId)", "The moon belongs to the parked row")

        let list = XCTAttachment(screenshot: app.screenshot())
        list.name = "All open list"
        list.lifetime = .keepAlways
        add(list)

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
        scrollTo("viewRow_parked", in: app).tap()
        XCTAssertTrue(taskRows(in: app).firstMatch.waitForExistence(timeout: 5), "Parked shows no task")
        XCTAssertEqual(taskRows(in: app).count, 1)
        XCTAssertEqual(taskRows(in: app, parkedOnly: true).count, 0, "In Parked the moon would be noise")
        XCTAssertEqual(parkedMarkers(in: app).count, 0, "Parked shows no moon glyph")
    }

    @MainActor
    func testSwipesOnParkedRowInOpenView() throws {
        let app = launchWithShortDoneWindow()
        captureAndPick("Fahrrad verkaufen", { $0.buttons["Park"] }, in: app)
        capture("Rechnung bezahlen", in: app)
        scrollTo("viewRow_open", in: app).tap()

        let parked = taskRows(in: app, parkedOnly: true).firstMatch
        XCTAssertTrue(parked.waitForExistence(timeout: 5), "All open shows no parked task")
        let id = parked.identifier.replacingOccurrences(of: "taskRow_", with: "")
        let other = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND NOT (label CONTAINS 'Parked')"))
            .firstMatch
        XCTAssertTrue(other.exists, "All open shows no other task")
        XCTAssertTrue(element("parkedMarker_\(id)", in: app).exists, "The parked row carries the moon glyph")
        XCTAssertEqual(parkedMarkers(in: app).count, 1, "Only the parked row carries the moon glyph")

        parked.swipeRight()
        XCTAssertTrue(element("swipeDone_\(id)", in: app).waitForExistence(timeout: 5), "Swipe right on a parked task should offer Complete")
        parked.swipeLeft()

        other.swipeLeft()
        XCTAssertTrue(app.buttons["Next up"].waitForExistence(timeout: 5), "Swipe left on an open task offers Next up")
        other.swipeRight()

        parked.swipeLeft()
        let activate = element("swipeActivate_\(id)", in: app)
        XCTAssertTrue(activate.waitForExistence(timeout: 5), "Swipe left on a parked task should offer Activate")
        XCTAssertEqual(activate.label, "Activate")
        XCTAssertFalse(app.buttons["Next up"].exists, "A parked task never shows in Next up, so no Next up swipe")
        activate.tap()

        let row = element("taskRow_\(id)", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Activated, the task stays in All open")
        XCTAssertTrue(taskRows(in: app, parkedOnly: true).firstMatch.waitForNonExistence(timeout: 5), "Activated, the moon goes")
        XCTAssertTrue(element("parkedMarker_\(id)", in: app).waitForNonExistence(timeout: 5), "Activated, the moon glyph goes")
        XCTAssertEqual(parkedMarkers(in: app).count, 0, "Activated, no moon glyph is left")
    }

    @MainActor
    func testOpenViewEmptySentence() throws {
        let app = launchWithShortDoneWindow()
        let openRow = scrollTo("viewRow_open", in: app)
        XCTAssertEqual(badgeNumbers(of: openRow), [], "Without tasks the row shows no number")
        openRow.tap()
        let empty = element("emptyViewLabel", in: app)
        XCTAssertTrue(empty.waitForExistence(timeout: 5), "All open shows no empty sentence")
        XCTAssertEqual(empty.label, "Nothing left open.")
    }
}
