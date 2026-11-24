---
entity_id: fix-978-s3-wiederoeffnen-warten
type: bugfix
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: fix-978-s3-wiederoeffnen-warten
---

# Spec: #978 Schnitt 3 (v2) — Wiederöffnungstest klickt das Menüleisten-Symbol über die vorderste App, ⌘W-Arm wieder hart

## Approval

- [ ] Approved (Henning)

## Purpose

Der Pflicht-Check „Mac Gallery (macOS)“ trägt seit #978 Schnitt 1 ein `XCTExpectFailure` am ⌘W-Arm, weil das Menüleisten-Panel nach dem
Klick aufs Symbol selten von selbst wieder zuklappt. Der Testläufer klickt bisher über das Statusobjekt der Loose-Ends-App; XCTest aktiviert
dabei die Ziel-App, Finder holt sich die Aktivierung zurück, die Klicksynthese zieht sich über Sekunden, das Maus-hoch kommt verspätet und
der Statusobjekt-Host beendet die Sitzung. Schnitt 3 (v2) ändert nur den Test: Der Klick läuft über eine Koordinate, deren Wurzel die
vorderste App ist, sodass XCTest nichts aktivieren muss; der ⌘W-Arm wird wieder hart. App-Code bleibt unberührt.

**Hintergrund, v1 widerlegt:** Die erste Fassung dieser Spec („warten, bis die vorderste App ruhig ist, dann klicken“) wurde durch den
Galerie-Versuch 3 (CI-Lauf 45387184786, Commit a24a607) widerlegt: Die Aktivierung geschieht innerhalb von `click()`, nicht davor, das
Warten kann sie nicht verhindern, und die 3-s-Haltezeit sieht den Fall nie, weil das Panel schon vorher zu ist. Befund:
`docs/artifacts/fix-978-s3-wiederoeffnen-warten/befund-galerie-versuch3.md`.

**Hat es bisher funktioniert?** Ja, überwiegend: 231 von 231 echte kurze Klicks im Wiederholungslauf blieben offen; Fehlfälle gibt es nur im
⌘W-Arm (App beim Klick nicht vorn, Finder vorn). Ob Nutzer das Verhalten sehen, ist nicht belegt. Analyse:
`docs/context/fix-978-s3-wiederoeffnen-warten.md` (Abschnitt „Analysis“); Vorgänger: `docs/specs/fix-978-s2-panel-ernte.md`.

## Source

- **File:** `LooseEndsUITests/MacGalleryTests.swift`
- **Identifier:** `assertSymbolOpensPanelWithOneClick`, `testMenuBarReopensAfterReturnWithOneClick`,
  `testMenuBarReopensAfterOpenAppWithOneClick`, `testMenuBarReopensAfterReturnWithControlClick`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NSWorkspace.shared.frontmostApplication` (AppKit im Testläufer) | API | vorderste App und ihre Bundle-ID lesen |
| XCUIAutomation (`XCUIApplication(bundleIdentifier:)`, `XCUICoordinate`, `statusItems`) | API | Klick über fremde Wurzel, Anhänge |
| `LooseEndsUITests/MacUITestSupport.swift` (`macLaunch`, `macMainWindow`) | Test-Werkzeug | nur gelesen |
| `LooseEnds/Mac/MenuBarCapture.swift` | App | unverändert; liefert das Panel-Protokoll |
| `scripts/mac_panel_repeat_summary.py` | Skript | liest die letzte Anhangzeile `… panel open|not open`; unverändert |
| `.github/workflows/mac-panel-repeat.yml`, Job „Mac Gallery (macOS)“ in `ci.yml` | CI | Nachweis; unverändert |
| `docs/specs/fix-978-s2-panel-ernte.md` | Spec | Vorgänger |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | Klick über `XCUICoordinate` mit Wurzel `XCUIApplication(bundleIdentifier:)` der vordersten App; Anhang mit `how:` und Klickdauer; ⌘W-Arm ohne `XCTExpectFailure`/`continueAfterFailure` |
| `scripts/test_menubar_panel_log.py` | MODIFY | im Arbeitsbaum bereits geändert: `TestOpenAppArmIsHard` statt Erwartung eines `XCTExpectFailure` |
| `scripts/test_mac_reopen_settle.py` | MODIFY | Quelltext-Gegenprobe für den neuen Klickweg |

Unverändert: `LooseEnds/Mac/MenuBarCapture.swift`, `.github/workflows/mac-panel-repeat.yml`, `scripts/mac_panel_repeat_summary.py`, `scripts/test_mac_panel_repeat_summary.py` (nur ausgeführt).

### Estimated Changes

- Files: 3 (nur Testcode und Skripttests)
- LoC: App-Code 0; Testcode ca. +35/-10 im UI-Test

Keine Änderung an `project.yml`, `Info.plist`, Entitlements oder AppStorage-Schlüsseln. Kein Pfad der Geräteliste berührt.

## Implementation Details

1. **Wartehilfe bleibt:** `waitForFrontmostSettled` (vorderste App seit 1 s unverändert, Obergrenze 10 s) liefert die Bundle-ID der vordersten
   App. Sie verhindert die Aktivierung nicht, legt aber fest, welche App Wurzel wird.
2. **Klick `frontmostRootClick`:** Wurzel ist `XCUIApplication(bundleIdentifier: <vorderste App>)`. Die Koordinate ist
   `coordinate(withNormalizedOffset: .zero).withOffset(...)`, der Offset ist die Mitte von `statusItem.frame` minus Ursprung des
   Wurzelrahmens. Die vorderste App ist schon aktiv, XCTest muss nichts aktivieren, der Nutzerzustand „Finder vorn, Loose Ends als
   `.accessory`“ bleibt beim Klick erhalten (#862 bleibt sichtbar).
3. **Rückfall:** Ist die vorderste App Loose Ends selbst oder nicht lesbar (oder der Wurzelrahmen leer), klickt der Test wie bisher
   `statusItem.click()`; der Anhang vermerkt es in `how:`.
4. **Anhang `mac-gallery-<label>-click`:** `click: <Sekunden>`, `how: user: frontmost root <bundle id>` (oder `how:` des Rückfalls), die
   Dauer von `click()` in Sekunden, und als letzte Zeile weiter `after: … s, panel open|not open`. Haltezeit 3 s bleibt (open = offen und
   nach 3 s noch offen).
5. **⌘W-Arm hart:** `continueAfterFailure = true` und der `XCTExpectFailure`-Block entfallen. Der Kontrollarm (`LE_PANEL_CONTROL_ARM`,
   `XCTSkip`) bleibt unverändert.
6. **Mechanismus-Nachweis statt nur Rate:** Die Basisrate ist klein (~0,5 %); 0 Fälle in N belegen nur „unter 3/N“. Deshalb wird im
   xcresult-Aktivitätsprotokoll des Klicks geprüft, dass keine Aktivierung der Ziel-App auftaucht, und die Klickdauer sowie der Abstand
   `panel key` → Maus hoch im Panel-Protokoll gelesen.

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Der Test ist hier das Erzeugnis; sein Nachweis sind die Läufe.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN der Quelltext von `MacGalleryTests.swift` WHEN `scripts/test_mac_reopen_settle.py` ihn liest THEN verlangt die Gegenprobe
  `XCUIApplication(bundleIdentifier:` als Klickwurzel, die Offset-Berechnung aus `statusItem.frame`, den Rückfall auf `statusItem.click()`,
  den Anhang `frontmost root` und die Klickdauer (vor der Änderung rot).
- [ ] Test 2: GIVEN der Quelltext WHEN `scripts/test_menubar_panel_log.py` ihn liest THEN fehlen `XCTExpectFailure` und
  `continueAfterFailure = true` im ⌘W-Arm (`TestOpenAppArmIsHard`).
- [ ] Test 3: GIVEN ein Anhang im neuen Format WHEN `scripts/test_mac_panel_repeat_summary.py` und die Zusammenfassung ihn lesen THEN stimmen
  Nenner, Zähler und Rate ohne Änderung am Skript.
- [ ] Test 4: GIVEN der Wiederholungslauf `mac-panel-repeat.yml` mit mindestens 100 Iterationen je Arm WHEN er endet THEN nennt
  `MacPanelRepeatSummary` je Arm Zähler 0 bei Nenner gleich Iterationszahl, und das Aktivitätsprotokoll des Klicks im ⌘W-Arm zeigt keine
  Aktivierung von `com.henning.looseends`.

### Abnahme (Stufen)

1. **Tests:** Skripttests grün, UI-Test-Bundles bauen, drei grüne Pflichtläufe.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Belege: Ergebnisbündel,
   `MacPanelRepeatSummary`, ein geöffneter Klickanhang und das Aktivitätsprotokoll, beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `assertSymbolOpensPanelWithOneClick` / When der Diff geprüft wird / Then läuft der Klick im Return- und im ⌘W-Arm über
  eine `XCUICoordinate`, deren Wurzel `XCUIApplication(bundleIdentifier:)` der nach `waitForFrontmostSettled` vordersten App ist, mit Offset
  gleich Mitte von `statusItem.frame` minus Ursprung des Wurzelrahmens; ist die vorderste App Loose Ends selbst oder nicht lesbar, klickt er
  wie bisher `statusItem.click()` und vermerkt das im Anhang. Belegt durch Diff und `scripts/test_mac_reopen_settle.py`.
- **AC-2:** Given der Anhang `mac-gallery-<label>-click` / When er geschrieben wird / Then nennt `how:` `user: frontmost root <bundle id>`
  (oder den Rückfall), eine Zeile nennt die Dauer des Klicks in Sekunden, und die letzte Zeile bleibt `after: … s, panel open|not open`.
  Belegt durch Diff, Skript-Test und einen geöffneten Anhang.
- **AC-3:** Given der ⌘W-Arm `testMenuBarReopensAfterOpenAppWithOneClick` / When der Diff geprüft wird / Then enthält er weder
  `XCTExpectFailure` noch `continueAfterFailure = true`, und die Haltezeit von 3 s bleibt. Belegt durch `grep` und `TestOpenAppArmIsHard`.
- **AC-4:** Given der Kontrollarm `testMenuBarReopensAfterReturnWithControlClick` / When der Diff geprüft wird / Then ist er unverändert
  (weiter mit `LE_PANEL_CONTROL_ARM` und `XCTSkip` geschützt). Belegt durch Diff.
- **AC-5:** Given ein Wiederholungslauf `mac-panel-repeat.yml` auf dem PR-Zweig mit mindestens 100 Iterationen je Arm / When er endet /
  Then gibt es keinen Fehlschlag in beiden Nutzerarmen, im xcresult-Aktivitätsprotokoll des Klicks im ⌘W-Arm steht kein „Activate
  com.henning.looseends“, die Klickdauer ist kleiner als 1 s, und im Panel-Protokoll liegt der Abstand `panel key` → Maus hoch unter 0,3 s.
  Belegt durch die Artefakte, geöffnet und beschrieben.
- **AC-6:** Given der Pflicht-Check „Mac Gallery (macOS)“ / When er auf dem Stand dreimal läuft / Then ist er jedes Mal beim ersten Versuch
  grün; ein Abbruch durch das 40-min-Zeitlimit (#974) zählt nicht und wird neu gestartet. Belegt durch drei Läufe, Ergebnisbündel geöffnet.
- **AC-7:** Given der Diff / When er geprüft wird / Then sind `scripts/test_menubar_panel_log.py` und `scripts/test_mac_reopen_settle.py`
  grün und der App-Code unverändert (0 LoC; `MenuBarCapture.swift`, `mac-panel-repeat.yml`, `mac_panel_repeat_summary.py` unberührt). Belegt
  durch Skriptlauf und `git diff --stat`.

## Alternativen

- **A Wurzel gleich vorderste App (gewählt):** Ursache weg, falls XCTest keine Aktivierung auslöst; #862 bleibt nutzertreu sichtbar.
- **B `app.activate()` vor dem Klick:** Finder holt die Aktivierung zurück, anderer Ausgangszustand als beim Nutzer. Verworfen.
- **C CGEvent plus TCC-Eintrag im Job:** kein offizieller Weg für das Recht `kTCCServicePostEvent` auf gehosteten Runnern, image-abhängig. Verworfen.
- **D Erkennen „ging auf, vom Host im Klick wieder zu“ plus eine Wiederholung (Rückfall):** nur Meldung, kein Beseitigen der Ursache, rund
  50 LoC plus Protokoll-Schnittstelle. Wird gebaut, falls AC-5 die Aktivierung trotz fremder Wurzel zeigt.
- **E App-Eingriff:** in S2 verworfen, Nutzer nicht belegt betroffen (231 von 231 offen).
- **v1 Warten vor dem Klick:** widerlegt (siehe Purpose).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testwerkzeug-Änderung; Speicherort, Datenmodell, Plattformzuschnitt und Abgleich bleiben, und keine der Alternativen
  kippt eine bestehende ADR.

## Known Limitations

- **Unbelegt, ob XCTest über eine fremde Wurzel nicht ebenfalls aktiviert:** Deshalb der Mechanismus-Nachweis (AC-5); Rückfall D.
- **Rate ist eine Stichprobe:** 100 Iterationen ohne Fehlschlag senken die Wahrscheinlichkeit, schließen sie nicht aus.
- **Zeitlimit der Galerie (#974):** 40 min, Läufe von 33 bis 41 min; ein Abbruch ist ein eigenes, vorbestehendes Problem.
- **Mac-UI-Tests nur in der CI:** nie auf Hennings Mac.

## Definition of Done

- [ ] AC-1 bis AC-7 erfüllt; Skript-Tests grün, UI-Test-Bundles bauen, drei Pflichtläufe grün, Wiederholungslauf mit mindestens 100
  Iterationen je Arm ohne Fehlschlag, Artefakte geöffnet und beschrieben.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ PR mit `Closes #978`, sobald alle Nachweise stehen.

## Changelog

- 2026-11-24: Initiale Spec für #978 Schnitt 3 (Warten vor dem Klick).
- 2026-11-24: v2 nach Galerie-Versuch 3: Klick über die vorderste App als Koordinatenwurzel, Mechanismus-Nachweis, v1 widerlegt.
