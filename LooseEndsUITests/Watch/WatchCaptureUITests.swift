import XCTest

/// Watch capture returns to the empty field after "Done" (#409). Runs in the watchOS simulator:
/// `./scripts/sim.sh watch-test-proof WatchCaptureUITests`. The system text input sheet and the app both
/// have a button "Done"/"Fertig": the app's is taken only after the sheet is gone, by identifier or label.
final class WatchCaptureUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        return app
    }

    /// AC-1, AC-3, AC-6: two captures in a row, each confirmed, each followed by the empty field.
    @MainActor
    func testTwoCapturesInARowReturnToEmptyField() throws {
        let app = launch()
        for text in ["Milch kaufen", "Brot holen"] {
            capture(text, in: app)
            XCTAssertTrue(confirmation(in: app).waitForExistence(timeout: 5), "„Gespeichert“ fehlt nach „\(text)“")
            snapshot("gespeichert: \(text)", of: app)
            XCTAssertTrue(field(in: app).waitForExistence(timeout: 5), "Feld kommt nach „\(text)“ nicht zurück")
            XCTAssertFalse(confirmation(in: app).exists, "Bestätigung steht noch neben dem Feld")
            let value = field(in: app).value as? String ?? ""
            XCTAssertFalse(value.contains(text), "Voriger Text steht noch im Feld: \(value)")
            XCTAssertFalse(sheetDone(in: app).exists, "Eingabeblatt öffnet sich von selbst")
            snapshot("leeres Feld nach: \(text)", of: app)
        }
    }

    /// AC-2: directly after "Done" the confirmation shows and the field is not there yet.
    ///
    /// Both facts come from one snapshot. Two separate queries ran 2.1 s after the tap under load (F002), past the
    /// 1.5 s the confirmation stands, and `waitForExistence` first looks after one second.
    @MainActor
    func testConfirmationIsVisibleBeforeFieldReturns() throws {
        let app = launch()
        capture("Milch kaufen", in: app)
        let deadline = Date().addingTimeInterval(5)
        var seen = (confirmation: false, field: false)
        repeat {
            seen = contents(of: try app.snapshot())
        } while !seen.confirmation && Date() < deadline
        XCTAssertTrue(seen.confirmation, "„Gespeichert“ fehlt")
        XCTAssertFalse(seen.field, "Feld ist sofort wieder da, ohne sichtbare Bestätigung")
    }

    /// What one snapshot shows at the same instant: the confirmation, a text field.
    @MainActor
    private func contents(of snapshot: XCUIElementSnapshot) -> (confirmation: Bool, field: Bool) {
        var result = (confirmation: false, field: false)
        var pending = [snapshot]
        while let node = pending.popLast() {
            if node.elementType == .staticText,
               node.identifier == "watch.capture.saved" || ["Saved", "Gespeichert"].contains(node.label) {
                result.confirmation = true
            }
            if node.elementType == .textField { result.field = true }
            pending += node.children
        }
        return result
    }

    /// The only text field on the screen once the system sheet is closed.
    @MainActor
    private func field(in app: XCUIApplication) -> XCUIElement { app.textFields.firstMatch }

    @MainActor
    private func sheetDone(in app: XCUIApplication) -> XCUIElement {
        app.navigationBars.buttons.element(boundBy: 1)
    }

    @MainActor
    private func appDone(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(
            format: "identifier == 'watch.capture.done' OR label IN {'Done', 'Fertig'}")).firstMatch
    }

    @MainActor
    private func confirmation(in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(
            format: "identifier == 'watch.capture.saved' OR label IN {'Saved', 'Gespeichert'}")).firstMatch
    }

    /// Tap the field, type into the system sheet, take it with the sheet's "Done", then the app's "Done".
    @MainActor
    private func capture(_ text: String, in app: XCUIApplication) {
        let focused = openInputSheet(in: app)
        focused.typeText(text)
        XCTAssertTrue(sheetDone(in: app).waitForExistence(timeout: 5), "Knopf des Eingabeblatts fehlt")
        sheetDone(in: app).tap()
        // The sheet's "Fertig" matches `appDone` too; take the app's only once the sheet is really gone.
        XCTAssertTrue(sheetDone(in: app).waitForNonExistence(timeout: 5), "Eingabeblatt schließt nicht")
        XCTAssertTrue(field(in: app).waitForExistence(timeout: 5), "Eingabefeld fehlt nach dem Eingabeblatt")
        XCTAssertTrue(appDone(in: app).waitForExistence(timeout: 5), "App-Knopf „Fertig“ fehlt")
        XCTAssertTrue(waitUntil("isEnabled == true AND isHittable == true", on: appDone(in: app), timeout: 5),
                      "App-Knopf „Fertig“ bleibt gesperrt, der Text kam nicht an")
        appDone(in: app).tap()
    }

    /// Opens the system input sheet and returns the element that holds keyboard focus in it.
    ///
    /// `typeText` needs keyboard focus ("Neither element nor any descendant has keyboard focus"). After the
    /// reset the field can be in the tree before it takes a tap, and under load the sheet's focus came 4 s
    /// late in a green run (first capture 2 s); a tap that lands too early opens nothing. So: wait until the
    /// field is hittable, tap, wait for focus. Only if no sheet opened at all is the tap repeated, once — the
    /// usual remedy for a lost focusing tap (tap until focus, e.g. XCUITestKit `focusAndSurfaceKeyboard`, up
    /// to three taps). An open sheet is never tapped again: the tap would land on its keys.
    @MainActor
    private func openInputSheet(in app: XCUIApplication) -> XCUIElement {
        let input = field(in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 10), "Eingabefeld fehlt")
        XCTAssertTrue(waitUntil("isHittable == true", on: input, timeout: 10), "Eingabefeld nicht antippbar")
        let focused = app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasKeyboardFocus == true")).firstMatch
        input.tap()
        if focused.waitForExistence(timeout: 10) {
            return focused
        }
        if !sheetDone(in: app).exists, input.isHittable {
            input.tap()
        }
        XCTAssertTrue(focused.waitForExistence(timeout: 10), "Eingabeblatt hat keinen Fokus")
        return focused
    }

    @MainActor
    private func waitUntil(_ format: String, on element: XCUIElement, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    private func snapshot(_ name: String, of app: XCUIApplication) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
