import XCTest

/// #982 Schnitt 1 (ADR-22): the real app, not the test mode. Every other capture test starts with
/// `--ui-testing`, which swapped the model out long ago (#228), so it could never show what Henning's
/// app does. This one starts like `CaptureCancelCrashTests`: real wiring, real store, a simulator that
/// carries an on-device model. „Vor Konzert“ must stay „Vor Konzert“ — no invented words, no duration,
/// no AI mark — and „Analyze again“ must not talk about Apple Intelligence.
final class NoModelCaptureTests: XCTestCase {
    private let spoken = "Vor Konzert"

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Microphone, speech and notifications ask on the first start of the real app.
    @MainActor
    private func allowSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<6 {
            let allow = springboard.buttons.matching(
                NSPredicate(format: "label IN {'Erlauben', 'Allow', 'OK', 'Beim Verwenden der App erlauben'}")
            ).firstMatch
            guard allow.waitForExistence(timeout: 3) else { return }
            allow.tap()
        }
    }

    /// Anything on screen that names the model: the field's mark or the old reanalysis line.
    private func modelMentions(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label CONTAINS[c] 'Apple Intelligence' OR label CONTAINS[c] 'Estimated by AI'"))
    }

    @MainActor
    func testSpokenTitleStaysAndAnalyzeAgainNamesNoModel() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-onboardingDone", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()   // bewusst ohne --ui-testing: die echte Verdrahtung läuft
        allowSystemAlerts()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 15), "Kein (+) auf dem Startbildschirm")
        captureButton.tap()
        allowSystemAlerts()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassung ging nicht auf")
        field.tap()
        field.typeText(spoken)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10))

        // Time for the rule pass and, before #982, for the model to rewrite the task.
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 10), "„New“ fehlt auf dem Startbildschirm")
        newRow.tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS %@", spoken)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Die Aufgabe steht nicht unter „New“")
        sleep(8)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "982-list-vor-konzert"
        shot.lifetime = .keepAlways
        add(shot)
        row.tap()

        let titleField = element("detailTitleField", in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Detail ging nicht auf")
        XCTAssertEqual(titleField.value as? String, spoken, "Der Titel ist das Gesagte, nichts dazuerfunden")
        XCTAssertFalse(element("field_duration", in: app).exists, "Keine Dauer, wenn keine genannt wurde")
        XCTAssertEqual(modelMentions(in: app).count, 0, "Kein KI-Merkmal in der Detailansicht")

        let more = element("detailMoreMenu", in: app)
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Kein „Mehr“-Menü im Detail")
        more.tap()
        let analyze = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == %@ OR label == %@", "analyzeAgainButton", "Analyze again"))
            .firstMatch
        XCTAssertTrue(analyze.waitForExistence(timeout: 5), "„Analyze again“ fehlt im Menü")
        analyze.tap()

        let note = element("reanalysisNote", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 15), "Die Neuanalyse meldet kein Ergebnis")
        let done = XCTAttachment(screenshot: app.screenshot())
        done.name = "982-detail-nach-analyze-again"
        done.lifetime = .keepAlways
        add(done)
        XCTAssertEqual(modelMentions(in: app).count, 0, "Die Neuanalyse nennt Apple Intelligence")
        XCTAssertEqual(titleField.value as? String, spoken, "Die Neuanalyse ändert den Titel nicht")
    }
}
