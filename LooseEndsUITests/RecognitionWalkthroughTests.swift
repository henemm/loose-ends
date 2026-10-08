import XCTest

/// #144, AC-9: der Ablauf, den jemand ohne Apple Intelligence erlebt — erfassen, Dauer und Kontext
/// selbst setzen, dasselbe noch einmal erfassen — durchgespielt in der echten App statt in einem
/// Testaufbau, der sich seinen Ausgangszustand selbst herstellt (die Lehre aus #136).
///
/// `--ui-testing` schaltet auf einen In-Memory-Store, lässt aber den echten
/// `FoundationModelsEnricher` laufen: im Simulator praktisch immer ohne Apple Intelligence. Die
/// Zusicherungen prüfen trotzdem das **Ergebnis** (steht der Wert dran?) und nie den Bedienweg
/// (habe ich ihn angetippt?) — robuster gegenüber einem Umschalter, den ein Modell schon gesetzt
/// haben könnte, und einem Rohtext, den es geglättet hat.
///
/// Seit #158 prüft er Werte auf Gleichheit, nicht auf Vorkommen: „Garden, Garten, Garden" enthält
/// „Garden" und lief unter `CONTAINS` grün, ebenso ein KI-Vermerk an einer selbst gesetzten Dauer.
/// Eine Feldzeile fasst Feldname, Wert und Herkunftsvermerk zu einer Beschriftung zusammen
/// („Duration, 30 min, From your words", siehe `fieldRow` in `TaskDetailView`); verglichen wird
/// diese ganze Beschriftung.
///
/// Die zweite Erfassung ist bewusst **wortgleich, nicht zeichengleich** ("streichen Zaun" statt
/// "Zaun streichen"): `RecognitionRule` vergleicht Wortmengen, und so bleiben die beiden Zeilen in
/// der Liste unterscheidbar. Der Text steht in keiner Wortliste von `ContextWordRule` und nennt
/// keinen Kontext: Bis #158 hieß er „Rasen mähen", und „Rasen" setzt Garden schon per Wortliste —
/// der Kontext der zweiten Aufgabe kam dann aus der Wortliste, nicht aus der Wiedererkennung, und
/// der Test war aus dem falschen Grund grün.
final class RecognitionWalkthroughTests: XCTestCase {
    private static let firstText = "Zaun streichen"
    private static let secondText = "streichen Zaun"
    private static let durationLabel = "30 min"
    private static let contextLabel = "Garden"
    /// Der Vermerk, den die Wiedererkennung an ihre Werte hängt (`.rule`, #101).
    private static let ruleMarker = "From your words"

    override func setUp() {
        continueAfterFailure = false
    }

    /// Englisch unabhängig von der Systemsprache des Macs: dieser Test vergleicht sichtbare
    /// Beschriftungen wörtlich ("30 min", "Garden"), der Lauf darf also nicht an der Sprache des
    /// Rechners hängen (dieselbe Falle wie in `CaptureSmokeTests`, gefunden bei #121).
    ///
    /// `-contextsEmptiedByUser NO`: `--ui-testing` gibt einen frischen In-Memory-Store, und
    /// `ContextSeeder` sät, solange der Nutzer den Katalog nicht selbst geleert hat (#146). Dieses
    /// Merkzeichen liegt in den Nutzereinstellungen und überlebt den Lauf; hätte ein früherer Lauf
    /// den letzten Kontext gelöscht, stünde der Store ohne Kontext da, und der Test scheiterte am
    /// Aufbau statt an der Sache (vor #146 mit `-contextsSeeded` so passiert, RED-Lauf 2026-09-28).
    /// Ein Startargument `-key value` landet in der Argument-Domäne und schlägt den gespeicherten Wert.
    @MainActor
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US",
            "-contextsEmptiedByUser", "NO",
        ]
        app.launch()
        return app
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

    /// Oberste Zeile der „Neu"-Liste. `ViewRules` sortiert absteigend nach Erfassungszeit, die
    /// jüngste Erfassung steht also immer oben — unabhängig davon, ob das Modell ihren Titel
    /// inzwischen geglättet hat und eine Suche nach dem Rohtext damit ins Leere liefe.
    @MainActor
    private func topRow(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "taskRow_"))
            .firstMatch
    }

    /// Hält fest, was Schritt 3 im Editor vorfand, als benannten Textanhang: ohne diesen Vermerk
    /// beweist ein grüner Gerätelauf nicht, welcher Ausgangszustand vorlag.
    @MainActor
    private func note(_ text: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(string: text)
        attachment.name = "schritt3-ausgangszustand"
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

    /// True, sobald das Element genau diese Beschriftung trägt — der Veredelungs-Durchgang läuft
    /// asynchron nach dem Speichern, die Ansicht zeigt das Ergebnis also erst kurz danach.
    @MainActor
    private func waitForLabel(_ label: String, of element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate(format: "label == %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Die erwartete Beschriftung einer Feldzeile: Feldname, Wert, und der Vermerk, falls einer dran ist.
    private func fieldLabel(_ name: String, _ value: String, marker: String? = nil) -> String {
        ([name, value] + (marker.map { [$0] } ?? [])).joined(separator: ", ")
    }

    /// Der Titel ist gesetzt: leer ist ein Fehlschlag (#158, #159), kein Nebenbefund. Ein leeres
    /// Textfeld meldet seinen Platzhalter „Title" als Wert, der zählt deshalb als leer.
    @MainActor
    private func assertTitleIsSet(in app: XCUIApplication, _ step: String) {
        let field = element("detailTitleField", in: app)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "\(step): Die Detailansicht zeigt kein Titelfeld")
        let title = (field.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertFalse(title.isEmpty || title == "Title", "\(step): Der Titel ist leer, Wert war „\(title)\"")
    }

    @MainActor
    func testWordEqualRecaptureTakesOverDurationAndContext() throws {
        let app = launch()

        // 1. Erste Erfassung.
        capture(Self.firstText, in: app)
        let newRow = element("viewRow_new", in: app)
        XCTAssertTrue(newRow.waitForExistence(timeout: 5), "Die Ansichtsliste zeigt kein Neu")
        newRow.tap()
        // Wie bei der zweiten Aufgabe: oberste Zeile, bestätigt über den unveränderlichen Rohtext,
        // weil eine Titelsuche ins Leere läuft, sobald das Modell den Titel glättet.
        let first = topRow(in: app)
        XCTAssertTrue(first.waitForExistence(timeout: 5), "Die erste Aufgabe steht nicht in Neu")
        shot(app, "1-erste-aufgabe-erfasst")
        first.tap()
        let firstRawText = element("detailRawTextMarker", in: app)
        XCTAssertTrue(waitForLabel(Self.firstText, of: firstRawText),
                      "Die geöffnete Detailansicht zeigt nicht den ersten Rohtext")
        assertTitleIsSet(in: app, "Erste Aufgabe")

        // 2. Dauer selbst setzen — der Normalfall, wenn kein Modell da ist.
        let durationRow = revealField("field_duration", in: app)
        XCTAssertTrue(durationRow.waitForExistence(timeout: 5), "Die Detailansicht listet keine Dauer")
        durationRow.tap()
        let thirtyMinutes = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", Self.durationLabel)).firstMatch
        XCTAssertTrue(thirtyMinutes.waitForExistence(timeout: 5), "Der Editor bietet \(Self.durationLabel) nicht an")
        thirtyMinutes.tap()
        back(in: app)
        // Selbst gesetzt heißt: kein Vermerk, weder ✦ noch » «.
        let ownDuration = fieldLabel("Duration", Self.durationLabel)
        XCTAssertTrue(waitForLabel(ownDuration, of: durationRow),
                      "Erwartet „\(ownDuration)\", Beschriftung war „\(durationRow.label)\"")

        // 3. Kontext selbst setzen, und zwar genau diesen einen. Hat das Modell schon Kontexte
        // gesetzt, werden sie abgewählt und Garden von Hand gewählt: Die Wiedererkennung übernimmt
        // nur Werte des Nutzers (#244), ein Modellwert ließe Schritt 5 aus dem falschen Grund scheitern.
        let contextsRow = revealField("field_contexts", in: app)
        if !contextsRow.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(contextsRow.waitForExistence(timeout: 5), "Die Detailansicht listet keine Kontexte")
        contextsRow.tap()
        let garden = app.buttons.matching(NSPredicate(format: "label == %@", Self.contextLabel)).firstMatch
        XCTAssertTrue(garden.waitForExistence(timeout: 5), "Der Editor bietet \(Self.contextLabel) nicht an")
        let selected = app.buttons.matching(NSPredicate(format: "selected == YES"))
        let preset = selected.allElementsBoundByIndex.map(\.label)
        note(preset.isEmpty ? "Schritt 3: kein Kontext gesetzt"
                            : "Schritt 3: vorgefunden \(preset.joined(separator: ", ")) — abgewählt", in: app)
        while selected.firstMatch.exists {
            let before = selected.count
            selected.firstMatch.tap()
            let fewer = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count < %d", before), object: selected)
            XCTAssertEqual(XCTWaiter().wait(for: [fewer], timeout: 5), .completed, "Ein Kontext ließ sich nicht abwählen")
        }
        garden.tap()
        back(in: app)
        let ownContext = fieldLabel("Contexts", Self.contextLabel)
        XCTAssertTrue(waitForLabel(ownContext, of: contextsRow),
                      "Erwartet „\(ownContext)\", Beschriftung war „\(contextsRow.label)\"")
        shot(app, "2-werte-von-hand-gesetzt")

        // 4. Zurück in die Liste und wortgleich erneut erfassen.
        // Geprüft wird, dass die Liste wieder da ist — nicht, dass die erste Zeile noch steht: hat
        // das Modell ihren Titel gesetzt, verlässt sie „Neu", sobald ihre KI-Vermerke gesehen sind.
        back(in: app)
        let captureButton = app.buttons["captureButton"]
        XCTAssertTrue(captureButton.waitForExistence(timeout: 5), "Nicht zurück in der Liste")
        capture(Self.secondText, in: app)
        // Die zweite Aufgabe wird über die oberste Zeile gefunden und über ihren unveränderlichen
        // Rohtext bestätigt: eine Labelsuche nach „streichen Zaun" bricht, sobald das Modell glättet.
        let second = topRow(in: app)
        XCTAssertTrue(second.waitForExistence(timeout: 10), "Die zweite Aufgabe steht nicht in Neu")
        shot(app, "3-wortgleich-erneut-erfasst")

        // 5. Der Nachweis: die zweite Aufgabe trägt genau Dauer und Kontext der ersten, mit dem
        // Vermerk der Regel — und nichts daneben.
        second.tap()
        let secondRawText = element("detailRawTextMarker", in: app)
        XCTAssertTrue(waitForLabel(Self.secondText, of: secondRawText),
                      "Die geöffnete Detailansicht zeigt nicht den zweiten Rohtext")
        assertTitleIsSet(in: app, "Zweite Aufgabe")
        let secondDuration = element("field_duration", in: app)
        XCTAssertTrue(secondDuration.waitForExistence(timeout: 5), "Die Detailansicht listet keine Dauer")
        let takenDuration = fieldLabel("Duration", Self.durationLabel, marker: Self.ruleMarker)
        XCTAssertTrue(waitForLabel(takenDuration, of: secondDuration),
                      "Erwartet „\(takenDuration)\", Beschriftung war „\(secondDuration.label)\"")
        let secondContexts = element("field_contexts", in: app)
        if !secondContexts.waitForExistence(timeout: 3) { app.swipeUp() }
        XCTAssertTrue(secondContexts.waitForExistence(timeout: 5), "Die Detailansicht listet keine Kontexte")
        let takenContext = fieldLabel("Contexts", Self.contextLabel, marker: Self.ruleMarker)
        XCTAssertTrue(waitForLabel(takenContext, of: secondContexts),
                      "Erwartet „\(takenContext)\", Beschriftung war „\(secondContexts.label)\"")
        shot(app, "4-zweite-aufgabe-mit-uebernommenen-werten")
    }
}
