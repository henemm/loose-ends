import XCTest

/// Screen 12 (#29): the onboarding on a fresh device, walked through and skipped. Runs against the
/// in-memory store of `--ui-testing`; `--ui-testing-onboarding` brings the onboarding up under it.
final class OnboardingTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(reason: String? = nil, language: String = "en", locale: String = "en_US") -> XCUIApplication {
        let app = XCUIApplication()
        var arguments = ["--ui-testing", "--ui-testing-onboarding", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        // The former argument (#342) is only passed to show that the app no longer reads it (#982 Schnitt 2).
        if let reason { arguments.append("--ui-testing-model-reason=\(reason)") }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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

    // MARK: - No model note any more (#982 Schnitt 2, ADR-22)

    /// AC-1: step one never speaks of Apple Intelligence, not even with the old reason argument (#342) that
    /// used to bring the note up under UI tests.
    @MainActor
    func testStepOneShowsNoModelNoteEvenWithTheOldReasonArgument() throws {
        let app = launch(reason: "deviceNotEligible")
        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForExistence(timeout: 10), "The onboarding should open on Siri")
        shot(app, "onboarding-982-no-model-note-en")
        XCTAssertFalse(element("onboardingModelNote", in: app).exists, "No model note on step one (ADR-22)")
        let mentions = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Apple Intelligence"))
        XCTAssertEqual(mentions.count, 0, "No text on step one names Apple Intelligence")
    }
}
