# Adversary Dialog — feat-950-titel-getippt
Spec: docs/specs/feat-950-titel-getippt.md
Datum: 2026-11-20 14:50

## Checkliste
- [x] **AC-1:** Eine mit Kanal `.keyboard` gespeicherte Aufgabe behält nach dem Erstlauf der Anreicherung ihren Regeltitel; das Modell schreibt keine Titel-Revision (Test 1).
- [x] **AC-2:** Bei „Erneut analysieren“ einer `.keyboard`-Aufgabe bleibt der Titel unverändert (Test 2).
- [x] **AC-3:** Eine `.keyboard`-Aufgabe endet nach der Anreicherung mit Status `active`, nie hängend in `unverified` (Test 3).
- [x] **AC-4:** Die vom Modell gelieferte Dauer und die Regelfelder werden bei `.keyboard`-Aufgaben weiter gesetzt (Test 4).
- [x] **AC-5:** Gegenprobe: Aufgaben mit Kanal `.app` und `.watch` werden weiter vom Modell verfeinert; das Verhalten für `.claude` bleibt unverändert (Tests 5 und 6).
- [x] **AC-6:** `CaptureChannel.keyboard` hat den Rohwert `"keyboard"`; ein unbekannter Rohwert liest sich als `.app` (Test 7).
- [x] **AC-7:** `forTyping(heard:)` macht aus `.app` ohne Gehörtes `.keyboard`, lässt `.app` mit Gehörtem und jeden anderen Kanal unverändert (Test 8).
- [x] **AC-8:** Im Erfassungssheet getippte Aufgaben und Aufgaben aus der Schreibzeile unter „Neu“ werden gespeichert und behalten im Simulator ihren eigenen Wortlaut als Titel (Tests 9 und 10).

## Dialog

### Runde 1
**Adversary:** Eigener Lauf (docs/artifacts/feat-950-titel-getippt/adversary-test-output.txt): KeyboardTitleTests 8 Tests, 0 Fehler; ClaudeTitleTests 6/6; Swift-Testing-Suites EnrichmentWriter, EnrichmentCoordinator, CaptureService bestanden (der XCTest-Zähler zeigt dort 0, weil Swift Testing; Suite-Zeilen "passed"). UI-Logs: testTypedCaptureKeepsItsWordingAsTitle und testTypedLineKeepsItsWordingAsTitle stehen als bestanden in ui-capture-proof.txt:131 und ui-drawer-proof.txt:27.
Ich verlange je AC Code-Beleg:

Confirmation:
  AC: AC-1
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:49
  Evidence: `keepsWording` sperrt den Titelzweig (Zeile 50) fuer `.keyboard`; Test 1 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-2
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:50
  Evidence: derselbe Writer laeuft bei reanalyze; Test 2 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:65
  Evidence: Zweig `keepsWording` hebt unprocessed/unverified auf active; Test 3 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: Shared/Enrichment/EnrichmentWriter.swift:50
  Evidence: nur der Titelblock ist gesperrt, andere Felder unveraendert (Diff beruehrt nur diesen Block); Test 4 gruen.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: Shared/Models/Enums.swift:24
  Evidence: keepsWording nur fuer .claude und .keyboard; .app/.watch weiter verfeinert (Test 5), Claude (Test 6, ClaudeTitleTests 6/6).
  Status: CONFIRMED

Confirmation:
  AC: AC-6
  Code reference: Shared/Models/Enums.swift:21
  Evidence: `case keyboard` String-Rohwert "keyboard"; TaskItem.capturedVia faellt bei unbekanntem Wert auf .app zurueck (Shared/Models/TaskItem.swift:130). CaseIterable-Nutzer: grep findet keine Stelle, die Kanaele aufzaehlt oder auf `.app` filtert; der Server/TranscriptCodec liest capturedVia nicht.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: Shared/Models/Enums.swift:28
  Evidence: forTyping nur .app && !heard -> .keyboard; Test 8 gruen. Share/Siri/Watch laufen nicht ueber CaptureView (ShareCaptureView, WatchCaptureView), Menueleiste uebergibt .app und bekommt die Regel mit.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Views/InboxDrawerView.swift:176
  Evidence: Schreibzeile speichert .keyboard; Sheet-Weg ueber CaptureView.swift:400; beide UI-Tests gruen (Logzeilen oben).
  Status: CONFIRMED

Randfall-Angriff: Der `heard`-Merker. `finish(saved:)` (CaptureView.swift:387-394) setzt bei vorhandenem onFinish `text = ""` zurueck, weil die View wiederverwendet wird (MenuBarExtra, Menueleisten-Panel, LooseEndsApp.swift:230). `heard` wird nirgends zurueckgesetzt.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEnds/Views/CaptureView.swift:392
  Description: `finish` leert `text`, aber nicht `heard`. Im Menueleisten-Panel (`CaptureView(channel: .app) { ... }`, LooseEnds/Mac/MenuBarCapture.swift:16) bleibt nach einer gesprochenen Erfassung oder einem gesprochenen, dann abgebrochenen Versuch `heard == true`, solange dieselbe View-Instanz lebt.
  Spec requirement: AC-8 / Purpose — getippte Aufgaben (auch Menueleisten-Panel, siehe Scope CaptureView) behalten ihren Titel.
  Conflict: Die naechste getippte Aufgabe im selben Panel wird `.app` statt `.keyboard`, das Modell darf ihren Titel verfeinern. Faellt sicher auf altes Verhalten zurueck, verletzt aber das Ziel; kein Test deckt Wiederverwendung ab.
  Remediation: in `finish` (vor `onFinish`) `heard = false` setzen; Unit-/UI-Test oder zumindest ein Test der reinen Zustandsregel.

**Implementierer:** (nicht anwesend; Antwort steht aus)

### Runde 2
**Adversary:** Zweite Pruefung auf Regressionen. grep ueber LooseEnds, Shared, LooseEndsShare, LooseEndsWatch, LooseEndsWidgets, server/src, Measurement: keine Stelle prueft `capturedVia == .app` oder zaehlt CaptureChannel auf ausser `keepsWording` (Shared/Models/Enums.swift:24) und EnrichmentWriter.swift:49. `Subtasks.add(via: .app)` unveraendert (Spec). iCloud-Mischbetrieb: aelterer Bau liest `.keyboard` als `.app` (TaskItem.swift:130), in der Spec als Restrisiko benannt. Der Dienst hat keinen Bezug zu `keyboard` (kein Treffer in cloudkit/server/src); Rohwert ist STRING, keine Schemaaenderung. Diktat via iOS-Tastatur zaehlt als getippt (Spec-Entscheidung). Leeres Transkript setzt `heard` nicht (CaptureView.swift:82), Sheet iPhone/iPad (ContentView.swift:111) ist pro Praesentation neu, dort kein Problem. Der QA-Hinweis: Swift-Testing-Suites zeigen im XCTest-Zaehler 0, Suite-Zeilen sind aber "passed".
Rest-Skepsis: Kein Test fuer F001. Alle anderen ACs durch Code und Lauf belegt.
**Implementierer:** (nicht anwesend)

### Runde 3
**Adversary:** Nachpruefung F001. Code reference: LooseEnds/Views/CaptureView.swift:393 setzt `heard = false` neben `text = ""` in `finish(saved:)`, direkt vor `onFinish(saved)`. Alle Ausgaenge des Panels, die den Zustand betreffen: `save()` (Zeile 401-402) ruft bei Erfolg `finish(saved: true)`; `cancel()` (auch `.cancelAction`/Escape, Zeile 178) ruft `finish(saved: false)`. Schlaegt Speichern fehl, bleibt der Zustand samt Text stehen (konsistent). Ausgaenge ohne finish: Klick ausserhalb/Panel-Schliessen und "Open Loose Ends" (MenuBarCapture.swift:30, 99) schliessen nur das Fenster; dort bleibt auch `text` erhalten, also bleibt `heard` zum Text passend, kein Widerspruch. `onDisappear` ruft nur `speech.stop()`. Das Sheet auf iPhone/iPad wird pro Praesentation neu erzeugt. Testbarkeit: Sprechen unter --ui-testing und im Simulator nicht moeglich, `heard` ist privater @State; der Fix ist eine Ein-Zeilen-Zuweisung auf dem einzigen Reset-Pfad, am Code belegt, aber ohne automatisierten Test. Rest-Randfall (kein Befund, Spec-Entscheidung): gesprochen, Text von Hand geleert, neu getippt zaehlt als gesprochen (CaptureView.swift:82). Lauf: KeyboardTitleTests 8/8, 0 failures (adversary-test-output.txt).
**Implementierer:** (nicht anwesend)

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Verdict

═══════════════════════════════════════
VERDICT: VERIFIED
═══════════════════════════════════════
F001 geschlossen: LooseEnds/Views/CaptureView.swift:393 setzt `heard = false` auf dem einzigen Reset-Pfad (finish), alle Speichern-/Abbrechen-Ausgaenge laufen darueber.
Tests: KeyboardTitleTests 8/8 passed, 0 failed, 0 übersprungen (frueher: ClaudeTitleTests 6/6, Writer/Coordinator/CaptureService-Suites bestanden)
Edge cases: All checked, none broken (kein automatisierter Test fuer den Reset, Sprache nicht simulierbar)
Regressions: None found
Checklist: 8/8 points proven

## Geprüfte Dateien

- sha256:7fd904d030a2b634d3c3eebd02270e940b703fc25e7443e30f1ac5fa59a13e7b  LooseEnds/Views/CaptureView.swift
- sha256:1a5d2daf928e1e781d676edfbc23034fb4306419db1c7fa9c5954b1b406a583a  LooseEnds/Views/InboxDrawerView.swift
- sha256:4e1d274d70b3c86b6e3ec0c53f1ac561a4d3a0c272b089dfbe4ed504c9c4a13a  Shared/Enrichment/EnrichmentWriter.swift
- sha256:009e430184f154e46ac71ca08b6669421c377746d5c761dfe63bdc9cc0b2a851  Shared/Models/Enums.swift

## Prüfbasis

- base: a3b2ea041b0bde230ec27310e0680ae9e6a9c05a
- blob:0cbc48fb010b1bfa6c121446e07ecd858a34ddfb  LooseEnds/Views/CaptureView.swift
- blob:201916205267eef6ccce3ca37bc497a9688e7c4e  LooseEnds/Views/InboxDrawerView.swift
- blob:6d87b4b4e1ff7fcb5b6e54468042fbe165b7964d  Shared/Enrichment/EnrichmentWriter.swift
- blob:7acdbab8040ca6a8d949302b32edb60e5cce939b  Shared/Models/Enums.swift
