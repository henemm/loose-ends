import XCTest

/// "Show in calendar" on the real path (#203): the calendar bridge runs (`--ui-testing-calendar`),
/// so switching it on asks for access, creates the "Loose Ends" calendar and shows it as the target;
/// picking another calendar for the task replaces it (#203 Teil C).
/// The store stays in memory (`--ui-testing`); only the simulator's calendar is touched.
final class CalendarTargetTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSwitchOnShowsTargetCalendar() throws {
        // XCTest's own handling taps the cancel button of a system prompt in the way of a gesture,
        // which turned access off on CI (#203). This one allows it instead.
        addUIInterruptionMonitor(withDescription: "Calendar access") { alert in
            for label in ["Allow Full Access", "Vollen Zugriff erlauben"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-calendar", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let capture = app.buttons["captureButton"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        let field = app.descendants(matching: .any).matching(identifier: "captureTextField").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Zahnarzt morgen um 14 Uhr")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = app.descendants(matching: .any).matching(identifier: "viewRow_new").firstMatch
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let toggle = app.switches["showInCalendarToggle"]
        if !toggle.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Detail should offer Show in calendar")
        XCTAssertEqual(toggle.value as? String, "0")
        // The element spans the row; the switch itself sits at the trailing edge.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()

        // A time without a duration asks for the duration first (#203, Teil B).
        let hour = app.descendants(matching: .any).matching(identifier: "calendarAskDuration_hour1").firstMatch
        if hour.waitForExistence(timeout: 5) {
            hour.tap()
            app.buttons["calendarAskConfirm"].tap()
        }

        let target = app.descendants(matching: .any).matching(identifier: "calendarTargetRow").firstMatch
        allowCalendarAccessIfAsked(until: target)

        if !target.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 5), "The detail should name the calendar the event goes to")
        XCTAssertTrue(target.label.contains("Loose Ends"), "Target calendar label was \(target.label)")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "detail-target-calendar"
        shot.lifetime = .keepAlways
        add(shot)

        // The task picks its own calendar (#203 Teil C): the row opens the list, another calendar
        // replaces "Loose Ends" in the row.
        target.tap()
        let picks = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'calendarPick_' AND NOT identifier ENDSWITH 'Loose Ends'"))
        let other = picks.firstMatch
        XCTAssertTrue(other.waitForExistence(timeout: 5), "The picker should list a calendar besides Loose Ends")
        let otherName = String(other.identifier.dropFirst("calendarPick_".count))
        let picker = XCTAttachment(screenshot: app.screenshot())
        picker.name = "calendar-picker"
        picker.lifetime = .keepAlways
        add(picker)
        other.tap()

        XCTAssertTrue(target.waitForExistence(timeout: 5))
        let moved = NSPredicate(format: "label CONTAINS %@", otherName)
        expectation(for: moved, evaluatedWith: target)
        waitForExpectations(timeout: 10)
        let chosen = XCTAttachment(screenshot: app.screenshot())
        chosen.name = "detail-chosen-calendar"
        chosen.lifetime = .keepAlways
        add(chosen)
    }

    /// The system asks once per install, in the simulator's own language. On a slow CI runner the
    /// prompt came only after about eight seconds (#203), so this watches for it until the target row
    /// shows up, for at most 30 seconds. A simulator that already granted access shows no prompt.
    @MainActor
    private func allowCalendarAccessIfAsked(until target: XCUIElement) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            for label in ["Allow Full Access", "Vollen Zugriff erlauben"] where springboard.buttons[label].exists {
                springboard.buttons[label].tap()
                return
            }
            if target.waitForExistence(timeout: 1) { return }
        }
    }
}
