import XCTest

/// #182: photographs the main screens, light and dark, so the look of a change can be seen from
/// CI without a local simulator (first use: #180, paper ground). Asserts only that each screen is
/// reached; the pictures are the point. CI exports the attachments named `gallery-*` as the
/// `DesignGallery` artifact.
final class DesignGalleryTests: XCTestCase {
    private static let tasks = ["Steuerbescheid morgen prüfen", "Anna wegen Sonntag anrufen", "Rasen mähen"]

    override func setUp() {
        continueAfterFailure = false
    }

    /// English and freshly seeded contexts, as in `RecognitionWalkthroughTests`: the seeding flag
    /// lives in the user defaults and would leave the in-memory store without contexts otherwise.
    /// Dark mode comes from `--ui-testing-dark`, read by the app itself: setting
    /// `XCUIDevice.shared.appearance` left the CI simulator light (first gallery run, #182).
    @MainActor
    private func launch(dark: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-contextsSeeded", "NO",
        ] + (dark ? ["--ui-testing-dark"] : [])
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func capture(_ text: String, in app: XCUIApplication) {
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "No capture button")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture sheet did not open")
        field.tap()
        field.typeText(text)
        let done = app.buttons["captureDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture sheet did not close")
    }

    /// Start screen (top and scrolled, for the section headers), the New list and a detail.
    @MainActor
    private func photograph(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = launch(dark: dark)
        for text in Self.tasks {
            capture(text, in: app)
        }
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no New")
        shot(app, "gallery-\(label)-1-start")
        app.swipeUp()
        shot(app, "gallery-\(label)-2-start-scrolled")
        app.swipeDown()

        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        shot(app, "gallery-\(label)-3-list-new")

        row.tap()
        XCTAssertTrue(element("detailRawText", in: app).waitForExistence(timeout: 5), "Detail did not open")
        shot(app, "gallery-\(label)-4-detail")
        app.terminate()
    }

    @MainActor
    func testPhotographMainScreens() throws {
        photograph(dark: false)
        photograph(dark: true)
    }
}
