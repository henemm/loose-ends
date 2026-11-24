---
entity_id: fix-978-s3-wiederoeffnen-warten
type: bugfix
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: fix-978-s3-wiederoeffnen-warten
---

# Spec: #978 Schnitt 3 — Wiederöffnungstests warten den App-Wechsel ab und prüfen eine Haltezeit, der ⌘W-Arm wird wieder hart

## Approval

- [ ] Approved (Henning)

## Purpose

Der Pflicht-Check „Mac Gallery (macOS)“ trägt seit #978 Schnitt 1 ein `XCTExpectFailure` am ⌘W-Arm, weil das Menüleisten-Panel nach
dem Klick aufs Symbol selten von selbst wieder zuklappt. Schnitt 2 hat die Ursache belegt (Fall 45334299531): Der Klick fällt in den
Nachlauf des App-Wechsels nach ⌘W, die XCUITest-Klicksynthese stellt das Loslassen verspätet zu, und der Statusobjekt-Host wertet es als
zweiten Klick. Schnitt 3 ändert nur den Test: Er klickt erst, wenn die vorderste App eine Sekunde unverändert ist, prüft das Panel nach
3 s Haltezeit und macht den ⌘W-Arm wieder hart. App-Code bleibt unberührt.

**Hat es bisher funktioniert?** Ja, überwiegend: S2 zählte 1 Fall in 420 Wiederöffnungen (Wiederholungsläufe), früher etwa 13 % im
Pflicht-Job, nur im Arm Open-App (⌘W-Weg). Ob Nutzer das Verhalten sehen, ist nicht belegt. Analyse und Belege:
`docs/context/fix-978-s3-wiederoeffnen-warten.md`; Vorgänger: `docs/specs/fix-978-s2-panel-ernte.md`.

## Source

- **File:** `LooseEndsUITests/MacGalleryTests.swift`
- **Identifier:** `assertSymbolOpensPanelWithOneClick`, `testMenuBarReopensAfterReturnWithOneClick`,
  `testMenuBarReopensAfterOpenAppWithOneClick`, `testMenuBarReopensAfterReturnWithControlClick`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NSWorkspace.shared.frontmostApplication` (AppKit im Testläufer) | API | vorderste App lesen; der Testläufer ist ein macOS-Prozess |
| XCUIAutomation (`XCUIApplication`, `statusItems`, `XCTWaiter`) | API | Klick, Warten, Anhänge |
| `LooseEndsUITests/MacUITestSupport.swift` (`macLaunch`, `macMainWindow`) | Test-Werkzeug | nur gelesen |
| `LooseEnds/Mac/MenuBarCapture.swift` | App | unverändert (kein App-Eingriff) |
| `scripts/mac_panel_repeat_summary.py` (+ `scripts/test_mac_panel_repeat_summary.py`) | Skript | liest die letzte Anhangzeile `… panel open|not open`; unverändert |
| `.github/workflows/mac-panel-repeat.yml`, Job „Mac Gallery (macOS)“ in `ci.yml` | CI | Nachweis; unverändert |
| `docs/specs/fix-978-s2-panel-ernte.md`, `docs/specs/fix-978-panel-schliesst.md` | Spec | Vorgänger |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `import AppKit`; Hilfe `waitForFrontmostSettled`; `assertSymbolOpensPanelWithOneClick` wartet davor und prüft die Haltezeit; ⌘W-Arm ohne `XCTExpectFailure`/`continueAfterFailure` |

Unverändert: `LooseEnds/Mac/MenuBarCapture.swift`, `.github/workflows/mac-panel-repeat.yml`, `scripts/mac_panel_repeat_summary.py`.

### Estimated Changes

- Files: 1 (nur Testcode)
- LoC: App-Code 0; Testcode ca. +45/-12

Keine Änderung an `project.yml`, `Info.plist`, Entitlements oder AppStorage-Schlüsseln. **Geräteliste:** berührt wird nur
`LooseEndsUITests/`, das steht nicht auf der Liste. Kein Pfad der Geräteliste berührt.

## Implementation Details

1. **Hilfe `waitForFrontmostSettled` (Testcode).** Liest `NSWorkspace.shared.frontmostApplication` (Bundle-ID) alle 0,1 s. „Ruhig“ heißt:
   die vorderste App ist seit 1 s unverändert. Obergrenze 10 s; nach Ablauf klickt der Test trotzdem und vermerkt den Ablauf im Anhang.
   Rückgabe: Verlauf als Zeilen (je Wechsel der vordersten App Zeit seit Start der Wartens und Bundle-ID, am Ende „settled after N s“ oder
   „timeout after 10 s“). Warten per Schleife mit kurzem Schlafen; keine Annahme, dass Loose Ends nicht aktiv ist, weil nach Return die
   App aktiv bleiben kann.
2. **`assertSymbolOpensPanelWithOneClick` (Reihenfolge):** Symbol existiert (10 s) → `waitForFrontmostSettled` → genau ein Klick
   (`statusItem.click()` oder der Klick des Kontrollarms) → Panel binnen 10 s → nach 3 s ist das Panel (`menuBarOpenApp`) noch vorhanden →
   Anhang → harte Assertions. Kein zweiter Klick, keine Wiederholung bei Fehlschlag.
3. **Anhangformat (Vertrag mit `mac_panel_repeat_summary.py`).** Der Anhang `mac-gallery-<label>-click` behält die Zeilen `click: <Sekunden
   seit 1970>`, `how: …` und die **letzte Zeile** `after: … s, panel open|not open`. „open“ heißt ab jetzt: Panel offen **und** nach 3 s noch
   offen; ein „geht auf, geht zu“ zählt damit als „not open“. Die Verlauf-Zeilen der vordersten App stehen **vor** der letzten Zeile. Das
   Skript liest nur `click:`, `how:` und die letzte Zeile mit `panel (open|not open)` am Zeilenende und bleibt unverändert.
4. **Alle drei Arme** (Return, ⌘W, Kontrollarm `reopen-return-control`) laufen durch dieselbe Hilfe, damit die Raten im Wiederholungslauf
   vergleichbar bleiben. Der Kontrollarm bleibt mit `LE_PANEL_CONTROL_ARM` und `XCTSkip` geschützt und klickt weiter per Koordinate.
5. **⌘W-Arm hart:** `continueAfterFailure = true` und der `XCTExpectFailure`-Block in `testMenuBarReopensAfterOpenAppWithOneClick`
   entfallen; der Kommentar dort wird auf den neuen Stand gebracht. `app.terminate()` bleibt am Ende.
6. **Nachweis:** drei grüne Pflichtläufe „Mac Gallery (macOS)“ und ein Wiederholungslauf `mac-panel-repeat.yml` mit mindestens 40
   Iterationen je Arm ohne Fehlschlag (Kontrollarm an).

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Der Test ist hier das Erzeugnis; sein Nachweis sind die Läufe.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN die Wiederöffnungstests ohne `XCTExpectFailure` und mit Haltezeit WHEN `xcodebuild build-for-testing` der UI-Test-Bundles
  läuft THEN kompiliert er (kein Fehler durch `import AppKit`, Concurrency oder Hilfe).
- [ ] Test 2: GIVEN ein Anhang im neuen Format (Verlauf-Zeilen, dann `after: … panel open`) WHEN `scripts/test_mac_panel_repeat_summary.py`
  und die Zusammenfassung ihn lesen THEN stimmen Nenner, Zähler und Rate, und die Skript-Tests sind unverändert grün.
- [ ] Test 3: GIVEN der Pflicht-Job „Mac Gallery (macOS)“ WHEN er auf dem PR-Zweig läuft THEN sind beide Wiederöffnungstests ohne
  `XCTExpectFailure` ausgeführt und grün, der Kontrollarm als übersprungen ausgewiesen.
- [ ] Test 4: GIVEN der Wiederholungslauf `mac-panel-repeat.yml` mit `iterationen` ≥ 40 und Kontrollarm WHEN er endet THEN nennt
  `MacPanelRepeatSummary` je Arm Nenner ≥ 40 und Zähler 0, und der Nenner stimmt mit der Iterationszahl überein.
- [ ] Test 5: GIVEN der Anhang eines Laufs WHEN er geöffnet wird THEN stehen die Verlauf-Zeilen der vordersten App vor der letzten Zeile,
  und bei Überschreitung der 10 s ist „timeout“ vermerkt.

### Abnahme (Stufen)

1. **Tests:** Skript-Tests grün, UI-Test-Bundles bauen, drei grüne Pflichtläufe.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Belege: Ergebnisbündel
   der Pflichtläufe, `MacPanelRepeatSummary` und ein geöffneter Klickanhang des Wiederholungslaufs, beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `LooseEndsUITests/MacGalleryTests.swift` / When der Diff geprüft wird / Then enthalten die Wiederöffnungstests kein
  `XCTExpectFailure` und kein `continueAfterFailure = true` mehr. Belegt durch Diff und `grep` auf beide Wörter in der Datei.
- **AC-2:** Given `assertSymbolOpensPanelWithOneClick` / When der Diff geprüft wird / Then ist die Reihenfolge Symbol existiert, ruhig warten
  (`waitForFrontmostSettled`: vorderste App seit 1 s unverändert, Abfrage alle 0,1 s, Obergrenze 10 s, danach trotzdem klicken und den Ablauf
  im Anhang vermerken), genau ein Klick, Panel binnen 10 s, nach 3 s noch vorhanden, Anhang, harte Assertions; es gibt keinen zweiten Klick
  und keine Wiederholung. Belegt durch Diff.
- **AC-3:** Given die Arme Return, ⌘W und Kontrollarm / When der Diff geprüft wird / Then gehen alle drei durch `assertSymbolOpensPanelWithOneClick`
  mit derselben Wartehilfe; der Kontrollarm bleibt mit `XCTSkip` ohne `LE_PANEL_CONTROL_ARM` geschützt. Belegt durch Diff.
- **AC-4:** Given der Klickanhang `mac-gallery-<label>-click` / When er geschrieben wird / Then behält er `click:`, `how:` und als letzte Zeile
  `… panel open|not open` (open = offen und nach 3 s noch offen), die Verlauf-Zeilen der vordersten App stehen davor, und
  `scripts/test_mac_panel_repeat_summary.py` ist ohne Änderung am Skript grün. Belegt durch die Skript-Tests und einen geöffneten Anhang.
- **AC-5:** Given der Pflicht-Check „Mac Gallery (macOS)“ / When er auf dem PR-Zweig dreimal nacheinander läuft / Then ist er jedes Mal beim
  ersten Versuch grün, ohne `XCTExpectFailure`. Belegt durch drei Läufe, deren Ergebnisbündel geöffnet und beschrieben sind.
- **AC-6:** Given `mac-panel-repeat.yml` auf dem PR-Zweig mit mindestens 40 Iterationen und Kontrollarm / When er endet / Then nennt
  `MacPanelRepeatSummary` je Arm Nenner ≥ 40 und Zähler 0 (keine Abweichung vom Soll-Nenner). Belegt durch das Artefakt, geöffnet und beschrieben.
- **AC-7:** Given der Diff / When er geprüft wird / Then berührt er nur `LooseEndsUITests/MacGalleryTests.swift` (App-Code 0 LoC;
  `MenuBarCapture.swift`, `mac-panel-repeat.yml`, `mac_panel_repeat_summary.py` unverändert), und der Build der UI-Test-Bundles ist grün.
  Belegt durch `git diff --stat` und den Bau.

## Alternativen

- **Feste Pause (z. B. 2 s) vor dem Klick:** einfacher, aber zeitgeraten; bei langsamem Runner zu kurz, sonst Leerlauf. Verworfen zugunsten
  der beobachteten Bedingung „vorderste App ruhig“.
- **Zweiter Klick / Wiederholung bei Fehlschlag:** verdeckt einen echten „geht nicht auf“-Fehler. Verworfen.
- **App-Eingriff (Panel ignoriert Loslassen während des Aktivierungswechsels):** in S2 als Alternative C verworfen; Nutzerbetroffenheit nicht
  belegt, Eingriff in das Systemverhalten des Statusobjekts. Keine ADR betroffen.
- **`XCTExpectFailure` belassen:** hält die CI grün, prüft aber nichts; widerspricht dem Ziel von #978.
- **Koordinatenklick auch für die Nutzerarme:** verwässert den Nutzerweg; der Kontrollarm bleibt Diagnose.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testwerkzeug-Änderung in einer Datei; Speicherort, Datenmodell, Plattformzuschnitt und Abgleich bleiben, und keine der
  Alternativen kippt eine bestehende ADR.

## Known Limitations

- **Wartezeit verdeckt nur einen engen Fall:** Sie verdeckt einen App-Fehler nur für Klicks genau während des Fensterwechsels; ein Nutzer,
  der in dieser Sekunde klickt, könnte das Zuklappen weiterhin sehen. Nutzerbetroffenheit ist im Issue als nicht belegt vermerkt.
- **Rate ist eine Stichprobe:** 40 Iterationen je Arm ohne Fehlschlag senken die Wahrscheinlichkeit eines Falls, schließen ihn nicht aus
  (S2: 1 in 420).
- **Weicher durch Obergrenze:** Nach 10 s ohne ruhige vorderste App klickt der Test trotzdem; der Anhang vermerkt das, das Skript zählt es nicht
  gesondert.
- **Mac-UI-Tests nur in der CI:** nie auf Hennings Mac.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt; UI-Test-Bundles bauen, Skript-Tests grün, drei Pflichtläufe grün, Wiederholungslauf mit ≥ 40 Iterationen je Arm
  ohne Fehlschlag, Artefakte geöffnet und beschrieben.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ PR mit `Closes #978`, sobald alle Nachweise stehen (Issue-Kommentar mit Befund
  und Raten).

## Changelog

- 2026-11-24: Initiale Spec für #978 Schnitt 3 (Wiederöffnungstests warten ab, Haltezeit, ⌘W-Arm hart).
