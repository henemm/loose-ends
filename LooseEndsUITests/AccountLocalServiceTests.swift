import XCTest

/// #615 S4f: signing out and deleting the account in the group "Claude", played with the real `ServiceClient` against
/// the throwaway service of `server/scripts/local-service.sh` (debug way of #795 S3b-2, no stand-in). The app starts
/// without `--ui-testing`, which would pick the stand-in transport. Address and session come from the test runner's
/// environment (`LOOSEENDS_DEBUG_SERVICE`, `LOOSEENDS_DEBUG_SESSION`, passed through by `sim.sh` as `TEST_RUNNER_…`);
/// without them every test is skipped, so the class stays green in CI. Only ever a token of the throwaway database.
/// What the service did is read outside the test (`local-fixture.ts rows`); here only the screen is checked.
final class AccountLocalServiceTests: XCTestCase {
    static let intro = "Sign in with Apple so Claude can read your open tasks and add new ones. Without signing in, nothing leaves this device."
    static let dialogTitle = "Delete account?"

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Starts the app on the debug way and opens the settings; skips without the local service or on the Mac.
    @MainActor
    private func openSettings() throws -> XCUIApplication {
        #if os(macOS)
        throw XCTSkip("On the Mac the gear opens the settings window (SettingsLink), not a sheet; see SettingsSmokeTests.")
        #endif
        let environment = ProcessInfo.processInfo.environment
        guard let service = environment["LOOSEENDS_DEBUG_SERVICE"], !service.isEmpty,
              let session = environment["LOOSEENDS_DEBUG_SESSION"], !session.isEmpty else {
            throw XCTSkip("kein lokaler Dienst: LOOSEENDS_DEBUG_SERVICE und LOOSEENDS_DEBUG_SESSION fehlen")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-LEDebugService", service, "-LEDebugSession", session, "-onboardingDone", "YES",
                               "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let gear = app.buttons["settingsButton"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15), "The start screen should show the gear")
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

    @MainActor
    private func shoot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The debug way starts signed in: the row stands without any sign-in dialog.
    @MainActor
    private func assertSignedIn(_ app: XCUIApplication) {
        let row = reveal(app, "accountSignedInRow")
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The debug session should show the signed-in row")
        reveal(app, "accountDeleteRow")
        XCTAssertFalse(element(app, "accountAppleButton").exists, "No sign-in button while signed in")
    }

    /// After the service answered: the sign-in button and the intro are back, the signed-in rows are gone.
    @MainActor
    private func assertSignedOut(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element(app, "accountSignedInRow").waitForNonExistence(timeout: 10),
                      "The signed-in row should go once the service answered", file: file, line: line)
        let button = reveal(app, "accountAppleButton", file: file, line: line)
        XCTAssertTrue(button.exists, "The sign-in button should be back", file: file, line: line)
        let hint = reveal(app, "accountHint", file: file, line: line)
        XCTAssertEqual(hint.label, Self.intro, file: file, line: line)
        XCTAssertFalse(element(app, "accountSignOutRow").exists, file: file, line: line)
        XCTAssertFalse(element(app, "accountDeleteRow").exists, file: file, line: line)
    }

    // MARK: - AC-5, AC-6

    @MainActor
    func testSignOutEndsOnlyThisSession() throws {
        let app = try openSettings()
        assertSignedIn(app)
        shoot(app, "local-signed-in")
        reveal(app, "accountSignOutRow").tap()
        XCTAssertFalse(app.staticTexts[Self.dialogTitle].exists, "Signing out asks nothing")
        assertSignedOut(app)
        shoot(app, "local-signed-out")
    }

    @MainActor
    func testDeleteRemovesTheAccount() throws {
        let app = try openSettings()
        assertSignedIn(app)
        shoot(app, "local-before-delete")
        reveal(app, "accountDeleteRow").tap()
        XCTAssertTrue(app.staticTexts[Self.dialogTitle].waitForExistence(timeout: 5), "Deleting asks first")
        shoot(app, "local-delete-dialog")
        app.buttons["Delete account"].tap()
        assertSignedOut(app)
        shoot(app, "local-after-delete")
    }
}
