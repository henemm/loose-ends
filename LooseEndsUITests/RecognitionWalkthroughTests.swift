import XCTest

/// #144, AC-9: der Ablauf, den jemand ohne Apple Intelligence erlebt — erfassen, Dauer und Kontext
/// selbst setzen, dasselbe noch einmal erfassen — durchgespielt in der echten App statt in einem
/// Testaufbau, der sich seinen Ausgangszustand selbst herstellt (die Lehre aus #136).
///
/// `--ui-testing` schaltet auf einen In-Memory-Store, lässt aber den echten
/// `FoundationModelsEnricher` laufen: im Simulator praktisch immer ohne Apple Intelligence. Die
/// Zusicherungen prüfen trotzdem das **Ergebnis** (steht der Wert dran?) und nie den Bedienweg
/// (habe ich ihn angetippt?) — robuster gegenüber einem Umschalter, den ein Modell schon gesetzt
/// haben könnte, und einem Rohtext, den es geglättet hat. Die Verschärfung der Zusicherungen auf
/// Wertgleichheit statt Teilzeichenfolgen ist #158.
///
/// Die zweite Erfassung ist bewusst **wortgleich, nicht zeichengleich** ("mähen Rasen" statt
/// "Rasen mähen"): `RecognitionRule` vergleicht Wortmengen, und so bleiben die beiden Zeilen in
/// der Liste unterscheidbar.
final class RecognitionWalkthroughTests: XCTestCase {
    private static let firstText = "Rasen mähen"
    private static let secondText = "mähen Rasen"
    private static let durationLabel = "30 min"
    private static let contextLabel = "Garden"

    override func setUp() {
        continueAfterFailure = false
    }

    /// Englisch unabhängig von der Systemsprache des Macs: dieser Test vergleicht sichtbare
    /// Beschriftungen wörtlich ("30 min", "Garden"), der Lauf darf also nicht an der Sprache des
    /// Rechners hängen (dieselbe Falle wie in `CaptureSmokeTests`, gefunden bei #121).
    ///
    /// `-contextsSeeded NO` ist nicht Kosmetik, sondern nötig: `--ui-testing` gibt einen frischen
    /// In-Memory-Store, `ContextSeeder` merkt sich sein einmaliges Säen aber in den
    /// Nutzereinstellungen — und die überleben den Lauf. Ab dem zweiten UI-Lauf auf demselben
    /// Simulator stünde der Store sonst ohne einen einzigen Kontext da, und dieser Test würde am
    /// Aufbau scheitern statt an der Sache (beim RED-Lauf am 2026-09-28 genau so passiert). Ein
    /// Startargument `-key value` landet in der Argument-Domäne und schlägt den gespeicherten Wert.
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-contextsSeeded", "NO",
        ]
        app.launch()
        return app
    }

    @MainActor
    private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func row(containing text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "taskRow_", text))
            .firstMatch
    }

    /// Oberste Zeile der „Neu"-Liste. `ViewRules` sortiert absteigend nach Erfassungszeit, die
    /// jüngste Erfassung steht also immer oben — unabhängig davon, ob das Modell ihren Titel
    /// inzwischen geglättet hat und eine Suche nach dem Rohtext damit ins Leere liefe.
    @MainActor
    private func topRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
    }

    /// Hält den in Schritt 3 genommenen Zweig als benannten Textanhang fest: ohne diesen Vermerk
    /// beweist ein grüner Gerätelauf nicht, dass der bedingte Zweig überhaupt gelaufen ist.
    @MainActor
    private func note(_ text: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(string: text)
        attachment.name = "schritt3-zweig"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func back(in app: XCUIApplication) {
        let button = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Kein Zurück-Knopf")
        button.tap()
    }

    /// Erfasst einen Text über das Capture-Blatt und wartet, bis es zu ist.
    @MainActor
    private func capture(_ text: String, in app: XCUIApplication) {
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 10), "Kein Capture-Knopf auf dem Bildschirm")
        captureButton.tap()
        let field = element("captureTextField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Capture-Blatt ging nicht auf")
        field.tap()
        field.typeText(text)
        let done = app.buttons["captureDoneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isEnabled, "Fertig muss anklickbar sein, sobald Text da ist")
        done.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Capture-Blatt schloss nach Fertig nicht")
    }

    /// True, sobald die Zeile die Beschriftung trägt — der Veredelungs-Durchgang läuft
    /// asynchron nach dem Speichern, die Liste zeigt das Ergebnis also erst kurz danach.
    @MainActor
    private func waitForLabel(_ substring: String, of element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", substring)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    @MainActor
    func testWordEqualRecaptureTakesOverDurationAndContext() throws {
        let app = launch()

        // 1. Erste Erfassung.
        capture(Self.firstText, in: app)
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Die Ansichtsliste zeigt kein Neu")
        newRow.tap()
        let first = row(containing: Self.firstText, in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Die erste Aufgabe steht nicht in Neu")
        shot(app, "1-erste-aufgabe-erfasst")
        first.tap()

        // 2. Dauer selbst setzen — der Normalfall, wenn kein Modell da ist.
        let durationRow = element("field_duration", in: app)
        XCTAssertTrue(durationRow.waitForExistence(timeout: 5), "Die Detailansicht listet keine Dauer")
        durationRow.tap()
        let thirtyMinutes = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", Self.durationLabel)).firstMatch
        XCTAssertTrue(thirtyMinutes.waitForExistence(timeout: 5), "Der Editor bietet \(Self.durationLabel) nicht an")
        thirtyMinutes.tap()
        back(in: app)
        XCTAssertTrue(waitForLabel(Self.durationLabel, of: durationRow),
                      "Die Dauer steht nicht in der Detailansicht, Beschriftung war \(durationRow.label)")

        // 3. Kontext selbst setzen.
        let contextsRow = element("field_contexts", in: app)
        if !contextsRow.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(contextsRow.waitForExistence(timeout: 5), "Die Detailansicht listet keine Kontexte")
        contextsRow.tap()
        let garden = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", Self.contextLabel)).firstMatch
        XCTAssertTrue(garden.waitForExistence(timeout: 5), "Der Editor bietet \(Self.contextLabel) nicht an")
        // Mit Apple Intelligence kann der Kontext schon stehen (`.isSelected` aus FieldEditorView);
        // ein unbedingtes Antippen würde ihn dann abwählen und den Test aus dem falschen Grund rot
        // machen. Welcher Zweig lief, steht als Anhang im Ergebnisbündel.
        let alreadySet = garden.isSelected
        note(alreadySet ? "Schritt 3: Kontext war bereits gesetzt (Modell) — nicht angetippt"
                        : "Schritt 3: Kontext war nicht gesetzt — angetippt", in: app)
        if !alreadySet {
            garden.tap()
        }
        back(in: app)
        XCTAssertTrue(waitForLabel(Self.contextLabel, of: contextsRow),
                      "Der Kontext steht nicht in der Detailansicht, Beschriftung war \(contextsRow.label)")
        shot(app, "2-werte-von-hand-gesetzt")

        // 4. Zurück in die Liste und wortgleich erneut erfassen.
        // Geprüft wird, dass die Liste wieder da ist — nicht, dass die erste Zeile noch steht: hat
        // das Modell ihren Titel gesetzt, verlässt sie „Neu", sobald ihre KI-Vermerke gesehen sind.
        back(in: app)
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5), "Nicht zurück in der Liste")
        capture(Self.secondText, in: app)
        // Die zweite Aufgabe wird über die oberste Zeile gefunden und über ihren unveränderlichen
        // Rohtext bestätigt: eine Labelsuche nach „mähen Rasen" bricht, sobald das Modell glättet.
        let second = topRow(in: app)
        XCTAssertTrue(second.waitForExistence(timeout: 10), "Die zweite Aufgabe steht nicht in Neu")
        shot(app, "3-wortgleich-erneut-erfasst")

        // 5. Der Nachweis: die zweite Aufgabe trägt Dauer und Kontext der ersten.
        second.tap()
        let secondRawText = element("detailRawText", in: app)
        XCTAssertTrue(waitForLabel(Self.secondText, of: secondRawText),
                      "Die geöffnete Detailansicht zeigt nicht den zweiten Rohtext")
        let secondDuration = element("field_duration", in: app)
        XCTAssertTrue(secondDuration.waitForExistence(timeout: 5), "Die Detailansicht listet keine Dauer")
        XCTAssertTrue(waitForLabel(Self.durationLabel, of: secondDuration),
                      "Die Dauer der ersten Aufgabe wurde nicht übernommen, Beschriftung war \(secondDuration.label)")
        let secondContexts = element("field_contexts", in: app)
        if !secondContexts.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(secondContexts.waitForExistence(timeout: 5), "Die Detailansicht listet keine Kontexte")
        XCTAssertTrue(waitForLabel(Self.contextLabel, of: secondContexts),
                      "Der Kontext der ersten Aufgabe wurde nicht übernommen, Beschriftung war \(secondContexts.label)")
        shot(app, "4-zweite-aufgabe-mit-uebernommenen-werten")
    }
}
