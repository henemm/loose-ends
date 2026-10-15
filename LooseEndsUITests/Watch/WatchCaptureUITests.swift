import XCTest

/// Watch capture returns to the empty field after "Done" (#409). Runs in the watchOS simulator:
/// `./scripts/sim.sh watch-test-proof WatchCaptureUITests`. The system text input sheet and the app both
/// have a button "Done"/"Fertig": the app's is taken only after the sheet is gone, by identifier or label.
final class WatchCaptureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
    }

    /// AC-1, AC-3, AC-6: two captures in a row, each confirmed, each followed by the empty field.
    func testTwoCapturesInARowReturnToEmptyField() throws {
        for text in ["Milch kaufen", "Brot holen"] {
            capture(text)
            XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "„Gespeichert“ fehlt nach „\(text)“")
            snapshot("gespeichert: \(text)")
            XCTAssertTrue(field.waitForExistence(timeout: 5), "Feld kommt nach „\(text)“ nicht zurück")
            XCTAssertFalse(confirmation.exists, "Bestätigung steht noch neben dem Feld")
            let value = field.value as? String ?? ""
            XCTAssertFalse(value.contains(text), "Voriger Text steht noch im Feld: \(value)")
            XCTAssertFalse(sheetDone.exists, "Eingabeblatt öffnet sich von selbst")
            snapshot("leeres Feld nach: \(text)")
        }
    }

    /// AC-2: directly after "Done" the confirmation shows and the field is not there yet.
    func testConfirmationIsVisibleBeforeFieldReturns() throws {
        capture("Milch kaufen")
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5), "„Gespeichert“ fehlt")
        XCTAssertFalse(field.exists, "Feld ist sofort wieder da, ohne sichtbare Bestätigung")
    }

    /// The only text field on the screen once the system sheet is closed.
    private var field: XCUIElement { app.textFields.firstMatch }
    private var sheetDone: XCUIElement { app.navigationBars.buttons.element(boundBy: 1) }
    private var appDone: XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier == 'watch.capture.done' OR label IN {'Done', 'Fertig'}")).firstMatch
    }
    private var confirmation: XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "identifier == 'watch.capture.saved' OR label IN {'Saved', 'Gespeichert'}")).firstMatch
    }

    /// Tap the field, type into the system sheet, take it with the sheet's "Done", then the app's "Done".
    private func capture(_ text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Eingabefeld fehlt")
        field.tap()
        app.typeText(text)
        XCTAssertTrue(sheetDone.waitForExistence(timeout: 5), "Knopf des Eingabeblatts fehlt")
        sheetDone.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Eingabeblatt schließt nicht")
        XCTAssertTrue(appDone.waitForExistence(timeout: 5), "App-Knopf „Fertig“ fehlt")
        appDone.tap()
    }

    private func snapshot(_ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
