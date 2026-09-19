import XCTest

/// Reproduziert den Absturz vom 2026-09-19: (+) antippen, dann Abbrechen — die App
/// reagiert nicht mehr.
///
/// Der Unterschied zu `CaptureSmokeTests`: dort startet die App mit `--ui-testing`,
/// und dieser Schalter schaltet die Spracherfassung ab. Der bestehende Abbrechen-Test
/// lief deshalb grün, während der Weg, den Henning geht, nie ausgeführt wurde.
/// Dieser Test startet die App ohne den Schalter, also mit Mikrofon und Erkennung.
final class CaptureCancelCrashTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Mikrofon, Spracherkennung und Mitteilungen fragt das System beim ersten Start ab.
    /// Henning hat das längst erlaubt; hier wird es im Lauf bestätigt.
    @MainActor
    private func allowSystemAlerts(in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<6 {
            let allow = springboard.buttons.matching(
                NSPredicate(format: "label IN {'Erlauben', 'Allow', 'OK', 'Beim Verwenden der App erlauben'}")
            ).firstMatch
            guard allow.waitForExistence(timeout: 3) else { return }
            allow.tap()
        }
    }

    @MainActor
    func testCancelAfterCaptureOpensLeavesAppAlive() throws {
        let app = XCUIApplication()
        app.launch()   // bewusst ohne --ui-testing: die Spracherfassung läuft mit
        allowSystemAlerts(in: app)

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 15), "Kein (+) auf dem Startbildschirm")
        captureButton.tap()
        allowSystemAlerts(in: app)

        let cancel = app.buttons["captureCancelButton"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "Erfassungs-Blatt ging nicht auf")
        cancel.tap()

        // Nach dem Abbrechen muss der Startbildschirm wieder bedienbar sein.
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10), "Abbrechen hat das Blatt nicht geschlossen")
        XCTAssertEqual(app.state, .runningForeground, "Die App läuft nach Abbrechen nicht mehr")
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "Startbildschirm reagiert nach Abbrechen nicht mehr")
        captureButton.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "Der (+) reagiert nach einem Abbrechen nicht mehr")
    }
}
