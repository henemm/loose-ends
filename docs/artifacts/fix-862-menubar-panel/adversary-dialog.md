# Adversary Dialog — fix-862-menubar-panel
Spec: docs/specs/fix-862-menubar-panel.md
Datum: 2026-11-21 07:45

## Checkliste
- [x] **AC-1:** Given ein frischer Start, das Panel über das Symbol geöffnet, Text getippt und Return gedrückt / When das Symbol genau einmal geklickt wird / Then ist das Panel innerhalb von 10 s da. Belegt durch Test 1, zuerst rot im CI-Lauf mit dem heutigen Code, dann grün.
- [ ] **AC-2:** Given ein frischer Start, „Open Loose Ends“ geklickt, Hauptfenster da und per ⌘W geschlossen / When das Symbol genau einmal geklickt wird / Then ist das Panel innerhalb von 10 s da. Belegt durch Test 2, zuerst rot, dann grün.
- [x] **AC-3:** Given `MenuBarCaptureView` / When der Diff geprüft wird / Then schließen Return und „Open Loose Ends“ das Panel über `@Environment(\.dismiss)` („Open Loose Ends“: erst `dismiss()`, dann `showMain`), `MacWindows.closeMenuBarPanel` ist entfernt und kein Aufrufer bleibt übrig. Belegt durch Diff-Prüfung und einen grünen Mac-Bau.
- [x] **AC-4:** Given `macOpenMainWindowIfNeeded` / When der Diff geprüft wird / Then enthält sie keinen zweiten Klick auf das Symbol und keine Wartezeit auf ein sich schließendes Panel mehr. Belegt durch Diff-Prüfung.
- [x] **AC-5:** Given der Mac-Galerie-Job / When er nach dem Fix läuft / Then sind `testPanelTypedGerman` und `testWindowFromMenuBarFitsScreen` beim ersten Versuch grün, ohne Wiederholung der CI. Belegt durch den Lauf.
- [ ] **AC-6:** Given der Job „Mac Gallery (macOS)“ / When er nach dem Fix in drei aufeinanderfolgenden CI-Läufen (verschiedene Pushes oder Neustarts ohne Codeänderung, jeweils erster Versuch) läuft / Then ist er jedes Mal grün (Galerie, Klick- und Tastatur-Tests). Belegt durch die Lauf-Nummern im Abschlussbericht.
- [x] **AC-7:** Given der Diff / When er geprüft wird / Then berührt er nur die drei genannten Dateien, kein `try?`, kein `print`, jede Funktion ≤ 50 LoC, kein Eintrag in `project.yml`, `Info.plist` oder Entitlements; alle Unit-Tests und der iOS-Bau sind grün.

## Dialog

### Runde 1
**Adversary:**
Geprüft (Diff gegen origin/main, Dateien gelesen, Belege geöffnet):

- AC-1 belegt, mit Vorbehalt F001: RED (`test-red-output.txt`, CI 44806231140, alter Code): beide neuen Tests rot "One click on the symbol opened no panel". GREEN (`adversary-test-output.txt`, Lauf 44877016605, Commit bb05d4d): `testMenuBarReopensAfterReturnWithOneClick` grün (20,7 s). Der Test wartet vor dem Klick auf das Verschwinden des Panels (`exists == false`, MacGalleryTests.swift:451-453) und klickt dann genau einmal (`assertSymbolOpensPanelWithOneClick`, Z. 478-493). Anhang: Panel offen, Feld leer (kein `value`, Done disabled), also frische Ansicht und kein altes Panel.
- AC-2 belegt: `testMenuBarReopensAfterOpenAppWithOneClick` rot, dann grün (26,2 s); ⌘W-Schließen wird abgewartet (Z. 469-470).
- AC-3 belegt: `LooseEnds/Mac/MenuBarCapture.swift:22` und `:33` rufen `dismiss()`; im Button steht `dismiss()` vor `MacWindows.showMain` (Z. 33-34). `closeMenuBarPanel` entfernt, Suche in LooseEnds, LooseEndsUITests, LooseEndsTests ohne Treffer. Grüner Mac-Bau: Lauf 44877016605, Job "Mac Gallery (macOS)" success, "Unit Tests (macOS destination)" success.
- AC-4 belegt: `LooseEndsUITests/MacUITestSupport.swift:48-53` hat einen Klick, dann `waitForExistence(10)`; Zweitklick und `macWait` auf schließendes Panel entfernt.
- AC-5 belegt: `testPanelTypedGerman` (40,8 s) und `testWindowFromMenuBarFitsScreen` (51,1 s) grün im Lauf 44877016605; "Executed 18 tests, with 0 failures". Die Protokolldatei ist gefiltert; "erster Versuch" ergibt sich nur aus dem Lauf selbst (Nachfrage 3).
- AC-6 OFFEN (kein Defekt): bisher ein grüner Lauf (44877016605), zwei weitere fehlen. Runde 2.
- AC-7 belegt bis auf: iOS-Bau von mir nicht neu gebaut, nur `test-green-output.txt` gelesen. Der Diff berührt unter LooseEnds und LooseEndsUITests genau drei Dateien (MenuBarCapture.swift, MacGalleryTests.swift, MacUITestSupport.swift); App-Code 10 geänderte Zeilen; kein `try?`/`print(` in MenuBarCapture.swift; keine Funktion nahe 50 LoC; nichts in project.yml/Info.plist/Entitlements. `test-green-output.txt`: 100 XCTest und 1215 Swift-Testing-Tests bestanden, 0 fehlgeschlagen; 3 von 6 Messstrecken (RawSentenceReportTests, SelfConsistencyReportTests, TextFormModelReportTests: Korpusdatei fehlt) und zwei Latenzschutz-Tests (de_DE nicht unterstützt) übersprungen, vorbestehend und nicht im Fix-Pfad.

Bohrfragen:
- Abbrechen: `CaptureView.finish(saved:false)` ruft `onFinish(false)` (CaptureView.swift:383-394), der Closure ruft `dismiss()` auch bei saved == false. Das entspricht dem alten Verhalten (`closeMenuBarPanel()` stand ebenfalls außerhalb von `if saved`). Kein Defekt.
- `dismiss` aufs falsche Fenster: `MenuBarCaptureView` ist Inhalt der MenuBarExtra-Szene; `dismiss` wirkt auf die präsentierende Szene dieses Inhalts, nicht aufs Hauptfenster. Test 2 belegt den AC-2-Weg (Hauptfenster erscheint nach "Open Loose Ends", ⌘W schließt es). `dismiss()` und `showMain` laufen direkt nacheinander; die Reihenfolge ist durch Test 2 belegt, nicht durch Code allein. Kein Defekt.
- 6,6 s bis zum offenen Panel (F001): beide Anhänge zeigen praktisch gleiche Werte (6,63 s und 6,65 s). Gleichheit auf 20 ms über zwei getrennte Prozesse spricht eher für Werkzeug-Latenz (`statusItem.click()` ist synchron und liegt im gemessenen Zeitraum, XCUITest wartet auf App-Ruhe) als für eine Entprellung im App-Code: im App-Code ist keine Verzögerung vorhanden (Diff komplett gelesen). Beweisen lässt es sich aus den vorhandenen Belegen nicht, weil das erste Öffnen über `openPanel` (MacGalleryTests.swift:312-316) keine Zeit anhängt.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:478
  Description: assertSymbolOpensPanelWithOneClick misst die Zeit von Klick bis Panel (6,6 s in beiden Läufen); das erste Öffnen in openPanel (Z. 312-316) wird nicht gemessen, es fehlt die Vergleichszahl.
  Spec requirement: AC-1/AC-2 — Panel innerhalb von 10 s nach genau einem Klick; AC-6 — drei grüne Läufe in Folge.
  Conflict: Ohne Vergleich bleibt offen, ob 6,6 s normale Werkzeug-Wartezeit oder verstecktes Verzögerungsverhalten ist; Reserve zur 10-s-Grenze nur 3,4 s.
  Remediation: Keine Codeänderung nötig. In Runde 2 die Zeiten der neuen Läufe auslesen und mit der ersten Öffnung vergleichen (Zeilenzeiten im Testlog). Nähert sich ein Wert 10 s, Test oder Analyse nachschärfen.

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:22
  Evidence: `dismiss()` statt `MacWindows.closeMenuBarPanel()` im Return-Weg; im "Open Loose Ends"-Button (Z. 33) vor `showMain`; `closeMenuBarPanel` entfernt, keine Aufrufer.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: LooseEndsUITests/MacUITestSupport.swift:48
  Evidence: Ein `statusItem.click()` gefolgt von `waitForExistence(timeout: 10)`; Zweitklick und Warten auf schließendes Panel gelöscht.
  Status: CONFIRMED

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:445
  Evidence: Test 1 RED im Lauf 44806231140, GREEN im Lauf 44877016605; wartet auf geschlossenes Panel, ein Klick, 10 s.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacGalleryTests.swift:462
  Evidence: Test 2 RED dann GREEN, ⌘W-Schließen abgewartet, ein Klick.
  Status: CONFIRMED

Nachfragen für Runde 2:
1. Zwei weitere Läufe des Jobs "Mac Gallery (macOS)" (jeweils erster Versuch, Lauf-Nummern): AC-6.
2. Klickdauer der beiden neuen Tests in den neuen Läufen; Vergleich mit dem ersten Öffnen (F001).
3. Wurde in einem der Läufe ein Test wiederholt (CI-Retry)? Dann zählt der Lauf nicht für AC-6.

**Implementierer:**
Zu F001 (Zeitachse aus `MacGallery.xcresult` des Laufs 44877016605, `xcresulttool get test-results activities`, Test `testMenuBarReopensAfterReturnWithOneClick`, Auszug in `ci-44877016605-reopen-return-timeline.txt`):
- Erstes Öffnen über `openPanel`, frischer Start: „Synthesize event“ 192,09 → „Wait for … to idle“ endet 197,53 (5,44 s), danach „menuBarOpenApp“ beim ersten Prüfen 198,58 vorhanden.
- Wiederöffnen nach Return (der Klick aus AC-1): „Synthesize event“ 203,15 → Idle-Ende 208,68 (5,53 s), „menuBarOpenApp“ beim ersten Prüfen 209,72 vorhanden.
- Die 6,6 s bestehen also aus XCUITests Warten auf App-Ruhe nach dem Klick (gleich lang wie beim allerersten Öffnen) plus dem ersten Abfrageintervall von ~1 s. Das 10-s-`waitForExistence` beginnt erst nach `click()`; das Panel war beim ersten Abfragen da, nach ~1 s von 10 s. Keine Verzögerung im App-Code, kein Rückfall.


### Runde 2
**Adversary:**
Nachgeprüft per `gh api` (gefiltert): Lauf 44877016605, Job "Mac Gallery (macOS)", Versuch 3 und Versuch 4 je `failure`, passend zu stand.md. Spec-Abschnitt "Known Limitations" gelesen (Z. 184-190), Diff der Testdatei gelesen: Z. 464 `throw XCTSkip("#978: ...")` als erste Anweisung des AC-2-Tests. App-Code `LooseEnds/Mac/MenuBarCapture.swift:22/33` unverändert gegenüber Runde 1 (`dismiss()`).

- AC-2: Ehrlich bewertet. Der Beleg ist ein Mal rot (44806231140), dann grün (Versuch 1) und in Versuch 2 sowie 11 Diagnoseläufen grün, aber in 2 von 4 Versuchen desselben Laufs rot, und der Test ist jetzt ausgesetzt. Das beweist: der alte Fehler "ein Klick öffnet kein Panel" ist behoben (Test 1, AC-1, stabil). Es beweist NICHT, dass der AC-2-Weg stabil ist: in den roten Versuchen öffnet sich das Panel und schließt sich binnen 5 s wieder, kein Panel nach 15,7 s. Das ist ein Schließen, keine Werkzeugverzögerung (F001 damit für die Klickdauer erledigt). Ob das ein Nutzerfehler ist oder nur Testumgebung (CI-Runner), ist ungeklärt. Weil der Pfad "Open Loose Ends" + ⌘W + Klick echte Bedienung ist, ist AC-2 nur teilweise belegt: AMBIGUOUS, nicht PROVEN.
- AC-6: Nicht erfüllt, nicht widerlegt. Auf dem Fix-Stand gibt es einen vollständig grünen Lauf (Versuch 1), im selben Lauf zwei Versuche mit rotem AC-2-Test und einen mit Jobgrenze (#974, Tastatur-Stufe). Auf dem neuen Stand (Skip) existiert noch kein Lauf. "Drei aufeinanderfolgende grüne Läufe, jeweils erster Versuch" ist erst in Phase 7 prüfbar. Mit Skip zählt der AC-2-Test nicht mit; das ist eine bewusste PO-Abweichung, kein Nachweis. Ein Lauf mit Skip ist "grün mit übersprungenem Test"; jede Zählung für AC-6 muss den Skip einzeln benennen.
- Zusatzrisiko: #974 (40-min-Jobgrenze der Tastatur-Stufe) kann AC-6 rot machen, ohne mit dem Fix zu tun zu haben. Phase 7 muss unterscheiden.
- Skip-Prüfung: die Anweisung steht vor `macLaunch`, kein halber Lauf; die Methode ist `throws`, kompiliert.

**Implementierer:**
(Aussage des Implementierers aus `docs/artifacts/fix-862-menubar-panel/stand.md`, vom Adversary gegengelesen; Versuch 3/4 rot per `gh` bestätigt.) Lauf 44877016605 (bb05d4d): Versuch 1 Mac Gallery komplett grün; Versuch 2 Galerie 18/18 und Klicktests 11/11 grün, Tastatur-Stufe nach 40 min Jobgrenze abgebrochen (#974); Versuch 3 und 4 nur `testMenuBarReopensAfterOpenAppWithOneClick` rot, sonst alles grün. Diagnosezweig (Draft-PR #975): volle MacGalleryTests 54/54, 72/72, 72/72 (inkl. Gegenprobe mit App-Code wie bb05d4d), AC-2-Test dort 11/11 grün; Hypothesen späte Aktivierung und verspätete Dock-Richtlinie mit Daten widerlegt, Ursache offen. PO-Entscheidung 2026-11-21 "Jetzt ausliefern": Rest als #978, Test per XCTSkip ausgesetzt, Spec dokumentiert unter Known Limitations. F001: in den roten Versuchen kein Panel nach 15,7 s, also Schließen. AC-6 ist erst nach dem Push per CI nachzuweisen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:33
  Description: Nach "Open Loose Ends" (dismiss() dann showMain) und ⌘W auf das Hauptfenster öffnet der Symbolklick das Panel in 2 von 4 Versuchen des Laufs 44877016605 nur kurz; es schließt sich binnen 5 s wieder (Ursache offen, #978).
  Spec requirement: AC-2 — nach genau einem Klick ist das Panel innerhalb von 10 s da.
  Conflict: Das Panel ist kurz da, aber der Weg ist nicht stabil; ein echter Nutzerfehler ist nicht ausgeschlossen. Der Test, der es belegt, ist ausgesetzt.
  Remediation: #978 verfolgen (Ursache finden, Skip entfernen). Im Abschlussbericht nennen; der PO hat das Restverhalten bewusst angenommen.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsUITests/MacGalleryTests.swift:464
  Description: Der AC-2-Test endet mit `throw XCTSkip(...)` vor dem ersten Schritt; er läuft nicht mehr.
  Spec requirement: AC-6 — Galerie, Klick- und Tastatur-Tests grün in drei Läufen in Folge; AC-2 — Test 2 belegt.
  Conflict: Die Abdeckung des AC-2-Weges fehlt in der CI; AC-6 kann nur "grün bei einem übersprungenen Test" werden. Der Skip ist in der Spec offen dokumentiert.
  Remediation: Skip mit #978 entfernen. In Phase 7 den Skip je Lauf einzeln benennen.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:478
  Description: Die Tastatur-Stufe des Jobs lief in Versuch 2 in die 40-min-Jobgrenze (#974), unabhängig vom Fix; kann AC-6 rot machen.
  Spec requirement: AC-6 — jedes Mal grün.
  Conflict: Ein rotes AC-6 kann aus #974 stammen, nicht aus dem Fix.
  Remediation: In Phase 7 die Ursache jedes roten Laufs benennen.

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:445
  Evidence: Test 1 rot (44806231140), grün in Versuch 1 und 2 und in den Diagnoseläufen; auch in den Versuchen 3 und 4 war nur der AC-2-Test rot. Der Fix wirkt am AC-1-Weg stabil.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:33
  Evidence: `dismiss()` vor `showMain`, `closeMenuBarPanel` entfernt, unverändert seit Runde 1.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: LooseEndsUITests/MacGalleryTests.swift:464
  Evidence: Die neue Skip-Zeile setzt den AC-2-Test aus: `throw XCTSkip("#978: ...")` als erste Anweisung, vor `macLaunch`; das Verhalten ist in der Spec unter Known Limitations (Z. 184-190) benannt und an #978 gebunden (PO 2026-11-21). Nur teilweise belegt: rot dann grün in Versuch 1, 2 von 4 Wiederholungen rot.
  Status: AMBIGUOUS

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

AMBIGUOUS

Bedingung: AC-2 ist nur teilweise belegt (rot dann grün, aber in 2 von 4 Versuchen des Fix-Laufs wieder rot; Test ausgesetzt, #978) und AC-6 ist offen (kein Lauf auf dem Stand mit Skip). Fix-Kern bewiesen: AC-1, AC-3, AC-4, AC-5, AC-7.
Findings: F002 (MEDIUM, seltenes Schließen im AC-2-Weg, #978), F003 (LOW, Skip), F004 (LOW, #974 Jobgrenze).
Phase 7: drei aufeinanderfolgende CI-Läufe (jeweils erster Versuch) des Jobs "Mac Gallery (macOS)" auf dem Stand mit Skip nachweisen, Lauf-Nummern nennen, den übersprungenen AC-2-Test je Lauf einzeln benennen, rote Läufe der Ursache nach (Fix, #974, #978) trennen.

## Geprüfte Dateien

- sha256:89485b028e72d4fb0b37f045a4d5d09752ec403421ed62ff2590b99937d99bb5  LooseEnds/Mac/MenuBarCapture.swift
- sha256:351c1669104ba19527ed9a0e9c76036fe826590b7fb816d3bf7f1c2c2865dd3e  LooseEndsUITests/MacGalleryTests.swift
- sha256:7a1ed27ee220a2d19016c52a29235e741633dd743aa35dc40b41bc75a6e56b3c  LooseEndsUITests/MacUITestSupport.swift

## Prüfbasis

- base: ec5707ab99acb0845f1a7beea1e4aea2ba638ce2
- blob:2f82202726776cb44d154164a84a2940e5ae2911  LooseEnds/Mac/MenuBarCapture.swift
- blob:76987d9d3d290ae497949ef8f70f7821a65053f9  LooseEndsUITests/MacGalleryTests.swift
- blob:f9aaf18a38ed1745d898f5c79f5207f1d7983141  LooseEndsUITests/MacUITestSupport.swift
