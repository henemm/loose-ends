import XCTest

/// "Show in calendar" on the real path (#203): the calendar bridge runs (`--ui-testing-calendar`),
/// so switching it on asks for access, creates the "Loose Ends" calendar and shows it as the target.
/// The store stays in memory (`--ui-testing`); only the simulator's calendar is touched.
final class CalendarTargetTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testSwitchOnShowsTargetCalendar() throws {
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

        allowCalendarAccessIfAsked()

        let target = app.descendants(matching: .any).matching(identifier: "calendarTargetRow").firstMatch
        if !target.waitForExistence(timeout: 10) { app.swipeUp() }
        XCTAssertTrue(target.waitForExistence(timeout: 5), "The detail should name the calendar the event goes to")
        XCTAssertTrue(target.label.contains("Loose Ends"), "Target calendar label was \(target.label)")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "detail-target-calendar"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The system asks once per install, in the simulator's own language. A simulator that already
    /// granted access shows nothing, which is fine.
    @MainActor
    private func allowCalendarAccessIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow Full Access", "Vollen Zugriff erlauben"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: label == "Allow Full Access" ? 5 : 1) {
                button.tap()
                return
            }
        }
    }
}
