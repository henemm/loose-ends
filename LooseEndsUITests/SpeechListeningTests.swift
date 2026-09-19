import XCTest

/// Henning, 2026-09-19: „Es sieht so aus, als würde ich gehört (Ausschläge in der Animation),
/// aber danach passiert nichts."
///
/// Ursache war nicht das Mikrofon — der Ton kam an. Die Spracherkennung startete nicht
/// („Failed to initialize recognizer"), und die App schrieb das nur ins Protokoll: sie hörte
/// äußerlich weiter zu und tat so, als liefe alles.
///
/// Die Regel, die dieser Test festhält: **Die Erfassung darf nie scheinbar zuhören, ohne dass
/// etwas passiert.** Entweder es wird erkannt, oder die App sagt, warum nicht. Läuft ohne
/// `--ui-testing`, sonst ist die Spracherfassung abgeschaltet.
final class SpeechListeningTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

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

    @MainActor
    func testCaptureNeverPretendsToListen() throws {
        let app = XCUIApplication()
        app.launch()
        allowSystemAlerts()

        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 15), "Kein (+) auf dem Startbildschirm")
        captureButton.tap()
        allowSystemAlerts()

        let field = app.descendants(matching: .any).matching(identifier: "captureTextField").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "Erfassung ging nicht auf")
        shot(app, "1-erfassung-offen")

        // 15 Sekunden Zeit: entweder es wird erkannt, oder die App meldet sich.
        let deadline = Date().addingTimeInterval(15)
        var ergebnis = "nichts"
        while Date() < deadline {
            if let text = field.value as? String, !text.isEmpty, text != "Was soll ich aufnehmen?" {
                ergebnis = "erkannt: \(text)"
                break
            }
            if app.alerts.firstMatch.exists {
                ergebnis = "Frage an den Nutzer: \(app.alerts.firstMatch.label)"
                break
            }
            if app.descendants(matching: .any).matching(identifier: "speechUnavailableLabel").firstMatch.exists {
                ergebnis = "Hinweis: Spracherkennung nicht verfügbar"
                break
            }
            if app.descendants(matching: .any).matching(identifier: "speechConsentLabel").firstMatch.exists {
                ergebnis = "Hinweis: Erkennung auf dem Gerät nicht gestartet"
                break
            }
            usleep(500_000)
        }
        shot(app, "2-ergebnis")

        XCTAssertNotEqual(ergebnis, "nichts",
                          "Die Erfassung hat 15 Sekunden lang zugehört, ohne zu erkennen und ohne es zu sagen")
        print("[REPRO] Ergebnis nach dem Öffnen der Erfassung: \(ergebnis)")
    }
}
