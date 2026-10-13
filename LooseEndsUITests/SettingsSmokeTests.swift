import XCTest

/// #311: the gear on the start screen opens the settings with the reminder time, and Done closes
/// them again. The value is not changed here: it lives in `UserDefaults` and would outlast the run.
final class SettingsSmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testGearOpensSettingsWithReminderTime() throws {
        #if os(macOS)
        throw XCTSkip("On the Mac the gear opens the settings window (SettingsLink), not a sheet with Done.")
        #endif
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let gear = app.buttons["settingsButton"]
        XCTAssertTrue(gear.waitForExistence(timeout: 10), "The start screen should show the gear")
        gear.tap()

        let picker = app.descendants(matching: .any).matching(identifier: "reminderTimePicker").firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "The settings should show the reminder time")

        let sync = app.descendants(matching: .any).matching(identifier: "iCloudSyncRow").firstMatch
        XCTAssertTrue(sync.exists, "The settings should show the iCloud sync row (#377)")

        let done = app.buttons["settingsDoneButton"]
        XCTAssertTrue(done.exists)
        done.tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Done should close the settings")
        XCTAssertTrue(app.buttons["captureButton"].isHittable, "The start screen should be usable again")
    }
}
