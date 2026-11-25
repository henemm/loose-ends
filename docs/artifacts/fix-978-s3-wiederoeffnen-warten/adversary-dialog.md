# Adversary Dialog — fix-978-s3-wiederoeffnen-warten
Spec: docs/specs/fix-978-s3-wiederoeffnen-warten.md
Datum: 2026-11-25 08:51

## Checkliste
- [x] **AC-1:** Given `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` lokal läuft / Then sind alle Skripttests grün, darunter neue Tests für die Arme `hold-1.0`/`hold-0.1` (Nenner, zu, offen, Rate) und den Abgleich Monitor gegen Log, einschließlich des Falls `monitor saw nothing`. Belegt durch den Testlauf.
- [x] **AC-2:** Given `LooseEndsUITests/MacGalleryTests.swift` / When das UI-Test-Bundle per swiftc- oder Build-Prüfung übersetzt wird / Then übersetzt es ohne Fehler, und `testHoldDurationProbe` klickt über `click(forDuration:thenDragTo:)` auf dieselbe Koordinate mit d = 1,0 s und 0,1 s im Wechsel und liest den Panel-Zustand nach 3 s. Belegt durch Prüfausgabe und Diff.
- [x] **AC-3:** Given der Test ohne gesetzte Variable `LE_PANEL_HOLD_PROBE` / When er läuft / Then ist er mit `XCTSkip` übersprungen, und der Quelltext enthält den Schutz wie der Kontrollarm mit `LE_PANEL_CONTROL_ARM`. Belegt durch Diff und ein Ergebnisbündel oder einen Quelltext-Test.
- [ ] **AC-4:** Given der Anhang je Klick / When der Test ihn schreibt / Then nennt er d, das Ergebnis (offen oder zu) und die Haltedauer des globalen Monitors oder den Text `monitor saw nothing`. Belegt durch Diff und einen geöffneten Anhang aus dem Probelauf.
- [x] **AC-5:** Given `.github/workflows/mac-panel-repeat.yml` / When der Diff geprüft wird / Then gibt es die bool-Eingabe `halteprobe`, die `LE_PANEL_HOLD_PROBE` setzt und nur diesen Test wählt, und ohne sie bleibt das bisherige Verhalten. Belegt durch Diff.
- [x] **AC-6:** Given der Diff dieses Schnitts / When `git diff --stat` gegen den Ausgangsstand geprüft wird / Then ist App-Code (`LooseEnds/`) unverändert, ebenso der Job „Mac Gallery (macOS)“, die drei Wiederöffnungstests und jede Gate-Konfiguration, und der Schnitt liegt bei höchstens 5 Dateien und ±250 LoC App-Code. Belegt durch `git diff --stat`.
- [ ] **AC-7:** Given der CI-Probelauf `mac-panel-repeat.yml` mit `halteprobe=true` und mindestens 20 Klicks je Arm / When er endet und ausgewertet wird / Then ist das Ergebnis als Beleg festgehalten (Lauf-Kennung, Zähler und Rate je Arm, Entscheidung nach der vorab festgelegten Regel): bestanden (1,0 s schließt in mindestens 95 %, 0,1 s in 0 %) führt zu Folgeschnitt v5, sonst gilt die Hypothese als widerlegt, Rückfall D. Beide Ausgänge erfüllen dieses Kriterium, es verlangt die Auswertung, nicht ein bestimmtes Ergebnis. Belegt durch die Artefakte `MacPanelRepeatSummary`, geöffnet und beschrieben, und eine Beleg-Datei unter `docs/artifacts/fix-978-s3-wiederoeffnen-warten/`.
- [ ] **AC-8:** Given derselbe Probelauf / When die Zusammenfassung gelesen wird / Then steht ausdrücklich, ob der Monitor im Testläufer die Ereignisse sah (Anzahl Klicks mit Monitorwert gegen `monitor saw nothing`) und ob Monitor- und Log-Dauer übereinstimmen; beide Antworten werden berichtet, keine wird vorausgesetzt. Belegt durch Zusammenfassung und Beleg-Datei.

## Dialog

### Runde 1
**Adversary:**

Tests: `python3 -m unittest scripts.test_mac_panel_repeat_summary scripts.test_mac_reopen_settle scripts.test_menubar_panel_log` = 76 passed, 0 failed, 0 übersprungen (Ausgabe: docs/artifacts/fix-978-s3-wiederoeffnen-warten/adversary-test-output.txt). Mac-UI-Tests nicht gestartet (Vorgabe).

Confirmation:
  AC: AC-1
  Code reference: scripts/test_mac_panel_repeat_summary.py:515
  Evidence: HoldProbeSummaryTests deckt Nenner/zu/offen/Rate je Arm, Monitor gegen Log, `monitor saw nothing`, Entscheidungsregel; 76 Tests grün. 19/20 = 0.95 >= 0.95 in Float wahr (geprüft), Grenze 95 % greift.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacGalleryTests.swift:537
  Evidence: `middle.click(forDuration: seconds, thenDragTo: middle)` auf dieselbe Koordinate, d aus [1.0, 0.1] im Wechsel (Zeile 509ff), `RunLoop.run(3 s)` dann Zustand. swiftc-Typecheck Exit 0 mit Gegenprobe (falscher Aufruf = 2 Fehler), also ist die API auf macOS verfügbar (mac-build-for-testing-summary.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/MacGalleryTests.swift:509
  Evidence: Erste Anweisung ist der Guard auf `LE_PANEL_HOLD_PROBE` mit `XCTSkip`; HoldProbeSourceTests (scripts/test_mac_panel_repeat_summary.py:608) prüft den Quelltext.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/mac-panel-repeat.yml:88
  Evidence: bool-Eingabe `halteprobe` (Standard false), setzt `TEST_RUNNER_LE_PANEL_HOLD_PROBE=1` und wählt nur `testHoldDurationProbe`; else-Zweig enthält exakt die drei bisherigen -only-testing-Optionen und den unveränderten Kontrollarm-Export. Bash-Array-Quoting `"${tests[@]}"` korrekt. Unter pull_request ergibt der Ausdruck `false`. Einzige Verhaltensänderung im Standardlauf: ein zusätzliches `hold_probe=false` in der Echo-/Summary-Zeile (harmlos).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: scripts/mac_panel_repeat_summary.py:224
  Evidence: `git diff --cached --name-only`: Workflow, MacGalleryTests.swift, Summary-Skript, zwei Artefakt-Dateien; kein `LooseEnds/`, kein ci.yml, kein Wiederöffnungstest geändert; App-Code 0 LoC. Entscheidungsregel exakt wie Spec Punkt 6 (n >= 20 je Arm, Rate >= 0.95, kurz 0 Fehler, sonst „zu wenig Klicks“ bzw. „nicht bestanden“).
  Status: CONFIRMED

Offen (kein Defekt, CI-Probelauf nötig): AC-4 (geöffneter Anhang), AC-7, AC-8.
Prüfung, ob der Lauf sie liefern KANN:
- Klickzahl: ein Test mit zwei holdClick je Iteration, `-test-iterations 20` ergibt 20 Klicks je Arm; Soll-Nenner wird per `--expected` geprüft, Abweichung wird ausgewiesen. Läuft in 120-min-Limit (ca. 1 min je Iteration).
- Anhangsname `mac-gallery-hold-<d>-<n>-click` passt zu `_HOLD_PATTERN` (xcresult-Suffix `_0_UUID` durch `(?:[_.]|$)` abgedeckt); Panel-Hierarchie-Anhang `mac-gallery-panel-hold-…` kollidiert nicht.
- key → Maus hoch: reale Logzeilen (probe-45562032666/MacPanelRepeatLog) haben `panel key …` und `monitor global|local type=2 …`; `parse_panel_log` bildet `kind="monitor global"`, `event=2`, `key_to_mouse_up` wertet `startswith("monitor")` und `event == 2`. Format passt.
- Monitor im Testläufer: Fehlen von Ereignissen blockiert nichts (`stop()` liefert nil, Anhang `monitor saw nothing`); Handler laufen während `RunLoop.run(3 s)`, weil XCUI-Aufruf den Main-Thread blockiert; Zeitstempel sind Ereigniszeiten, daher unkritisch.

Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:578
  Description: `HoldMonitor.stop()` gibt nil zurück, wenn nur `down` ohne `up` gesehen wurde; der Anhang schreibt dann `monitor saw nothing`.
  Spec requirement: AC-8 — ausdrücklich berichten, ob der Monitor die Ereignisse sah.
  Conflict: Teilweise Sicht (nur down) wird als „sah nichts“ gezählt und verfälscht „Monitor sah Ereignisse: X von N“.
  Remediation: Bei down ohne up `monitor saw down only` schreiben (und im Skript zählen) oder in der Doku festhalten.

Finding:
  ID: F002
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:537
  Description: `click(forDuration:thenDragTo:)` ist ein Drag mit Haltezeit; XCTest kann zusätzliche Drag-Dauer/-Ereignisse vor Maus hoch anhängen, die tatsächliche Haltedauer kann also über d liegen (besonders im 0,1-s-Arm).
  Spec requirement: AC-7 — Entscheidung nach Regel auf Basis von d = 1,0 s vs 0,1 s.
  Conflict: Die Arme sind nach Soll-d gezählt, nicht nach gemessener Dauer; ein 0,1-s-Arm mit realer Haltedauer > 0,5 s würde die Hypothese verfälschen. Die Messwerte (Monitor/Log-Spalten) liegen im Bericht, werden aber nicht in die Entscheidung einbezogen.
  Remediation: Bei der Auswertung (AC-7) Monitor-/Log-Dauer je Arm ansehen und im Beleg nennen; keine Codeänderung nötig.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: scripts/mac_panel_repeat_summary.py:203
  Description: Die Log-Dauer ist key → Maus hoch, die Monitor-Dauer Maus runter → hoch; `key` liegt nach Maus runter. Toleranz 0,1 s kann bei 0,1-s-Klicks „mismatch“ ergeben, obwohl beide Monitore dasselbe sehen.
  Spec requirement: AC-8 — ob Monitor- und Log-Dauer übereinstimmen.
  Conflict: Mögliche Schein-Abweichung; gemeldet wird aber beides in Zahlen je Klick, keine Fehlentscheidung.
  Remediation: In der Auswertung des Probelaufs die Differenz je Klick lesen statt nur die Summe.

Weitere Randfälle geprüft, kein Defekt: 0 Klicks (Entscheidung „zu wenig Klicks“, Rate „–“), Lauf mit Zeitlimit-Abbruch (Nenner < 20, „zu wenig Klicks“ bzw. Abweichungszeile), Rate 19/20 (95 % zählt als bestanden), Anhang ohne Monitorzeile (ValueError wie beim bestehenden `parse_click`), Standardlauf ohne halteprobe (Arme/Report unverändert, `hold_report` nur bei Halte-Armen; Test `test_reopen_report_has_no_hold_section`).
**Implementierer:**

### Runde 2
**Adversary:**
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

VERDICT: AMBIGUOUS

Ambiguous: AC-4 (geöffneter Anhang), AC-7 und AC-8 warten auf den CI-Probelauf (kein Defekt, nach Commit+Push zu liefern).
Proven points: 5/8 (AC-1, AC-2, AC-3, AC-5, AC-6)
Tests: 76 passed, 0 failed, 0 übersprungen
Findings: F001, F002, F003 (alle LOW, keine blockierend)

## Geprüfte Dateien

- sha256:ed5c8ec8df8aee70e2671f65198f8b8063643476918964c109f3f027d2f7368d  .github/workflows/mac-panel-repeat.yml
- sha256:a875664e09748c2e5fc269fb30c261112d6e041442eaaf5305be8a07307850f9  LooseEndsUITests/MacGalleryTests.swift
- sha256:c4bf3114d1da9734a3a70b1c32095ae4c2e461ab7f08a1b3f7c6b3c03e11e8f2  scripts/mac_panel_repeat_summary.py
- sha256:497e066214f18dfcca7707059d7c18169837870ca1c56426b402c4c93a92c5ae  scripts/test_mac_panel_repeat_summary.py

## Prüfbasis

- base: f0e7efdc365d72593727cbed636eddf51112b5a5
- blob:12707ef32accec989edaafdde24415626f4fcf65  .github/workflows/mac-panel-repeat.yml
- blob:5d5d733d523550437941d85254baf10878a93f37  LooseEndsUITests/MacGalleryTests.swift
- blob:a062fc0d8d843f6745ab9d0198d70739709c4bc0  scripts/mac_panel_repeat_summary.py
- blob:a2e5370deccd9351cf872e87c5653d33e6f432c4  scripts/test_mac_panel_repeat_summary.py

## Geprüfte Dateien

- sha256:ed5c8ec8df8aee70e2671f65198f8b8063643476918964c109f3f027d2f7368d  .github/workflows/mac-panel-repeat.yml
- sha256:a875664e09748c2e5fc269fb30c261112d6e041442eaaf5305be8a07307850f9  LooseEndsUITests/MacGalleryTests.swift
- sha256:c4bf3114d1da9734a3a70b1c32095ae4c2e461ab7f08a1b3f7c6b3c03e11e8f2  scripts/mac_panel_repeat_summary.py
- sha256:497e066214f18dfcca7707059d7c18169837870ca1c56426b402c4c93a92c5ae  scripts/test_mac_panel_repeat_summary.py

## Prüfbasis

- base: f0e7efdc365d72593727cbed636eddf51112b5a5
- blob:12707ef32accec989edaafdde24415626f4fcf65  .github/workflows/mac-panel-repeat.yml
- blob:5d5d733d523550437941d85254baf10878a93f37  LooseEndsUITests/MacGalleryTests.swift
- blob:a062fc0d8d843f6745ab9d0198d70739709c4bc0  scripts/mac_panel_repeat_summary.py
- blob:a2e5370deccd9351cf872e87c5653d33e6f432c4  scripts/test_mac_panel_repeat_summary.py
