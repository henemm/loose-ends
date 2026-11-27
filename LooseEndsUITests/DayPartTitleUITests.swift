import XCTest

/// #1001, Abnahme Stufe 2: „Pakete wegbringen heute Morgen“ in die Schreibzeile tippen; in der Schublade, unter
/// „Jetzt“ und im Detail steht „Pakete wegbringen“, ohne das „Morgen“ der Tageszeit (vorher: „Pakete wegbringen
/// Morgen“). Läuft gegen einen Speicher im Arbeitsspeicher (`--ui-testing`).
final class DayPartTitleUITests: XCTestCase {
    private let spoken = "Pakete wegbringen heute Morgen"
    private let expected = "Pakete wegbringen"

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testDayPartLeavesTheTitle() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + LaunchLanguage.arguments
        app.launch()

        let line = element("startCaptureField", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 10), "Der Startbildschirm zeigt keine Schreibzeile")
        line.tap()
        line.typeText(spoken + "\n")

        let first = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'drawerRow_'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), "Return sollte die Aufgabe in die Schublade legen")
        XCTAssertTrue(first.label.contains(expected), "Die Zeile zeigt den Titel, war \(first.label)")
        XCTAssertFalse(first.label.contains("Morgen"), "Die Tageszeit gehört nicht in den Titel, war \(first.label)")
        shot(app, "1001-zeile")

        // Ein Tipp auf den Satz des Tages beendet die Eingabe: die Schublade klappt zu.
        let header = element("startHeader", in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 5))
        header.tap()
        XCTAssertTrue(first.waitForNonExistence(timeout: 10), "Die Schublade sollte zuklappen")

        // Für heute gesagt: die Aufgabe steht sofort unter „Jetzt“.
        let now = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH 'nowRow_' AND label CONTAINS %@", expected)).firstMatch
        XCTAssertTrue(now.waitForExistence(timeout: 10), "Die Aufgabe für heute steht nicht unter „Jetzt“")
        XCTAssertFalse(now.label.contains("Morgen"), "Die Tageszeit gehört nicht in den Titel, war \(now.label)")
        shot(app, "1001-jetzt")
        now.tap()

        let titleField = element("detailTitleField", in: app)
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Detail ging nicht auf")
        XCTAssertEqual(titleField.value as? String, expected, "Die Tageszeit am Datum gehört nicht in den Titel")
        shot(app, "1001-detail")
    }
}
