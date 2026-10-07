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
            "-contextsEmptiedByUser", "NO",
            // The start screen as it opens by default: projects and contexts folded.
            "-startShowsProjects", "NO", "-startShowsContexts", "NO",
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

    /// One task into "Next up", so the start screen's preview (#180) has something to show. Best
    /// effort: if the swipe does not reveal the button, the start screen shows its empty line instead.
    @MainActor
    private func lineUpFirstTask(in app: XCUIApplication, from newRow: XCUIElement) {
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        row.swipeLeft()
        let nextUp = app.buttons["Next up"]
        if nextUp.waitForExistence(timeout: 3) {
            nextUp.tap()
        }
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()
    }

    /// Start screen (top and scrolled, for the section headers), an empty view, the New list and a detail.
    @MainActor
    private func photograph(dark: Bool) {
        let label = dark ? "dark" : "light"
        let app = launch(dark: dark)
        for text in Self.tasks {
            capture(text, in: app)
        }
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Start screen shows no New")
        lineUpFirstTask(in: app, from: newRow)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Not back on the start screen")
        shot(app, "gallery-\(label)-1-start")
        app.swipeUp()
        shot(app, "gallery-\(label)-2-start-scrolled")
        app.swipeDown()

        // An empty view: the loose thread over its sentence (#180, step 3).
        // Completed: nothing is finished in the gallery, and unlike the occasional views it is
        // always on the start screen (empty ones like Waiting are hidden since 2026-10-05).
        let doneRow = element("viewRow_done", in: app)
        for _ in 0..<3 where !doneRow.waitForExistence(timeout: 2) {
            app.swipeUp()
        }
        XCTAssertTrue(doneRow.waitForExistence(timeout: 5), "Start screen shows no Completed")
        doneRow.tap()
        XCTAssertTrue(element("emptyViewLabel", in: app).waitForExistence(timeout: 5), "Completed is not empty")
        shot(app, "gallery-\(label)-5-empty")
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), "No back button")
        back.tap()

        // Completed sits at the bottom; New is back at the top.
        for _ in 0..<3 where !newRow.waitForExistence(timeout: 2) {
            app.swipeDown()
        }
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "New shows no task")
        shot(app, "gallery-\(label)-3-list-new")

        row.tap()
        XCTAssertTrue(element("detailRawTextMarker", in: app).waitForExistence(timeout: 5), "Detail did not open")
        shot(app, "gallery-\(label)-4-detail")

        // Energy (#112): the slider between the batteries, then the words in the detail.
        let addDetail = element("addDetailRow", in: app)
        if addDetail.waitForExistence(timeout: 3) {
            addDetail.tap()
        }
        let energyRow = element("field_energy", in: app)
        XCTAssertTrue(energyRow.waitForExistence(timeout: 5), "Detail offers no energy")
        energyRow.tap()
        let slider = app.sliders["energySlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "Energy editor shows no slider")
        slider.adjust(toNormalizedSliderPosition: 1.0 / 6.0)
        XCTAssertTrue(app.buttons["energyRemoveButton"].waitForExistence(timeout: 5), "The slider set no value")
        shot(app, "gallery-\(label)-6-energy")
        let backToDetail = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backToDetail.waitForExistence(timeout: 5), "No back button")
        backToDetail.tap()
        XCTAssertTrue(energyRow.waitForExistence(timeout: 5), "Not back in the detail")
        shot(app, "gallery-\(label)-7-detail-energy")

        // Field origin (#101): "morgen" is read from the words, so the due date carries »« and its
        // editor shows "From your words" with the word marked. The simulator has no model, so
        // nothing here carries the spark.
        let backToList = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(backToList.waitForExistence(timeout: 5), "No back button")
        backToList.tap()
        let taxRow = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "taskRow_", "Steuerbescheid"))
            .firstMatch
        XCTAssertTrue(taxRow.waitForExistence(timeout: 10), "New shows no Steuerbescheid")
        taxRow.tap()
        // Below the place section (#241) the summary can sit under the fold.
        let summary = element("originSummary", in: app)
        if !summary.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Detail shows no origin summary")
        shot(app, "gallery-\(label)-8-detail-origin")
        let dueRow = element("field_dueDate", in: app)
        XCTAssertTrue(dueRow.waitForExistence(timeout: 5), "Detail shows no due date")
        dueRow.tap()
        XCTAssertTrue(element("originRuleHeader", in: app).waitForExistence(timeout: 5), "Editor shows no From your words")
        shot(app, "gallery-\(label)-9-origin-rule")
        app.terminate()
    }

    @MainActor
    func testPhotographMainScreens() throws {
        photograph(dark: false)
        photograph(dark: true)
    }
}
