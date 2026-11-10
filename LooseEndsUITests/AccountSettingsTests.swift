import XCTest

/// #615 S4c-1: the settings group "Claude" under iCloud, played against the stand-in service of `--ui-testing`
/// (no Apple dialog, no network). The English texts below are the catalog keys; the German ones are in the spec.
/// The head "Claude" carries `accountSection`; the hint under the group carries `accountHint`.
/// The group stands under iCloud, near the bottom of the first screen: the form builds rows only once they are on
/// screen, so every check of a row or the hint first scrolls it into view (`reveal`).
final class AccountSettingsTests: XCTestCase {
    static let intro = "Sign in with Apple so Claude can read your open tasks and add new ones. Without signing in, nothing leaves this device."
    static let signedInHint = "Claude sees your open tasks. Signing out disconnects only this device. Deleting the account removes everything the service keeps of yours for Claude."
    static let notAllowed = "This Apple account is not yet cleared for Claude."
    static let retryLater = "The service can't be reached right now. Try again later."
    static let dialogTitle = "Delete account?"
    static let dialogMessage = "Claude will no longer see your tasks. Your tasks in the app stay as they are."

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    @MainActor
    private func openSettings(_ extra: [String] = []) throws -> XCUIApplication {
        #if os(macOS)
        throw XCTSkip("On the Mac the gear opens the settings window (SettingsLink), not a sheet; see SettingsSmokeTests.")
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        let gear = app.buttons["settingsButton"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "The start screen should show the gear")
        gear.tap()
        XCTAssertTrue(element(app, "iCloudSyncRow").waitForExistence(timeout: 5), "The settings should show the iCloud row")
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Scrolls the settings gently until `id` is on screen and tappable; fails with the identifier after six swipes.
    @MainActor
    @discardableResult
    private func reveal(_ app: XCUIApplication, _ id: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        let target = element(app, id)
        for _ in 0..<6 {
            if target.waitForExistence(timeout: 1), target.isHittable { return target }
            app.swipeUp(velocity: .slow)
        }
        if !(target.exists && target.isHittable) {
            XCTFail("\(id) did not come into view", file: file, line: line)
        }
        return target
    }

    /// Label and value of a combined row, so a check does not depend on how the system splits them.
    private func spoken(_ element: XCUIElement) -> String {
        [element.label, element.value as? String ?? ""].joined(separator: " ")
    }

    @MainActor
    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func assertSignedOut(_ app: XCUIApplication, hint: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = reveal(app, "accountAppleButton", file: file, line: line)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "The sign-in button should be there", file: file, line: line)
        XCTAssertTrue(button.isHittable, "The sign-in button should be tappable", file: file, line: line)
        let shown = reveal(app, "accountHint", file: file, line: line)
        XCTAssertTrue(shown.waitForExistence(timeout: 5), file: file, line: line)
        XCTAssertEqual(shown.label, hint, file: file, line: line)
        XCTAssertFalse(element(app, "accountSignedInRow").exists, "No signed-in row while signed out", file: file, line: line)
        XCTAssertFalse(element(app, "accountSignOutRow").exists, file: file, line: line)
        XCTAssertFalse(element(app, "accountDeleteRow").exists, file: file, line: line)
    }

    @MainActor
    private func signIn(_ app: XCUIApplication) {
        let button = reveal(app, "accountAppleButton")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(element(app, "accountSignedInRow").waitForExistence(timeout: 5), "Signing in should show the signed-in row")
    }

    // MARK: - AC-1 to AC-7

    @MainActor
    func testSignedOutShowsGroupBelowICloud() throws {
        let app = try openSettings()
        let head = element(app, "accountSection")
        XCTAssertTrue(head.waitForExistence(timeout: 5), "The settings should show the group Claude")
        XCTAssertEqual(head.label, "Claude")
        // Compared before any scrolling, while the iCloud row and the head are both on screen.
        XCTAssertLessThan(element(app, "iCloudSyncRow").frame.minY, head.frame.minY, "Claude stands below the iCloud row")
        assertSignedOut(app, hint: Self.intro)
        shoot(app, "account-signed-out")

        // Scroll gently until the calendar row is on screen; the group's hint must still stand above it.
        let calendar = element(app, "defaultCalendarRow")
        for _ in 0..<4 where !(calendar.exists && calendar.isHittable) {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(calendar.exists, "The calendar row should come into view")
        let hint = element(app, "accountHint")
        XCTAssertTrue(hint.exists, "The hint of Claude should still be in view")
        XCTAssertLessThan(hint.frame.minY, calendar.frame.minY, "Claude stands above the calendar")
    }

    @MainActor
    func testSignInShowsSignedInRows() throws {
        let app = try openSettings()
        signIn(app)
        let row = element(app, "accountSignedInRow")
        reveal(app, "accountDeleteRow")
        reveal(app, "accountHint")
        XCTAssertTrue(spoken(row).contains("Signed in with Apple"), spoken(row))
        XCTAssertTrue(spoken(row).contains("This device"), spoken(row))
        XCTAssertTrue(element(app, "accountSignOutRow").exists)
        XCTAssertTrue(element(app, "accountSignOutRow").label.contains("Sign out"))
        XCTAssertTrue(element(app, "accountDeleteRow").exists)
        XCTAssertTrue(element(app, "accountDeleteRow").label.contains("Delete account"))
        XCTAssertEqual(element(app, "accountHint").label, Self.signedInHint)
        XCTAssertFalse(element(app, "accountAppleButton").exists, "The sign-in button goes once signed in")
        shoot(app, "account-signed-in")
    }

    @MainActor
    func testSignOutNeedsNoConfirmation() throws {
        let app = try openSettings()
        signIn(app)
        reveal(app, "accountSignOutRow").tap()
        XCTAssertFalse(app.staticTexts[Self.dialogTitle].exists, "Signing out asks nothing")
        XCTAssertTrue(element(app, "accountSignedInRow").waitForNonExistence(timeout: 5))
        assertSignedOut(app, hint: Self.intro)
    }

    @MainActor
    private func openDeleteDialog(_ app: XCUIApplication) {
        reveal(app, "accountDeleteRow").tap()
        XCTAssertTrue(app.staticTexts[Self.dialogTitle].waitForExistence(timeout: 5), "Deleting asks first")
        XCTAssertTrue(app.staticTexts[Self.dialogMessage].exists)
        XCTAssertTrue(app.buttons["Delete account"].exists)
    }

    @MainActor
    func testDeleteCancelKeepsSignedIn() throws {
        let app = try openSettings()
        signIn(app)
        openDeleteDialog(app)
        shoot(app, "account-delete-dialog")
        // Since iOS 26 a `.cancel` button may not be drawn; tapping beside the dialog cancels it then.
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        }
        XCTAssertTrue(app.staticTexts[Self.dialogTitle].waitForNonExistence(timeout: 5), "Cancel closes the dialog")
        XCTAssertTrue(element(app, "accountSignedInRow").exists, "Cancel keeps the account")
        XCTAssertFalse(element(app, "accountAppleButton").exists)
    }

    @MainActor
    func testDeleteConfirmSignsOut() throws {
        let app = try openSettings()
        signIn(app)
        openDeleteDialog(app)
        app.buttons["Delete account"].tap()
        XCTAssertTrue(element(app, "accountSignedInRow").waitForNonExistence(timeout: 5))
        assertSignedOut(app, hint: Self.intro)
    }

    @MainActor
    func testNotAllowedShowsItsSentence() throws {
        let app = try openSettings(["--ui-testing-account-not-allowed"])
        reveal(app, "accountAppleButton").tap()
        reveal(app, "accountHint")
        XCTAssertTrue(app.staticTexts[Self.notAllowed].waitForExistence(timeout: 5))
        assertSignedOut(app, hint: Self.notAllowed)
        shoot(app, "account-not-allowed")
    }

    /// #615 S4c-2b (F001): while signing in the Apple button stays, grey, with the progress row under it; a second tap
    /// does nothing. The stand-in answers after 2 s (`--ui-testing-account-slow`).
    @MainActor
    func testSigningInKeepsDisabledAppleButton() throws {
        let app = try openSettings(["--ui-testing-account-slow"])
        let button = reveal(app, "accountAppleButton")
        button.tap()

        let progress = element(app, "accountProgressRow")
        XCTAssertTrue(progress.waitForExistence(timeout: 2), "Signing in should show the progress row")
        XCTAssertTrue(spoken(progress).contains("Signing in …"), spoken(progress))
        XCTAssertTrue(button.exists, "The sign-in button stays while Apple's answer is on its way")
        XCTAssertFalse(button.isEnabled, "The sign-in button cannot be tapped while signing in")
        XCTAssertLessThan(button.frame.minY, progress.frame.minY, "The progress row stands under the button")
        shoot(app, "account-signing-in")

        button.tap()
        XCTAssertTrue(element(app, "accountSignedInRow").waitForExistence(timeout: 10), "Signing in should end signed in")
        XCTAssertFalse(element(app, "accountAppleButton").exists, "The sign-in button goes once signed in")
        XCTAssertFalse(element(app, "accountHint").label == Self.retryLater, "The second tap started nothing")
        shoot(app, "account-signed-in-after-wait")
    }

    @MainActor
    func testRetryLaterShowsItsSentence() throws {
        let app = try openSettings(["--ui-testing-account-retry-later"])
        reveal(app, "accountAppleButton").tap()
        reveal(app, "accountHint")
        XCTAssertTrue(app.staticTexts[Self.retryLater].waitForExistence(timeout: 5))
        assertSignedOut(app, hint: Self.retryLater)
        // A second try is possible and ends the same way.
        reveal(app, "accountAppleButton").tap()
        reveal(app, "accountHint")
        XCTAssertTrue(app.staticTexts[Self.retryLater].waitForExistence(timeout: 5))
        assertSignedOut(app, hint: Self.retryLater)
        shoot(app, "account-retry-later")
    }
}
