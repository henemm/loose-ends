import XCTest

/// Screen 12 (#29): the onboarding on a fresh device, walked through and skipped. Runs against the
/// in-memory store of `--ui-testing`; `--ui-testing-onboarding` brings the onboarding up under it.
final class OnboardingTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(language: String = "en", locale: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-onboarding", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    func testWalkThroughThreeStepsToTheStartScreen() throws {
        let app = launch()

        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForExistence(timeout: 10), "The onboarding should open on Siri")
        let next = element("onboardingNextButton", in: app)
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()

        XCTAssertTrue(element("onboardingStep_notifications", in: app).waitForExistence(timeout: 5), "Second step: notifications")
        XCTAssertTrue(element("onboardingAllowNotifications", in: app).exists, "Notifications can be allowed here")
        // "Not now": the permission prompt itself stays silent under UI tests.
        next.tap()

        XCTAssertTrue(element("onboardingStep_contexts", in: app).waitForExistence(timeout: 5), "Third step: the starter contexts")
        XCTAssertTrue(element("onboardingContexts", in: app).exists, "The starter contexts are listed")
        next.tap()

        // The start screen may sit in the hierarchy behind the cover already: wait for the cover to go.
        XCTAssertTrue(element("onboardingStep_contexts", in: app).waitForNonExistence(timeout: 5), "The onboarding should be gone")
        XCTAssertTrue(app.buttons["captureButton"].waitForExistence(timeout: 5), "Start should land on the start screen")
        XCTAssertTrue(app.buttons["captureButton"].isHittable, "The start screen should be usable")
    }

    @MainActor
    func testSkipEndsTheOnboardingAtOnce() throws {
        let app = launch()

        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForExistence(timeout: 10))
        let skip = element("onboardingSkipButton", in: app)
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "Every step offers Skip")
        skip.tap()

        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForNonExistence(timeout: 5), "Skip should close the onboarding")
        XCTAssertTrue(app.buttons["captureButton"].waitForExistence(timeout: 5), "Skip should land on the start screen")
        XCTAssertTrue(app.buttons["captureButton"].isHittable, "The start screen should be usable")
    }

    /// #342 Teil 5: on a device without Apple Intelligence the first start says what still works and what is missing.
    /// Under `--ui-testing` the model counts as off (as in the enrichment), so the note is there; the text must name the rules' work (tags, duration) and the gap (title).
    @MainActor
    func testNoteWithoutModelSaysWhatStillWorksInEnglish() throws {
        let app = launch()

        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForExistence(timeout: 10))
        let note = element("onboardingModelNote", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5), "Without a model the Siri step carries a note")
        let text = note.label
        for word in ["Tags", "durations", "title"] {
            XCTAssertTrue(text.contains(word), "The note should name \(word): \(text)")
        }
    }

    @MainActor
    func testNoteWithoutModelSaysWhatStillWorksInGerman() throws {
        let app = launch(language: "de", locale: "de_DE")

        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForExistence(timeout: 10))
        let note = element("onboardingModelNote", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5), "Without a model the Siri step carries a note")
        let text = note.label
        for word in ["Tags", "Dauer", "Titel"] {
            XCTAssertTrue(text.contains(word), "The note should name \(word): \(text)")
        }
    }
}
