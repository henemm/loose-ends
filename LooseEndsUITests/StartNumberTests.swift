#if os(iOS)
import XCTest

/// One number everywhere (#637): the number on the app icon stands over "Now" on the start screen, and every
/// task it counts stands there. `--ui-testing-leftovers` puts Henning's case into the in-memory store: four
/// deadlines passed (one of them lined up) and one more task lined up, so the icon says 5.
final class StartNumberTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-leftovers", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    @MainActor
    private func elements(prefix: String, in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testNumberOverNowIsTheNumberOfRows() throws {
        let app = launch()

        let number = app.descendants(matching: .any).matching(identifier: "nowCount").firstMatch
        XCTAssertTrue(number.waitForExistence(timeout: 10), "Now shows no number")
        XCTAssertEqual(number.label, "5", "The number over Now is not the icon's number")
        XCTAssertEqual(elements(prefix: "nowRow_", in: app).count, 5, "Not every counted task stands in Now")
        XCTAssertEqual(elements(prefix: "newDate_", in: app).count, 4, "The four left tasks do not offer a new date")
        attachScreenshot(of: app, named: "start-number-5")
    }

    @MainActor
    func testNewDateFromNowLowersTheNumber() throws {
        let app = launch()

        let number = app.descendants(matching: .any).matching(identifier: "nowCount").firstMatch
        XCTAssertTrue(number.waitForExistence(timeout: 10), "Now shows no number")
        // The one that is not lined up: its new date moves it out of Now.
        let button = elements(prefix: "newDate_", in: app).element(boundBy: 3)
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No new-date button in Now")
        button.tap()
        let tomorrow = app.buttons["newDateTomorrow"]
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 5), "The new-date sheet did not open")
        tomorrow.tap()

        XCTAssertTrue(tomorrow.waitForNonExistence(timeout: 5), "The new-date sheet did not close")
        XCTAssertEqual(number.label, "4", "The number did not follow the new date")
        XCTAssertEqual(elements(prefix: "nowRow_", in: app).count, 4)
        attachScreenshot(of: app, named: "start-number-4")
    }
}
#endif
