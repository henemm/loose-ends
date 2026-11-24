# Adversary Dialog — fix-978-s2-panel-ernte
Spec: docs/specs/fix-978-s2-panel-ernte.md
Datum: 2026-11-23 16:23

## Checkliste
- [ ] **AC-1:** Given `MenuBarCapture.swift` / When das Panelfenster Key wird, Key verliert oder verschwindet / Then schreibt die App immer eine Zeile der Kategorie `MenuBarPanel` mit Stapel bis 40 Rahmen ab dem ersten Rahmen außerhalb des Beobachters, CGEvent-Feldern des aktuellen Ereignisses (oder „nil“) und bei `key`/`resign` `NSApp.isActive` und `isKeyWindow`. Belegt durch Diff und `log show`-Zeilen im Artefakt `MacGalleryPanelLog` des PR-Laufs, geöffnet und beschrieben.
- [ ] **AC-2:** Given `MenuBarCapture.swift` / When die App `didBecomeActive`, `didResignActive`, `didHide`, `didActivateApplication` oder einen Space-Wechsel erlebt und nach `key` 3 s vergangen sind / Then stehen dazu Zeilen im Protokoll (aktivierte App nur als Bundle-ID, Monitorzeilen mit Rohtyp, Fensternummer, Zeitstempel), und die Monitore sind nach 3 s entfernt. Belegt durch Diff und das Artefakt `MacGalleryPanelLog`.
- [x] **AC-3:** Given der Diff von `MenuBarCapture.swift` / When er geprüft wird / Then ändert er kein Verhalten (`applyDockPolicy`, `dismiss()`, `showMain` unberührt; der lokale Monitor gibt jedes Ereignis unverändert zurück), liest nie `subtype` oder `data1`, enthält kein `print`, kein `try?`, keinen Aufgabentext, Fenstertitel oder Token in den Zeilen, jede Funktion ≤ 50 LoC, App-Code ≤ 250 LoC. Belegt durch Diff-Prüfung und `git diff --stat`.
- [x] **AC-4:** Given `.github/workflows/mac-panel-repeat.yml` / When sie geprüft wird / Then ist der Workflow per `workflow_dispatch` auf beliebigem Ref startbar (Eingaben `iterationen`, `kontrollarm`, `sandbox`), fährt nur die beiden Wiederöffnungstests und den Kontrollarm mit `-test-iterations`, zählt alle Iterationen (nicht nur Fehlschläge) und lädt Panel-Protokoll, xcresult und Zusammenfassung hoch. Belegt durch Diff und den Lauf auf dem PR-Zweig.
- [ ] **AC-5:** Given ein Lauf des Wiederholungsworkflows auf dem PR-Zweig / When er endet / Then enthalten die Artefakte `MacPanelRepeatLog`, `MacPanelRepeatResults` und `MacPanelRepeatSummary`, und die Zusammenfassung nennt je Arm (Return, Open-App, Kontrollarm) Nenner, Zähler und Rate. Belegt durch die Artefakte, geöffnet und beschrieben (null Fälle sind ein gültiges Ergebnis, die Zählung muss stehen).
- [ ] **AC-6:** Given der Kontrollarm in `MacGalleryTests.swift` / When der Pflicht-Job „Mac Gallery (macOS)“ läuft / Then ist der Kontrollarm als übersprungen ausgewiesen, die beiden Wiederöffnungstests klicken weiter mit `statusItem.click()` wie ein Nutzer, und der Job ist beim ersten Versuch grün. Belegt durch Diff und das Ergebnisbündel des PR-Laufs.
- [x] **AC-7:** Given `scripts/test_mac_panel_repeat_summary.py` / When es läuft / Then ist es grün und prüft Nenner, Zähler, Rate und Zeitachse mit festen Eingaben. Belegt durch den Lauf (lokal und in der CI).
- [x] **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die fünf genannten Dateien, kein Eintrag in `project.yml`, `Info.plist` oder Entitlements; Unit-Tests und iOS-Bau sind grün. Belegt durch `git diff --stat` und die Läufe.

## Dialog

### Runde 1
**Adversary:** Gestagten Diff (Basis origin/main), Spec und Vorgänger-Protokoll gelesen. `python3 scripts/test_mac_panel_repeat_summary.py -v` selbst ausgeführt: 19 Tests OK (docs/artifacts/fix-978-s2-panel-ernte/adversary-test-output.txt). Mac-UI-Tests, Swift-Mac-Bau und CI-Schritte sind lokal nicht ausführbar; AC-1/2/5/6 sind nur im Code bestätigt, Laufbelege offen: braucht PR-Lauf.

Finding:
  ID: F001
  Severity: MEDIUM
  Category: edge_case
  Code reference: scripts/mac_panel_repeat_summary.py:45
  Description: `clicks()` zählt jeden Klickanhang aus `manifest.json`. Ob `xcresulttool export attachments` bei `-test-iterations` alle Wiederholungen listet (Mehrfacheinträge je Test) oder nur eine, ist nicht belegt. Die Zusammenfassung kennt die erwartete Zahl (Iterationen je Test) nicht und prüft den Nenner gegen nichts.
  Spec requirement: AC-5 — je Arm Nenner, Zähler, Rate; Nenner = alle Wiederöffnungen.
  Conflict: Fehlen Iterationen im Manifest, ist der Nenner zu klein und die Rate zu hoch, ohne dass es auffällt. Das Risiko ist durch den ersten PR-Lauf prüfbar (Nenner je Arm muss 20 sein).
  Remediation: `--expected N` in das Skript, Zusammenfassung warnt bei n != N je Arm; mindestens im ersten Lauf von Hand gegen 20 prüfen.

Finding:
  ID: F002
  Severity: MEDIUM
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:489
  Description: Der Kontrollarm hat weder `XCTExpectFailure` noch `continueAfterFailure = true`; ein Fehlschlag macht den Test rot und lässt `app.terminate()` aus. Dasselbe gilt für den unveränderten Return-Test (Zeile 456). Der Run-Schritt des Workflows (`set -o pipefail`) wird bei jedem Fall rot, der Job damit auch; Uploads laufen wegen `if: always()` trotzdem.
  Spec requirement: AC-4/AC-5 — alle Iterationen laufen, Zählung steht; die Spec schreibt für den Kontrollarm kein Ergebnis-Verhalten vor.
  Conflict: Spec-konform (Zähler kommt aus dem Anhang, nicht aus dem Testergebnis), aber ein Lauf mit Fall ist rot, und eine nicht beendete App kann die Folge-Iteration stören (`macLaunch` startet neu, Wirkung unbelegt). Die Prüfung auf dem PR-Zweig ist kein Pflicht-Check.
  Remediation: Kontrollarm wie den Open-App-Test mit nonStrict-Erwartung und `continueAfterFailure = true` fahren, oder das Ergebnis des Run-Schritts bewusst als Information behandeln. Entscheidung Tech Lead, kein Blocker.

Finding:
  ID: F003
  Severity: LOW
  Category: spec_violation
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:132
  Description: `callers()` filtert alle Rahmen mit `MenuBarPanelLog` oder `MacAppDelegate` aus dem gesamten Stapel, nicht nur die führenden bis zum ersten fremden Rahmen.
  Spec requirement: AC-1 — Stapel bis 40 Rahmen ab dem ersten Rahmen außerhalb des Beobachters.
  Conflict: Liegt ein Rahmen von `MacAppDelegate` tiefer im Stapel (Delegate-Aufruf als Auslöser), fehlt er und verdeckt die Ursache.
  Remediation: `drop(while:)` statt `filter`.

Finding:
  ID: F004
  Severity: LOW
  Category: edge_case
  Code reference: LooseEndsUITests/MacGalleryTests.swift:510
  Description: Fällt `coordinateClick` auf `XCUICoordinate.click()` zurück, steht das nur im Anhang (`how: control: XCUICoordinate fallback`); `mac_panel_repeat_summary.py` zählt das nicht.
  Spec requirement: Known Limitations — der Fallback steht im Befund.
  Conflict: Die Rate des Kontrollarms ist dann nicht als Fallback erkennbar, ohne Anhänge zu öffnen; die Aussage über das Prüfwerkzeug würde unbemerkt verwässert.
  Remediation: Zähler „Fallback“ je Arm in der Zusammenfassung (Zeile `how:` im Anhang).

Ohne Befund, mit Beleg:
- Verhalten (AC-3): `applyDockPolicy` (MenuBarCapture.swift:86) und `showMain` (92) unverändert, `dismiss()` nicht im Diff; der lokale Monitor gibt `event` unverändert zurück (189); Beobachter schreiben nur Logger-Zeilen. Suche nach subtype, data1, print und try? im Code: nur der Kommentar zu `subtype`/`data1` (Zeile 106). Zeilen tragen nur Klassenname, Rohtypen, Fensternummer, PIDs, Zeitstempel, Bundle-ID; kein Titel, kein Text. Funktionsgrößen: record 12, callers 6, observeActivation 25, startMonitors 21 Zeilen (alle ≤ 50); App-Code netto ca. +107 Zeilen (121 ins, 14 del), Grenze 250.
- Monitor-Lebensdauer (AC-2): `startMonitors` ruft zuerst `stopMonitors` (höchstens ein Paar); `monitorRound` verhindert, dass ein alter 3-s-Timer ein neueres Paar entfernt (Zeile 198); Entfernen per `NSEvent.removeMonitor`. Bei hide/close enden Monitore nicht früher, aber spätestens nach 3 s: begrenzt.
- Swift 6: Monitor-Closures rufen nur `nonisolated` `logMonitored`; Timer und Beobachter laufen über `MainActor.assumeIsolated` mit `queue: .main`; `panel.isKeyWindow` wird im `assumeIsolated`-Block gelesen (Zeile 299). Dass `panel` (nicht Sendable) in den Block getragen wird, statt nur eines Strings wie im Vorgänger, kann der Mac-Bau anders bewerten: offen: braucht PR-Lauf.
- AC-4: `workflow_dispatch` mit `iterationen`, `kontrollarm`, `sandbox`; `pull_request` nur `paths: mac-panel-repeat.yml`; nur drei `-only-testing` (88-90); `-test-iterations` mit der Iterationszahl (91); `log show --start` mit der Startzeit des Jobs (100); Log-, Export- und drei Upload-Schritte `if: always()` plus `continue-on-error`; `timeout-minutes: 120` (34). Eingaben gehen nur über `env`, nie inline in `run:`: keine Shell-Injection (ein ungültiger Wert für `iterationen` scheitert höchstens in xcodebuild; dispatchen können nur Schreibberechtigte). `TEST_RUNNER_LE_PANEL_CONTROL_ARM` wird nur bei `CONTROL_ARM=true` exportiert (81); ohne sie springt der Test mit `XCTSkip` (491). Beim `pull_request` ist `inputs` leer, die Vorgaben 20/an/aus greifen korrekt.
- AC-6 (Code): Kontrollarm geschützt durch `XCTSkip` (491); Return- und Open-App-Test klicken weiter mit `statusItem.click()` (Default-Zweig in `assertSymbolOpensPanelWithOneClick`), `XCTExpectFailure` im Open-App-Test (478) unverändert.
- Skript (AC-7): Kontrollarm-Label steht im Regex vor dem Return-Label (Zeile 20), `reopen-return-control` zählt also nicht als Return; Zeitzone UTC durch `TZ=UTC` im Workflow plus Offset-Parsing. 19 Tests grün.
- AC-8: Diff gegenüber origin/main berührt `MenuBarCapture.swift`, `MacGalleryTests.swift`, `mac-panel-repeat.yml`, `mac_panel_repeat_summary.py`, `test_mac_panel_repeat_summary.py` plus Spec, Kontext, Briefing und Artefakte unter docs/; kein `project.yml`, keine `Info.plist`, keine Entitlements.
**Implementierer:**

### Runde 2
**Adversary:** Zweite, gezielte Runde gegen Punkte, die in Runde 1 zu schnell grün wirkten.
- Zählung bei Fehlschlag: Der Klickanhang wird in `assertSymbolOpensPanelWithOneClick` vor dem `XCTAssertTrue` angehängt, also auch bei „not open“; Nenner und Zähler stehen unabhängig vom Testergebnis. Schlägt schon das erste `openPanel` fehl, entsteht kein Klickanhang und die Iteration fehlt im Nenner; korrekt (keine Wiederöffnung), wird aber nicht ausgewiesen (zu F001).
- Regex-Härte: der Anhangsname muss auf `-click` enden oder mit Trenner weitergehen und passt so auf Xcodes Exportnamen mit Suffix. Weicht das Manifest-Feld ab (anderes Feld als `suggestedHumanReadableName`), stehen alle Arme auf 0: sichtbar, nicht still falsch, aber erst im PR-Lauf prüfbar.
- Datenschutz im Skript: Ausgabe nur Zeiten, Typnummern, PIDs, Zeilenart; die Bundle-ID aus „app activate“ wird nicht übernommen (`parse_panel_log` liest nur event, cg, source, target).
- Zeitleiste: `timeline` nimmt nur Zeilen 0 bis 15 s nach dem Klick; Prüfläufer und App laufen auf demselben Host, kein Uhrenversatz.
- Monitor-Last: Der lokale Monitor schreibt 3 s lang jede Ereignisart, auch Mausbewegungen; nur `type`, `windowNumber`, `timestamp`, keine Tasteninhalte; Menge begrenzt.
- Spec-Konformität F002: Die Spec verlangt für den Kontrollarm keinen Erwartungsfehler und keinen grünen Wiederholungslauf (Test 4: alle Iterationen laufen, Zusammenfassung nennt Nenner, Zähler, Rate). Rot bei einem Fall ist spec-konform; als Empfehlung belassen.
- Rennen zwischen Monitor-Closure und `stopMonitors`: beide laufen auf dem Main-Thread, kein Befund.
Keine weiteren Befunde.
**Implementierer:**

### Runde 3
**Adversary:** Nachbesserung gegen den gestagten Diff geprüft; `python3 scripts/test_mac_panel_repeat_summary.py -v` selbst ausgeführt: 28 Tests OK, 0 übersprungen (angehängt an adversary-test-output.txt).
- F001 geschlossen (Code): `deviations` (scripts/mac_panel_repeat_summary.py:90) nennt je aktivem Arm jede Abweichung Nenner gegen `--expected`; der Workflow übergibt `--expected` mit der Iterationszahl und `--arms` (mac-panel-repeat.yml:114; Arme return, open-app, plus control nur bei aktivem Kontrollarm). Eine verkürzte Manifest-Liste oder gestörte Folge-Iteration fällt damit in der Zusammenfassung auf. Ob das Manifest bei Iterationen vollständig ist, zeigt weiterhin erst der PR-Lauf (offen: braucht PR-Lauf).
- F002: vom Tech Lead entschieden, bleibt so (Return-Test laut Spec unverändert, Kontrollarm gleich hart für Vergleichbarkeit, Auswertung läuft über if: always(), nächster app.launch() beendet eine stehengebliebene Instanz, der Nenner-Wächter aus F001 deckt eine gestörte Folge-Iteration auf). Als akzeptiert vermerkt, kein offener Befund.
- F003 geschlossen: `callers()` (MenuBarCapture.swift:132) nutzt `drop(while:)`, überspringt also nur die führenden Rahmen von MenuBarPanelLog und MacAppDelegate; tiefere Rahmen bleiben. Funktion weiter 6 Zeilen.
- F004 geschlossen: `how_of` und `count_how` (Skript Zeilen 72 bis 87) zählen den Klickweg je Arm (statusitem, cgevent, xcuicoordinate als Rückfall, sonst unbekannt); der Bericht listet ihn je Arm.
Keine neuen Befunde im Code. Offen bleiben nur die Laufbelege AC-1, AC-2, AC-5, AC-6 und der Mac-Swift-6-Bau auf dem PR-Zweig.
**Implementierer:**

## Herkunft der Vorbedingungen

kein Sprachprofil konfiguriert (`precondition_origins.default_lang`)

## Bestätigungen

Confirmation:
  AC: AC-1
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:118
  Evidence: `record` schreibt bei key, resign, hide und close eine Zeile mit Stapel (bis 40), cg-Feldern oder „nil“ und `active`/`keyWindow`. Laufbeleg (Artefakt MacGalleryPanelLog): offen: braucht PR-Lauf.
  Status: AMBIGUOUS

Confirmation:
  AC: AC-2
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:183
  Evidence: `observeActivation` (151) schreibt App-, Workspace- und Space-Zeilen; `startMonitors` ersetzt das alte Paar und entfernt es nach 3 s. Laufbeleg offen: braucht PR-Lauf.
  Status: AMBIGUOUS

Confirmation:
  AC: AC-3
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:189
  Evidence: lokaler Monitor gibt `event` unverändert zurück; kein subtype, data1, print, try?; Funktionen ≤ 50 Zeilen; ca. +107 App-Zeilen netto.
  Status: CONFIRMED

Confirmation:
  AC: AC-4
  Code reference: .github/workflows/mac-panel-repeat.yml:88
  Evidence: drei -only-testing, `-test-iterations`, Eingaben nur über env, Uploads mit `if: always()` und `continue-on-error`, Zeitgrenze 120 (Zeile 34), Kontrollarm-Variable nur bei `CONTROL_ARM=true` (81). Lauf auf dem PR-Zweig offen: braucht PR-Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-5
  Code reference: scripts/mac_panel_repeat_summary.py:128
  Evidence: `report` gibt je Arm Nenner, Zähler, Rate aus; die drei Artefakte sind im Workflow definiert. Artefakte des Laufs offen: braucht PR-Lauf; Manifest-Risiko bei Iterationen (F001).
  Status: AMBIGUOUS

Confirmation:
  AC: AC-6
  Code reference: LooseEndsUITests/MacGalleryTests.swift:491
  Evidence: `XCTSkip` ohne `LE_PANEL_CONTROL_ARM`; Pflichttests klicken mit `statusItem.click()`. Grüner Pflicht-Job offen: braucht PR-Lauf.
  Status: AMBIGUOUS

Confirmation:
  AC: AC-7
  Code reference: scripts/mac_panel_repeat_summary.py:62
  Evidence: `python3 scripts/test_mac_panel_repeat_summary.py -v`: 19 Tests OK, Ausgabe in adversary-test-output.txt.
  Status: CONFIRMED

Confirmation:
  AC: AC-8
  Code reference: LooseEnds/Mac/MenuBarCapture.swift:307
  Evidence: nur die fünf genannten Dateien plus Dokumente und Artefakte unter docs/; project.yml, Info.plist, Entitlements ohne Diff. iOS-Bau und Unit-Tests: offen: braucht PR-Lauf.
  Status: CONFIRMED

Confirmation:
  AC: AC-7
  Code reference: scripts/test_mac_panel_repeat_summary.py:1
  Evidence: 28 Tests OK (Runde 3), Ausgabe in adversary-test-output.txt.
  Status: CONFIRMED

## Verdict

VERDICT: AMBIGUOUS

Grund: Im Code sind keine Befunde mehr offen (F001, F003, F004 geschlossen, F002 vom Tech Lead als akzeptiert entschieden). Ambiguous nur, weil die Laufbelege AC-1, AC-2, AC-5, AC-6 (Panel-Log, Wiederholungslauf-Artefakte, Pflicht-Job grün, Mac-Swift-6-Bau) noch auf den PR-Lauf warten.

Proven points: AC-3, AC-4 (Code), AC-7, AC-8 (Diff) bestätigt; AC-1, AC-2, AC-5, AC-6 im Code bestätigt, Laufbeleg offen: braucht PR-Lauf.
Tests: 28 passed, 0 failed, 0 übersprungen (scripts/test_mac_panel_repeat_summary.py); Mac-UI-Tests lokal nicht ausführbar.
Recommendation: Nach Push PR-Lauf und Wiederholungslauf prüfen (Nenner je Arm = 20 ohne Abweichungszeile, Panel-Log, Pflicht-Job grün mit Kontrollarm übersprungen), dann VERIFIED.

## Geprüfte Dateien

- sha256:05862f4d00a8c539043257bceaf746e610a8b72f6e2e710d925b11b5779a1e5f  .github/workflows/mac-panel-repeat.yml
- sha256:97b41b3aec9b67451792c73ac5be0e53467d51dd0b1055eb9ee845ebc38217e6  LooseEnds/Mac/MenuBarCapture.swift
- sha256:b39f3050e76ecaa537358ef3712b32feb31b9be11a566c7ae9afd924f57bce2f  LooseEndsUITests/MacGalleryTests.swift
- sha256:7d41009d5fee0a33839986decaf92083d7101ac0768ecf9d16972c877470151e  scripts/mac_panel_repeat_summary.py
- sha256:5780b9a45b2a540f95bbadf8dc0b2f4b206b08fcbb7fecb200103fb7325d43d4  scripts/test_mac_panel_repeat_summary.py

## Prüfbasis

- base: 4f3eb7d1436276dd0164d1fc84e9f59cffce698f
- blob:34516285072b96e128b00267710ed3f4b6aa42e9  .github/workflows/mac-panel-repeat.yml
- blob:b214d1417a3663b7179bac7e21c74c5bfe48ecdb  LooseEnds/Mac/MenuBarCapture.swift
- blob:5e88f752ad6c4f315d0b59d20e3d7eb95f32cbaa  LooseEndsUITests/MacGalleryTests.swift
- blob:1cf5d406d59e48ed043c944eac0118461a5192e1  scripts/mac_panel_repeat_summary.py
- blob:bceb080a3c4fff6dc8bd3136cbf1a2f9770d5ff3  scripts/test_mac_panel_repeat_summary.py
