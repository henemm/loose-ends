import XCTest

/// The detail as the approved draft shows it (#538, Henning 2026-10-18), run with the standard switches
/// (`--ui-testing-fields-standard`), not with everything on as the other smoke tests do. Before this
/// change the detail showed nine sections, seven of them empty with a head and a button each; now a
/// new task shows only its title and one line of words, and a section comes with its word.
final class FieldsSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-fields-standard", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Captures `text`, opens it from "New" and returns once the detail stands.
    @MainActor
    private func captureAndOpenDetail(_ text: String, in app: XCUIApplication) {
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
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Captured task should appear in New")
        row.tap()
        XCTAssertTrue(element("detailTitleField", in: app).waitForExistence(timeout: 5), "Detail should open")
    }

    @MainActor
    private func backToStart(in app: XCUIApplication) {
        let gear = app.buttons["settingsButton"]
        for _ in 0..<4 where !(gear.exists && gear.isHittable) {
            let back = app.navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: 5) else { break }
            back.tap()
            _ = gear.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(gear.waitForExistence(timeout: 5), "Should be back at the start screen")
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Draft "Morgen": a new task without a date offers Note, Attachment · Due · Duration · Tags and
    /// nothing else; no empty section stands on the page; the word opens the section.
    @MainActor
    func testNewTaskShowsOnlyTheStandardWordsAndNoEmptySection() throws {
        let app = launch()
        captureAndOpenDetail("Reher ansprechen wegen Roberts Nachricht", in: app)

        let line = element("wordLine", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 5), "The detail should offer its empty fields as one line of words")
        for word in ["field_notes", "field_attachments", "field_dueDate", "field_duration", "field_contexts"] {
            XCTAssertTrue(element(word, in: app).waitForExistence(timeout: 3), "The standard should offer \(word)")
        }
        // Off in the standard: not offered. Waiting for a date: not offered without one.
        for word in ["field_importance", "field_urgency", "field_energy", "field_project", "field_subtasks",
                     "field_waitingOn", "field_place", "field_repeatRule", "field_calendar"] {
            XCTAssertFalse(element(word, in: app).exists, "\(word) should not be offered on a new task with the standard")
        }
        // No empty section with its own head and button any more.
        for control in ["noteField", "editNoteButton", "addFileButton", "addPhotoButton", "showInCalendarToggle",
                        "addPlaceButton", "subtaskTextField", "chooseBlockerButton", "waitingOnHeader"] {
            XCTAssertFalse(element(control, in: app).exists, "An empty \(control) should not stand on the page")
        }
        shot(app, "538-1-new-task-standard-words")

        // The word opens the section ready for input; the word leaves the line.
        element("field_notes", in: app).tap()
        let note = element("noteField", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5), "Tapping + Note should open the note field")
        XCTAssertFalse(element("field_notes", in: app).exists, "An opened section leaves the word line")
        note.typeText("Robert wartet auf Antwort")
        element("detailTitleField", in: app).tap()
        XCTAssertTrue(element("noteText", in: app).waitForExistence(timeout: 5), "Leaving the field should show the note as text")
        shot(app, "538-2-note-opened-from-the-word")
    }

    /// Draft rule 4: with a date, Calendar joins the When line; Repeat only once it is switched on.
    @MainActor
    func testCalendarWaitsForADate() throws {
        let app = launch()
        captureAndOpenDetail("Steuerbescheid morgen prüfen", in: app)

        XCTAssertTrue(element("field_calendar", in: app).waitForExistence(timeout: 5), "A dated task should offer Calendar")
        let dueRow = element("field_dueDate", in: app)
        XCTAssertTrue(dueRow.waitForExistence(timeout: 5), "The set date stands as a line")
        XCTAssertTrue(dueRow.label.contains("Tomorrow"), "Row label was \(dueRow.label)")
        XCTAssertFalse(element("field_repeatRule", in: app).exists, "Repeat is off in the standard")
        XCTAssertFalse(element("showInCalendarToggle", in: app).exists, "The calendar section waits for its word")
        shot(app, "538-3-dated-task-offers-calendar")
    }

    /// Draft rule 7: Settings › Fields, one switch per field; switching Projects on offers the word in
    /// the detail and the group on the start page, which the standard leaves out.
    @MainActor
    func testFieldsSettingSwitchesWordAndStartPageGroup() throws {
        let app = launch()
        XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(element("projectsToggle", in: app).exists, "With Projects off the start page has no Projects group")
        XCTAssertTrue(element("contextsToggle", in: app).waitForExistence(timeout: 5), "Tags are on in the standard")

        app.buttons["settingsButton"].tap()
        let fieldsRow = element("fieldsRow", in: app)
        for _ in 0..<4 where !(fieldsRow.exists && fieldsRow.isHittable) { app.swipeUp() }
        XCTAssertTrue(fieldsRow.waitForExistence(timeout: 5), "Settings should offer Fields")
        fieldsRow.tap()
        XCTAssertTrue(element("fieldSettings", in: app).waitForExistence(timeout: 5), "The Fields page should open")
        shot(app, "538-4-fields-page")
        let projects = app.switches["fieldSwitch_project"]
        for _ in 0..<4 where !(projects.exists && projects.isHittable) { app.swipeUp() }
        XCTAssertTrue(projects.waitForExistence(timeout: 5), "The page should hold a switch for Projects")
        XCTAssertEqual(projects.value as? String, "0", "Projects are off in the standard")
        projects.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(projects.value as? String, "1")
        XCTAssertFalse(app.switches["fieldSwitch_dueDate"].exists, "Due is fixed and has no switch")

        app.navigationBars.buttons.firstMatch.tap()
        let done = app.buttons["settingsDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(element("projectsToggle", in: app).waitForExistence(timeout: 5),
                      "With Projects on the start page shows the Projects group")

        captureAndOpenDetail("Keller entrümpeln", in: app)
        XCTAssertTrue(element("field_project", in: app).waitForExistence(timeout: 5), "The detail should now offer + Project")
        XCTAssertFalse(element("field_importance", in: app).exists, "The other switches stay off")
        shot(app, "538-5-project-offered-after-switch")
    }

    /// #344: "Important" and "Urgent" in the list row are signs without words; the detail repeats each
    /// sign behind the value of its register line. The words are sorted in by rules at capture.
    /// The duration is read from "20 Minuten" by the rule (#673). Project does not become a register line here
    /// (projects are off in the standard); its sign is covered in FieldGlyphTests.
    @MainActor
    func testSignsStandInTheRowAndBehindTheValuesInTheDetail() throws {
        let app = launch()
        captureAndOpenDetail("Wichtig dringend Steuerbescheid morgen 20 Minuten prüfen", in: app)

        for field in ["importance", "urgency", "dueDate", "duration"] {
            let row = element("field_\(field)", in: app)
            XCTAssertTrue(row.waitForExistence(timeout: 5), "The detail should hold field_\(field)")
            XCTAssertTrue(element("fieldGlyph_\(field)", in: app).exists, "fieldGlyph_\(field) should stand in the line")
        }
        XCTAssertTrue(element("field_importance", in: app).label.contains("Importance"),
                      "The line keeps its name for VoiceOver, was \(element("field_importance", in: app).label)")
        shot(app, "344-1-detail-signs")

        backToStart(in: app)
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let importance = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'importanceMarker_'")).firstMatch
        let urgency = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'urgencyMarker_'")).firstMatch
        XCTAssertTrue(importance.waitForExistence(timeout: 5), "A high importance shows its sign in the row")
        XCTAssertTrue(urgency.exists, "A high urgency shows its sign in the row")
        XCTAssertEqual(importance.label, "Important")
        XCTAssertEqual(urgency.label, "Urgent")
        shot(app, "344-2-row-signs")
    }

    /// #344 UI test C (AC-4, AC-5): below High the row shows no sign, the detail still shows the ladder.
    /// The rules only ever set High (`ImportanceUrgencyRule`), so the task is captured as High/High and
    /// lowered in the register lines' editors to Medium, then Low, and its urgency to Low.
    @MainActor
    func testLowAndMediumShowNoSignInTheRowButTheLadderInTheDetail() throws {
        let app = launch()
        captureAndOpenDetail("Wichtig dringend Steuerbescheid prüfen", in: app)

        let importanceRow = element("field_importance", in: app)
        XCTAssertTrue(importanceRow.waitForExistence(timeout: 5), "The detail should hold field_importance")
        choose("Medium", in: importanceRow, app: app)
        XCTAssertTrue(element("fieldGlyph_importance", in: app).exists, "Medium keeps its sign behind the value")
        shot(app, "344-3-detail-importance-medium")

        choose("Low", in: importanceRow, app: app)
        XCTAssertTrue(element("fieldGlyph_importance", in: app).exists, "Low keeps its sign behind the value")
        let urgencyRow = element("field_urgency", in: app)
        XCTAssertTrue(urgencyRow.waitForExistence(timeout: 5), "The detail should hold field_urgency")
        choose("Low", in: urgencyRow, app: app)
        XCTAssertTrue(element("fieldGlyph_urgency", in: app).exists, "Urgency keeps its sign behind the value")
        shot(app, "344-4-detail-importance-low")

        backToStart(in: app)
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The task should stand in New")
        let importance = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'importanceMarker_'")).firstMatch
        let urgency = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'urgencyMarker_'")).firstMatch
        XCTAssertFalse(importance.exists, "A low importance shows no sign in the row")
        XCTAssertFalse(urgency.exists, "A low urgency shows no sign in the row")
        shot(app, "344-5-row-without-signs")
    }

    /// Opens the editor of a register line, picks `level` and waits until the line says it.
    @MainActor
    private func choose(_ level: String, in line: XCUIElement, app: XCUIApplication) {
        line.tap()
        let option = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", level)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "The editor should offer \(level)")
        option.tap()
        // A single choice closes the editor by itself (#482).
        let shows = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", level), object: line)
        XCTAssertEqual(XCTWaiter().wait(for: [shows], timeout: 5), .completed, "Line label was \(line.label)")
    }
}
