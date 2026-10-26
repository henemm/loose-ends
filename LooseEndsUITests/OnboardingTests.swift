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
        // #342: the simulator has a model, so the note never shows; this brings each case up (only under --ui-testing).
        if let reason { arguments.append("--ui-testing-model-reason=\(reason)") }
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// The note's words as the screen shows them; fails when the note is not on step one.
    @MainActor
    private func modelNoteText(_ app: XCUIApplication, shot name: String) -> String {
        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForExistence(timeout: 10), "The onboarding should open on Siri")
        let note = element("onboardingModelNote", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The model note should stand on step one")
        shot(app, name)
        return note.label
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

    // MARK: - The model note on the screen (#342, Schnitt 1a)

    @MainActor
    func testNoModelNoteSaysWhatStillWorksInEnglish() throws {
        let text = modelNoteText(launch(reason: "deviceNotEligible"), shot: "onboarding-342-not-eligible-en")
        XCTAssertEqual(text, "This device has no Apple Intelligence. Due dates, importance, urgency and tags are still found; a duration only when you name it or the task came up before.")
    }

    @MainActor
    func testNoModelNoteSaysWhatStillWorksInGerman() throws {
        let text = modelNoteText(launch(reason: "deviceNotEligible", language: "de", locale: "de_DE"), shot: "onboarding-342-not-eligible-de")
        XCTAssertEqual(text, "Dieses Gerät hat kein Apple Intelligence. Fälligkeit, Wichtigkeit, Dringlichkeit und Etiketten werden trotzdem erkannt; eine Dauer nur, wenn du sie nennst oder die Aufgabe schon einmal da war.")
    }

    @MainActor
    func testTurnedOffNoteStandsOnTheScreen() throws {
        let text = modelNoteText(launch(reason: "appleIntelligenceNotEnabled"), shot: "onboarding-342-turned-off-en")
        XCTAssertEqual(text, "Apple Intelligence is off. Turn it on in Settings so new tasks get a title and a duration.")
    }

    @MainActor
    func testNotReadyNoteStandsOnTheScreen() throws {
        let text = modelNoteText(launch(reason: "modelNotReady"), shot: "onboarding-342-not-ready-en")
        XCTAssertEqual(text, "Apple Intelligence is still getting ready. Tasks captured meanwhile are sorted once it is.")
    }

    @MainActor
    func testNoNoteWhileTheModelIsThere() throws {
        let app = launch()
        XCTAssertTrue(element("onboardingStep_siri", in: app).waitForExistence(timeout: 10))
        shot(app, "onboarding-342-no-note-en")
        XCTAssertFalse(element("onboardingModelNote", in: app).exists, "The simulator has a model: no note")
    }
}
