import XCTest

/// #279/#297: Die Erfassung zeigt, dass zugehört wird, bevor das erste Wort kommt: grau „Listening …“ an der
/// Stelle des Textes und ein runder Mikrofonknopf. Simulator und CI haben kein Mikrofon; der Festzustand
/// `--ui-testing-speech-listening` gilt als „hört zu“ mit festen Pegeln, ohne Mikrofon und Erkennung.
final class SpeechListeningIndicatorTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + extra
        app.launch()
        return app
    }

    @MainActor
    private func openCapture(_ app: XCUIApplication) -> XCUIElement {
        let plus = app.buttons["captureButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "Kein (+) auf dem Startbildschirm")
        plus.tap()
        let field = app.descendants(matching: .any).matching(identifier: "captureTextField").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassung ging nicht auf")
        return field
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testListeningFixedStateShowsHintAndStopButton() throws {
        for dark in [false, true] {
            let app = launch(extra: ["--ui-testing-speech-listening"] + (dark ? ["--ui-testing-dark"] : []))
            _ = openCapture(app)

            let hint = app.descendants(matching: .any).matching(identifier: "listeningHint").firstMatch
            XCTAssertTrue(hint.waitForExistence(timeout: 10), "Hinweis „Listening …“ fehlt")
            XCTAssertEqual(hint.label, "Listening …")

            let mic = app.buttons["micButton"]
            XCTAssertTrue(mic.waitForExistence(timeout: 5), "Mikrofonknopf fehlt")
            XCTAssertEqual(mic.label, "Stop listening")
            attachScreenshot(app, name: dark ? "hoert-zu-dunkel" : "hoert-zu-hell")
            app.terminate()
        }
    }

    @MainActor
    func testHintIsReplacedByTypedText() throws {
        let app = launch(extra: ["--ui-testing-speech-listening"])
        let field = openCapture(app)

        let hint = app.descendants(matching: .any).matching(identifier: "listeningHint").firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 10), "Hinweis „Listening …“ fehlt")
        field.tap()
        field.typeText("Milch")
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: hint)
        XCTAssertEqual(XCTWaiter.wait(for: [gone], timeout: 5), .completed, "Hinweis bleibt trotz Text stehen")
    }

    @MainActor
    func testNoHintWithoutArgument() throws {
        let app = launch(extra: [])
        _ = openCapture(app)

        let hint = app.descendants(matching: .any).matching(identifier: "listeningHint").firstMatch
        XCTAssertFalse(hint.waitForExistence(timeout: 3), "Hinweis ohne Startargument sichtbar")
    }
}
