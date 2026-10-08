import XCTest

/// #274: Die Spracheingabe zeigte Wellenform, aber keinen Text, und die App sagte nichts dazu.
/// Seitdem steht nach 6 s Ton ohne Ergebnis eine graue Zeile mit der Kurzdiagnose. Der Simulator hat
/// keine Sprachmodelle; dieser Test belegt Anzeige und Text mit festem Zustand
/// (`--ui-testing-speech-diagnosis`), nicht die Zähler (die belegt der Lauf auf dem Gerät).
final class SpeechDiagnosisLineTests: XCTestCase {
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
    private func openCapture(_ app: XCUIApplication) {
        let plus = app.buttons["captureButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "Kein (+) auf dem Startbildschirm")
        plus.tap()
        let field = app.descendants(matching: .any).matching(identifier: "captureTextField").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassung ging nicht auf")
    }

    @MainActor
    func testDiagnosisLineShowsFixedState() throws {
        let app = launch(extra: ["--ui-testing-speech-diagnosis"])
        openCapture(app)

        let line = app.descendants(matching: .any).matching(identifier: "speechDiagnosisLabel").firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Diagnosezeile fehlt")
        XCTAssertEqual(
            line.label,
            "No text yet — model: installed · microphone: yes · speech: yes · buffers: 62 · results: 0"
        )
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "diagnosezeile"
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testNoDiagnosisLineWithoutArgument() throws {
        let app = launch(extra: [])
        openCapture(app)

        let line = app.descendants(matching: .any).matching(identifier: "speechDiagnosisLabel").firstMatch
        XCTAssertFalse(line.waitForExistence(timeout: 3), "Diagnosezeile ohne Startargument sichtbar")
    }
}
