#if os(iOS)
import XCTest

/// The place notification (#240, Schnitt 2): the notification center runs as the real delegate
/// (`--ui-testing-notifications`), and `--ui-testing-places` puts the task the banner names
/// (`…0240`, „UI test place“, with a place) into the in-memory store. The real place trigger never
/// fires in the Simulator, and `add` from the app fails there (UNErrorDomain 2003), so the banner comes
/// from outside: `LOOSEENDS_PUSH=scripts/fixtures/place-reminder.apns ./scripts/sim.sh test-proof
/// PlaceNotificationTapTests` pushes it every 5 s; without it (CI) the tests skip.
final class PlaceNotificationTapTests: XCTestCase {
    private let bannerTitle = "UI test place"

    @MainActor
    private var springboard: XCUIApplication { XCUIApplication(bundleIdentifier: "com.apple.springboard") }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LOOSEENDS_PUSH_FEED"] == "1",
                          "Needs pushed place notifications: LOOSEENDS_PUSH=… ./scripts/sim.sh test-proof")
    }

    @MainActor
    func testBannerWhileAppIsOpenKeepsAppAlive() throws {
        let app = launchAndAllow()

        XCTAssertTrue(banner().waitForExistence(timeout: 60), "The place notification never showed up in front")
        XCTAssertFalse(app.wait(for: .notRunning, timeout: 5), "App crashed when the place notification came in")
        XCTAssertEqual(app.state, .runningForeground)
        XCTAssertTrue(app.buttons["captureButton"].isHittable)
        attachScreenshot(of: app, named: "place-in-front")
    }

    @MainActor
    func testTapBannerFromHomeOpensApp() throws {
        let app = launchAndAllow()
        XCUIDevice.shared.press(.home)

        let banner = banner()
        XCTAssertTrue(banner.waitForExistence(timeout: 60), "The place notification never showed up")
        banner.tap()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15), "App not in front after the tap, state \(app.state.rawValue)")
        XCTAssertFalse(app.wait(for: .notRunning, timeout: 5), "App crashed after opening from the place notification")
        attachScreenshot(of: app, named: "opened-from-place")
    }

    @MainActor
    func testButtonsCompleteWithoutTomorrow() throws {
        let app = launchAndAllow()
        XCTAssertTrue(app.staticTexts[bannerTitle].waitForExistence(timeout: 10), "The seeded place task is not in the list")

        let banner = banner()
        XCTAssertTrue(banner.waitForExistence(timeout: 60), "The place notification never showed up in front")
        banner.press(forDuration: 1.5)

        let complete = springboard.buttons["Complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 10), "No Complete button on the place notification")
        XCTAssertTrue(springboard.buttons["Next up"].exists, "No Next up button on the place notification")
        XCTAssertFalse(springboard.buttons["Tomorrow"].exists, "A place has no day, Tomorrow must not show")
        attachScreenshot(of: app, named: "place-buttons")
        complete.tap()

        let row = app.staticTexts[bannerTitle]
        XCTAssertTrue(row.waitForNonExistence(timeout: 15), "The place task is still open after Complete")
        XCTAssertFalse(app.wait(for: .notRunning, timeout: 3), "App crashed after Complete")
        attachScreenshot(of: app, named: "place-completed")
    }

    // MARK: - Helpers

    @MainActor
    private func launchAndAllow() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing", "--ui-testing-notifications", "--ui-testing-places", "-onboardingDone", "YES",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["captureButton"].waitForExistence(timeout: 15), "Start screen not reached")
        allowIfAsked()
        return app
    }

    /// Notification and location access are asked once per install, in the simulator's own language.
    @MainActor
    private func allowIfAsked() {
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 45) else { return }
            let labels = ["Allow", "Erlauben", "Allow While Using App", "Beim Verwenden der App erlauben"]
            guard let label = labels.first(where: { alert.buttons[$0].exists }) else {
                XCTFail("Unknown permission prompt: \(alert.buttons.allElementsBoundByIndex.map(\.label))")
                return
            }
            alert.buttons[label].tap()
        }
    }

    @MainActor
    private func banner() -> XCUIElement {
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
#endif
