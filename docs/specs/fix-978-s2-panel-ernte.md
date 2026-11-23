---
entity_id: fix-978-s2-panel-ernte
type: bugfix
created: 2026-11-23
updated: 2026-11-23
status: draft
workflow: fix-978-s2-panel-ernte
---

# Spec: #978 Schnitt 2 — Ursache des selbst schließenden Menüleisten-Panels sichtbar machen und Fälle per Wiederholungslauf herbeiführen

## Approval

- [ ] Approved (Henning)

## Purpose

Das Menüleisten-Panel der Mac-App geht nach einer Wiederöffnung (Klick aufs Symbol nach Return oder nach „Open Loose Ends“ und ⌘W)
selten auf und nach 0,8 bis 1,0 s von selbst wieder zu, immer mit dem undokumentierten Ereignistyp 21 als aktuellem Ereignis.
Drei Fälle liegen vor (PR-Lauf 45070786960, main-Läufe 45138541451 und 45180196067); das Protokoll aus Schnitt 1 reicht für die
Ursache nicht, weil der Stapel auf 12 Rahmen gekürzt ist und Typ, Quelle und Ziel des Ereignisses 21 fehlen. Schnitt 2 ändert kein
Produktverhalten: Er macht die Ursache im Protokoll sichtbar, führt Fälle per Wiederholungslauf selbst herbei (statt auf den
Zufall im Pflicht-Job zu warten, PO 2026-11-23) und zählt eine Rate mit Nenner. Fix oder Testumbau ist Schnitt 3 mit eigener Spec.

**Hat es bisher funktioniert?** Ja, überwiegend: bisher S1 2 von 15 und am 2026-11-23 3 Fehlschläge in etwa 6 Wiederöffnungen über
drei Läufe. Ob Nutzer das Verhalten sehen, ist nicht belegt. Analyse und Belege: `docs/context/fix-978-s2-panel-ernte.md`;
Vorgänger: `docs/specs/fix-978-panel-schliesst.md`.

## Source

- **File:** `LooseEnds/Mac/MenuBarCapture.swift`
- **Identifier:** `enum MenuBarPanelLog` (`record`), `MacAppDelegate.observeWindows` / `observePanelHiding`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SwiftUI `MenuBarExtra(.window)` (`LooseEnds/App/LooseEndsApp.swift`) | API | Panel und Symbol, unverändert |
| `NSEvent.cgEvent`, `CGEvent` (Typ, Fensternummer, Ziel-PID, `eventSourceUnixProcessID`, Zeitstempel) | API | sichere Ereignisfelder; `cgEvent` kann nil sein |
| `NSEvent.addLocalMonitorForEvents` / `addGlobalMonitorForEvents` | API | Ereignisse nach `key`; global nur Maus, ohne Berechtigung |
| `NSApplication.didBecomeActive/didResignActive/didHide`, `NSWorkspace.didActivateApplication`, `activeSpaceDidChangeNotification` | API | Zeilen zu Aktivierung und Space-Wechsel |
| `os.Logger` (Subsystem `com.henning.looseends`, Kategorie `MenuBarPanel`) | API | Zeilen; Kategorie bleibt, damit `log show` in `ci.yml` unverändert greift |
| `LooseEndsUITests/MacGalleryTests.swift`, `MacUITestSupport.swift` | Test-Werkzeug | Wiederöffnungstests, Kontrollarm |
| `scripts/mac_ci_entitlements.py`, `.github/actions/select-xcode-27` | CI | Sandbox-Schlüssel und Xcode-Wahl, vom Pflicht-Job übernommen |
| `.github/workflows/ci.yml`, Job „Mac Gallery (macOS)“ | CI | Vorlage der Schritte; bleibt in den Schritten unverändert |
| `docs/specs/fix-978-panel-schliesst.md`, `docs/specs/fix-862-menubar-panel.md` | Spec | Vorgänger |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | `MenuBarPanelLog`: Stapel bis 40 Rahmen, CGEvent-Felder, `isActive`/`isKeyWindow`, Aktivierungs- und Space-Zeilen, Ereignismonitore (nur Diagnose) |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | Kontrollarm: Variante der Wiederöffnung mit Koordinatenklick, nur mit Umgebungsflag aktiv, sonst `XCTSkip` |
| `.github/workflows/mac-panel-repeat.yml` | CREATE | Wiederholungslauf der Wiederöffnungstests (`workflow_dispatch` mit Eingabe `iterationen`, zusätzlich `pull_request` nur auf diese Datei), lädt Panel-Protokoll, xcresult und Zusammenfassung hoch |
| `scripts/mac_panel_repeat_summary.py` | CREATE | zählt aus den exportierten Anhängen Nenner und Zähler je Arm und baut je Fall die Zeitachse aus Panel-Protokoll und Klickanhang |
| `scripts/test_mac_panel_repeat_summary.py` | CREATE | Prüfskript mit festen Eingaben (Testcode) |

Danach, ohne Produktcode: `docs/artifacts/fix-978-s2-panel-ernte/` (gefilterte Protokolle, Fall- und Ratentabelle).

### Estimated Changes

- Files: 5 (dazu Belege unter `docs/artifacts/`)
- LoC: App-Code +~60 bis 100 (`MenuBarCapture.swift`, Grenze ±250); Testcode und Skripte ca. +150, zählen nicht mit; Workflow ca. +120

Keine Änderung an `project.yml`, `Info.plist`, Entitlements oder AppStorage-Schlüsseln. **Geräteliste:** berührt werden `LooseEnds/Mac/`,
`LooseEndsUITests/`, `.github/` und `scripts/`, keiner steht auf der Liste. Kein Pfad der Geräteliste berührt.

## Implementation Details

1. **Protokoll erweitern (`MenuBarCapture.swift`, nur Diagnose, kein Verhalten).** Die Zeilen bleiben `Logger`, Kategorie
   `MenuBarPanel`, Stufe Notice, immer aktiv.
   - *Stapel:* bis 40 Rahmen ab dem ersten Rahmen außerhalb des eigenen Beobachters (Rahmen mit `MenuBarPanelLog` oder
     `MacAppDelegate` werden übersprungen), damit sichtbar wird, wer schließt.
   - *Ereignis:* Felder nur über `event.cgEvent` (kann nil sein, dann „nil“): CG-Typ, Fensternummer, Ziel-PID, `eventSourceUnixProcessID`,
     Zeitstempel. Nie `subtype` oder `data1` lesen (werfen bei unbekannten Typen wie 21).
   - *Zustand:* `NSApp.isActive` und `isKeyWindow` des Panels bei `key` und `resign`.
   - *Zusätzliche Zeilen:* `NSApplication.didBecomeActive`, `didResignActive`, `didHide`; `NSWorkspace.didActivateApplication` (nur
     Bundle-ID der aktivierten App); `NSWorkspace.activeSpaceDidChangeNotification`.
   - *Ereignismonitore:* ab `key` für 3 s ein lokaler Monitor, der je Ereignis Rohtyp, Fensternummer und Zeitstempel schreibt, das
     Ereignis unverändert zurückgibt und danach entfernt wird; dazu ein globaler Monitor nur für Mausereignisse im selben Zeitfenster.
     Höchstens ein Monitorpaar zugleich; ein neues `key` ersetzt das alte.
   - Keine Nutzerdaten, kein Aufgabentext, kein Fenstertitel, kein Token. Kein `print`, kein `try?`, Swift 6 strict concurrency,
     jede Funktion ≤ 50 LoC (die Erweiterung wird in kleine Hilfsfunktionen geteilt). `applyDockPolicy`, `dismiss()` und `showMain`
     bleiben unberührt, die Beobachter ändern ihr Verhalten nicht.
2. **Kontrollarm (`MacGalleryTests.swift`).** Eine dritte Variante der Wiederöffnung klickt das Symbol nicht mit `statusItem.click()`,
   sondern mit einem Koordinatenklick (Maus-CGEvents auf die Mitte von `statusItem.frame`, gesendet vom Testläufer). Sie ist nur
   aktiv, wenn die Umgebungsvariable `LE_PANEL_CONTROL_ARM` gesetzt ist, sonst `XCTSkip`; im Pflicht-Job läuft sie also nie. Die beiden
   vorhandenen Wiederöffnungstests klicken unverändert wie ein Nutzer (`statusItem.click()`); `XCTExpectFailure` aus Schnitt 1 bleibt
   (Rückbau ist Schnitt 3). Jede Variante hängt weiter `mac-gallery-<label>-click` mit Klickzeit und „panel open/not open“ an; der
   Kontrollarm trägt eine eigene Marke (`reopen-return-control`), damit der Nenner je Arm zählbar ist. Gleiche Fehlerrate wie die
   Nutzerklick-Arme spricht für App/System, Rate null für das Prüfwerkzeug (Klicksynthese).
3. **Wiederholungsworkflow (`mac-panel-repeat.yml`).** Auslöser `workflow_dispatch` (beliebiger Ref, Eingaben `iterationen` mit
   Vorgabe 20, `kontrollarm` mit Vorgabe an, `sandbox` mit Vorgabe aus) und `pull_request` nur für Änderungen an dieser Datei (damit
   der erste Lauf auf dem PR-Zweig belegbar ist, Vorgabewerte). Schritte wie im Mac-Galerie-Job: Xcode 27 wählen
   (`select-xcode-27`), XcodeGen, Automationsmodus, danach `xcodebuild test -test-iterations N` auf nur die beiden Wiederöffnungstests
   und den Kontrollarm. `-test-iterations` fährt alle Iterationen auch nach einem Fehlschlag (anders als `-run-tests-until-failure`), weil
   die **Rate** gesucht ist: Nenner = alle Wiederöffnungen. Mit `sandbox` an wird wie im Schritt „Sandbox of the real app“ gebaut und
   mit `scripts/mac_ci_entitlements.py` neu signiert; ohne läuft der Bau wie der Galerie-Lauf des Pflicht-Jobs, in dem die Fälle
   auftraten. Das Panel-Protokoll kommt per `log show` mit Startzeit des Jobs (`--start`, nicht `--last`) in eine Datei, der Export
   der Anhänge wie im Pflicht-Job; Hochladen als `MacPanelRepeatLog`, `MacPanelRepeatResults` (xcresult, Logs) und `MacPanelRepeatSummary`.
   Protokoll- und Export-Schritte `if: always()` mit `continue-on-error`; Zeitgrenze 120 min. Die Zusammenfassung schreibt auch in
   `$GITHUB_STEP_SUMMARY`: je Arm Nenner, Zähler, Rate.
4. **Auswertung (`scripts/mac_panel_repeat_summary.py`).** Liest die exportierten `…-click`-Anhänge (Nenner je Arm, Zähler = „not
   open“) und das Panel-Protokoll; je Fall eine Zeitachse: Klick angefordert, `key`, Ereignis 21 samt Quelle-PID und Typ, `resign`,
   Ende der Klicksynthese. Die Ausgabe enthält nur Zeiten, Typnummern und PIDs.
5. **Fälle herbeiführen (Definition of Done).** Mit dem ersten Wiederholungslauf wertet Claude die Fälle aus (Zeitachse, Rate je Arm,
   Quelle des Ereignisses 21), legt die gefilterten Belege unter `docs/artifacts/fix-978-s2-panel-ernte/` ab und kommentiert den
   Befund samt Empfehlung für Schnitt 3 in #978. Tritt in einem Lauf kein Fall auf, startet Claude weitere Läufe selbst; es gibt
   keinen Sammel-Stichtag.

## Test Plan

Mac-UI-Tests laufen nur in der CI (macOS 27), nie auf Hennings Mac. Iterationszahlen und Fallauswertung liegen im Wiederholungslauf.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN ein Panel-Protokoll mit festen Beispielzeilen (Klickanhänge „open“ und „not open“, `key`, `resign` mit Ereignis 21)
  WHEN `scripts/test_mac_panel_repeat_summary.py` die Zusammenfassung baut THEN stimmen Nenner, Zähler und Rate je Arm und die Zeitachse
  eines Falls (RED: Skript fehlt).
- [ ] Test 2: GIVEN der Pflicht-Job „Mac Gallery (macOS)“ ohne `LE_PANEL_CONTROL_ARM` WHEN er läuft THEN steht der Kontrollarm als
  übersprungen im Ergebnis, die beiden Wiederöffnungstests sind ausgeführt, der Job ist grün.
- [ ] Test 3: GIVEN der Pflicht-Job WHEN `MacGalleryPanelLog` geprüft wird THEN enthält er die neuen Zeilen (Stapel mit mehr als 12 Rahmen
  ab dem ersten Rahmen außerhalb des Beobachters, `isActive`/`isKeyWindow` bei `key` und `resign`, Ereignisfelder oder „nil“,
  Aktivierungszeilen) und keinen Aufgabentext, keinen Fenstertitel, kein Token.
- [ ] Test 4: GIVEN der Wiederholungsworkflow auf dem PR-Zweig WHEN er mit den Vorgabewerten läuft THEN laufen alle Iterationen
  beider Wiederöffnungstests und des Kontrollarms, und `MacPanelRepeatSummary` nennt je Arm Nenner, Zähler und Rate.
- [ ] Test 5: GIVEN der Kontrollarm WHEN der Diff geprüft wird THEN ist er mit `XCTSkip` ohne `LE_PANEL_CONTROL_ARM` geschützt und die
  beiden Pflichttests klicken weiter mit `statusItem.click()`.
- [ ] Test 6: GIVEN `MenuBarCapture.swift` WHEN iOS-Bau und Unit-Tests laufen THEN bleiben sie grün (`#if os(macOS)`).

### Abnahme (Stufen)

1. **Tests:** Unit-Tests und iOS-Bau grün (`./scripts/sim.sh sim-unit`, `./scripts/sim.sh build`); Pflicht-Job „Mac Gallery (macOS)“ grün.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur in der CI; dort öffnet die echte Mac-App, das ist die Stufe. Belege: Artefakte
   `MacGalleryPanelLog` des Pflicht-Jobs sowie `MacPanelRepeatLog`, `MacPanelRepeatResults`, `MacPanelRepeatSummary` des Wiederholungslaufs
   auf dem PR-Zweig, geöffnet und beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `MenuBarCapture.swift` / When das Panelfenster Key wird, Key verliert oder verschwindet / Then schreibt die App immer eine
  Zeile der Kategorie `MenuBarPanel` mit Stapel bis 40 Rahmen ab dem ersten Rahmen außerhalb des Beobachters, CGEvent-Feldern des aktuellen
  Ereignisses (oder „nil“) und bei `key`/`resign` `NSApp.isActive` und `isKeyWindow`. Belegt durch Diff und `log show`-Zeilen im Artefakt
  `MacGalleryPanelLog` des PR-Laufs, geöffnet und beschrieben.
- **AC-2:** Given `MenuBarCapture.swift` / When die App `didBecomeActive`, `didResignActive`, `didHide`, `didActivateApplication` oder
  einen Space-Wechsel erlebt und nach `key` 3 s vergangen sind / Then stehen dazu Zeilen im Protokoll (aktivierte App nur als Bundle-ID,
  Monitorzeilen mit Rohtyp, Fensternummer, Zeitstempel), und die Monitore sind nach 3 s entfernt. Belegt durch Diff und das Artefakt
  `MacGalleryPanelLog`.
- **AC-3:** Given der Diff von `MenuBarCapture.swift` / When er geprüft wird / Then ändert er kein Verhalten (`applyDockPolicy`, `dismiss()`,
  `showMain` unberührt; der lokale Monitor gibt jedes Ereignis unverändert zurück), liest nie `subtype` oder `data1`, enthält kein `print`,
  kein `try?`, keinen Aufgabentext, Fenstertitel oder Token in den Zeilen, jede Funktion ≤ 50 LoC, App-Code ≤ 250 LoC. Belegt durch
  Diff-Prüfung und `git diff --stat`.
- **AC-4:** Given `.github/workflows/mac-panel-repeat.yml` / When sie geprüft wird / Then ist der Workflow per `workflow_dispatch` auf beliebigem
  Ref startbar (Eingaben `iterationen`, `kontrollarm`, `sandbox`), fährt nur die beiden Wiederöffnungstests und den Kontrollarm mit
  `-test-iterations`, zählt alle Iterationen (nicht nur Fehlschläge) und lädt Panel-Protokoll, xcresult und Zusammenfassung hoch. Belegt
  durch Diff und den Lauf auf dem PR-Zweig.
- **AC-5:** Given ein Lauf des Wiederholungsworkflows auf dem PR-Zweig / When er endet / Then enthalten die Artefakte `MacPanelRepeatLog`,
  `MacPanelRepeatResults` und `MacPanelRepeatSummary`, und die Zusammenfassung nennt je Arm (Return, Open-App, Kontrollarm) Nenner, Zähler
  und Rate. Belegt durch die Artefakte, geöffnet und beschrieben (null Fälle sind ein gültiges Ergebnis, die Zählung muss stehen).
- **AC-6:** Given der Kontrollarm in `MacGalleryTests.swift` / When der Pflicht-Job „Mac Gallery (macOS)“ läuft / Then ist der Kontrollarm als
  übersprungen ausgewiesen, die beiden Wiederöffnungstests klicken weiter mit `statusItem.click()` wie ein Nutzer, und der Job ist beim
  ersten Versuch grün. Belegt durch Diff und das Ergebnisbündel des PR-Laufs.
- **AC-7:** Given `scripts/test_mac_panel_repeat_summary.py` / When es läuft / Then ist es grün und prüft Nenner, Zähler, Rate und Zeitachse
  mit festen Eingaben. Belegt durch den Lauf (lokal und in der CI).
- **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die fünf genannten Dateien, kein Eintrag in `project.yml`,
  `Info.plist` oder Entitlements; Unit-Tests und iOS-Bau sind grün. Belegt durch `git diff --stat` und die Läufe.

## Alternativen

- **B — Test klickt per Koordinate oder `AXPress` statt `statusItem.click()` (Testumbau ohne Beleg):** schneller, aber ohne Ursache
  geraten und verwässert womöglich den Nutzerweg. Die Koordinatenvariante läuft deshalb nur als Kontrollarm in der Diagnose und beweist
  oder widerlegt Ursache 1 (Prüfwerkzeug); erst danach kann Schnitt 3 sie übernehmen. Es fällt keine ADR, nur die Definition of Done von #978.
- **C — App hält das Panel bei `resign` ohne Nutzerereignis offen:** greift in das normale Schließen beim Klick daneben ein und
  verdeckt eine Ursache, die vielleicht nur im Prüfwerkzeug liegt. Es fällt keine ADR.
- **D — `MenuBarExtra(.window)` durch eigenes `NSStatusItem` plus `NSPanel` ersetzen:** nur sinnvoll, falls belegt ist, dass SwiftUI
  selbst schließt und Nutzer betroffen sind. Es würde die Bauweise aus #356/#862 kippen (Entscheidung für `MenuBarExtra`). Ohne Befund
  spekulativ; in diesem Schnitt keine ADR.
- **E — weiter auf Zufallsfälle im Pflicht-Job warten:** ohne Nenner, bei Raten um 13 % langsam und mit 35-min-Läufen teuer; durch den
  PO am 2026-11-23 ausgeschlossen (kein Sammeln, dann Auswerten).

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Schnitt 2 fügt nur Diagnose (Protokollzeilen, Ereignismonitore), einen zusätzlichen Test hinter einer Umgebungsvariable
  und einen Wiederholungsworkflow hinzu; Speicherort, Datenmodell, Plattformzuschnitt und Abgleich bleiben, und keine der Alternativen
  B, C und E kippt eine bestehende ADR. Alternative D würde die Bauweise aus #356/#862 kippen und wäre erst mit Befund eine eigene
  ADR in Schnitt 3.

## Known Limitations

- **Ursache kann offen bleiben:** Schnitt 2 liefert Material und eine Rate, keinen Fix. Fix oder Testumbau, `XCTExpectFailure` raus,
  Test hart und drei Läufe grün folgen in Schnitt 3 mit eigener Spec.
- **Koordinatenklick als Kontrollarm:** Posten von Maus-CGEvents durch den Testläufer kann an fehlender Bedienungshilfen-Freigabe
  scheitern; dann fällt der Arm auf `XCUICoordinate.click()` zurück, was dieselbe Synthese nutzt und die Aussage abschwächt. Das steht
  dann im Befund.
- **Sandbox-Frage:** Die Fälle traten im Galerie-Lauf ohne App Sandbox auf; der Schalter `sandbox` prüft, ob sie sich ändert. Die
  Vorgabe ist aus (wie im Pflicht-Job).
- **Zähler über Anhänge:** Der nicht strikte erwartete Fehlschlag macht den Test grün; gezählt wird deshalb aus dem Anhang
  „panel open/not open“ und dem Protokoll, nicht aus dem Testergebnis.
- **Unbewiesen für Nutzer:** Ob Henning oder andere Nutzer das Schließen je sehen, ist nicht belegt.
- **Laufzeit:** Ein Wiederholungslauf mit 20 Iterationen braucht deutlich mehr als der Pflicht-Job (Zeitgrenze 120 min).

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt; Unit-Tests, iOS-Bau und Pflicht-Job grün; Artefakte des PR-Laufs und des Wiederholungslaufs geöffnet und
  beschrieben.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ PR mit `Refs #978` (nicht `Closes`).
- [ ] Nach dem ersten Wiederholungslauf (kein AC, das QA-Gate kennt keinen Aufschub): Fälle ausgewertet, je Fall Zeitachse (Klick
  angefordert, `key`, Ereignis 21 mit Quelle-PID, `resign`, Synthese-Ende), Rate je Arm, gefilterte Belege unter
  `docs/artifacts/fix-978-s2-panel-ernte/`, Kommentar in #978 mit Befund und Empfehlung für Schnitt 3.
- [ ] Tritt im ersten Lauf kein Fall auf, startet Claude selbst weitere Läufe (mehr Iterationen, `sandbox` an), bis Fälle oder eine
  belastbare Rate „kein Auftreten in N Wiederöffnungen je Arm“ vorliegen; kein Sammel-Stichtag. #978 bleibt bis Schnitt 3 offen.

## Changelog

- 2026-11-23: Initiale Spec für #978 Schnitt 2 (Ursache sichtbar machen, Wiederholungsworkflow mit Kontrollarm, Auswertung der Fälle).
