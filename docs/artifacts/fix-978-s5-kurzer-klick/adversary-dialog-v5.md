# Adversary Dialog — fix-978-s5-kurzer-klick
Spec: docs/specs/fix-978-s5-kurzer-klick.md
Datum: 2026-11-25 15:15

## Checkliste
- [x] **AC-1:** Given `scripts/test_mac_panel_repeat_summary.py` / When `python3 -m unittest` lokal läuft / Then sind alle Skripttests grün, darunter neue Tests, die einen Klick ohne Maus-hoch im 3-s-Fenster als „kurz (kein Maus-hoch)“ einordnen (kein späteres Maus-hoch wird gepaart), einen Klick mit Maus-hoch im Fenster mit seiner Haltedauer ausweisen und die neue `how`-Kategorie zählen. Belegt durch den Testlauf.
- [x] **AC-2:** Given `scripts/test_mac_reopen_settle.py` / When er lokal läuft / Then ist er grün und verlangt: genau ein Helfer mit `click(forDuration: 0.1, thenDragTo:)` auf dieselbe Koordinate, benutzt von `openPanel` und beiden Nutzerarmen, kein `frontmostRootClick`, kein `waitForFrontmostSettled`, keine Rückfall-Regel, keine Wiederholung. Belegt durch den Testlauf.
- [x] **AC-3:** Given `LooseEndsUITests/MacGalleryTests.swift` / When das UI-Test-Bundle per Build-Prüfung übersetzt wird / Then übersetzt es ohne Fehler, der Anhang `how` lautet `user: short click 0.1 s`, und Kontrollarm sowie Halteprobe bleiben mit ihren Umgebungsvariablen und `XCTSkip` erhalten. Belegt durch Prüfausgabe und Diff.
- [x] **AC-4:** Given der Diff dieses Schnitts / When `git diff --stat` gegen den Ausgangsstand geprüft wird / Then ist App-Code (`LooseEnds/`) unverändert (0 LoC), ebenso der Job „Mac Gallery (macOS)“ in `ci.yml` und jede Gate-Konfiguration, und der Schnitt liegt bei höchstens 5 Dateien. Belegt durch `git diff --stat`.
- [x] **AC-5:** Given der Auswerter und ein ausgewerteter Lauf / When der Bericht `MacPanelRepeatSummary` gelesen wird / Then nennt er je Klick die Haltedauer (Sekunden oder „kurz (kein Maus-hoch)“) und zählt Nenner, Panel-zu und Rate je Arm. Belegt durch den geöffneten Bericht.
- [x] **AC-6:** Given der Test im Pflichtjob / When der Klick das Panel nicht öffnet oder es direkt wieder zu ist / Then schlägt der Test hart fehl, ohne zweiten Versuch. Belegt durch Quelltext-Test (AC-2) und Diff.
- [ ] **AC-7:** Given der Nachweislauf `mac-panel-repeat.yml` mit `iterationen=40` / When er endet und ausgewertet wird / Then liegen je Nutzerarm (`ReturnWithOneClick`, `OpenAppWithOneClick`) 40 Klicks vor, 0 Panel-zu-Fälle, die Haltedauern stehen im Bericht, und Lauf-Kennung, Zähler und Rate stehen in einer Beleg-Datei unter `docs/artifacts/fix-978-s5-kurzer-klick/`. Tritt im Open-App-Arm ein Panel-zu-Fall bei kurzer Haltedauer auf, gilt die Abbruchregel: Stopp, neue Analyse mit Alternative A, AC-8 wird nicht angegangen. Belegt durch die Artefakte, geöffnet und beschrieben.
- [ ] **AC-8:** Given der Stand dieses Schnitts im Pull Request, vor dem Merge / When der Job „Mac Gallery (macOS)“ dreimal hintereinander auf demselben Commit läuft (Erstlauf plus zwei Wiederholungen) / Then sind alle drei grün (DoD von #978); die Lauf-Kennungen stehen in `docs/artifacts/fix-978-s5-kurzer-klick/` und im Issue #978. Belegt durch die CI-Läufe.

## Dialog

### Runde 1
**Adversary:** Testlauf `python3 -m unittest scripts.test_mac_panel_repeat_summary scripts.test_mac_reopen_settle scripts.test_menubar_panel_log scripts.test_ci_xcode27 -v`: 102 Tests, OK, 0 übersprungen (adversary-test-output.txt). Grenzprobe `hold_of` direkt: Maus-hoch bei 2.999 s gepaart (2.999 s), bei genau 3.0 s -> „kurz (kein Maus-hoch)“ (Fenster halboffen, `<`); Maus-hoch vor key -> kurz; zwei key-Einträge -> erster key zählt (0.5 s); Maus-hoch ohne key -> None (Bericht „–“); nur type=1 -> kurz; key bei 14.9 s zählt, bei 15.0 s nicht. how_of: `control: XCUICoordinate click, no right to post events` -> xcuicoordinate (nicht short-click); `user: short click 0.1 s` -> short-click; alte v3-Texte -> unbekannt (gewollt). Swift: `shortClick` nimmt Mitte (0.5/0.5) und `click(forDuration: 0.1, thenDragTo: middle)`; keine while/for-Wiederholung um den Klick, kein XCTExpectFailure; Kontrollarm (LE_PANEL_CONTROL_ARM, XCTSkip) nutzt weiter den CGEvent-Weg `coordinateClick`, Halteprobe (LE_PANEL_HOLD_PROBE, XCTSkip) bleibt. `git diff --stat HEAD -- LooseEnds .github` leer; 2 Dateien uncommittet + 2 Skripttests im RED-Commit = 4 Dateien. build-check.txt: BUILD SUCCEEDED, 0 error.
**Implementierer:** –

### Runde 2
**Adversary:** Versuch, AC-6 zu brechen: assertSymbolOpensPanelWithOneClick klickt genau einmal, hartes XCTAssertTrue bei fehlendem/zugehendem Panel, der alte Fallback-XCTFail ist entfernt (Fallback existiert nicht mehr). Versuch AC-2/AC-5 zu brechen: Skripttests prüfen Helfer-Körper ohne Kommentare; Bericht hat Abschnitt „Haltedauer je Klick“ (`reopen_hold_report`) mit Arm, Ergebnis, Haltedauer, Nenner/zu/Rate je Arm bleiben aus dem bestehenden Zähler. Restrisiko: Bericht gegen ein echtes CI-Protokoll nicht prüfbar (AC-7 offen); ein Klick ohne key zeigt „–“ statt Kategorie (kosmetisch). AC-7 und AC-8 benötigen Commit/Push und CI; nicht erfunden, offen.
**Implementierer:** –

### Findings
Finding:
  ID: F001
  Severity: LOW
  Category: edge_case
  Code reference: scripts/mac_panel_repeat_summary.py:224
  Description: `hold_of` liefert None, wenn der Klick keine key-Zeile hat; der Bericht zeigt dann „–“ ohne Hinweis, dass das Panel nie key wurde.
  Spec requirement: AC-5 — je Klick Haltedauer oder „kurz (kein Maus-hoch)“
  Conflict: Bei nicht geöffnetem Panel (not open) ist „–“ sinnvoll, die Spalte „Ergebnis“ erklärt es; nur kosmetisch.
  Remediation: optional „kein key“ ausgeben.

### Confirmations
Confirmation:
  AC: AC-1
  Code reference: scripts/mac_panel_repeat_summary.py:212
  Evidence: key_to_mouse_up sucht Maus-hoch nur im 3-s-Fenster; Grenzprobe 3.0 s -> kurz; Tests ShortClickSummaryTests grün.
  Status: CONFIRMED
Confirmation:
  AC: AC-1
  Code reference: scripts/test_mac_panel_repeat_summary.py:630
  Evidence: ShortClickSummaryTests decken Test 1-3 und AC-5 ab, alle ok.
  Status: CONFIRMED
Confirmation:
  AC: AC-2
  Code reference: scripts/test_mac_reopen_settle.py:56
  Evidence: ShortClickSourceTests (9 Tests) grün: ein Helfer, openPanel und beide Arme, v1/v3 weg, keine Wiederholung.
  Status: CONFIRMED
Confirmation:
  AC: AC-3
  Code reference: LooseEndsUITests/MacGalleryTests.swift:609
  Evidence: shortClick liefert `user: short click 0.1 s`; Kontrollarm Z. 485 und Halteprobe Z. 508 hinter Env + XCTSkip; build-check.txt: BUILD SUCCEEDED.
  Status: CONFIRMED
Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/MacGalleryTests.swift:314
  Evidence: LooseEnds/ und .github unverändert (git diff --stat leer), insgesamt 4 Dateien.
  Status: CONFIRMED
Confirmation:
  AC: AC-5
  Code reference: scripts/mac_panel_repeat_summary.py:285
  Evidence: reopen_hold_report listet je Klick Haltedauer; Zähler je Arm unverändert.
  Status: CONFIRMED
Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/MacGalleryTests.swift:626
  Evidence: ein Klick, harte XCTAssert, keine Schleife/Fallback.
  Status: CONFIRMED

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  AC-7: Nachweislauf mac-panel-repeat iterationen=40 existiert noch nicht (nur nach Commit/Push in der CI möglich) - offen.
  AC-8: drei grüne Mac-Gallery-Läufe existieren noch nicht - offen.

Proven points: 6/8 (AC-1..AC-6)
Tests: 102 passed, 0 failed, 0 übersprungen
Finding F001 (LOW, kosmetisch)
Recommendation: AC-7/AC-8 nach Push in der CI nachweisen.

## Geprüfte Dateien

- sha256:7e56a6506539e5f00cf282e29b39356fcc827732b4ae1810d2275f9ec4aaa7c8  LooseEndsUITests/MacGalleryTests.swift
- sha256:25540f0acbc21471d1dba531c626cbf3a40d4210b9b4cf49c93cbc0cd744bca5  scripts/mac_panel_repeat_summary.py
- sha256:a0f071f0317fdd21be1e6815ba8d07c5ca47b611b15d275a4f56cb0a02711e13  scripts/test_mac_panel_repeat_summary.py
- sha256:77d1eb75eb67e7b5147bc101e1c97977072ce26d64083cce33f9c4b43997494b  scripts/test_mac_reopen_settle.py

## Prüfbasis

- base: 33a102b76c8c000e05549636f4c9010a0e9916be
- blob:3b051e98c7c266ece3c778afe38bc468b1f543ef  LooseEndsUITests/MacGalleryTests.swift
- blob:8d1d6baa38d97019c92b080858cf2b38868fcdf7  scripts/mac_panel_repeat_summary.py
- blob:8d07a19d9649947cc9e7aa32f3834b5ede4b3431  scripts/test_mac_panel_repeat_summary.py
- blob:3b17aa8ed037227953d5b29b4bef1dfdbd5e0410  scripts/test_mac_reopen_settle.py
