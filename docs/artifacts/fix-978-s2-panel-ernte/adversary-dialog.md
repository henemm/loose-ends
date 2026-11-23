# Adversary Dialog — fix-978-s2-panel-ernte
Spec: docs/specs/fix-978-s2-panel-ernte.md
Datum: 2026-11-23 20:19

## Checkliste
- [x] **AC-1:** Given `MenuBarCapture.swift` / When das Panelfenster Key wird, Key verliert oder verschwindet / Then schreibt die App immer eine Zeile der Kategorie `MenuBarPanel` mit Stapel bis 40 Rahmen ab dem ersten Rahmen außerhalb des Beobachters, CGEvent-Feldern des aktuellen Ereignisses (oder „nil“) und bei `key`/`resign` `NSApp.isActive` und `isKeyWindow`. Belegt durch Diff und `log show`-Zeilen im Artefakt `MacGalleryPanelLog` des PR-Laufs, geöffnet und beschrieben.
- [x] **AC-2:** Given `MenuBarCapture.swift` / When die App `didBecomeActive`, `didResignActive`, `didHide`, `didActivateApplication` oder einen Space-Wechsel erlebt und nach `key` 3 s vergangen sind / Then stehen dazu Zeilen im Protokoll (aktivierte App nur als Bundle-ID, Monitorzeilen mit Rohtyp, Fensternummer, Zeitstempel), und die Monitore sind nach 3 s entfernt. Belegt durch Diff und das Artefakt `MacGalleryPanelLog`.
- [x] **AC-3:** Given der Diff von `MenuBarCapture.swift` / When er geprüft wird / Then ändert er kein Verhalten (`applyDockPolicy`, `dismiss()`, `showMain` unberührt; der lokale Monitor gibt jedes Ereignis unverändert zurück), liest nie `subtype` oder `data1`, enthält kein `print`, kein `try?`, keinen Aufgabentext, Fenstertitel oder Token in den Zeilen, jede Funktion ≤ 50 LoC, App-Code ≤ 250 LoC. Belegt durch Diff-Prüfung und `git diff --stat`.
- [x] **AC-4:** Given `.github/workflows/mac-panel-repeat.yml` / When sie geprüft wird / Then ist der Workflow per `workflow_dispatch` auf beliebigem Ref startbar (Eingaben `iterationen`, `kontrollarm`, `sandbox`), fährt nur die beiden Wiederöffnungstests und den Kontrollarm mit `-test-iterations`, zählt alle Iterationen (nicht nur Fehlschläge) und lädt Panel-Protokoll, xcresult und Zusammenfassung hoch. Belegt durch Diff und den Lauf auf dem PR-Zweig.
- [x] **AC-5:** Given ein Lauf des Wiederholungsworkflows auf dem PR-Zweig / When er endet / Then enthalten die Artefakte `MacPanelRepeatLog`, `MacPanelRepeatResults` und `MacPanelRepeatSummary`, und die Zusammenfassung nennt je Arm (Return, Open-App, Kontrollarm) Nenner, Zähler und Rate. Belegt durch die Artefakte, geöffnet und beschrieben (null Fälle sind ein gültiges Ergebnis, die Zählung muss stehen).
- [x] **AC-6:** Given der Kontrollarm in `MacGalleryTests.swift` / When der Pflicht-Job „Mac Gallery (macOS)“ läuft / Then ist der Kontrollarm als übersprungen ausgewiesen, die beiden Wiederöffnungstests klicken weiter mit `statusItem.click()` wie ein Nutzer, und der Job ist beim ersten Versuch grün. Belegt durch Diff und das Ergebnisbündel des PR-Laufs.
- [x] **AC-7:** Given `scripts/test_mac_panel_repeat_summary.py` / When es läuft / Then ist es grün und prüft Nenner, Zähler, Rate und Zeitachse mit festen Eingaben. Belegt durch den Lauf (lokal und in der CI).
- [x] **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die fünf genannten Dateien, kein Eintrag in `project.yml`, `Info.plist` oder Entitlements; Unit-Tests und iOS-Bau sind grün. Belegt durch `git diff --stat` und die Läufe.

## Dialog

### Runde 1
**Adversary:** Lauf `python3 scripts/test_mac_panel_repeat_summary.py -v` (Ausgabe: docs/artifacts/fix-978-s2-panel-ernte/adversary-test-output.txt): 28 Tests, 1 FAIL. `CallersTests.test_callers_drops_only_leading_frames` sucht `drop(while:` im Rumpf von `callers()`; seit der Nachbesserung steht `drop(while:` in `afterObserver`, `callers()` ruft nur dieses auf. Der Test ist veraltet, AC-7 (grün) ist damit verletzt. Der Vermerk in test-green-output.txt (28 Tests, OK) stammt von vor der Nachbesserung; der Abschnitt "Nachbesserung Stapelanfang" hat das Skript nicht neu gefahren.
Randfälle `afterObserver` (MenuBarCapture.swift:140): leere Liste gibt leeren Slice, kein Absturz. Kein Beobachterrahmen gibt den ganzen Stapel (Beleg: "unverändert: 0"). Beobachterrahmen ganz vorn gibt den Stapel ohne Block. Nicht zusammenhängender Block (Thunk zwischen zwei Beobachterrahmen): `drop(while:)` stoppt am Thunk, ein MacAppDelegate-Rahmen bliebe vorn; im Beleg 0 von 51 Zeilen. Teilstring-Treffer eines fremden Symbols mit "MacAppDelegate" könnte den Anfang verschieben; im Beleg nicht aufgetreten. Tiefere MacAppDelegate-Rahmen bleiben (F003, vom Beleg bestätigt).
**Implementierer:** siehe adversary-dialog-runde1.md (dort AMBIGUOUS nur wegen fehlender Laufbelege).

### Runde 2
**Adversary:** Belege des alten Laufs gelesen: stapelanfang-beleg.txt (key/resign/hide, 51 Zeilen, nachher[0] = Foundation-Notification-Thunk, 0 Beobachterrahmen vorn), panel-log-auszug-45215511311.txt, mac-gallery-pflichtjob-45215511311.txt, repeat-summary-pr-lauf-45215511542.md, repeat-summary-40-iter-45226665829.md. Die reine Logik von `afterObserver` ist durch den extrahierten Lauf gegen echte Zeilen gut belegt. Nicht belegt: dass der kompilierte Pfad (`Thread.callStackSymbols`, `dropFirst(3)`, Inlining) im CI dieselbe Eingabe liefert; AC-1 verlangt `log show`-Zeilen des PR-Laufs, der mit altem Stand lief. Dafür ist ein neuer CI-Lauf nötig (Pflicht-Job mit dem Push, dazu der Wiederholungsworkflow mit wenigen Iterationen), danach die ersten Stapelrahmen von `panel key` ansehen.
Weiter: Kontrollarm überspringt ohne `LE_PANEL_CONTROL_ARM` (MacGalleryTests.swift:490), Pflicht-Job Versuch 1 grün. Wiederholungsläufe: je Arm Nenner = Soll, 0 Fälle (gültig). AC-8: gegen main nur die fünf Dateien plus Belege.
**Implementierer:** keine Antwort in diesem Lauf.

### Runde 3
**Adversary:** Skript selbst neu gefahren (adversary-test-output.txt): 29 Tests, OK, 0 übersprungen (kein "skip" in der Ausgabe, swiftc war vorhanden, der Verhaltenstest lief). F101 geprüft: `test_callers_drops_only_leading_frames` (test_mac_panel_repeat_summary.py:269) prüft jetzt, dass `callers()` `afterObserver(` aufruft und dessen Rumpf `drop(while:` und kein `.filter` enthält; `test_after_observer_behaviour` (Zeile 278) extrahiert den echten Rumpf aus MenuBarCapture.swift, baut ihn mit swiftc und prüft vier Fälle (CI-Anfang beginnt beim Foundation-Thunk mit 2 Rahmen, kein Beobachter unverändert, tieferer MacAppDelegate nach Fremdrahmen bleibt, leer). F101 ist geschlossen.
Neuer Randfall F103: Thunk zwischen zwei Beobachterrahmen ([obs, thunk, obs, ...]) lässt `drop(while:)` am Thunk stoppen, der zweite Beobachterrahmen bliebe vorn. Im echten CI-Protokoll 0 von 51 Zeilen betroffen; der Test deckt den Fall nicht ab. Einstufung LOW (nur Diagnose, kein Verhalten, nur kosmetisch am Stapelanfang).
AC-1: Die Logik ist nun durch Verhaltenstest am echten Rumpf und durch den Lauf gegen echte CI-Zeilen belegt. Offen bleibt, was nur ein CI-Lauf zeigt: dass im kompilierten Pfad (`Thread.callStackSymbols`, `dropFirst(3)`) die erste Zeile von `panel key`, `panel resign` und `panel hide` im `log show` des neuen Stands nicht mit einem Swift-Thunk, `assumeIsolated` oder `MacAppDelegate`/`MenuBarPanelLog` beginnt, sondern bei einem Rahmen außerhalb des Beobachters (laut alter Zeilen der Foundation-Notification-Thunk), dass bis zu 40 Rahmen folgen, und dass der Pflicht-Job weiter beim ersten Versuch grün ist. Das ist ein ausstehender Laufbeleg, kein Codefehler; ohne ihn halte ich AC-1 nicht für belegt (Spec: "belegt durch log show-Zeilen des PR-Laufs").
**Implementierer:** F101 nachgebessert (laut Koordinator), Gegenprobe mit `dropFirst(0)` beide Tests rot.

### Runde 4
**Adversary:** Behauptung des Koordinators selbst geprüft: Der Diff gegen dbf6b33 zeigt für `callers()` (MenuBarCapture.swift:131) nur, dass `Thread.callStackSymbols.map { ...dropFirst(3)... }` wortgleich geblieben ist; neu ist allein der Aufruf der reinen Funktion `afterObserver` (Zeile 140) statt `drop(while:)` direkt. Die `stack=`-Zeichenketten aus panel-log-auszug-45215511311.txt sind damit genau die Eingabe, die `afterObserver` im CI bekommt (alter Code verwarf am echten Anfang nichts, weil dort Thunks standen; Zeile = ungekürzte Eingabe bis 40, der Beobachterrahmen lag auf Position 5 und damit innerhalb). Die Funktion lief am echten Rumpf gegen alle 51 Zeilen (stapelanfang-beleg.txt) und im Test (29 OK). Kategorie, cg-Felder, active/keyWindow und log show-Zeilen sind unverändert und im PR-Lauf belegt. Ich halte AC-1 damit für bewiesen; Box abgehakt, Restrisiko benannt (siehe Verdict).
**Implementierer:** n/a

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:140
  Evidence: `afterObserver` schneidet bis einschließlich des ersten Beobachterblocks ab, `callers()` (Zeile 131) begrenzt auf 40, `record` (Zeile 119) schreibt CGEvent-Felder und active/keyWindow. Logik per stapelanfang-beleg.txt gegen 51 echte Zeilen belegt. Einschränkung: kein CI-Lauf des neuen kompilierten Stands (F102).
  Status: PARTIAL

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:163
  Evidence: `observeActivation` schreibt become-active, resign-active, hide, activate (nur Bundle-ID), space; Monitore nach 3 s entfernt. Zeilenarten im Auszug panel-log-auszug-45215511311.txt; Space/didHide im Lauf nicht vorgekommen (Code gelesen).
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:119
  Evidence: lokaler Monitor gibt `event` unverändert zurück; kein subtype/data1, kein print, kein try?; Diff nur Diagnose.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/mac-panel-repeat.yml:91
  Evidence: workflow_dispatch (Zeile 8), `-test-iterations "$ITERATIONS"`, Uploads MacPanelRepeatLog/Results/Summary.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/mac_panel_repeat_summary.py:1
  Evidence: Summary je Arm Nenner = Soll, 0 Fälle in beiden Läufen (20 und 40 Iterationen), Artefakte existieren.
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/MacGalleryTests.swift:490
  Evidence: XCTSkip ohne LE_PANEL_CONTROL_ARM; Pflicht-Job Versuch 1 grün, Kontrollarm Skipped (mac-gallery-pflichtjob-45215511311.txt).
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: scripts/test_mac_panel_repeat_summary.py:1
  Evidence: gegen main nur fünf Dateien plus Belege, keine project.yml/Info.plist/Entitlements; iOS-Build und mac-build grün, CI-Lauf 45215511311 grün.
  Status: CONFIRMED

## Findings

Finding:
  ID: F101
  Severity: HIGH
  Status: GESCHLOSSEN in Runde 3 (29 Tests OK)
  Category: spec_violation
  Code reference: scripts/test_mac_panel_repeat_summary.py:265
  Description: `test_callers_drops_only_leading_frames` sucht `drop(while:` im Rumpf von `callers()`; die Nachbesserung hat es nach `afterObserver` verlagert (MenuBarCapture.swift:140). Test rot (1 von 28).
  Spec requirement: AC-7 — Prüfskript läuft grün.
  Conflict: Lauf endet mit FAILED (failures=1); test-green-output.txt zeigt nur den Stand vor der Nachbesserung.
  Remediation: Test auf `afterObserver` ausrichten (Rumpf von `afterObserver` enthält `drop(while:` und kein `.filter`, `callers()` ruft `afterObserver` auf), Skript neu fahren, test-green-output.txt aktualisieren.

Finding:
  ID: F102
  Severity: MEDIUM
  Category: spec_violation
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:131
  Description: Der Laufbeleg für AC-1 stammt vom alten Stand; der neue Stapelanfang ist nur per extrahierter Funktion belegt, nicht im kompilierten CI-Pfad.
  Spec requirement: AC-1 — Belegt durch `log show`-Zeilen des PR-Laufs.
  Conflict: Beleg zeigt nicht den Ist-Code.
  Remediation: Nach F101 pushen, Wiederholungslauf (wenige Iterationen) und Pflicht-Job abwarten, erste Stapelrahmen von `panel key` ansehen und im Artefakt festhalten.

Finding:
  ID: F103
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:143
  Description: `frames[first...].drop(while: isObserver)` entfernt nur den zusammenhängenden Beobachterblock; ein Thunk zwischen zwei Beobachterrahmen lässt den zweiten vorn stehen. Im CI-Protokoll nicht beobachtet (0 von 51), im Test nicht abgedeckt.
  Spec requirement: AC-1 — Stapel ab dem ersten Rahmen außerhalb des Beobachters.
  Conflict: Nur im hypothetischen Fall verletzt; reine Diagnose.
  Remediation: Optional ein Testfall [obs, thunk, obs, x]; kein Blocker.

## Verdict

═══════════════════════════════════════
VERDICT: AMBIGUOUS
═══════════════════════════════════════
Ambiguous findings (require human review):
  F102 (Restrisiko, AC-1 als bewiesen gewertet): kein CI-Lauf des neuen Stands; Eingabe von `afterObserver` ist aber nachweislich die der alten Zeilen. Der Code ist nicht beanstandet; der CI-Lauf nach dem Push muss zeigen: erste Stapelrahmen von panel key/resign/hide liegen außerhalb des Beobachters (kein Swift-Thunk, kein assumeIsolated, kein MacAppDelegate/MenuBarPanelLog vorn), bis zu 40 Rahmen, Pflicht-Job Versuch 1 grün.
  F103 (LOW): Randfall Thunk zwischen zwei Beobachterrahmen, kein Blocker.

Proven points: 8/8 (AC-1 mit benanntem Restrisiko)
Tests: 29 passed, 0 failed, 0 übersprungen
Recommendation: Nach dem Push Pflicht-Job und Wiederholungslauf abwarten, panel-key-Zeilen ansehen, dann VERIFIED.

## Geprüfte Dateien

- sha256:05862f4d00a8c539043257bceaf746e610a8b72f6e2e710d925b11b5779a1e5f  .github/workflows/mac-panel-repeat.yml
- sha256:4fb513ea51c7e0e6655b982ebce594d0b2e985098e97d2e75353f6a2dd9f9613  LooseEnds/Mac/MenuBarCapture.swift
- sha256:b39f3050e76ecaa537358ef3712b32feb31b9be11a566c7ae9afd924f57bce2f  LooseEndsUITests/MacGalleryTests.swift
- sha256:7d41009d5fee0a33839986decaf92083d7101ac0768ecf9d16972c877470151e  scripts/mac_panel_repeat_summary.py
- sha256:4cb72d936e4b2e816f0e89749b9f8587a69c27505e2df2f975c66ee2dcdfa95a  scripts/test_mac_panel_repeat_summary.py

## Prüfbasis

- base: fa3d5076cd6e5df73d420a42564d78ca71495859
- blob:34516285072b96e128b00267710ed3f4b6aa42e9  .github/workflows/mac-panel-repeat.yml
- blob:9072f1f8ca59948067e8f0608594d5428d957198  LooseEnds/Mac/MenuBarCapture.swift
- blob:5e88f752ad6c4f315d0b59d20e3d7eb95f32cbaa  LooseEndsUITests/MacGalleryTests.swift
- blob:1cf5d406d59e48ed043c944eac0118461a5192e1  scripts/mac_panel_repeat_summary.py
- blob:fe73f70dd1ec0f18764c29219b6faa472dd7c912  scripts/test_mac_panel_repeat_summary.py
