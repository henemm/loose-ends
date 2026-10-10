import XCTest

/// Tapping a due reminder (#295): the notification center runs as the real delegate
/// (`--ui-testing-notifications`). The banner comes from outside: `add` from the app fails in the
/// iOS 27 Simulator (UNErrorDomain 2003), so `LOOSEENDS_PUSH=scripts/fixtures/due-reminder.apns
/// ./scripts/sim.sh test-proof DueNotificationTapTests` pushes it every 5 s and sets
/// `LOOSEENDS_PUSH_FEED`; without it (CI) the tests skip. The store stays in memory
/// (`--ui-testing`); `-onboardingDone YES` makes the launch ask for access as after the onboarding.
final class DueNotificationTapTests: XCTestCase {
    private let bannerTitle = "UI test reminder"

    @MainActor
    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LOOSEENDS_PUSH_FEED"] == "1",
                          "Needs pushed reminders: LOOSEENDS_PUSH=… ./scripts/sim.sh test-proof")
    }

    @MainActor
    func testTapBannerFromHomeOpensApp() throws {
        let app = launchAndAllow()
        XCUIDevice.shared.press(.home)

        let banner = reminderBanner()
        XCTAssertTrue(banner.waitForExistence(timeout: 60), "The due reminder never showed up")
        banner.tap()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App not in front after the tap, state \(app.state.rawValue)")
        XCTAssertTrue(app.buttons["captureButton"].waitForExistence(timeout: 10), "App not usable after the tap")
        // The crash came right after the switch into the app; it must still be there a moment later.
        XCTAssertFalse(app.wait(for: .notRunning, timeout: 5), "App crashed after opening from the reminder")
        XCTAssertTrue(app.buttons["captureButton"].isHittable)
        attachScreenshot(of: app, named: "opened-from-reminder")
    }

    @MainActor
    func testBannerWhileAppIsOpenKeepsAppAlive() throws {
        let app = launchAndAllow()

        XCTAssertTrue(reminderBanner().waitForExistence(timeout: 60), "The due reminder never showed up in front")
        XCTAssertFalse(app.wait(for: .notRunning, timeout: 5), "App crashed when the reminder came in")
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.buttons["captureButton"].isHittable)
        attachScreenshot(of: app, named: "reminder-in-front")
    }

    // MARK: - Helpers

    @MainActor
    private func launchAndAllow() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--ui-testing-notifications", "-onboardingDone", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["captureButton"].waitForExistence(timeout: 15), "Start screen not reached")
        allowNotificationsIfAsked()
        return app
    }

    /// The system asks once per install, in the simulator's own language; a simulator that already
    /// granted access shows no prompt. The launch asks only after the catch-up pass, which took
    /// more than ten seconds on a fresh simulator.
    @MainActor
    private func allowNotificationsIfAsked() {
        let alert = springboard.alerts.firstMatch
        guard alert.waitForExistence(timeout: 45) else { return }
        for label in ["Allow", "Erlauben"] where alert.buttons[label].exists {
            alert.buttons[label].tap()
            return
        }
        XCTFail("Unknown permission prompt: \(alert.buttons.allElementsBoundByIndex.map(\.label))")
    }

    @MainActor
    private func reminderBanner() -> XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", bannerTitle)).firstMatch
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
