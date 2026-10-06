import XCTest

/// #157: Regression — „Garden, Garten, Garden" an einer Aufgabe.
///
/// Früher legte die Seitenleiste einen zweiten Kontext „Garden" neben dem gesäten an, und der
/// Feldeditor bot „Garden" doppelt an. Jetzt wird der zweite „Garden" mit einer Meldung abgelehnt;
/// „Garten" ist ein anderer Name und wird weiterhin angelegt.
final class ContextUniquenessTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Empty fields wait behind "Add detail" (#187): open it if the row is not there yet.
    @MainActor
    private func revealField(_ id: String, in app: XCUIApplication) -> XCUIElement {
        let row = element(id, in: app)
        if !row.waitForExistence(timeout: 2) {
            let add = element("addDetailRow", in: app)
            if add.waitForExistence(timeout: 3) { add.tap() }
        }
        return row
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Types the name into the sidebar's name alert and confirms it.
    @MainActor
    private func addContext(_ name: String, in app: XCUIApplication) {
        let button = element("newContextButton", in: app)
        // Contexts start folded on the start screen; an earlier run may have left them open.
        if !button.waitForExistence(timeout: 3) {
            let toggle = element("contextsToggle", in: app)
            if !toggle.waitForExistence(timeout: 3) { app.swipeUp() }
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Start screen should offer the Contexts group")
            toggle.tap()
        }
        if !button.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Kein Neuer-Kontext-Knopf")
        button.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5), "Namens-Alert ging nicht auf")
        let field = alert.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Alert ohne Textfeld")
        field.typeText(name)
        alert.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(alert.textFields.firstMatch.waitForNonExistence(timeout: 5), "Namens-Alert schloss nicht")
    }

    @MainActor
    func testSecondGardenIsRejected() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-contextsEmptiedByUser", "NO",
        ]
        app.launch()

        // „Garden" ist gesät; ein zweites Mal wird es abgelehnt.
        addContext("Garden", in: app)
        let rejection = app.alerts["A context with this name already exists."]
        XCTAssertTrue(rejection.waitForExistence(timeout: 5), "Keine Meldung zum doppelten Namen")
        shot(app, "1-meldung-doppelter-name")
        rejection.buttons["OK"].firstMatch.tap()
        XCTAssertTrue(rejection.waitForNonExistence(timeout: 5), "Meldung schloss nicht")

        // „Garten" ist ein anderer Name und wird ohne Meldung angelegt.
        addContext("Garten", in: app)
        XCTAssertFalse(app.alerts.firstMatch.waitForExistence(timeout: 2), "Garten wurde abgelehnt")
        shot(app, "2-seitenleiste")

        let captureButton = app.buttons["captureButton"]
        if !captureButton.waitForExistence(timeout: 3) { app.swipeDown() }
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "Kein Capture-Knopf")
        captureButton.tap()
        let captureField = element("captureTextField", in: app)
        XCTAssertTrue(captureField.waitForExistence(timeout: 5))
        captureField.tap()
        captureField.typeText("Rasen mähen")
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(captureField.waitForNonExistence(timeout: 5))

        let newRow = element("viewRow_new", in: app)
        if !newRow.waitForExistence(timeout: 3) { app.swipeDown() }
        XCTAssertTrue(newRow.waitForExistence(timeout: 5))
        newRow.tap()
        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Keine Aufgabe in Neu")
        row.tap()

        let contextsRow = revealField("field_contexts", in: app)
        if !contextsRow.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(contextsRow.waitForExistence(timeout: 5))
        contextsRow.tap()

        // Nur die wählbaren Zeilen zählen: „Garden" steht auch als Wert unter „Nachher" (#101).
        let gardens = app.buttons.matching(NSPredicate(format: "label == %@", "Garden"))
        XCTAssertTrue(gardens.firstMatch.waitForExistence(timeout: 5), "Der Editor bietet Garden nicht an")
        let garten = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Garten")).firstMatch
        XCTAssertTrue(garten.waitForExistence(timeout: 5), "Der Editor bietet Garten nicht an")
        shot(app, "3-editor-optionen")
        XCTAssertEqual(gardens.count, 1, "Der Editor bietet Garden \(gardens.count)-mal an")

        if !gardens.firstMatch.isSelected { gardens.firstMatch.tap() }
        app.navigationBars.buttons.firstMatch.tap()
        _ = XCTWaiter().wait(for: [expectation(description: "settle")], timeout: 1.5)
        shot(app, "4-detail-nach-antippen")
        // Der Herkunftsvermerk (#101) hängt hinten an, wenn die Erschließung „Garden" gesetzt hat.
        let shown = contextsRow.label
            .replacingOccurrences(of: "Contexts, ", with: "")
            .replacingOccurrences(of: ", From your words", with: "")
            .replacingOccurrences(of: ", Estimated by AI", with: "")
        XCTAssertEqual(shown, "Garden", "Beschriftung war \(contextsRow.label)")
    }
}
