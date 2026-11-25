---
entity_id: fix-978-s3-wiederoeffnen-warten
type: bugfix
created: 2026-11-24
updated: 2026-11-25
status: draft
workflow: fix-978-s3-wiederoeffnen-warten
---

# Spec: #978 Schnitt 3 (v4) — Haltedauer-Probe für das Menüleisten-Panel (reine Messung, kein Testumbau)

Vorgänger v1–v3 widerlegt, siehe Kontextdatei `docs/context/fix-978-s3-wiederoeffnen-warten.md`.

## Approval

- [ ] Approved (Henning)

## Purpose

Das Menüleisten-Panel klappt im Pflicht-Check „Mac Gallery (macOS)“ gelegentlich direkt nach dem Öffnen wieder zu (#978). Die Versuche v1
(warten), v2 und v3 (andere Klickwurzel, keine Aktivierung) haben die Ursache nicht getroffen; der v3-Probelauf zeigte den Fall auch ohne
Aktivierung. Neue Arbeitshypothese: Das System schließt das Fenster, wenn zwischen Maus-runter und Maus-hoch zu viel Zeit liegt (aus drei
Fällen: 0,71 bis 0,93 s zu, höchstens 0,36 s offen). Schnitt 3 v4 baut deshalb nur eine Probe, die die Haltedauer gezielt einstellt
(1,0 s gegen 0,1 s) und das Ergebnis zählt. Ob die Hypothese stimmt, entscheidet der Lauf, nicht diese Spec; beide Ausgänge sind ein
Ergebnis der Messung. App-Code, Pflicht-Job und die drei Wiederöffnungstests bleiben unverändert.

**Hat es bisher funktioniert?** Überwiegend ja (231 von 231 kurze echte Klicks blieben offen; Fehlfälle selten, im Test an Klicks mit
langer Synthese). Ob Nutzer es sehen, ist nicht belegt. Befund: `docs/artifacts/fix-978-s3-wiederoeffnen-warten/befund-v3-probelauf.md`;
Analyse v4: Kontextdatei, Abschnitt „## Analysis“.

## Source

- **File:** `LooseEndsUITests/MacGalleryTests.swift`
- **Identifier:** `testHoldDurationProbe` (neu) und eine Monitor-Hilfe im selben File

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| XCUIAutomation (`XCUICoordinate.click(forDuration:thenDragTo:)`, `statusItems`) | API | Klick mit einstellbarer Haltedauer auf dieselbe Koordinate (`press(forDuration:)` gibt es auf macOS nicht) |
| AppKit im Testläufer (`NSEvent.addGlobalMonitorForEvents`) | API | misst die Haltedauer so, wie der Läufer sie sieht; ob er die Ereignisse überhaupt sieht, ist offen und wird berichtet |
| `LooseEndsUITests/MacUITestSupport.swift` (`macLaunch`, `macMainWindow`) | Test-Werkzeug | nur gelesen |
| `LooseEnds/Mac/MenuBarCapture.swift` | App | unverändert; liefert das Panel-Protokoll (key, Maus hoch, resign) |
| `.github/workflows/mac-panel-repeat.yml` | CI | neue Eingabe `halteprobe`; Träger des Probelaufs |
| `scripts/mac_panel_repeat_summary.py` | Skript | zählt die Halte-Arme, wertet das Panel-Protokoll je Klick aus |
| `scripts/test_mac_panel_repeat_summary.py` | Skripttest | Tests für die neuen Arme |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `testHoldDurationProbe` + Monitor-Hilfe, nur mit `LE_PANEL_HOLD_PROBE`, sonst `XCTSkip` |
| `.github/workflows/mac-panel-repeat.yml` | MODIFY | bool-Eingabe `halteprobe`: setzt die Variable, wählt nur diesen Test |
| `scripts/mac_panel_repeat_summary.py` | MODIFY | Arme `hold-1.0`/`hold-0.1` zählen, key → Maus hoch je Klick, Abgleich Monitor gegen Log |
| `scripts/test_mac_panel_repeat_summary.py` | MODIFY | Tests dazu (Testcode) |

Unverändert: App-Code, Job „Mac Gallery (macOS)“ in `ci.yml`, die drei Wiederöffnungstests, der Kontrollarm, jede Gate-Konfiguration.

### Estimated Changes

- Files: 4
- LoC: App-Code 0; Werkzeugcode ca. +45 (UI-Test) +10 (Workflow) +30 (Skript); dazu Testcode im Skripttest

Keine Änderung an `project.yml`, `Info.plist`, Entitlements oder AppStorage-Schlüsseln. Kein Pfad der Geräteliste berührt.

## Implementation Details

1. **Test `testHoldDurationProbe`:** läuft nur, wenn `LE_PANEL_HOLD_PROBE` gesetzt ist, sonst `XCTSkip` (wie der Kontrollarm mit
   `LE_PANEL_CONTROL_ARM`). Je Iteration: Panel zu (Ausgangszustand wie die Wiederöffnungstests), dann ein Klick auf die Mitte des
   Statussymbols über `XCUICoordinate.click(forDuration: d, thenDragTo: <dieselbe Koordinate>)`, mit d = 1,0 s und d = 0,1 s im Wechsel.
   Nach 3 s wird der Panel-Zustand gelesen (offen oder zu). Der Test selbst bleibt grün, solange er messen konnte; das Ergebnis steht im
   Anhang, nicht im Testausgang (es ist eine Messung, kein Wächter).
2. **Monitor:** ein globaler `NSEvent`-Monitor im Testläufer (`.leftMouseDown`, `.leftMouseUp`) hält je Klick die `timestamp`-Differenz.
   Sieht er nichts, steht im Anhang `monitor saw nothing`. Das wird berichtet, nicht vorausgesetzt.
3. **Anhang je Klick** (`mac-gallery-hold-<d>-<n>-click` o. ä.): `d: <Sekunden>`, `result: open|closed`, `monitor hold: <s>|monitor saw nothing`.
4. **Workflow:** Eingabe `halteprobe` (bool, Standard false) setzt `LE_PANEL_HOLD_PROBE=1` und wählt nur `testHoldDurationProbe`; ohne sie
   verhält sich der Workflow wie bisher. Artefakte wie bisher (`MacPanelRepeatLog`, `…Results`, `…Summary`).
5. **Auswertung:** `mac_panel_repeat_summary.py` zählt je Arm (`hold-1.0`, `hold-0.1`) Nenner, zu, offen und Rate; je Klick key → Maus hoch
   aus dem Panel-Protokoll (CGEvent-Zeitstempel); gleicht Monitor- und Log-Dauer ab (Übereinstimmung, Abweichung, `monitor saw nothing`).
6. **Entscheidungsregel (vorab festgelegt):** Lauf mit mindestens 20 Klicks je Arm. **Bestanden** = 1,0 s schließt in mindestens 95 % und
   0,1 s in 0 % → Hypothese belegt, Folgeschnitt v5 (Testumbau: Klickweg zurück auf `statusItem.click()`, Haltedauer messen, über der Schwelle
   genau eine Wiederholung mit Anhang, darunter hart rot). **Nicht bestanden** → Hypothese widerlegt, Rückfall D (siehe Alternativen).
   Ein durch das Zeitlimit #974 abgebrochener Lauf zählt nicht und wird neu gestartet. Kein Schritt braucht eine menschliche Sperre.

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Lokal laufen die Skripttests und eine Übersetzungsprüfung.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN Anhänge und Panel-Protokoll-Zeilen für Arm `hold-1.0` (z. B. 20 Klicks, 20 zu) und `hold-0.1` (20 Klicks, 0 zu) WHEN
  `scripts/test_mac_panel_repeat_summary.py` die Zusammenfassung prüft THEN stimmen Nenner, Zähler und Rate je Arm (vor der Änderung rot).
- [ ] Test 2: GIVEN ein Klick mit Log-Dauer 0,93 s und Monitor-Dauer 0,95 s sowie ein Klick mit `monitor saw nothing` WHEN die
  Zusammenfassung läuft THEN wird die Übereinstimmung beziehungsweise „Monitor sah nichts“ je Klick und in Summe ausgewiesen.
- [ ] Test 3: GIVEN der Test ohne `LE_PANEL_HOLD_PROBE` WHEN er in der CI-Auswahl läuft THEN ist er übersprungen und der Pflicht-Job
  unverändert grün.
- [ ] Test 4: GIVEN der Probelauf `mac-panel-repeat.yml` mit `halteprobe=true` und mindestens 20 Iterationen WHEN er endet THEN liegt je Arm
  eine Zusammenfassung mit mindestens 20 Klicks vor und die Entscheidungsregel aus Punkt 6 ist angewendet.

### Abnahme (Stufen)

1. **Tests:** Skripttests grün, UI-Test-Bundle übersetzt, Probelauf ausgewertet.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Belege: Zusammenfassung,
   ein geöffneter Klickanhang je Arm, beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` lokal läuft / Then sind alle Skripttests grün,
  darunter neue Tests für die Arme `hold-1.0`/`hold-0.1` (Nenner, zu, offen, Rate) und den Abgleich Monitor gegen Log, einschließlich des
  Falls `monitor saw nothing`. Belegt durch den Testlauf.
- **AC-2:** Given `LooseEndsUITests/MacGalleryTests.swift` / When das UI-Test-Bundle per swiftc- oder Build-Prüfung übersetzt wird / Then
  übersetzt es ohne Fehler, und `testHoldDurationProbe` klickt über `click(forDuration:thenDragTo:)` auf dieselbe Koordinate mit d = 1,0 s
  und 0,1 s im Wechsel und liest den Panel-Zustand nach 3 s. Belegt durch Prüfausgabe und Diff.
- **AC-3:** Given der Test ohne gesetzte Variable `LE_PANEL_HOLD_PROBE` / When er läuft / Then ist er mit `XCTSkip` übersprungen, und der
  Quelltext enthält den Schutz wie der Kontrollarm mit `LE_PANEL_CONTROL_ARM`. Belegt durch Diff und ein Ergebnisbündel oder einen
  Quelltext-Test.
- **AC-4:** Given der Anhang je Klick / When der Test ihn schreibt / Then nennt er d, das Ergebnis (offen oder zu) und die Haltedauer des
  globalen Monitors oder den Text `monitor saw nothing`. Belegt durch Diff und einen geöffneten Anhang aus dem Probelauf.
- **AC-5:** Given `.github/workflows/mac-panel-repeat.yml` / When der Diff geprüft wird / Then gibt es die bool-Eingabe `halteprobe`, die
  `LE_PANEL_HOLD_PROBE` setzt und nur diesen Test wählt, und ohne sie bleibt das bisherige Verhalten. Belegt durch Diff.
- **AC-6:** Given der Diff dieses Schnitts / When `git diff --stat` gegen den Ausgangsstand geprüft wird / Then ist App-Code (`LooseEnds/`)
  unverändert, ebenso der Job „Mac Gallery (macOS)“, die drei Wiederöffnungstests und jede Gate-Konfiguration, und der Schnitt liegt bei
  höchstens 5 Dateien und ±250 LoC App-Code. Belegt durch `git diff --stat`.
- **AC-7:** Given der CI-Probelauf `mac-panel-repeat.yml` mit `halteprobe=true` und mindestens 20 Klicks je Arm / When er endet und
  ausgewertet wird / Then ist das Ergebnis als Beleg festgehalten (Lauf-Kennung, Zähler und Rate je Arm, Entscheidung nach der vorab
  festgelegten Regel): bestanden (1,0 s schließt in mindestens 95 %, 0,1 s in 0 %) führt zu Folgeschnitt v5, sonst gilt die Hypothese als
  widerlegt, Rückfall D. Beide Ausgänge erfüllen dieses Kriterium, es verlangt die Auswertung, nicht ein bestimmtes Ergebnis. Belegt durch
  die Artefakte `MacPanelRepeatSummary`, geöffnet und beschrieben, und eine Beleg-Datei unter `docs/artifacts/fix-978-s3-wiederoeffnen-warten/`.
- **AC-8:** Given derselbe Probelauf / When die Zusammenfassung gelesen wird / Then steht ausdrücklich, ob der Monitor im Testläufer die
  Ereignisse sah (Anzahl Klicks mit Monitorwert gegen `monitor saw nothing`) und ob Monitor- und Log-Dauer übereinstimmen; beide Antworten
  werden berichtet, keine wird vorausgesetzt. Belegt durch Zusammenfassung und Beleg-Datei.

## Definition of Done

- [ ] AC-1 bis AC-8 belegt (Skripttests, Übersetzungsprüfung, Probelauf ausgewertet)
- [ ] Beleg-Datei des Probelaufs unter `docs/artifacts/fix-978-s3-wiederoeffnen-warten/`, Ergebnis im Issue #978 kommentiert
- [ ] Folgeschritt nach der Entscheidungsregel festgehalten (v5 oder Rückfall D), Issue bleibt offen (`Refs #978`)
- [ ] Kein Pfad der Geräteliste berührt.

## Alternativen

- **Probe zuerst, dann v5 (gewählt):** Ursache per Schalter belegt oder widerlegt, bevor der Test umgebaut wird (Lehre aus v1–v3); zwei
  kleine Schnitte.
- **v5 sofort (Messen plus eine Wiederholung):** ein Schnitt, aber Umbau auf unbewiesener Ursache. Verworfen.
- **D Erkennen „ging auf, vom Host im Klick wieder zu“ plus eine Wiederholung:** meldet nur, beseitigt die Ursache nicht; rund 50 LoC.
  Rückfall, falls die Probe die Hypothese widerlegt.
- **CGEvent mit festem kurzem Abstand:** am genauesten, aber das Posten ist auf dem gehosteten Läufer gesperrt. Verworfen.
- **E App-Eingriff (Panel gegen Schließen nach langem Halten sperren):** App-Code gegen Systemverhalten; kippt die S2-Festlegung „kein
  App-Eingriff“. Verworfen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Reine Messung im Testwerkzeug; Speicherort, Datenmodell, Plattformzuschnitt und Abgleich bleiben, keine bestehende ADR
  wird berührt oder gekippt.

## Changelog

- 2026-11-25: v4 ersetzt v3 (widerlegt durch Probelauf 45562032666); Haltedauer-Probe statt Klickwurzel-Umbau.
- 2026-11-24: v1–v3 (Warten, Wurzel `XCUIApplication`, Wurzel Menüleiste), siehe Kontextdatei.
