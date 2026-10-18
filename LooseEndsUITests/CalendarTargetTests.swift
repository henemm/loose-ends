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
        scrollUntilVisible(toggle, named: "showInCalendarToggle", in: app, firstWait: 3)
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
        allowCalendarAccessIfAsked()

        scrollUntilVisible(target, named: "calendarTargetRow", in: app, firstWait: 10)
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

    /// The settings name where new appointments go (#203 Teil C2). Without calendar access the row
    /// shows the default and explains why it cannot be changed; opening the settings never asks.
    @MainActor
    func testSettingsShowDefaultCalendarRow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let gear = app.buttons["settingsButton"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10))
        gear.tap()
        let row = app.descendants(matching: .any).matching(identifier: "defaultCalendarRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Settings should offer the default calendar")
        XCTAssertTrue(row.label.contains("Loose Ends"), "Row label was \(row.label)")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "settings-default-calendar"
        shot.lifetime = .keepAlways
        add(shot)
    }

    /// The real path of #203 Teil C2: access is granted on a first task, the settings pick another
    /// calendar as this device's default, a second task switched on lands there, the first one stays
    /// in "Loose Ends" (AC-1, AC-2, AC-3, AC-4). At the end the default goes back to "Loose Ends".
    @MainActor
    func testDefaultCalendarIsStampedOnSwitchOn() throws {
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

        // 1. A first task switched on: access granted, the calendar list is filled.
        let first = switchOnNewTask("Zahnarzt morgen um 14 Uhr", titled: "Zahnarzt", in: app)
        XCTAssertTrue(first.label.contains("Loose Ends"), "First task's calendar was \(first.label)")
        backToStart(in: app)

        // 2. The settings pick another calendar as this device's default.
        let otherName = pickDefault(in: app) { picks in
            picks.matching(NSPredicate(format: "NOT identifier ENDSWITH 'Loose Ends'")).firstMatch
        }
        let settingsShot = XCTAttachment(screenshot: app.screenshot())
        settingsShot.name = "settings-default-chosen"
        settingsShot.lifetime = .keepAlways
        add(settingsShot)
        app.buttons["settingsDoneButton"].tap()

        // 3. A second task switched on goes to the default, not to "Loose Ends".
        let second = switchOnNewTask("Steuer morgen um 16 Uhr", titled: "Steuer", in: app)
        let stamped = NSPredicate(format: "label CONTAINS %@", otherName)
        expectation(for: stamped, evaluatedWith: second)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(second.label.contains("Loose Ends"), "Second task's calendar was \(second.label)")
        let secondShot = XCTAttachment(screenshot: app.screenshot())
        secondShot.name = "detail-default-stamped"
        secondShot.lifetime = .keepAlways
        add(secondShot)

        // 4. The first task stays where it was (AC-4).
        app.navigationBars.buttons.firstMatch.tap()
        let firstRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS 'Zahnarzt'")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "The first task should still be listed")
        firstRow.tap()
        let firstAgain = app.descendants(matching: .any).matching(identifier: "calendarTargetRow").firstMatch
        scrollUntilVisible(firstAgain, named: "calendarTargetRow", in: app, firstWait: 5)
        XCTAssertTrue(firstAgain.waitForExistence(timeout: 5))
        XCTAssertTrue(firstAgain.label.contains("Loose Ends"), "First task moved to \(firstAgain.label)")
        let firstShot = XCTAttachment(screenshot: app.screenshot())
        firstShot.name = "detail-first-stays"
        firstShot.lifetime = .keepAlways
        add(firstShot)

        // Clean up: the default goes back to "Loose Ends" for the next run.
        backToStart(in: app)
        _ = pickDefault(in: app) { picks in
            picks.matching(NSPredicate(format: "identifier ENDSWITH 'Loose Ends'")).firstMatch
        }
        app.buttons["settingsDoneButton"].tap()
    }

    /// Captures `text`, opens it from "New", switches on "Show in calendar" and returns the target row.
    @MainActor
    private func switchOnNewTask(_ text: String, titled title: String, in app: XCUIApplication) -> XCUIElement {
        let capture = app.buttons["captureButton"]
        XCTAssertTrue(capture.waitForExistence(timeout: 10))
        capture.tap()
        let field = app.descendants(matching: .any).matching(identifier: "captureTextField").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5))

        let newRow = app.descendants(matching: .any).matching(identifier: "viewRow_new").firstMatch
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "New should list the task \(title)")
        row.tap()

        let toggle = app.switches["showInCalendarToggle"]
        scrollUntilVisible(toggle, named: "showInCalendarToggle", in: app, firstWait: 3)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Detail should offer Show in calendar")
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()

        let hour = app.descendants(matching: .any).matching(identifier: "calendarAskDuration_hour1").firstMatch
        if hour.waitForExistence(timeout: 5) {
            hour.tap()
            app.buttons["calendarAskConfirm"].tap()
        }
        let target = app.descendants(matching: .any).matching(identifier: "calendarTargetRow").firstMatch
        allowCalendarAccessIfAsked()
        scrollUntilVisible(target, named: "calendarTargetRow", in: app, firstWait: 10)
        XCTAssertTrue(target.waitForExistence(timeout: 5), "The detail should name the calendar the event goes to")
        return target
    }

    /// Back through the navigation until the gear of the start screen shows.
    @MainActor
    private func backToStart(in app: XCUIApplication) {
        let gear = app.buttons["settingsButton"]
        for _ in 0..<4 where !gear.isHittable {
            let back = app.navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: 5) else { break }
            back.tap()
            _ = gear.waitForExistence(timeout: 2)
        }
        XCTAssertTrue(gear.waitForExistence(timeout: 5) && gear.isHittable, "Should be back at the start screen")
    }

    /// Opens the settings, taps the default row, picks the calendar `choose` returns and checks that
    /// the row names it. Leaves the settings open; returns the picked name.
    @MainActor
    private func pickDefault(in app: XCUIApplication, choose: (XCUIElementQuery) -> XCUIElement) -> String {
        app.buttons["settingsButton"].tap()
        let row = app.descendants(matching: .any).matching(identifier: "defaultCalendarRow").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Settings should offer the default calendar")
        row.tap()
        let picks = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'calendarPick_'"))
        let pick = choose(picks)
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "The picker should list the calendar to choose")
        let name = String(pick.identifier.dropFirst("calendarPick_".count))
        pick.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@", name), evaluatedWith: row)
        waitForExpectations(timeout: 10)
        return name
    }

    /// The system asks once per install, in the simulator's own language. Waits a short while for the
    /// prompt itself (#341), not 30 s for the row: a simulator that already granted access shows none. A
    /// prompt that comes later (slow CI runner, #203) is caught by the interruption monitor on the next gesture.
    @MainActor
    private func allowCalendarAccessIfAsked() {
        let alert = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch
        guard alert.waitForExistence(timeout: 3) else { return }
        for label in ["Allow Full Access", "Vollen Zugriff erlauben"] where alert.buttons[label].exists {
            alert.buttons[label].tap()
            return
        }
    }

    /// A row below the screen edge is only created once the list scrolls; one swipe sometimes did not
    /// move the list (#305). Up to five slow swipes on the list, each followed by a short look.
    @MainActor
    private func scrollUntilVisible(_ element: XCUIElement, named name: String, in app: XCUIApplication,
                                    firstWait: TimeInterval, file: StaticString = #filePath, line: UInt = #line) {
        if element.waitForExistence(timeout: firstWait) { return }
        let list = app.collectionViews.firstMatch
        for _ in 0..<5 {
            list.swipeUp(velocity: .slow)
            if element.waitForExistence(timeout: 1) { return }
        }
        XCTFail("\(name) nach 5 Wischversuchen nicht erzeugt", file: file, line: line)
    }
}
