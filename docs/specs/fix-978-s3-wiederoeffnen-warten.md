---
entity_id: fix-978-s3-wiederoeffnen-warten
type: bugfix
created: 2026-11-24
updated: 2026-11-24
status: draft
workflow: fix-978-s3-wiederoeffnen-warten
---

# Spec: #978 Schnitt 3 (v3) — Wiederöffnungstest klickt über die Menüleiste der vordersten App, ⌘W-Arm wieder hart

## Approval

- [ ] Approved (Henning)

## Purpose

Der Pflicht-Check „Mac Gallery (macOS)“ trägt seit #978 Schnitt 1 ein `XCTExpectFailure` am ⌘W-Arm, weil das Menüleisten-Panel nach dem
Klick aufs Symbol selten von selbst wieder zuklappt. Der Testläufer klickt bisher über das Statusobjekt der Loose-Ends-App; XCTest aktiviert
dabei die Ziel-App, Finder holt sich die Aktivierung zurück, die Klicksynthese zieht sich über Sekunden, das Maus-hoch kommt verspätet und
der Statusobjekt-Host beendet die Sitzung. Schnitt 3 (v3) ändert nur den Test: Der Klick läuft über eine Koordinate, deren Wurzel die
Menüleiste der vordersten App ist, sodass XCTest nichts aktivieren muss; der ⌘W-Arm wird wieder hart, und ein stiller Rückfall auf den alten
Klickweg kann den Lauf nie mehr grün färben. App-Code bleibt unberührt.

**Hintergrund, v1 und v2 widerlegt:**

- v1 („warten, bis die vorderste App ruhig ist, dann klicken“) wurde durch Galerie-Versuch 3 (CI-Lauf 45387184786, Commit a24a607)
  widerlegt: Die Aktivierung geschieht innerhalb von `click()`, nicht davor. Befund:
  `docs/artifacts/fix-978-s3-wiederoeffnen-warten/befund-galerie-versuch3.md`.
- v2 (Wurzel = `XCUIApplication(bundleIdentifier:)` der vordersten App) wurde durch den v2-Galerielauf 45464097119 widerlegt: Ein
  `XCUIApplication`-Element hat auf macOS keinen Rahmen, also griff in beiden Armen der stille Rückfall `statusItem.click()` (Klickdauer
  5–6 s), und der Lauf war grün, ohne den neuen Weg je zu gehen. Befund: `docs/artifacts/fix-978-s3-wiederoeffnen-warten/befund-v2-galerie1.md`.
- Beleg für v3: Im selben Hierarchieauszug hat die Menüleiste einen echten Rahmen (`MenuBar, {{0.0, 0.0}, {1024.0, 30.0}}`); Menüleisten-
  Elemente tragen Bildschirmkoordinaten.

**Hat es bisher funktioniert?** Ja, überwiegend: 231 von 231 echte kurze Klicks im Wiederholungslauf blieben offen; Fehlfälle gibt es nur im
⌘W-Arm (App beim Klick nicht vorn, Finder vorn). Ob Nutzer das Verhalten sehen, ist nicht belegt. Analyse:
`docs/context/fix-978-s3-wiederoeffnen-warten.md` (Abschnitt „Analysis“, Analyse v3); Vorgänger: `docs/specs/fix-978-s2-panel-ernte.md`.

## Source

- **File:** `LooseEndsUITests/MacGalleryTests.swift`
- **Identifier:** `frontmostRootClick`, `assertSymbolOpensPanelWithOneClick`, `testMenuBarReopensAfterReturnWithOneClick`,
  `testMenuBarReopensAfterOpenAppWithOneClick`, `testMenuBarReopensAfterReturnWithControlClick`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `NSWorkspace.shared.frontmostApplication` (AppKit im Testläufer) | API | vorderste App und ihre Bundle-ID lesen |
| XCUIAutomation (`XCUIApplication(bundleIdentifier:)`, `menuBars`, `XCUICoordinate`, `statusItems`) | API | Klick über die Menüleiste der fremden App, Anhänge |
| `LooseEndsUITests/MacUITestSupport.swift` (`macLaunch`, `macMainWindow`) | Test-Werkzeug | nur gelesen |
| `LooseEnds/Mac/MenuBarCapture.swift` | App | unverändert; liefert das Panel-Protokoll |
| `scripts/mac_panel_repeat_summary.py` | Skript | liest `how:` und die letzte Anhangzeile; bekommt neue Kategorien |
| `.github/workflows/mac-panel-repeat.yml`, Job „Mac Gallery (macOS)“ in `ci.yml` | CI | Nachweis; unverändert |
| `docs/specs/fix-978-s2-panel-ernte.md` | Spec | Vorgänger |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `frontmostRootClick`: Wurzel = `XCUIApplication(bundleIdentifier: vorderste).menuBars.element(boundBy: 0)`, nur bei nicht leerem Rahmen mit Ursprung y = 0; Offset = Mitte Symbol − Ursprung Menüleiste; `how: user: frontmost menu bar <bundle id>`; zwei Rückfälle mit eigenem Text; ⌘W-Arm hart bei fremder vorderster App und Rückfall |
| `scripts/mac_panel_repeat_summary.py` | MODIFY | `how_of`/`_HOW` um `menubar-root`, `fallback-looseends`, `fallback-noframe` erweitern (spezifische Texte vor `statusItem.click()` prüfen) |
| `scripts/test_mac_panel_repeat_summary.py` | MODIFY | Tests für die neuen Kategorien; Rumpfprüfung der S2-Gegenprobe an den neuen Klickweg (Testcode) |
| `scripts/test_mac_reopen_settle.py` | MODIFY | Quelltext-Gegenprobe: `menuBars`, Rahmen-/Ursprungsprüfung, neue `how`-Texte, harte Rückfall-Assertion im ⌘W-Arm nur bei fremder vorderster App (Testcode) |
| `scripts/test_menubar_panel_log.py` | MODIFY | im Arbeitsbaum bereits geändert: `TestOpenAppArmIsHard` statt Erwartung eines `XCTExpectFailure` (Testcode) |

Unverändert: `LooseEnds/Mac/MenuBarCapture.swift`, `.github/workflows/mac-panel-repeat.yml`, der Kontrollarm
`testMenuBarReopensAfterReturnWithControlClick`.

### Estimated Changes

- Files: 5 (UI-Testdatei, Auswerteskript, drei Skripttests; Skripttests sind Testcode)
- LoC: App-Code 0; Werkzeugcode ca. +35/-10 (UI-Test +20/-8, Auswerteskript +15/-3), dazu Testcode in den Skripttests

Keine Änderung an `project.yml`, `Info.plist`, Entitlements, AppStorage-Schlüsseln oder Gate-Konfiguration. Kein Pfad der Geräteliste berührt.

## Implementation Details

1. **Wartehilfe bleibt:** `waitForFrontmostSettled` (vorderste App seit 1 s unverändert, Obergrenze 10 s) liefert die Bundle-ID der vordersten
   App. Sie verhindert die Aktivierung nicht, legt aber fest, welche App die Wurzel stellt.
2. **Klick `frontmostRootClick`:** Wurzel ist `XCUIApplication(bundleIdentifier: <vorderste App>).menuBars.element(boundBy: 0)`. Sie gilt nur,
   wenn ihr Rahmen nicht leer ist und ihr Ursprung bei y = 0 liegt (Hauptmenüleiste). Die Koordinate ist
   `coordinate(withNormalizedOffset: .zero).withOffset(...)`, der Offset ist die Mitte von `statusItem.frame` minus Ursprung der Menüleiste
   (beides Bildschirmpunkte). Die vorderste App ist schon aktiv, XCTest muss nichts aktivieren, der Nutzerzustand „Finder vorn, Loose Ends
   als `.accessory`“ bleibt erhalten (#862 bleibt sichtbar). Genau ein Klick, keine Wiederholung.
3. **Rückfälle mit eigenem Text (`statusItem.click()` wie bisher):**
   - Loose Ends selbst ist vorn (nichts zu aktivieren): `user: statusItem.click() fallback (frontmost com.henning.looseends)`.
   - Fremde vorderste App ohne brauchbaren Menüleistenrahmen (leer, nicht lesbar, Ursprung y ≠ 0, keine Menüleiste):
     `user: statusItem.click() fallback (frontmost <id>, no menu bar frame)`.
4. **Anhang `mac-gallery-<label>-click`:** `click: <Sekunden>`, `how: …` (ein Text aus Punkt 2 oder 3), `click duration: <s> s` und als letzte
   Zeile weiter `after: … s, panel open|not open`. Haltezeit 3 s bleibt (open = offen und nach 3 s noch offen).
5. **⌘W-Arm hart:** `continueAfterFailure = true` und der `XCTExpectFailure`-Block entfallen, kein `XCTExpectFailure` an anderer Stelle.
   Zusätzlich: ist im ⌘W-Arm eine fremde App vorn (nicht Loose Ends) und greift ein Rückfall, ist der Test rot, und die Meldung nennt `how`
   (Lehre aus v2: ein stiller Rückfall wird nie grün). Ist Loose Ends vorn, bleibt der Rückfall zulässig und wird getrennt gezählt.
   Der Return-Arm folgt derselben Rückfall-Regel nur bei fremder vorderster App; sonst zählt er den Rückfall. Der Kontrollarm
   (`LE_PANEL_CONTROL_ARM`, `XCTSkip`) bleibt unverändert.
6. **Auswerteskript:** `how_of` ordnet nach spezifischen Texten zuerst: `frontmost menu bar` → `menubar-root`;
   `fallback (frontmost com.henning.looseends)` → `fallback-looseends`; `no menu bar frame` → `fallback-noframe`; danach die bisherigen
   Kategorien. Als Beleg zählt nur `menubar-root`; `fallback-looseends` wird getrennt ausgewiesen, `fallback-noframe` ist ein Befund.
7. **Nachweis in drei Stufen, jede kann den Ansatz widerlegen, bevor die nächste Zeit kostet:**
   1. *Probelauf* `mac-panel-repeat.yml` mit 1–2 Iterationen ohne Kontrollarm: ⌘W-Arm `how` = `frontmost menu bar <id>`, Klickdauer < 1 s,
      im Klickprotokoll des xcresult kein „Activate com.henning.looseends“, im Panel-Protokoll `key` → Maus hoch < 0,3 s. Fällt einer
      davon durch (auch: Menüleiste ohne Rahmen, Klickdauer ≥ 1 s), ist A′ widerlegt: Rückfallplan D, der Workflow geht zurück in die
      Analyse. Ist die vorderste App weder Loose Ends noch Finder (Dock, loginwindow), gilt dieselbe Regel; die App steht im Anhang.
   2. *Wiederholungsläufe* mit mindestens 100 Iterationen je Arm in Summe (Teilläufe wegen der 120-min-Grenze erlaubt), 0 Fälle.
   3. *Pflicht-Check* „Mac Gallery (macOS)“ dreimal beim ersten Versuch grün; je Bündel werden `how` und Klickdauer abgelesen. Ein durch das
      Zeitlimit #974 abgebrochener Lauf zählt nicht und wird neu gestartet.

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Der Test ist hier das Erzeugnis; sein Nachweis sind die Läufe.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN der Quelltext von `MacGalleryTests.swift` WHEN `scripts/test_mac_reopen_settle.py` ihn liest THEN verlangt die Gegenprobe
  `menuBars` als Klickwurzel, die Rahmen- und Ursprung-y-Prüfung, die Offset-Berechnung aus `statusItem.frame`, die drei `how`-Texte, den
  Rückfall auf `statusItem.click()` und die harte Assertion im ⌘W-Arm bei fremder vorderster App (vor der Änderung rot).
- [ ] Test 2: GIVEN der Quelltext WHEN `scripts/test_menubar_panel_log.py` ihn liest THEN fehlen `XCTExpectFailure` und
  `continueAfterFailure = true` im ⌘W-Arm (`TestOpenAppArmIsHard`).
- [ ] Test 3: GIVEN Anhänge mit `how: user: frontmost menu bar com.apple.finder`, `…fallback (frontmost com.henning.looseends)` und
  `…fallback (frontmost com.apple.finder, no menu bar frame)` WHEN `scripts/test_mac_panel_repeat_summary.py` `how_of` und die
  Zusammenfassung prüft THEN lauten die Kategorien `menubar-root`, `fallback-looseends`, `fallback-noframe`, und Nenner, Zähler und Rate
  stimmen.
- [ ] Test 4: GIVEN der Probelauf `mac-panel-repeat.yml` mit 1–2 Iterationen WHEN er endet THEN ist im ⌘W-Arm `how` = `frontmost menu bar`,
  die Klickdauer < 1 s, das Klickprotokoll ohne „Activate com.henning.looseends“ und `key` → Maus hoch < 0,3 s.
- [ ] Test 5: GIVEN Wiederholungsläufe mit zusammen mindestens 100 Iterationen je Arm WHEN sie enden THEN nennt `MacPanelRepeatSummary`
  je Arm Zähler 0 bei Nenner gleich Iterationszahl, und jeder gezählte ⌘W-Klick ist `menubar-root`.

### Abnahme (Stufen)

1. **Tests:** Skripttests grün, UI-Test-Bundles bauen, drei grüne Pflichtläufe.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Belege: Ergebnisbündel,
   `MacPanelRepeatSummary`, ein geöffneter Klickanhang und das Aktivitätsprotokoll, beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `assertSymbolOpensPanelWithOneClick` / When der Diff geprüft wird / Then läuft der Klick im Return- und im ⌘W-Arm über
  eine `XCUICoordinate` mit Wurzel `XCUIApplication(bundleIdentifier: <vorderste App>).menuBars.element(boundBy: 0)`, nur bei nicht leerem
  Rahmen mit Ursprung y = 0, mit Offset gleich Mitte von `statusItem.frame` minus Ursprung der Menüleiste. Belegt durch Diff und
  `scripts/test_mac_reopen_settle.py`.
- **AC-2:** Given der Anhang `mac-gallery-<label>-click` / When er geschrieben wird / Then nennt `how:` genau einen der Texte
  `user: frontmost menu bar <bundle id>`, `user: statusItem.click() fallback (frontmost com.henning.looseends)` oder
  `user: statusItem.click() fallback (frontmost <id>, no menu bar frame)`, eine Zeile nennt die Klickdauer in Sekunden, und die letzte Zeile
  bleibt `after: … s, panel open|not open`. Belegt durch Diff, Skript-Test und einen geöffneten Anhang.
- **AC-3:** Given der ⌘W-Arm `testMenuBarReopensAfterOpenAppWithOneClick` / When der Diff geprüft wird / Then enthält er weder
  `XCTExpectFailure` noch `continueAfterFailure = true`, die Haltezeit von 3 s bleibt, und bei fremder vorderster App mit Rückfall ist der
  Test rot mit `how` in der Meldung; ist Loose Ends vorn, ist der Rückfall zulässig. Belegt durch `grep`, `TestOpenAppArmIsHard` und
  `scripts/test_mac_reopen_settle.py`.
- **AC-4:** Given der Kontrollarm `testMenuBarReopensAfterReturnWithControlClick` und `LooseEnds/Mac/MenuBarCapture.swift` / When der Diff
  geprüft wird / Then sind beide unverändert (Kontrollarm weiter mit `LE_PANEL_CONTROL_ARM` und `XCTSkip` geschützt, App-Code 0 LoC).
  Belegt durch `git diff --stat`.
- **AC-5:** Given Anhänge mit den drei neuen `how`-Texten / When `scripts/mac_panel_repeat_summary.py` sie liest / Then ergeben sie die
  Kategorien `menubar-root`, `fallback-looseends`, `fallback-noframe` (nicht `unbekannt` oder `statusitem`), und als Beleg zählt nur
  `menubar-root`. Belegt durch `scripts/test_mac_panel_repeat_summary.py`.
- **AC-6:** Given der Probelauf `mac-panel-repeat.yml` mit 1–2 Iterationen ohne Kontrollarm / When er endet / Then ist im ⌘W-Arm `how` =
  `frontmost menu bar <id>`, die Klickdauer < 1 s, im Klickprotokoll des xcresult steht kein „Activate com.henning.looseends“ und im
  Panel-Protokoll liegt `key` → Maus hoch unter 0,3 s; sonst gilt A′ als widerlegt, Rückfallplan D, Workflow zurück in die Analyse. Belegt
  durch die Artefakte, geöffnet und beschrieben.
- **AC-7:** Given Wiederholungsläufe `mac-panel-repeat.yml` auf dem PR-Zweig mit zusammen mindestens 100 Iterationen je Arm (Teilläufe
  erlaubt) / When sie enden / Then gibt es 0 Fälle in beiden Nutzerarmen, und jeder gezählte Klick im ⌘W-Arm ist `menubar-root`
  (Rückfälle werden benannt und getrennt ausgewiesen). Belegt durch `MacPanelRepeatSummary`, geöffnet und beschrieben.
- **AC-8:** Given der Pflicht-Check „Mac Gallery (macOS)“ / When er auf dem Stand dreimal läuft / Then ist er jedes Mal beim ersten Versuch
  grün, und je Bündel sind `how` und Klickdauer abgelesen; ein Abbruch durch das Zeitlimit #974 zählt nicht und wird neu gestartet. Belegt
  durch drei Läufe, Ergebnisbündel geöffnet.

## Alternativen

- **A′ Wurzel = Menüleiste der vordersten App (gewählt):** Ursache weg, falls XCTest keine Aktivierung auslöst (Probelauf, AC-6); #862 bleibt
  nutzertreu sichtbar; rund 15 LoC.
- **A″ Wurzel = Menüleiste der Systemoberfläche (`com.apple.controlcenter`/`systemuiserver`):** aktiviert evtl. eine Agent-App, fremder
  Aktivierungszustand. Verworfen.
- **B `app.activate()` vor dem Klick:** Finder holt die Aktivierung zurück, anderer Ausgangszustand als beim Nutzer. Verworfen.
- **C CGEvent plus TCC-Eintrag im Job:** kein offizieller Weg für `kTCCServicePostEvent` auf gehosteten Runnern, image-abhängig. Verworfen.
- **D Erkennen „ging auf, vom Host im Klick wieder zu“ plus eine Wiederholung (Rückfall):** nur Meldung, kein Beseitigen der Ursache, rund
  50 LoC plus Protokoll-Schnittstelle. Wird gebaut, falls AC-6 A′ widerlegt.
- **E App-Eingriff:** in S2 verworfen, Nutzer nicht belegt betroffen (231 von 231 offen).
- **v1 Warten vor dem Klick, v2 Wurzel `XCUIApplication` selbst:** widerlegt (siehe Purpose).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Testwerkzeug-Änderung; Speicherort, Datenmodell, Plattformzuschnitt und Abgleich bleiben, und keine der Alternativen
  kippt eine bestehende ADR.

## Known Limitations

- **Unbelegt, dass die Finder-Menüleiste einen Rahmen liefert und `click()` auf ihrer Koordinate nichts aktiviert:** Deshalb der Probelauf
  (AC-6) vor jeder Zählung; Rückfall D.
- **Rate ist eine Stichprobe:** Die Basisrate ist klein (~0,5 %); 100 Iterationen ohne Fehlschlag senken die Wahrscheinlichkeit, schließen sie
  nicht aus. Darum zählt zusätzlich der Mechanismus (kein „Activate“, Klickdauer, `key` → Maus hoch).
- **Zeitlimit der Galerie (#974):** 40 min, Läufe von 33 bis 41 min; ein Abbruch ist ein eigenes, vorbestehendes Problem.
- **Mac-UI-Tests nur in der CI:** nie auf Hennings Mac.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt; Skript-Tests grün, UI-Test-Bundles bauen, Probelauf bestanden, Wiederholungsläufe mit mindestens 100
  Iterationen je Arm ohne Fehlschlag, drei Pflichtläufe grün, Artefakte geöffnet und beschrieben.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ PR mit `Closes #978`, sobald alle Nachweise stehen.

## Changelog

- 2026-11-24: Initiale Spec für #978 Schnitt 3 (Warten vor dem Klick).
- 2026-11-24: Phase 6: `scripts/test_mac_panel_repeat_summary.py` in die betroffenen Dateien aufgenommen (S2-Gegenprobe auf v2).
- 2026-11-24: v2 nach Galerie-Versuch 3: Klick über die vorderste App als Koordinatenwurzel, Mechanismus-Nachweis, v1 widerlegt.
- 2026-11-24: v3 nach v2-Galerielauf 45464097119 (`XCUIApplication.frame` auf macOS leer, stiller Rückfall): Wurzel = Menüleiste der vordersten
  App, Rückfälle mit eigenem Text, ⌘W-Arm hart bei fremder vorderster App, neue Auswertekategorien, Nachweis in drei Stufen; v1 und v2 widerlegt.
