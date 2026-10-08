import XCTest

/// The measuring launch argument (#22) opens capture straight away, the way the Control Center
/// button does; without it the app starts as before.
final class LaunchArgumentTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    func testMeasureArgumentOpensCaptureWithoutTap() {
        let app = launch(extra: ["-measureLaunch"])
        XCTAssertTrue(element("captureTextField", in: app).waitForExistence(timeout: 15),
                      "Capture should be open without a tap")
        attachScreenshot(named: "measure-launch-capture")
    }

    @MainActor
    func testWithoutArgumentAppStartsUnchanged() {
        let app = launch()
        XCTAssertTrue(element("captureButton", in: app).waitForExistence(timeout: 15),
                      "Main view should show the capture button")
        XCTAssertFalse(element("captureTextField", in: app).waitForExistence(timeout: 3),
                       "Capture must not open by itself")
        attachScreenshot(named: "plain-launch-main")
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
