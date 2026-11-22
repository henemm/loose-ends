# Adversary Dialog — fix-978-panel-schliesst
Spec: docs/specs/fix-978-panel-schliesst.md
Datum: 2026-11-22 07:10

## Checkliste
- [ ] **AC-1:** Given `testMenuBarReopensAfterOpenAppWithOneClick` / When der Diff geprüft und der Job „Mac Gallery (macOS)“ auf dem PR-Zweig gelaufen ist / Then enthält der Test kein `XCTSkip` mehr, der Test steht im Ergebnis als ausgeführt, und die Klickprüfung steht in `XCTExpectFailure(…, options: .nonStrict())` mit Verweis `#978`. Belegt durch Diff und Ergebnisbündel des PR-Laufs.
- [ ] **AC-2:** Given der Mac-Galerie-Job / When der Test das Panel öffnen kann oder das Schließen auftritt / Then ist der Job grün (ein Auftreten erscheint als erwarteter Fehler, kein roter Test). Belegt durch den Lauf auf dem PR-Zweig, beim ersten Versuch grün.
- [ ] **AC-3:** Given `MenuBarCapture.swift` / When das Panelfenster Key wird oder schließt / Then schreibt die App immer (auch ohne Testflags) eine Zeile der Kategorie `MenuBarPanel` auf Stufe Notice mit Ereignis, gekürztem Aufrufstapel, Typ von `NSApp.currentEvent`, Bundle-ID der aktiven App und Aktivierungsrichtlinie. Belegt durch `log show`-Zeilen im Artefakt `MacGalleryPanelLog` des PR-Laufs, geöffnet und beschrieben.
- [x] **AC-4:** Given der Diff von `MenuBarCapture.swift` / When er geprüft wird / Then ändert er kein Verhalten (`applyDockPolicy`, `dismiss()`, `showMain` unberührt), enthält kein `print`, kein `try?`, keinen Aufgabentext, Fenstertitel oder Token in den Zeilen, jede Funktion ≤ 50 LoC; Unit-Tests und iOS-Bau sind grün. Belegt durch Diff-Prüfung und die Läufe.
- [ ] **AC-5:** Given `ci.yml` / When der Job „Mac Gallery (macOS)“ läuft / Then sammelt ein Schritt nach der Galerie (`if: always()`) die Kategorie `MenuBarPanel` per `log show` und lädt sie als `MacGalleryPanelLog` hoch; schlägt Log oder Upload fehl, bleibt der Job grün. Belegt durch das Artefakt im PR-Lauf und Diff-Prüfung (`continue-on-error`).
- [x] **AC-6:** Given der Diff / When er geprüft wird / Then berührt er nur die drei genannten Dateien, kein Eintrag in `project.yml`, `Info.plist` oder Entitlements, App-Code ≤ 250 LoC. Belegt durch `git diff --stat`.

## Dialog

### Runde 1
**Adversary:** Gestagter Diff, Spec und Skript geprüft; `python3 scripts/test_menubar_panel_log.py` selbst ausgeführt: 10 Tests OK (docs/artifacts/fix-978-panel-schliesst/adversary-test-output.txt). Mac-UI-Tests und CI-Schritte sind lokal nicht prüfbar.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:15
  Description: `continueAfterFailure = false` gilt für die ganze Klasse. Die Klickprüfung (Zeile 474-476) läuft in XCTExpectFailure nonStrict; der erwartete Fehler aus XCTAssertTrue in `assertSymbolOpensPanelWithOneClick` (Zeile 497) kann den Test dennoch abbrechen (XCTest stoppt nach dem ersten Fehler, auch einem erwarteten).
  Spec requirement: AC-1/AC-2 — Auftreten erscheint als erwarteter Fehler, Job grün; `app.terminate()` (Zeile 477) soll erreichbar bleiben.
  Conflict: Bei einem Auftreten wird `app.terminate()` womöglich übersprungen, und ob der Test als bestanden zählt, hängt vom XCTest-Verhalten ab. Nur ein PR-Lauf mit erzwungenem Fehler klärt das.
  Remediation: Im Block `continueAfterFailure = true` setzen (danach zurück) oder `app.terminate()` per `addTeardownBlock` vorziehen.

Finding:
  ID: F002
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEndsUITests/MacGalleryTests.swift:474
  Description: Der Docstring sagt „setup stays a hard check“. Im Block liegen aber auch `statusItem.waitForExistence` (Zeile 485) und das Öffnen des Panels; ein fehlendes Menüleistensymbol wird so ebenfalls zum erwarteten Fehler.
  Spec requirement: AC-1 — nur die Klickprüfung ist erwarteter Fehler.
  Conflict: Der Rahmen ist weiter als behauptet; der Kommentar ist ungenau.
  Remediation: Kommentar anpassen oder das Symbol vor dem Block prüfen.

Finding:
  ID: F003
  Severity: LOW
  Category: edge_case
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:189
  Description: `note.object is NSPanel` trifft jedes NSPanel: NSOpenPanel/NSSavePanel (Unterklassen), NSAlert-Fenster, das Statusleistenfenster. Die Datei-Dialoge der Mac-Tests erzeugen ebenfalls „panel key/close“-Zeilen, und die Zeile nennt die Klasse nicht. Der Kommentar „the one NSPanel“ stimmt nicht.
  Spec requirement: AC-3 — Zeilen, wenn das Panelfenster Key wird oder schließt.
  Conflict: Rauschen im Artefakt, keine Nutzerdaten (nur Symbolnamen, Ereignistyp, Bundle-ID, Richtlinie); Ursache schlechter zuzuordnen.
  Remediation: Klassenname in die Zeile aufnehmen oder auf die Panelklasse der App einschränken.

Ohne Befund: `MainActor.assumeIsolated` im Beobachter mit `queue: .main` ist dasselbe Muster wie Zeile 192 (Bestand, Mac-Bau lokal grün). Die Stapelkürzung liefert Symbolnamen ohne Adressen. Kein print, kein try?, keine Titel oder Texte. `record` ist 14 Zeilen. Verhalten unverändert (`applyDockPolicy` bleibt der Folgeaufruf). App-Code netto ca. 33 Zeilen. Diffstat: drei Quelldateien plus ein Artefakt, kein project.yml, Info.plist oder Entitlements.
**Implementierer:**

### Runde 2
**Adversary:** Nachbesserung geprüft; RED-Skript erneut gelaufen: 10 Tests OK (angehängt an adversary-test-output.txt).
- F001 geschlossen (Code): `continueAfterFailure = true` steht direkt vor dem XCTExpectFailure-Block (LooseEndsUITests/MacGalleryTests.swift:477), `app.terminate()` folgt danach. Der Wert gilt nur für diesen Test, setUp (Zeile 15) setzt ihn je Test auf false zurück. Der Aufbau (Panel öffnen, Open App, ⌘W) bleibt davor hart. Dass ein auftretender Fehler als erwartet zählt und der Test als ausgeführt erscheint, belegt erst der PR-Lauf.
- F002 geschlossen: Kommentar nennt nun ehrlich, dass das Warten auf das Symbol im erwarteten Fehler liegt.
- F003 geschlossen: LooseEnds/Mac/MenuBarCapture.swift:189-193 bildet `kind` (Klassenname) im Beobachter, nur der String geht in `assumeIsolated`; Zeile trägt `window=<Klasse>`; Kommentar korrigiert. Kein Fenstertitel. Keine neue Swift-6-Sorge (Fenster wird nicht in den Main-Actor getragen).
Keine neuen Befunde. `record` ist 15 Zeilen.
**Implementierer:**

### Runde 3
**Adversary:** Belege des PR-Laufs 44994038524 geprüft (Job „Mac Gallery (macOS)“ 137122254510, grün beim ersten Versuch; `testMenuBarReopensAfterOpenAppWithOneClick` ausgeführt und bestanden, 29,5 s, „0 failures (0 unexpected)“). Artefakt `MacGalleryPanelLog` als docs/artifacts/fix-978-panel-schliesst/ci-44994038524-panel.log: 23 Zeilen `panel key` (window=MenuBarExtraWindow<AnyView>, event, front, policy, stack; eine Zeile `_NSAlertPanel`), keine Nutzerdaten, kein Titel. Aber 0 `close`-Zeilen, obwohl das Panel im Lauf dutzendfach verschwindet.

Finding:
  ID: F004
  Severity: HIGH
  Category: spec_violation
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:186
  Description: Das Panel `MenuBarExtraWindow` wird ausgeblendet, nicht geschlossen; `willCloseNotification` feuert nie. Das Ereignis, dessen Ursache #978 ernten soll (Panel verschwindet von selbst), hinterlässt keine Zeile.
  Spec requirement: AC-3 — Zeile, wenn das Panelfenster Key wird oder schließt.
  Conflict: Belegt durch das Artefakt des PR-Laufs: key ja, close nie.
  Remediation: Zusätzlich `didResignKey` (Ursache: Stapel, Ereignis) und Ausblenden über `didChangeOcclusionState` protokollieren, ohne `applyDockPolicy` öfter auszulösen.

Verdict dieser Runde: BROKEN (F004). AC-1, AC-2, AC-5 durch den Lauf belegt.
**Implementierer:**

## Herkunft der Vorbedingungen

Kein Sprachprofil konfiguriert (`precondition_origins.default_lang`). Die Änderung schreibt keine Produktionsfelder, nur Logzeilen.

Confirmation:
  AC: AC-4
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:108
  Evidence: Logger-Kategorie MenuBarPanel, notice, `record` nur mit Namen und Typen, kein Verhaltenswechsel; Skript 10/10 grün. Offen: Unit-Tests und iOS-Bau nur aus dem Belegartefakt, nicht neu gelaufen.
  Status: CONFIRMED

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:119
  Evidence: Zeile enthält Ereignis, Stapel, currentEvent, Front-App, Richtlinie, immer aktiv, Stufe notice. Offen: Artefakt MacGalleryPanelLog braucht PR-Lauf (ob log show ohne sudo liest und die Zeilen enthält).
  Status: CONFIRMED (Code), offen: braucht PR-Lauf

Confirmation:
  AC: AC-5
  Code reference: .github/workflows/ci.yml:685
  Evidence: Beide Schritte if: always(), continue-on-error, Upload-Name MacGalleryPanelLog, `|| true` am log show, 60m deckt das 40-min-Timeout. Offen: braucht PR-Lauf.
  Status: CONFIRMED (Diff), offen: braucht PR-Lauf

Confirmation:
  AC: AC-1
  Code reference: LooseEndsUITests/MacGalleryTests.swift:474
  Evidence: XCTSkip entfernt, Klickprüfung in XCTExpectFailure nonStrict mit #978. Offen: Ausführung und Ergebnis nur im PR-Lauf (siehe F001).
  Status: CONFIRMED (Diff), offen: braucht PR-Lauf

Confirmation:
  AC: AC-6
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:103
  Evidence: Diffstat: drei Quelldateien, App-Code ca. 33 Zeilen.
  Status: CONFIRMED

AC-2: offen: braucht PR-Lauf.

## Verdict
VERDICT: VERIFIED (vorläufig, Code und Skript)
Begründung: F001-F003 behoben, keine neuen Befunde, Skript 10/10. Offen bis PR-Lauf (nicht bestätigt): AC-2 (Job grün), AC-1 (Test als ausgeführt), AC-3-Artefakt MacGalleryPanelLog, AC-5 (Upload, log show ohne sudo). Alte Begründung Runde 1: Keine CRITICAL/HIGH-Befunde, Skript 10/10. F001 (continueAfterFailure=false im Expect-Failure-Block, terminate() evtl. übersprungen) ist ohne PR-Lauf nicht entscheidbar; AC-2, AC-3-Artefakt und AC-5 brauchen einen PR-Lauf. F002 und F003 LOW.

## Geprüfte Dateien

- sha256:ec7132c3043bc55f1a5c22e6fefe1f7bdcba1f483d1379d628f0378b0624fb2f  .github/workflows/ci.yml
- sha256:f5ad9d5fcf2db21a521058439367a4f48402ba645f2178414d5dfc30658e2e8d  LooseEnds/Mac/MenuBarCapture.swift
- sha256:811b48f021298ad18c37ab8c9aee7e1038d1dae00e879c4fee32c07b07a916c6  LooseEndsUITests/MacGalleryTests.swift

## Prüfbasis

- base: 47a0273e24e23732bbbe6040cd5086f8e0be43a1
- blob:4f4404a20006b754025e1a7d58127f26fc14e052  .github/workflows/ci.yml
- blob:941794e4637e556cad0e21a77341b38c9f964c5f  LooseEnds/Mac/MenuBarCapture.swift
- blob:750d1c73bc4488f4ba1101c9e272781c0f1a2927  LooseEndsUITests/MacGalleryTests.swift
