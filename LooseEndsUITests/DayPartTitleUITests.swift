import XCTest

/// #1001, Abnahme Stufe 2: „Pakete wegbringen heute Morgen“ erfassen; in der Liste und im Detail steht
/// „Pakete wegbringen“, ohne das „Morgen“ der Tageszeit (vorher: „Pakete wegbringen Morgen“).
final class DayPartTitleUITests: XCTestCase {
    private let spoken = "Pakete wegbringen heute Morgen"
    private let expected = "Pakete wegbringen"

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    func testDayPartLeavesTheTitle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-onboardingDone", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 15), "Kein (+) auf dem Startbildschirm")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassung ging nicht auf")
        field.tap()
        field.typeText(spoken)
        app.buttons["captureDoneButton"].tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 10))

        let looseEnds = element("viewRow_open", in: app)
        for _ in 0..<3 where !looseEnds.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(looseEnds.waitForExistence(timeout: 10), "„Loose ends“ fehlt auf dem Startbildschirm")
        looseEnds.tap()
        let row = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'taskRow_' AND label CONTAINS %@", expected)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Die Aufgabe steht nicht unter „Loose ends“")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "1001-liste-pakete-wegbringen"
        shot.lifetime = .keepAlways
        add(shot)
        row.tap()

        let titleField = element("detailTitleField", in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Detail ging nicht auf")
        XCTAssertEqual(titleField.value as? String, expected, "Die Tageszeit am Datum gehört nicht in den Titel")
        let detail = XCTAttachment(screenshot: app.screenshot())
        detail.name = "1001-detail-pakete-wegbringen"
        detail.lifetime = .keepAlways
        add(detail)
    }
}
