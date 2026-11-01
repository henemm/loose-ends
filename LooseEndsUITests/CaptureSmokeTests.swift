import XCTest

/// Smoke test for the first end-to-end path: capture a task, find it in "New".
/// Runs against an in-memory store (`--ui-testing`), so it never touches real data.
final class CaptureSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// English regardless of the host Mac's system language: these tests match several visible
    /// labels literally ("Weekly", "Complete", …), so the run must not depend on the machine's
    /// locale (found while reproducing #121 — a German-language Mac otherwise renders "Täglich"
    /// and every such match silently fails).
    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    /// Any element carrying the identifier, whatever control SwiftUI backs it with.
    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// A section shows only with content (#538): its word in the line below opens it. Nothing to do
    /// when the section is already there.
    @MainActor
    private func openSection(_ word: String, showing id: String, in app: XCUIApplication) {
        let target = element(id, in: app)
        if target.waitForExistence(timeout: 2) { return }
        let button = element(word, in: app)
        for _ in 0..<5 where !(button.exists && button.isHittable) { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "The word line should offer \(word)")
        button.tap()
    }

    /// Empty fields wait behind "Add detail" (#187): open it if the row is not there yet.
    @MainActor
    private func revealField(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let row = element(id, in: app)
        if !row.waitForExistence(timeout: 2) {
            let add = element("addDetailRow", in: app)
            if add.waitForExistence(timeout: 3) { add.tap() }
        }
        return row
    }

    /// The captured task's row, found by identifier: the model may rewrite the title (#165). The
    /// in-memory store of `--ui-testing` starts empty and each test captures one task, so the first
    /// `taskRow_*` is the one just captured.
    @MainActor
    private func taskRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_'"))
            .firstMatch
    }

    /// The open detail belongs to the captured task: its raw text is immutable, unlike the title.
    @MainActor
    private func assertDetailRawText(_ text: String, in app: XCUIApplication) {
        let rawText = element("detailRawTextMarker", in: app)
        XCTAssertTrue(rawText.waitForExistence(timeout: 5), "Detail should show the raw text")
        XCTAssertEqual(rawText.label, text, "Detail should belong to the captured task")
    }

    /// Opens the long-press menu on a row. The runner may still be animating the list, so wait
    /// until the row is hittable and retry with a longer press if the menu did not open — a slow
    /// CI runner can miss the first one or two attempts (#114). On a slow runner the press can
    /// also arrive as a tap: the row is a `NavigationLink` and opens the detail instead. Then the
    /// row is gone, so go back to the list before the next, longer press (#165). The detail is
    /// also recognised by `detailRawText`: a row looked up by label matches the title shown there.
    @MainActor
    private func openMenu(on row: XCUIElement, expecting item: XCUIElement) {
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Row should exist before opening its menu")
        let hittable = NSPredicate(format: "isHittable == true")
        _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: row)], timeout: 5)
        let detailRawText = element("detailRawTextMarker", in: XCUIApplication())
        for duration in [1.2, 1.5, 2.0] {
            row.press(forDuration: duration)
            if item.waitForExistence(timeout: 5) {
                return
            }
            if !row.exists || detailRawText.exists {
                let back = XCUIApplication().navigationBars.buttons.firstMatch
                if back.waitForExistence(timeout: 5) {
                    back.tap()
                }
                XCTAssertTrue(detailRawText.waitForNonExistence(timeout: 5), "Should have left the detail")
                XCTAssertTrue(row.waitForExistence(timeout: 5), "Row should be back after leaving the detail")
                _ = XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: hittable, object: row)], timeout: 5)
            }
        }
    }

    /// Editor → detail → list → sidebar, then "Repeating"; returns the task row found there.
    /// Whether the task still sits in "New" depends on enrichment and on "Looks right" (#165, #349),
    /// so the row is looked up under "Repeating", where its rule keeps it regardless of either.
    @MainActor
    private func openRepeatingFromEditor(in app: XCUIApplication, detailMarker: XCUIElement) -> XCUIElement {
        let backToDetail = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backToDetail.waitForExistence(timeout: 5))
        backToDetail.tap()
        XCTAssertTrue(detailMarker.waitForExistence(timeout: 5), "Should be back at the detail")

        let backToList = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backToList.waitForExistence(timeout: 5))
        backToList.tap()
        XCTAssertTrue(detailMarker.waitForNonExistence(timeout: 5), "Should have left the detail")

        let backToSidebar = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backToSidebar.waitForExistence(timeout: 5))
        backToSidebar.tap()
        let repeatingRow = element("viewRow_repeating", in: app)
        XCTAssertTrue(repeatingRow.waitForExistence(timeout: 5), "Start screen should show Repeating")
        repeatingRow.tap()

        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The task should be listed under Repeating")
        return row
    }

    /// Long press → Delete → confirm. The caller checks that the row left the list.
    @MainActor
    private func deleteFromMenu(_ row: XCUIElement, in app: XCUIApplication) {
        let delete = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDelete", "Delete"))
            .firstMatch
        openMenu(on: row, expecting: delete)
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Long press should open the menu with Delete")
        delete.tap()

        let confirm = app.buttons["confirmDeleteButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
    }

    /// True once the element reports the value, so a switch is read after it moved, not before.
    @MainActor
    private func waitForValue(_ expected: String, of element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        valueAfterWaiting(for: expected, of: element, timeout: timeout) == expected
    }

    /// The value once it matches, otherwise the value of one last read after the deadline. The
    /// deadline runs on the clock: a single lookup slower than the timeout (4 s on the CI runner,
    /// #172) can no longer end the wait without the element having been read after it.
    @MainActor
    private func valueAfterWaiting(for expected: String, of element: XCUIElement, timeout: TimeInterval) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (element.value as? String) == expected { return expected }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.value as? String
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

        let captured = taskRow(in: app)
        XCTAssertTrue(captured.waitForExistence(timeout: 5), "Captured task should appear in New")
        captured.tap()
        assertDetailRawText("Rasenmäher Ölwechsel", in: app)
    }

    /// Captures `text`, opens New and returns the detail's title field (#202).
    @MainActor
    private func captureAndOpenDetail(_ text: String, in app: XCUIApplication) -> XCUIElement {
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Captured task should appear in New")
        row.tap()
        let titleField = element("detailTitleField", in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Detail should offer the title field")
        return titleField
    }

    /// #202: a task has a title from the moment it is captured, without the model (the simulator has none).
    @MainActor
    func testCapturedTaskHasTitleInDetail() throws {
        let app = launch()
        let titleField = captureAndOpenDetail("termin bei Auto Senger machen für Inspektion und Reifenwechsel.", in: app)

        XCTAssertTrue(waitForValue("Termin bei Auto Senger machen für Inspektion und Reifenwechsel", of: titleField),
                      "Title field should hold the cleaned title, was \(String(describing: titleField.value))")
        XCTAssertFalse(element("detailRawText", in: app).exists, "Same words as the title: no \"You said:\" line")
        attachScreenshot(app, "202-detail-regeltitel")

        // Back to the list: the row carries the same title. The simulator has a model that may replace
        // it meanwhile with the same words in lower case, so the row check ignores case (#202).
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 5) { back.tap() }
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.lowercased().contains("Termin bei Auto Senger machen für Inspektion und Reifenwechsel".lowercased()),
                      "Row should show the title, was \(row.label)")
    }

    /// #202: a long dictation gets its first twelve words as title; the full text stays below.
    @MainActor
    func testLongCaptureKeepsFullTextBelowTwelveWordTitle() throws {
        let app = launch()
        let words = "eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf dreizehn vierzehn"
        let titleField = captureAndOpenDetail(words, in: app)

        XCTAssertTrue(waitForValue("Eins zwei drei vier fünf sechs sieben acht neun zehn elf zwölf", of: titleField),
                      "Title should hold the first twelve words, was \(String(describing: titleField.value))")
        let rawText = element("detailRawText", in: app)
        XCTAssertTrue(rawText.waitForExistence(timeout: 5), "Different words: \"You said:\" shows the full text")
        XCTAssertEqual(rawText.label, words)
        // #216: twelve words do not fit one line; the field wraps instead of ending in "…". One line
        // of the title font is about 25 pt high, so a wrapped field is clearly taller than 40 pt.
        XCTAssertGreaterThan(titleField.frame.height, 40, "Long title should wrap, field was \(titleField.frame)")
        attachScreenshot(app, "202-detail-zwoelf-woerter")
    }

    /// Keeps a screenshot in the result bundle as evidence (#202).
    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Nur für den Nachweis an Henning: hält jeden Schritt des Capture-Wegs als Bild fest.
    @MainActor
    func testPlusButtonProof() throws {
        func shot(_ app: XCUIApplication, _ name: String) {
            let a = XCTAttachment(screenshot: app.screenshot())
            a.name = name
            a.lifetime = .keepAlways
            add(a)
        }

        let app = launch()
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "Kein Capture-Button auf dem Startbildschirm")
        shot(app, "1-startbildschirm-mit-plus")

        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture-Blatt ging nach dem Tippen auf + nicht auf")
        shot(app, "2-nach-tippen-auf-plus")

        field.tap()
        field.typeText("Reifen wechseln lassen")
        shot(app, "3-aufgabe-eingetippt")

        let done = app.buttons["captureDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isEnabled, "Fertig muss anklickbar sein, sobald Text da ist")
        done.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture-Blatt schloss nach Fertig nicht")

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let captured = taskRow(in: app)
        XCTAssertTrue(captured.waitForExistence(timeout: 5), "Erfasste Aufgabe taucht nicht in Neu auf")
        shot(app, "4-aufgabe-steht-in-neu")
        captured.tap()
        assertDetailRawText("Reifen wechseln lassen", in: app)
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

        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Task row should be listed in New")
        row.tap()

        let rawText = element("detailRawTextMarker", in: app)
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

        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Task row should be listed in New")
        let done = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDone", "Complete"))
            .firstMatch
        openMenu(on: row, expecting: done)
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Long press should open the menu with Complete")
        done.tap()

        // Done waits out its three seconds with Undo before the task leaves (#32).
        XCTAssertTrue(element("emptyViewLabel", in: app).waitForExistence(timeout: 10), "New should be empty after Done")
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "The finished task should leave New")
    }

    @MainActor
    func testNewProjectAppearsOnStartScreen() throws {
        let app = launch()

        let newProject = element("newProjectButton", in: app)
        // The Projects line of the start screen opens the page with the button (#428).
        let toggle = element("projectsToggle", in: app)
        if !toggle.waitForExistence(timeout: 5) { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Start screen should offer the Projects line")
        toggle.tap()
        XCTAssertTrue(newProject.waitForExistence(timeout: 5), "Start screen should offer New project")
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
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Reifen wechseln", in: app)

        let importanceRow = revealField("field_importance", in: app)
        XCTAssertTrue(importanceRow.waitForExistence(timeout: 5), "Detail should list Importance")
        importanceRow.tap()

        let high = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "High")).firstMatch
        XCTAssertTrue(high.waitForExistence(timeout: 5), "Editor should offer High")
        high.tap()
        // A single choice closes the editor by itself (#482).

        let showsHigh = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'High'"), object: importanceRow)
        XCTAssertEqual(XCTWaiter().wait(for: [showsHigh], timeout: 5), .completed, "Row label was \(importanceRow.label)")
    }

    @MainActor
    func testRepeatEditorUpdatesDetail() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Rasen mähen am Samstag")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Rasen mähen am Samstag", in: app)

        let repeatRow = revealField("field_repeatRule", in: app)
        XCTAssertTrue(repeatRow.waitForExistence(timeout: 5), "Detail should list Repeat")
        repeatRow.tap()

        let weekly = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Weekly")).firstMatch
        XCTAssertTrue(weekly.waitForExistence(timeout: 5), "Editor should offer Weekly")
        weekly.tap()
        XCTAssertTrue(element("repeatIntervalStepper", in: app).waitForExistence(timeout: 5), "A rule shows its interval")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()

        XCTAssertTrue(repeatRow.waitForExistence(timeout: 5))
        XCTAssertTrue(repeatRow.label.contains("Weekly"), "Row label was \(repeatRow.label)")
    }

    /// #121: a repeating task gains a `CompletionRecord` on every completed cycle
    /// (`TaskActions.complete`). Deleting it afterward detaches a SwiftData object that still has
    /// a populated relationship — the same ordering FocusBlox's own postmortem (BUG_112) names as
    /// the cause of a "backing data was detached" crash. Reproduces with the app itself alive to
    /// prove it, not just that the row vanished.
    @MainActor
    func testDeletingRecurringTaskAfterCompletionDoesNotCrash() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Tabletten nehmen morgen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Tabletten nehmen morgen", in: app)

        let repeatRow = revealField("field_repeatRule", in: app)
        XCTAssertTrue(repeatRow.waitForExistence(timeout: 5), "Detail should list Repeat")
        repeatRow.tap()

        let daily = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Daily")).firstMatch
        XCTAssertTrue(daily.waitForExistence(timeout: 5), "Editor should offer Daily")
        daily.tap()
        XCTAssertTrue(element("repeatIntervalStepper", in: app).waitForExistence(timeout: 5), "A rule shows its interval")

        let repeating = openRepeatingFromEditor(in: app, detailMarker: repeatRow)

        let complete = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDone", "Complete"))
            .firstMatch
        openMenu(on: repeating, expecting: complete)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "Long press should open the menu with Complete")
        complete.tap()

        // Done lands once its three seconds with Undo have run out (#32); only then does the
        // task carry the completion record this test is about.
        let undo = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'undoComplete_'"))
            .firstMatch
        // Not asserted: on a slow runner the window may be over before the first lookup returns.
        _ = undo.waitForExistence(timeout: 2)
        XCTAssertTrue(undo.waitForNonExistence(timeout: 10), "The Done window should run out")

        // A repeating task rolls forward instead of leaving the list — same row, new due date,
        // and now a populated `completions` relationship (the crash precondition).
        XCTAssertTrue(repeating.waitForExistence(timeout: 5), "A repeating task stays listed after completion")

        deleteFromMenu(repeating, in: app)

        XCTAssertTrue(repeating.waitForNonExistence(timeout: 5), "The deleted recurring task should leave the list")
        // Proof the app is still alive and responsive, not just that this one element vanished.
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5), "App should still respond after deleting a recurring task")
    }

    /// #443: a weekly task is not "Due" while its next round lies ahead — neither once the rule is set
    /// nor after completing it — and stays under "Repeating". Played through as the user does it.
    @MainActor
    func testWeeklyTaskIsNotDueUntilItsDay() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Fußnagel behandeln morgen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Fußnagel behandeln morgen", in: app)

        let repeatRow = revealField("field_repeatRule", in: app)
        XCTAssertTrue(repeatRow.waitForExistence(timeout: 5), "Detail should list Repeat")
        repeatRow.tap()
        let weekly = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Weekly")).firstMatch
        XCTAssertTrue(weekly.waitForExistence(timeout: 5), "Editor should offer Weekly")
        weekly.tap()
        XCTAssertTrue(element("repeatIntervalStepper", in: app).waitForExistence(timeout: 5), "A rule shows its interval")

        let repeating = openRepeatingFromEditor(in: app, detailMarker: repeatRow)
        assertDueViewHoldsNoTask(in: app, step: "after setting the rule")

        let repeatingRow = element("viewRow_repeating", in: app)
        XCTAssertTrue(repeatingRow.waitForExistence(timeout: 5))
        repeatingRow.tap()
        XCTAssertTrue(repeating.waitForExistence(timeout: 5), "The weekly task is listed under Repeating")

        let complete = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDone", "Complete"))
            .firstMatch
        openMenu(on: repeating, expecting: complete)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "Long press should open the menu with Complete")
        complete.tap()
        let undo = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'undoComplete_'"))
            .firstMatch
        _ = undo.waitForExistence(timeout: 2)
        XCTAssertTrue(undo.waitForNonExistence(timeout: 10), "The Done window should run out")
        XCTAssertTrue(repeating.waitForExistence(timeout: 5), "A repeating task stays listed after completion")

        assertDueViewHoldsNoTask(in: app, step: "after completing it")
        let again = element("viewRow_repeating", in: app)
        XCTAssertTrue(again.waitForExistence(timeout: 5))
        again.tap()
        XCTAssertTrue(taskRow(in: app).waitForExistence(timeout: 5), "Repeating still shows the task")
        attachScreenshot(app, "443-wiederholend-zeigt-aufgabe")
    }

    /// Sidebar → "Due": no task row, the empty text instead. Leaves the list open.
    @MainActor
    private func assertDueViewHoldsNoTask(in app: XCUIApplication, step: String) {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 3) { back.tap() }
        let dueRow = element("viewRow_due", in: app)
        XCTAssertTrue(dueRow.waitForExistence(timeout: 5), "Start screen should show Due")
        dueRow.tap()
        XCTAssertTrue(element("emptyViewLabel", in: app).waitForExistence(timeout: 5),
                      "Due should be empty \(step): a weekly task is not due yet")
        XCTAssertFalse(taskRow(in: app).exists, "Due must not list the weekly task \(step)")
        attachScreenshot(app, "443-faellig-leer-\(step)")
        let leave = app.navigationBars.buttons.firstMatch
        if leave.waitForExistence(timeout: 3) { leave.tap() }
    }

    @MainActor
    func testCompletedTaskShowsUnderCompleted() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Keller aufräumen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        let complete = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDone", "Complete"))
            .firstMatch
        openMenu(on: row, expecting: complete)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "Long press should open the menu with Complete")
        complete.tap()
        XCTAssertTrue(element("emptyViewLabel", in: app).waitForExistence(timeout: 10))

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        let doneRow = element("viewRow_done", in: app)
        // Completed sits last on the start screen; below the sentence and the Next up preview
        // (#180) it starts out of sight on an iPhone.
        for _ in 0..<3 where !doneRow.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(doneRow.waitForExistence(timeout: 5), "Start screen should show Completed")
        doneRow.tap()

        XCTAssertTrue(row.waitForExistence(timeout: 5), "The finished task should be listed under Completed")
        row.tap()
        assertDetailRawText("Keller aufräumen", in: app)
    }

    /// #565, Schnitt 3 (Henning, 2026-10-20): finishing a task while a subtask is still open asks
    /// "Complete all" or "Keep open ones" instead of closing it silently.
    @MainActor
    func testCompletingWithAnOpenSubtaskAsks() throws {
        let app = launch()
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Umzug planen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Umzug planen", in: app)

        openSection("field_subtasks", showing: "subtaskTextField", in: app)
        let subtaskField = element("subtaskTextField", in: app)
        if !subtaskField.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(subtaskField.waitForExistence(timeout: 5), "Detail should offer a subtask field")
        subtaskField.tap()
        subtaskField.typeText("Kartons holen\n")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subtaskRow_"))
            .firstMatch.waitForExistence(timeout: 5), "The subtask should be listed")

        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Detail should offer its menu")
        more.tap()
        let complete = element("menuDone", in: app)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "The menu should offer Complete")
        complete.tap()

        let keepOpen = element("completeKeepOpenSubtasks", in: app)
        XCTAssertTrue(keepOpen.waitForExistence(timeout: 5), "An open subtask should make Complete ask first")
        XCTAssertTrue(element("completeAllSubtasks", in: app).exists, "The question should offer Complete all")
        element("completeAllSubtasks", in: app).tap()
        XCTAssertTrue(element("emptyViewLabel", in: app).waitForExistence(timeout: 10), "New should be empty after Complete all")
    }

    /// #667 (Henning, 2026-10-24): the detail's "…" menu is the list's menu, Delete included. Delete
    /// asks, then the task is gone and the detail with it.
    @MainActor
    func testDeleteFromTheDetailLeavesIt() throws {
        let app = launch()
        let row = captureIntoNew("Alte Rechnung wegwerfen", in: app)
        row.tap()
        assertDetailRawText("Alte Rechnung wegwerfen", in: app)

        let more = element("detailMoreMenu", in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Detail should offer the More menu")
        more.tap()
        let delete = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDelete", "Delete"))
            .firstMatch
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "The detail's menu should offer Delete")
        delete.tap()
        let confirm = app.buttons["confirmDeleteButton"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Delete should ask first")
        confirm.tap()

        XCTAssertTrue(element("detailRawTextMarker", in: app).waitForNonExistence(timeout: 5), "The detail should leave the deleted task")
        XCTAssertTrue(element("emptyViewLabel", in: app).waitForExistence(timeout: 10), "New should be empty after the delete")
    }

    /// #605 (Henning, 2026-10-21): deleting a task with a subtask left the task standing; its
    /// subtasks are to stay, as tasks of their own, one level up.
    @MainActor
    func testDeletingATaskLiftsItsSubtask() throws {
        let app = launch()
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Umzug planen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Umzug planen", in: app)

        openSection("field_subtasks", showing: "subtaskTextField", in: app)
        let subtaskField = element("subtaskTextField", in: app)
        if !subtaskField.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(subtaskField.waitForExistence(timeout: 5), "Detail should offer a subtask field")
        subtaskField.tap()
        subtaskField.typeText("Kartons holen\n")
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subtaskRow_"))
            .firstMatch.waitForExistence(timeout: 5), "The subtask should be listed")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Back in New, the task should be listed")
        deleteFromMenu(row, in: app)
        XCTAssertTrue(row.waitForNonExistence(timeout: 5), "The deleted task should leave New")

        let toSidebar = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(toSidebar.waitForExistence(timeout: 5))
        toSidebar.tap()
        let openRow = element("viewRow_open", in: app)
        XCTAssertTrue(openRow.waitForExistence(timeout: 5), "The start screen should offer Loose ends")
        openRow.tap()
        let lifted = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS %@", "Kartons holen"))
            .firstMatch
        XCTAssertTrue(lifted.waitForExistence(timeout: 5), "The subtask should stand in Loose ends as a task of its own")
        let parentLeft = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS %@", "Umzug planen"))
            .firstMatch
        XCTAssertFalse(parentLeft.exists, "The deleted task should not stand there")
    }

    @MainActor
    func testSubtaskCanBeAddedAndChecked() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Einkaufen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Einkaufen", in: app)

        openSection("field_subtasks", showing: "subtaskTextField", in: app)
        let subtaskField = element("subtaskTextField", in: app)
        if !subtaskField.waitForExistence(timeout: 3) {
            app.swipeUp()
        }
        XCTAssertTrue(subtaskField.waitForExistence(timeout: 5), "Detail should offer a subtask field")
        subtaskField.tap()
        subtaskField.typeText("Milch")
        let add = app.buttons["subtaskAddButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertTrue(add.isEnabled, "Add must be enabled once there is text")
        add.tap()

        let line = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subtaskRow_"))
            .firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 5), "The new subtask should be listed")
        XCTAssertTrue(line.label.contains("Milch"), "Row label was \(line.label)")
        line.tap()

        let progress = element("subtaskProgress", in: app)
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "Checking a line off should show the progress")
        XCTAssertEqual(progress.label, "1 of 1 done")

        // #565: the line opens its own detail, and that detail names its task.
        let details = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "subtaskDetails_"))
            .firstMatch
        XCTAssertTrue(details.waitForExistence(timeout: 5), "The line should offer its own detail")
        details.tap()
        let partOf = element("partOfParentButton", in: app)
        XCTAssertTrue(partOf.waitForExistence(timeout: 5), "The subtask's detail should name its task")
        let subtaskDetail = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'detailRawTextMarker' AND label == 'Milch'"))
            .firstMatch
        XCTAssertTrue(subtaskDetail.waitForExistence(timeout: 5), "Details should open the subtask's own detail")
    }

    @MainActor
    func testCalendarSwitchStaysOn() throws {
        let app = launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        // The calendar waits for a due date (#538, rule 4): "morgen" gives the task one at capture.
        field.typeText("Zahnarzt anrufen morgen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Zahnarzt anrufen morgen", in: app)

        // The word "+ Calendar" switches on (#538); a day without a time asks first (#203, Teil B)
        // and the switch stays off until the sheet is answered.
        let word = element("field_calendar", in: app)
        for _ in 0..<5 where !(word.exists && word.isHittable) { app.swipeUp() }
        XCTAssertTrue(word.waitForExistence(timeout: 5), "Detail should offer Calendar in the word line")
        word.tap()
        let toggle = app.switches["showInCalendarToggle"]
        // "All day" is a segment of the timing control (#574).
        let allDay = app.segmentedControls.buttons["All day"].firstMatch
        XCTAssertTrue(allDay.waitForExistence(timeout: 5), "Without a time the switch should ask first")
        allDay.tap()
        let add = app.buttons["calendarAskConfirm"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        XCTAssertTrue(waitForValue("1", of: toggle), "Answering should switch it on, value was \(String(describing: toggle.value))")
        let appointment = element("calendarAppointmentRow", in: app)
        if !appointment.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(appointment.waitForExistence(timeout: 5), "The detail should show the appointment")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValue("1", of: toggle), "The switch should be saved")
    }

    /// Captures one task and opens "New"; returns its row there.
    @MainActor
    private func captureIntoNew(_ text: String, in app: XCUIApplication) -> XCUIElement {
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10))
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Task row should be listed in New")
        return row
    }

    /// #33: "Move → Date…" opens a calendar and sets the chosen day as the due date.
    @MainActor
    func testMoveToChosenDateSetsDueDate() throws {
        let app = launch()
        let row = captureIntoNew("Garage aufräumen", in: app)

        let move = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Move"))
            .firstMatch
        openMenu(on: row, expecting: move)
        XCTAssertTrue(move.waitForExistence(timeout: 5), "Long press should open the menu with Move")
        move.tap()

        let chooseDate = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuMoveDate", "Date…"))
            .firstMatch
        XCTAssertTrue(chooseDate.waitForExistence(timeout: 5), "Move should offer Date…")
        chooseDate.tap()

        let confirm = app.buttons["moveDateConfirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Date… should open the calendar sheet")
        XCTAssertTrue(element("moveDatePicker", in: app).exists, "The sheet should show the calendar")
        confirm.tap()
        XCTAssertTrue(confirm.waitForNonExistence(timeout: 5), "Move should close the sheet")

        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertDetailRawText("Garage aufräumen", in: app)
        // Empty fields wait behind "Add detail" (#187): a due date row without opening it proves the move.
        XCTAssertTrue(element("field_dueDate", in: app).waitForExistence(timeout: 5), "The moved task should show its due date")
    }

    /// #32: Done waits three seconds; a second tap on the row takes it back and the task stays.
    @MainActor
    func testUndoInsideTheDoneWindowKeepsTheTask() throws {
        // 20 s instead of 3: the tap must land inside the window even on a slow runner (#172).
        let app = launch(extra: ["--ui-testing-long-done-window"])
        let row = captureIntoNew("Briefkasten leeren", in: app)

        let complete = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "menuDone", "Complete"))
            .firstMatch
        openMenu(on: row, expecting: complete)
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "Long press should open the menu with Complete")
        complete.tap()

        let undo = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'undoComplete_'"))
            .firstMatch
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "Done should first wait with Undo")
        undo.tap()
        XCTAssertTrue(undo.waitForNonExistence(timeout: 5), "Undo should end the window")

        // The task is still open and listed.
        XCTAssertFalse(element("emptyViewLabel", in: app).waitForExistence(timeout: 5), "New must not empty after Undo")
        XCTAssertTrue(row.exists, "The task should stay in New after Undo")
    }

    /// #34: "Analyze again" in the detail's menu runs the pipeline once more and says what it found.
    /// The CI simulator has no Apple Intelligence, so this proves the path and the report, not the model.
    @MainActor
    func testAnalyzeAgainReportsBack() throws {
        let app = launch()
        let row = captureIntoNew("Steuererklärung morgen abgeben", in: app)
        row.tap()
        assertDetailRawText("Steuererklärung morgen abgeben", in: app)

        let more = element("detailMoreMenu", in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Detail should offer the More menu")
        more.tap()
        let analyze = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "analyzeAgainButton", "Analyze again"))
            .firstMatch
        XCTAssertTrue(analyze.waitForExistence(timeout: 5), "More should offer Analyze again")
        analyze.tap()

        let note = element("reanalysisNote", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 10), "The detail should report what the second run found")
        XCTAssertTrue(element("detailRawTextMarker", in: app).exists, "The raw text stays as it was")
    }

    /// #441: a sentence at the end of the detail sets the fields the rules read; the rest stays.
    /// #556, #557: the due editor of a task due today at 8:00. Both weeks of the calendar stand, today
    /// among them and tappable (the first week was dropped). The 8:00 is a word of its own, marked, and
    /// "Other time …" stays next to it (8:00 used to take its place); a tap on it opens the wheel.
    @MainActor
    func testDueEditorKeepsOtherTimeAndThisWeek() throws {
        let app = launch()
        _ = captureAndOpenDetail("Heute um 8 Uhr Brötchen holen", in: app)

        let dueRow = revealField("field_dueDate", in: app)
        XCTAssertTrue(dueRow.waitForExistence(timeout: 10), "The rules should read today at 8 as the due date")
        dueRow.tap()

        let today = Calendar.current.startOfDay(for: Date()).formatted(.iso8601.year().month().day())
        let todayCell = element("dueDay_\(today)", in: app)
        XCTAssertTrue(todayCell.waitForExistence(timeout: 5), "The calendar should show this week, today included")
        XCTAssertTrue(todayCell.isHittable, "Today should be tappable in the calendar")

        let custom = element("quickTime_custom", in: app)
        XCTAssertTrue(custom.waitForExistence(timeout: 5), "The set 8:00 should stand as a word of its own")
        XCTAssertTrue(custom.label.contains("8:00"), "The own time word was \(custom.label)")
        XCTAssertTrue(custom.isSelected, "The set time should be marked")
        let other = element("quickTime_other", in: app)
        XCTAssertTrue(other.exists, "Other time … should stay next to a time of its own")
        XCTAssertEqual(other.label, "Other time …")
        let nine = element("quickTime_9", in: app)
        let sameLine = abs(custom.frame.midY - nine.frame.midY) < 4
        XCTAssertTrue(sameLine ? custom.frame.minX < nine.frame.minX : custom.frame.minY < nine.frame.minY,
                      "8:00 should stand before 9:00, was \(custom.frame) and \(nine.frame)")
        attachScreenshot(app, "556-faellig-andere-uhrzeit")

        other.tap()
        XCTAssertTrue(element("dueOtherTimePicker", in: app).waitForExistence(timeout: 5), "Other time … should open the wheel")
    }

    /// #544: the note takes typed text on the iPhone too, and keeps it. Leaving the field writes the
    /// note; at rest it shows as text, and it is still there after the detail is closed and reopened.
    @MainActor
    func testNoteIsTypedAndSaved() throws {
        let app = launch()
        _ = captureAndOpenDetail("Paket abholen", in: app)

        openSection("field_notes", showing: "noteField", in: app)
        let note = element("noteField", in: app)
        for _ in 0..<5 where !(note.exists && note.isHittable) { app.swipeUp() }
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The detail should offer the note field")
        note.tap()
        note.typeText("Abholcode 4711")
        // Leaving the field writes the note: the title takes the focus.
        let title = element("detailTitleField", in: app)
        for _ in 0..<5 where !(title.exists && title.isHittable) { app.swipeDown() }
        title.tap()
        let text = element("noteText", in: app)
        XCTAssertTrue(text.waitForExistence(timeout: 5), "At rest the note shows as text")
        XCTAssertTrue(text.label.contains("4711"), "Note was \(text.label)")
        attachScreenshot(app, "544-notiz-gespeichert")

        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
        let row = taskRow(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The task should still be in New")
        row.tap()
        let again = element("noteText", in: app)
        for _ in 0..<5 where !again.exists { app.swipeUp() }
        XCTAssertTrue(again.waitForExistence(timeout: 5), "Reopened, the detail should show the note")
        XCTAssertTrue(again.label.contains("4711"), "Saved note was \(again.label)")
    }

    /// #786: a policy number is no phone number. It stays in the title, and the rule writes no note,
    /// on the iPhone as on the Mac (the iOS `NSDataDetector` took the bare digit run for a number).
    @MainActor
    func testPolicyNumberStaysInTitleAndNoteStaysEmpty() throws {
        let app = launch()
        let titleField = captureAndOpenDetail("Die Police 30021988 umschreiben lassen", in: app)

        XCTAssertTrue(waitForValue("Die Police 30021988 umschreiben lassen", of: titleField),
                      "Title should keep the number, was \(String(describing: titleField.value))")
        let note = element("noteText", in: app)
        for _ in 0..<3 where !note.exists { app.swipeUp() }
        XCTAssertFalse(note.waitForExistence(timeout: 3), "No note expected, found \(note.label)")
        attachScreenshot(app, "786-police-im-titel")
    }

    /// #786 (#439): a dictated phone number leaves the title and goes into the note.
    @MainActor
    func testPhoneNumberGoesToNoteNotTitle() throws {
        let app = launch()
        let titleField = captureAndOpenDetail("Ruf 040 1234567 an", in: app)

        let note = element("noteText", in: app)
        for _ in 0..<5 where !note.waitForExistence(timeout: 2) { app.swipeUp() }
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The rule should write the number into the note")
        XCTAssertTrue(note.label.contains("040 1234567"), "Note was \(note.label)")
        for _ in 0..<5 where !titleField.isHittable { app.swipeDown() }
        let title = (titleField.value as? String) ?? ""
        XCTAssertFalse(title.contains("040"), "Title should leave the number out, was \(title)")
        attachScreenshot(app, "786-nummer-in-notiz")
    }

    /// #544: "File" opens the document picker and "Photo" the photo picker. Both are system sheets
    /// with a Cancel button the detail itself never has; Cancel closes them again.
    @MainActor
    func testFileAndPhotoButtonsOpenTheirPickers() throws {
        let app = launch()
        _ = captureAndOpenDetail("Vertrag ablegen", in: app)

        openSection("field_attachments", showing: "addFileButton", in: app)
        let file = element("addFileButton", in: app)
        for _ in 0..<5 where !(file.exists && file.isHittable) { app.swipeUp() }
        XCTAssertTrue(file.waitForExistence(timeout: 5), "The detail should offer File")
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertFalse(cancel.exists, "Nothing to cancel before the tap")
        file.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 20), "File should open the document picker")
        attachScreenshot(app, "544-datei-auswahl")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Cancel should close the document picker")

        let photo = element("addPhotoButton", in: app)
        XCTAssertTrue(photo.waitForExistence(timeout: 5), "The detail should offer Photo")
        photo.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 20), "Photo should open the photo picker")
        attachScreenshot(app, "544-foto-auswahl")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Cancel should close the photo picker")
    }
}
