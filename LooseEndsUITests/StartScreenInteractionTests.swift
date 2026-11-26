import XCTest

/// The start screen's "Now" rows act like the list (#303): swipe right is Done with Undo,
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

    /// One captured task, lined up in Next up from "Loose ends" (#1000: no "New"), then back on the start screen.
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

        scrollTo("viewRow_open", in: app).tap()
        // The only task in the list: a date word ("Heute") leaves the title, so the text would not match.
        let row = firstElement(prefix: "taskRow_", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Loose ends shows no task")
        row.swipeLeft()
        let nextUp = app.buttons["Next up"]
        XCTAssertTrue(nextUp.waitForExistence(timeout: 5), "Swipe left offers no Next up")
        nextUp.tap()
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
        // "Loose ends" stands low in the index: scroll back up to "Now", where the callers look.
        let now = firstElement(prefix: "nowRow_", in: app)
        for _ in 0..<2 where !(now.waitForExistence(timeout: 2) && now.isHittable) { app.swipeDown() }
    }

    /// What is due today stands in the "Now" block of the start screen (#299, #368). The rule step reads
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

        let due = firstElement(prefix: "nowRow_", in: app)
        XCTAssertTrue(due.waitForExistence(timeout: 15), "A task due today should show on the start screen")
        XCTAssertTrue(due.label.contains("Rechnung"), "Row label was \(due.label)")
    }

    @MainActor
    func testPreviewRowSwipesToDoneAndBack() throws {
        let app = launch()
        captureAndLineUp("Rechnung bezahlen", in: app)

        let preview = firstElement(prefix: "nowRow_", in: app)
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

        let preview = firstElement(prefix: "nowRow_", in: app)
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

    // MARK: - Now (#368)

    @MainActor
    private func nowRows(in app: XCUIApplication) -> [XCUIElement] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'nowRow_'")).allElementsBoundByIndex
    }

    /// Seven tasks due today: five rows, "2 more" unfolds in place and folds again (AC-6).
    @MainActor
    func testNowMoreExpandsInPlace() throws {
        let app = launch()
        for number in 1...7 { capture("Heute Aufgabe \(number)", in: app) }

        let more = element("nowMore", in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 15), "Seven tasks should leave a \"more\" row")
        XCTAssertEqual(nowRows(in: app).count, 5, "Five rows before unfolding")
        XCTAssertEqual(more.label, "2 more")

        more.tap()
        XCTAssertTrue(app.staticTexts["Show less"].waitForExistence(timeout: 5), "Unfolded, the row offers Show less")
        XCTAssertEqual(nowRows(in: app).count, 7, "All seven rows after unfolding")

        more.tap()
        XCTAssertTrue(app.staticTexts["2 more"].waitForExistence(timeout: 5), "Folded again")
        XCTAssertEqual(nowRows(in: app).count, 5)
    }

    /// Empty "Now" keeps its heading and the hint, with no rows and no "more" (AC-10).
    @MainActor
    func testEmptyNowShowsTheHint() throws {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Swipe left on any task to line it up here."].waitForExistence(timeout: 10))
        XCTAssertTrue(nowRows(in: app).isEmpty)
        XCTAssertFalse(element("nowMore", in: app).exists)
    }

    /// A task that is lined up and due today stands once (AC-7); taking it out of Next up leaves it in Now (AC-9).
    @MainActor
    func testRemovingNextUpFromDueRowKeepsItInNow() throws {
        let app = launch()
        captureAndLineUp("Heute Rechnung bezahlen", in: app)
        XCTAssertEqual(nowRows(in: app).count, 1, "A lined up task that is due today stands once")

        let row = firstElement(prefix: "nowRow_", in: app)
        let remove = app.buttons["Remove from Next up"]
        for duration in [1.2, 2.0, 3.0] where !remove.exists {
            row.press(forDuration: duration)
            _ = remove.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(remove.exists, "Long press should open the task menu")
        remove.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Due today, the task stays in Now")
        XCTAssertEqual(nowRows(in: app).count, 1)
    }

    /// A tap on a "Now" row opens that task; Back brings the same row back (#398).
    @MainActor
    func testNowRowOpensItsTask() throws {
        let app = launch()
        captureAndLineUp("Rechnung bezahlen", in: app)

        let row = firstElement(prefix: "nowRow_", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Start screen shows no Now row")
        let id = row.identifier
        row.tap()
        XCTAssertTrue(element("detailTitleField", in: app).waitForExistence(timeout: 5), "The tap should open the detail")
        let marker = element("detailRawTextMarker", in: app)
        XCTAssertTrue(marker.waitForExistence(timeout: 5), "The detail lacks its raw text marker")
        XCTAssertTrue(marker.label.contains("Rechnung bezahlen"), "The detail is another task: \(marker.label)")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
        XCTAssertTrue(element(id, in: app).waitForExistence(timeout: 5), "Back on the start screen the same row stands in Now")
    }

    /// A task without a date is captured but nothing stands for now: Now keeps only its hint (#398), and since
    /// #1000 no inbox bar stands for "New".
    @MainActor
    func testUndatedTaskKeepsTheNowHint() throws {
        let app = launch()
        capture("Rechnung bezahlen", in: app)

        XCTAssertTrue(app.staticTexts["Swipe left on any task to line it up here."].waitForExistence(timeout: 5), "Now should keep its hint")
        XCTAssertFalse(element("inboxBar", in: app).exists, "No inbox bar any more (#1000)")
        XCTAssertTrue(nowRows(in: app).isEmpty, "A task without a date is not for now")
        XCTAssertFalse(element("nowMore", in: app).exists)
    }

    /// Unfolded, then down to five: the block folds, so two more tasks find it folded at "2 more" (#398).
    @MainActor
    func testNowFoldsAgainOnceFiveAreLeft() throws {
        let app = launchWithShortDoneWindow()
        for number in 1...7 { capture("Heute Aufgabe \(number)", in: app) }

        let more = element("nowMore", in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 15), "Seven tasks should leave a \"more\" row")
        more.tap()
        XCTAssertTrue(waitForNowRows(7, in: app), "All seven rows after unfolding")

        for left in [6, 5] {
            let row = firstElement(prefix: "nowRow_", in: app)
            row.swipeRight()
            let complete = app.buttons["Complete"]
            if complete.waitForExistence(timeout: 2) { complete.tap() }
            XCTAssertTrue(waitForNowRows(left, in: app), "After the Done window \(left) rows should be left")
        }
        XCTAssertFalse(more.exists, "Five rows need no \"more\"")

        for number in 8...9 { capture("Heute Aufgabe \(number)", in: app) }
        XCTAssertTrue(more.waitForExistence(timeout: 15), "Seven tasks again should bring the \"more\" row back")
        XCTAssertEqual(more.label, "2 more", "The block should stand folded, not unfolded from before")
        XCTAssertEqual(nowRows(in: app).count, 5, "Folded, five rows")
    }

    /// Waits until Now shows exactly `count` rows; a completed row stays through its Done window.
    @MainActor
    private func waitForNowRows(_ count: Int, in app: XCUIApplication, timeout: TimeInterval = 15) -> Bool {
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'nowRow_'"))
        let reached = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: rows)
        return XCTWaiter().wait(for: [reached], timeout: timeout) == .completed
    }

    // MARK: - Tag words in the index (#368, #421: the chips became italic words under „Tags“)

    /// A task the rule files under Garden raises a chip with the list's count; the tap opens that list (AC-13).
    @MainActor
    func testChipOpensItsView() throws {
        let app = launch()
        XCTAssertFalse(firstElement(prefix: "chip_", in: app).exists, "No chip without a task in a context")
        capture("Rasen mähen", in: app)

        let chip = firstElement(prefix: "chip_", in: app)
        XCTAssertTrue(chip.waitForExistence(timeout: 20), "A context with a task should raise a chip")
        XCTAssertTrue(chip.label.contains("Garden"), "Chip label was \(chip.label)")
        XCTAssertTrue(chip.label.contains("1"), "Chip label was \(chip.label)")
        // The list reports the chip's row as its frame; the capsule sits at the leading edge, so tap there.
        chip.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.5)).tap()

        XCTAssertTrue(app.navigationBars["Garden"].waitForExistence(timeout: 5), "The chip should open its context")
        XCTAssertEqual(taskRows(in: app).count, 1, "The list holds as many rows as the chip counted")
    }

    // MARK: - Index lines (#368, #421: the grid became the contents index)

    /// All open and Completed open from the grid (AC-15).
    @MainActor
    func testGridCellOpensView() throws {
        let app = launch()
        scrollTo("viewRow_done", in: app).tap()
        XCTAssertTrue(app.navigationBars["Completed"].waitForExistence(timeout: 5), "The Completed cell should open its list")
        app.navigationBars.buttons.firstMatch.tap()

        scrollTo("viewRow_open", in: app).tap()
        XCTAssertTrue(app.navigationBars["All open"].waitForExistence(timeout: 5), "The All open cell should open its list")
    }

    /// The Projects line opens its own page with the new-project button (#428); nothing unfolds on the start screen.
    @MainActor
    func testProjectsLineOpensPage() throws {
        let app = launch()
        let newProject = element("newProjectButton", in: app)
        XCTAssertFalse(newProject.exists, "The start screen should not unfold the projects")
        scrollTo("projectsToggle", in: app).tap()
        XCTAssertTrue(element("catalogTitle", in: app).waitForExistence(timeout: 5), "The line should open the Projects page")
        XCTAssertTrue(newProject.waitForExistence(timeout: 5), "The page should offer New project")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(newProject.waitForNonExistence(timeout: 5), "Back on the start screen the button should be gone")
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

    /// Captures one task, opens "Loose ends" (#1000: no "New"; an earlier parked task may stand there too, so the
    /// row is found by its text), long-presses it and picks a menu entry; waits until the row no longer stands
    /// there as an open task (Complete takes it out, Park marks it with the moon), then goes back to the start screen.
    @MainActor
    private func captureAndPick(_ text: String, _ entry: (XCUIApplication) -> XCUIElement, in app: XCUIApplication) {
        capture(text, in: app)
        scrollTo("viewRow_open", in: app).tap()
        let row = taskRow(containing: text, in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Loose ends shows no \(text)")
        let item = entry(app)
        // A slow runner can miss the first press (#114).
        for duration in [1.2, 2.0, 3.0] where !item.exists {
            row.press(forDuration: duration)
            _ = item.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(item.exists, "The long-press menu lacks the entry")
        item.tap()
        let stillOpen = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS %@ AND NOT (label CONTAINS 'Parked')", text))
        let picked = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == 0"), object: stillOpen)
        XCTAssertEqual(XCTWaiter().wait(for: [picked], timeout: 10), .completed, "The task should no longer stand as open")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
        // "Loose ends" stands low in the index: back to the top of the start screen, as before #1000.
        let header = element("startHeader", in: app)
        for _ in 0..<2 where !(header.waitForExistence(timeout: 2) && header.isHittable) { app.swipeDown() }
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
        // In the iPhone grid (#368) the two cells share a row, All open on the left; with one column it sits above.
        let openFirst = openRow.frame.minY < doneRow.frame.minY
            || (openRow.frame.minY == doneRow.frame.minY && openRow.frame.minX < doneRow.frame.minX)
        XCTAssertTrue(openFirst, "All open comes right before Completed")
        XCTAssertEqual(badgeNumbers(of: openRow), ["2"], "The count should match the list: one open, one parked")

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

    /// A row of the open list whose label names the task.
    @MainActor
    private func taskRow(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS %@", text)).firstMatch
    }

    /// "Loose ends" sorted by pressure (#545, #657): a task due today stands first, an unweighted one
    /// after it, a task due the day after tomorrow under "Later" below that, the parked one last under
    /// its own grey head, whatever the order of capture. The unweighted task is captured before the due
    /// one, so the old order (capture time) would fail; the later one is dated, so the order of #545
    /// (every dated task first) would fail. The rule step reads "heute" and "übermorgen" without
    /// Apple Intelligence (#95), so this holds in the simulator.
    @MainActor
    func testOpenViewOrdersDueThenUnweightedThenLaterThenParked() throws {
        let app = launchWithShortDoneWindow()
        captureAndPick("Fahrrad verkaufen", { $0.buttons["Park"] }, in: app)
        capture("Übermorgen Reifen wechseln", in: app)
        capture("Blumen gießen", in: app)
        capture("Heute die Rechnung bezahlen", in: app)
        let due = firstElement(prefix: "nowRow_", in: app)
        XCTAssertTrue(due.waitForExistence(timeout: 15), "The task due today should reach the start screen before the list is checked")

        scrollTo("viewRow_open", in: app).tap()
        XCTAssertTrue(app.navigationBars["All open"].waitForExistence(timeout: 5), "All open did not open")
        let dueRow = taskRow(containing: "Rechnung", in: app)
        let plainRow = taskRow(containing: "Blumen", in: app)
        let laterRow = taskRow(containing: "Reifen", in: app)
        let parkedRow = taskRow(containing: "Fahrrad", in: app)
        XCTAssertTrue(dueRow.waitForExistence(timeout: 5), "All open shows no due task")
        XCTAssertTrue(plainRow.exists, "All open shows no unweighted task")
        XCTAssertTrue(laterRow.exists, "All open shows no later task")
        XCTAssertTrue(parkedRow.exists, "All open shows no parked task")
        XCTAssertEqual(taskRows(in: app).count, 4, "The due, the unweighted, the later and the parked task")

        XCTAssertLessThan(dueRow.frame.minY, plainRow.frame.minY, "Due today stands above the unweighted task")
        XCTAssertLessThan(plainRow.frame.minY, laterRow.frame.minY, "The unweighted task stands above the later one (#657)")
        XCTAssertLessThan(laterRow.frame.minY, parkedRow.frame.minY, "The later task stands above the parked one")
        for (head, row) in [("todayHead", dueRow), ("undatedHead", plainRow), ("laterHead", laterRow)] {
            let headElement = element(head, in: app)
            XCTAssertTrue(headElement.exists, "\(head) is missing")
            XCTAssertLessThan(headElement.frame.minY, row.frame.minY, "\(head) stands above its block")
        }
        let parkedHead = element("parkedHead", in: app)
        XCTAssertTrue(parkedHead.waitForExistence(timeout: 5), "The parked block carries its own head")
        XCTAssertGreaterThan(parkedHead.frame.minY, laterRow.frame.minY, "The head stands below the open tasks")
        XCTAssertLessThan(parkedHead.frame.minY, parkedRow.frame.minY, "The head stands above the parked task")
        XCTAssertEqual(parkedMarkers(in: app).count, 1, "The parked row still carries the moon")

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "All open by pressure"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The index marks the open list on the iPad, where it is a sidebar next to the list (#334); on the iPhone
    /// it is a page, so after "Back" nothing stays marked. Since #1000 the index lists Loose ends and Completed,
    /// and no New, on the iPhone page and in the iPad sidebar alike.
    @MainActor
    func testIndexMarksTheOpenListOnIPadOnly() throws {
        #if os(macOS)
        // The UI test target compiles for the Mac too (CI "macOS destination"): no UIDevice, no orientation there.
        throw XCTSkip("The sidebar mark is an iPad and iPhone behaviour")
        #else
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        if isPad { XCUIDevice.shared.orientation = .landscapeLeft }
        defer { if isPad { XCUIDevice.shared.orientation = .portrait } }
        let app = launch()
        let openRow = scrollTo("viewRow_open", in: app)
        XCTAssertTrue(scrollTo("viewRow_done", in: app).exists, "The index lists Completed")
        XCTAssertFalse(element("viewRow_new", in: app).exists, "The index lists no New (#1000)")
        XCTAssertFalse(openRow.isSelected, "Nothing is open yet, so nothing is marked")
        openRow.tap()
        XCTAssertTrue(app.navigationBars["All open"].waitForExistence(timeout: 5), "All open did not open")

        if isPad {
            XCTAssertTrue(openRow.waitForExistence(timeout: 5), "The sidebar should stay next to the list")
            XCTAssertTrue(openRow.isSelected, "The open list is marked in the sidebar (#334)")
            XCTAssertFalse(element("viewRow_done", in: app).isSelected, "Only the open list is marked")
            XCTAssertFalse(element("viewRow_new", in: app).exists, "The sidebar lists no New (#1000)")
        } else {
            let back = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
            back.tap()
            XCTAssertTrue(scrollTo("viewRow_open", in: app).waitForExistence(timeout: 5))
            XCTAssertFalse(element("viewRow_open", in: app).isSelected, "On the iPhone the index is a page: nothing stays marked")
        }
        #endif
    }
}
