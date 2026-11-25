---
entity_id: fix-978-s5-kurzer-klick
type: bugfix
created: 2026-11-25
updated: 2026-11-25
status: draft
workflow: fix-978-s5-kurzer-klick
---

# Spec: #978 Schnitt v5 — kurzer Klick auf das Menüleistensymbol in den Mac-UI-Tests

Vorgänger: `docs/specs/fix-978-s3-wiederoeffnen-warten.md` (v4, Halteprobe, belegt). Analyse: `docs/context/fix-978-s5-kurzer-klick.md`.

## Approval

- [ ] Approved (Henning)

## Purpose

Das Menüleisten-Panel klappt im Pflicht-Check „Mac Gallery (macOS)“ gelegentlich direkt nach dem Öffnen wieder zu (#978). Die Halteprobe v4
(Lauf 45602877961) hat die Ursache belegt: `click()` von XCTest hält das Symbol unter Last 0,7 bis 0,9 s, und das Loslassen nach so langem
Halten schließt das Panel wie ein Systemmenü; `click(forDuration: 1.0)` schloss 20 von 20, `click(forDuration: 0.1)` 0 von 20. Schnitt v5
baut den Test auf den Weg eines Menschen um: überall, wo der Test das Symbol klickt, ein kurzer Klick von 0,1 s, ohne Wiederholung, hart rot.
Die v1- und v3-Klickwege entfallen. Der Auswerter paart zudem nicht mehr falsch (beim kurzen Klick gibt es im Panel-Protokoll kein Maus-hoch).

**Hat es bisher funktioniert?** Überwiegend ja (kurze echte Klicks blieben offen); der Fehler liegt im Prüfwerkzeug, die App ist unberührt.
Offen ist nur, ob der kurze Klick auch im Open-App-Arm trägt; das entscheidet der Nachweislauf (AC-7).

## Source

- **File:** `LooseEndsUITests/MacGalleryTests.swift`
- **Identifier:** `openPanel`, `testMenuBarReopensAfterReturnWithOneClick`, `testMenuBarReopensAfterOpenAppWithOneClick`, neuer Helfer für den kurzen Klick

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| XCUIAutomation (`XCUICoordinate.click(forDuration:thenDragTo:)`) | API | kurzer Klick auf dieselbe Koordinate mit einstellbarer Haltedauer |
| `LooseEnds/Mac/MenuBarCapture.swift` (Panel-Protokoll `MenuBarPanel`) | App | unverändert; einzige Quelle der Haltedauer, die XCTest-Klicks sieht |
| `LooseEndsUITests/MacUITestSupport.swift` | Test-Werkzeug | nur gelesen |
| CI-Job „Mac Gallery (macOS)“ in `.github/workflows/ci.yml` | CI | Pflicht-Check, Träger der drei grünen Läufe; unverändert |
| `.github/workflows/mac-panel-repeat.yml` | CI | Nachweislauf mit `iterationen=40` je Nutzerarm |
| `scripts/mac_panel_repeat_summary.py` | Skript | Auswerter: Haltedauer je Klick, neue Kategorie |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | ein Helfer für den kurzen Klick (Mitte des Symbols, `click(forDuration: 0.1, thenDragTo:)` auf dieselbe Koordinate) in `openPanel` und beiden Nutzerarmen; `frontmostRootClick` (v3), `waitForFrontmostSettled` (v1) und die Rückfall-Regel entfernt; Anhang `how` = `user: short click 0.1 s`; Kontrollarm und Halteprobe bleiben |
| `scripts/mac_panel_repeat_summary.py` | MODIFY | Maus-hoch nur im 3-s-Monitorfenster nach `key`; keins → Kategorie „kurz (kein Maus-hoch)“; neue `how`-Kategorie; Haltedauer je Klick im Bericht |
| `scripts/test_mac_reopen_settle.py` | MODIFY | v2/v3-Erwartungen ersetzt: genau ein kurzer Klick, kein `frontmostRootClick`/`waitForFrontmostSettled`, keine Wiederholung |
| `scripts/test_mac_panel_repeat_summary.py` | MODIFY | Tests für kurze Klicks ohne Maus-hoch und die neue `how`-Kategorie |
| `.github/workflows/mac-panel-repeat.yml` | MODIFY (nur falls nötig) | Kommentare; der Nachweislauf selbst braucht nur die Eingabe `iterationen=40` |

### Estimated Changes

- Files: 4 bis 5
- LoC: App-Code 0; Testcode und Skripte ca. +40/−150 (zählt nicht zum Limit)

Keine Änderung an `project.yml`, `Info.plist`, Entitlements, AppStorage-Schlüsseln oder Gate-Konfiguration. Kein Pfad der Geräteliste berührt.

## Implementation Details

Reihenfolge der Umsetzung:

1. **Auswerter zuerst (mit Test):** `key_to_mouse_up` sucht das Maus-hoch nur im 3-s-Monitorfenster nach dem `key`-Eintrag. Findet es keins,
   steht der Klick in der Kategorie „kurz (kein Maus-hoch)“ (beim kurzen Klick bleibt das Ereignis beim Statusobjekt; vorher wurde mit einem
   späteren Maus-hoch nach 11 bis 13 s fälschlich gepaart). `how_of`/`_HOW` kennen `user: short click 0.1 s` und die entfallenen
   Kategorien nicht mehr. Der Bericht nennt die Haltedauer je Klick (Sekunden oder die Kategorie „kurz“).
2. **Helfer:** ein Helfer im UI-Test berechnet die Mitte des Statussymbols und ruft `click(forDuration: 0.1, thenDragTo:)` auf dieselbe
   Koordinate. `openPanel` und beide Nutzerarme (`…AfterReturnWithOneClick`, `…AfterOpenAppWithOneClick`) benutzen ihn; der Anhang `how`
   lautet `user: short click 0.1 s`. Keine Wiederholung, jeder Fehlschlag ist hart rot.
3. **Entfernt:** `frontmostRootClick`, `waitForFrontmostSettled` und die Rückfall-Regel. Kontrollarm (`LE_PANEL_CONTROL_ARM`) und Halteprobe
   (`LE_PANEL_HOLD_PROBE`) bleiben, laufen nur per Umgebungsvariable und sonst als `XCTSkip`, nie im Pflichtjob.
4. **Skripttests nachziehen** (`test_mac_reopen_settle.py`, `test_mac_panel_repeat_summary.py`).
5. **Nachweislauf:** `mac-panel-repeat.yml` mit `iterationen=40`, beide Nutzerarme, Auswertung aus `MacPanelRepeatSummary`.
6. **DoD #978:** drei aufeinanderfolgende grüne Läufe des Jobs „Mac Gallery (macOS)“.

**Abbruchregel (vorab festgelegt):** Zeigt der Nachweislauf Panel-zu-Fälle im Open-App-Arm bei kurzer Haltedauer, ist die Ursache dort eine
andere. Dann Stopp, keine Schwellen- oder Wiederholungs-Flickerei, neue Analyse (Alternative A prüfen).

Die Haltedauer-Grenzen aus den Messungen (Erfolge ≤ 0,36 s, Fehlfälle ≥ 0,71 s, Systemverhalten ab etwa 0,7 s) werden nicht als Schwelle im
Test verwendet; der Test verlässt sich auf die kurze Synthese von 0,1 s (gemessen 0,036 bis 0,137 s) und der Bericht zeigt die Haltedauer.

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Lokal laufen die Skripttests und eine Übersetzungsprüfung.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN ein Panel-Protokoll mit `key` und einem Maus-hoch erst 12 s später WHEN der Auswerter paart THEN steht der Klick in der
  Kategorie „kurz (kein Maus-hoch)“ und nicht mit 12 s Haltedauer (vor der Änderung rot).
- [ ] Test 2: GIVEN ein Panel-Protokoll mit Maus-hoch 0,93 s nach `key` WHEN der Auswerter paart THEN steht 0,93 s als Haltedauer des Klicks im Bericht.
- [ ] Test 3: GIVEN Anhänge mit `how = user: short click 0.1 s` WHEN `how_of` kategorisiert THEN wird die neue Kategorie je Arm gezählt.
- [ ] Test 4: GIVEN der Quelltext von `MacGalleryTests.swift` WHEN `test_mac_reopen_settle.py` ihn prüft THEN gibt es den Helfer mit
  `click(forDuration: 0.1`, aber weder `frontmostRootClick` noch `waitForFrontmostSettled`, und `openPanel` sowie beide Nutzerarme benutzen den
  Helfer ohne Wiederholungsschleife.
- [ ] Test 5: GIVEN der Nachweislauf `mac-panel-repeat.yml` mit `iterationen=40` WHEN er endet THEN liegen je Nutzerarm 40 Klicks vor, 0 Panel-zu-Fälle,
  und die Haltedauern stehen im Bericht.

### Abnahme (Stufen)

1. **Tests:** Skripttests grün, UI-Test-Bundle übersetzt, Nachweislauf ausgewertet.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Belege: Zusammenfassung,
   ein geöffneter Klickanhang je Arm, beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` lokal läuft / Then sind alle Skripttests grün, darunter
  neue Tests, die einen Klick ohne Maus-hoch im 3-s-Fenster als „kurz (kein Maus-hoch)“ einordnen (kein späteres Maus-hoch wird gepaart), einen
  Klick mit Maus-hoch im Fenster mit seiner Haltedauer ausweisen und die neue `how`-Kategorie zählen. Belegt durch den Testlauf.
- **AC-2:** Given `scripts/test_mac_reopen_settle.py` / When er lokal läuft / Then ist er grün und verlangt: genau ein Helfer mit
  `click(forDuration: 0.1, thenDragTo:)` auf dieselbe Koordinate, benutzt von `openPanel` und beiden Nutzerarmen, kein `frontmostRootClick`, kein
  `waitForFrontmostSettled`, keine Rückfall-Regel, keine Wiederholung. Belegt durch den Testlauf.
- **AC-3:** Given `LooseEndsUITests/MacGalleryTests.swift` / When das UI-Test-Bundle per Build-Prüfung übersetzt wird / Then übersetzt es ohne
  Fehler, der Anhang `how` lautet `user: short click 0.1 s`, und Kontrollarm sowie Halteprobe bleiben mit ihren Umgebungsvariablen und `XCTSkip`
  erhalten. Belegt durch Prüfausgabe und Diff.
- **AC-4:** Given der Diff dieses Schnitts / When `git diff --stat` gegen den Ausgangsstand geprüft wird / Then ist App-Code (`LooseEnds/`)
  unverändert (0 LoC), ebenso der Job „Mac Gallery (macOS)“ in `ci.yml` und jede Gate-Konfiguration, und der Schnitt liegt bei höchstens 5
  Dateien. Belegt durch `git diff --stat`.
- **AC-5:** Given der Auswerter und ein ausgewerteter Lauf / When der Bericht `MacPanelRepeatSummary` gelesen wird / Then nennt er je Klick die
  Haltedauer (Sekunden oder „kurz (kein Maus-hoch)“) und zählt Nenner, Panel-zu und Rate je Arm. Belegt durch den geöffneten Bericht.
- **AC-6:** Given der Test im Pflichtjob / When der Klick das Panel nicht öffnet oder es direkt wieder zu ist / Then schlägt der Test hart fehl,
  ohne zweiten Versuch. Belegt durch Quelltext-Test (AC-2) und Diff.
- **AC-7:** Given der Nachweislauf `mac-panel-repeat.yml` mit `iterationen=40` / When er endet und ausgewertet wird / Then liegen je Nutzerarm
  (`ReturnWithOneClick`, `OpenAppWithOneClick`) 40 Klicks vor, 0 Panel-zu-Fälle, die Haltedauern stehen im Bericht, und Lauf-Kennung, Zähler
  und Rate stehen in einer Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/`. Tritt im Open-App-Arm ein Panel-zu-Fall bei kurzer
  Haltedauer auf, gilt die Abbruchregel: Stopp, neue Analyse mit Alternative A, AC-8 wird nicht angegangen. Belegt durch die Artefakte, geöffnet
  und beschrieben.
- **AC-8:** Given der Stand dieses Schnitts im Pull Request, vor dem Merge / When der Job „Mac Gallery (macOS)“ dreimal hintereinander auf
  demselben Commit läuft (Erstlauf plus zwei Wiederholungen) / Then sind alle drei grün (DoD von #978); die Lauf-Kennungen stehen in
  `docs/artifacts/fix-978-s5-kurzer-klick/` und im Issue #978. Belegt durch die CI-Läufe.

## Definition of Done

- [ ] AC-1 bis AC-8 belegt (Skripttests, Übersetzungsprüfung, Nachweislauf, drei grüne Galerie-Läufe)
- [ ] Beleg-Datei des Nachweislaufs unter `docs/artifacts/fix-978-s5-kurzer-klick/`, Ergebnis im Issue #978 kommentiert
- [ ] Issue #978 erst nach den drei grünen Läufen schließen, bis dahin `Refs #978`
- [ ] Kein Pfad der Geräteliste berührt.

## Alternativen

- **B kurzer Klick an allen Stellen, keine Wiederholung (gewählt):** stellt die Streuung an der Quelle ab (Haltedauer 0,036 bis 0,137 s,
  0 von 20 zu), kein App-Code, wenig Testcode.
- **A `statusItem.click()` behalten, Haltedauer per Accessibility aus der App lesen, über einer Schwelle von 0,4 bis 0,7 s genau einmal
  wiederholen:** duldet die Streuung statt sie abzustellen und braucht App-Code unter `--ui-testing` nur für einen Test. Nicht gewählt; Rückfall,
  falls der Open-App-Arm mit dem kurzen Klick scheitert (Abbruchregel).
- **C Produkt ändern (Panel bei Maus-hoch öffnen oder langes Halten nicht schließen lassen):** weicht vom Systemverhalten der Menüleiste ab,
  berührt die #862-Lösung (`dismiss()`), und es gibt keinen Nutzerbefund. Nicht gewählt.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Änderung am Testwerkzeug und an den Auswertungsskripten; App, Datenmodell und Plattformzuschnitt bleiben, keine
  bestehende ADR wird berührt oder gekippt.

## Changelog

- 2026-11-25: Initial spec created (v5, Empfehlung B aus der Analyse; löst die Wiederholungs-Idee aus Befund v4 durch den kurzen Klick ab).
