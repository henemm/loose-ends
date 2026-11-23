# Context: fix-978-s2-panel-ernte (#978 Schnitt 2)

## Request Summary
Die roten Läufe des Jobs „Mac Gallery (macOS)“ mit Panel-Protokoll (seit #981, 2026-11-23) auswerten und fehlende Fälle
selbst per Wiederholungsläufe herbeiführen, ohne Sammel-Stichtag (PO 2026-11-23). Ziel laut DoD: Ursache mit Beleg
(App oder Prüfwerkzeug), dann Fix bzw. Testumbau, Test wieder hart und dreimal hintereinander grün.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Mac/MenuBarCapture.swift` | `MenuBarPanelLog.record` (Z. 111) und `MacAppDelegate.observeWindows`/`observePanelHiding` (Z. 190–228): Zeilen `key`/`close`/`resign`/`hide` mit Fensterklasse, `NSApp.currentEvent`, vorderster App, Aktivierungsrichtlinie, Stack |
| `LooseEndsUITests/MacGalleryTests.swift` | `openPanel` (Z. 311), `testMenuBarReopensAfterReturnWithOneClick` (Z. 445, hart), `testMenuBarReopensAfterOpenAppWithOneClick` (Z. 466, `XCTExpectFailure` nicht strikt), `assertSymbolOpensPanelWithOneClick` (Z. 485, Anhang `…-click` mit Klickzeit) |
| `LooseEndsUITests/MacUITestSupport.swift` | `macOpenMainWindowIfNeeded` (Z. 38): zweites Fehlerbild „Menu bar panel shows no Open Loose Ends“ |
| `.github/workflows/ci.yml` | Job „Mac Gallery (macOS)“, Panel-Log per `log show` (Z. ~692), Artefakte `MacGalleryPanelLog`, `MacGalleryResults` (xcresult + Logs) |
| `docs/artifacts/fix-862-menubar-panel/`, `docs/artifacts/fix-978-panel-schliesst/` | frühere Zeitachsen, Panel-Logs aus S1 |

## Erste Befunde (2026-11-23, beim Sammeln)
- main-Lauf 45138541451 (4cc97f6), rot: `testMenuBarReopensAfterReturnWithOneClick`. Panel-Log, Prozess 23297:
  `key` 09:21:13 (öffnen), `resign`/`hide` 09:21:22 (Return, ev=10), Klick des Tests angefordert 09:21:24.239,
  `key` 09:21:24.562 (ev=13, front Finder, accessory), **`resign` 09:21:25.373 mit ev=21**, `hide` 09:21:25.440.
  XCTest meldet das synthetisierte Klickereignis erst 09:21:29.798 fertig (5,5 s), dann 10 s Warten, kein Panel.
  → Das Panel ging auf und **nach 0,8 s wieder zu**, mitten in der Klicksynthese. Die Deutung im Issue-Kommentar
  („fünf key ohne resign“) war falsch: das sind fünf verschiedene Prozesse (je ein Test, Ende per `terminate`).
- PR-Lauf 45070786960 (S1, abgebrochen), Prozess 27700 = `reopen-open-app`: `key` ev=13 → nach 1,0 s `resign` ev=21.
  Dasselbe Muster beim ersten Fehlerbild.
- `ev=21` ist kein öffentlicher `NSEventType` (SDK 27.2: 18 Rotate, 19/20 Gesten, 22 ScrollWheel); 21 fehlt in den Headern.
  Recherche (Apple-Doku, Foren) ergab keine Bedeutung. In grünen Wiederöffnungen folgt auf `key` ev=13 kein `resign`.

## Existing Patterns
- Belege werden nach `docs/artifacts/<workflow>/` übernommen (gefiltert, keine Nutzerdaten).
- Diagnose-Workflow `diag-862.yml` (Draft-PR #975) für gezielte Wiederholungen; Wiederholung des echten Jobs per
  `gh run rerun --job`.

## Dependencies
- Upstream: SwiftUI `MenuBarExtra(.window)`, AppKit-Aktivierung (accessory/regular), XCUITest-Klicksynthese.
- Downstream: Pflicht-Check „Mac Gallery (macOS)“ macht fremde PRs rot (#983).

## Risks & Considerations
- Seltenes Ereignis: Wiederholungen nötig; Runner-Minuten (macOS) teuer, je Lauf ~35 min.
- Ein Testumbau darf den Nutzerweg nicht verwässern (DoD: prüft den Nutzerweg).
- Event 21 könnte von XCTest (synthetisierte Ereignisse) stammen → Prüfwerkzeug; nicht belegt, bis mehr Fälle da sind.

## Laufende Wiederholungen
- 2026-11-23: Mac-Galerie-Job von main-Lauf 45138541451 neu gestartet (Versuch 2). In /20-analyse Ergebnis und Panel-Log holen (`gh run download 45138541451 -n MacGalleryPanelLog` lädt den neuesten Versuch), weitere Versuche nach Bedarf.
- Offen nebenher: Doku-PR #989 (Regel „kein Sammeln, dann Auswerten“) mergen, sobald seine CI grün ist (Auto-Merge im Repo aus).

## Analysis

### Type
Bug (selten, nur in der CI beobachtet: Menüleisten-Panel geht nach dem Wiederöffnen von selbst wieder zu)

### Befunde (2026-11-23, Phase 2)
Drei Fälle mit Panel-Protokoll, alle mit demselben Muster:

| Lauf | Test | Klick → `key` | `key` → `resign` | `currentEvent` beim `resign` | Activate vor Klick |
|---|---|---|---|---|---|
| PR 45070786960 (S1) | reopen-open-app | – | 1,0 s | 21 | – |
| main 45138541451 | reopen-return (rot) | 0,32 s | 0,81 s | 21 | nein |
| main 45180196067 (grün!) | reopen-open-app (erwarteter Fehlschlag, nicht strikt) | – | 0,90 s | 21 | ja |

- Der grüne main-Lauf 45180196067 enthält einen Fall: `XCTExpectFailure: matcher accepted … opened no panel (reopen-open-app)`,
  Prozess 25836, `key` ev=13 13:17:36.305 → `resign`/`hide` ev=21 nach 0,9 s, front Finder, accessory. Der Fehler ist also
  häufiger als die roten Läufe zeigen; der nicht strikte erwartete Fehlschlag verschluckt ihn.
- Erfolgreiche Wiederöffnungen (27233, 30812, 22426): `key` ev=13, danach **kein** `resign` bis zum nächsten Testschritt.
- XCTests „Activate“ vor der Klicksynthese unterscheidet nicht: der rote Return-Fall hatte keins, der grüne
  reopen-open-app-Erfolg im roten Lauf hatte eins. Die Synthese eines Status-Item-Klicks dauert immer ~5,5 s, auch im Erfolg.
- Recherche: `NSEventType` 21 ist undokumentiert. Fallbericht winit #104 / servo cocoa-rs #155: Typ 21 kommt an, wenn
  Systemmenüs der Menüleiste aufgehen (Spotlight, WLAN, Batterie). Eine Bedeutung nennt niemand. Apple-Forum
  „Various menu bar NSStatusItem issues with macOS 27“ (thread 836113) war nicht abrufbar (502).
- Der Stapel im Protokoll ist auf 12 Rahmen gekürzt und endet in `_CFXNotificationPost`: wer das Panel schließt
  (SwiftUI/AppKit), ist dadurch **nicht** sichtbar. Das Protokoll reicht für die Ursache nicht.

### Mögliche Ursachen
1. Prüfwerkzeug: XCTests synthetisierter Klick auf das Status-Item erzeugt ein Menüleisten-Systemereignis (Typ 21),
   bei dem SwiftUIs `MenuBarExtra(.window)` das Panel schließt; ein echter Klick erzeugt es nicht.
2. App/System: Jedes Menüleisten-Systemereignis (auch Spotlight, Kontrollzentrum) schließt das Panel, solange die App
   nicht aktiv ist (accessory, Finder vorn) – dann träfe es auch Nutzer, nur selten.
3. Aktivierungs-Wettlauf nach `terminate`/⌘W/Return (Richtlinie wechselt accessory↔regular) – durch die Tabelle eher
   unwahrscheinlich (Fälle mit und ohne Activate, beide Richtlinien-Vorgeschichten).
Nicht entscheidbar mit dem jetzigen Protokoll: Typ, Untertyp und Ziel des Ereignisses 21 und der Aufrufer der Schließung fehlen.

### Technical Approach (Empfehlung S2: Ursache sichtbar machen und Fälle selbst herbeiführen)
1. `MenuBarPanelLog` erweitern (nur Diagnose, kein Verhalten): Stapel bis 40 Rahmen ab dem ersten Rahmen außerhalb
   des eigenen Beobachters; für das aktuelle Ereignis die sicheren `CGEvent`-Felder (CG-Typ, Fensternummer, Ziel-PID,
   Quelle/`eventSourceUnixProcessID`, Zeitstempel) statt `subtype`/`data1` (die werfen bei unbekannten Typen);
   zusätzlich ein lokaler Ereignismonitor, der von `key` bis 3 s danach jedes Ereignis mit Rohtyp und Fensternummer
   protokolliert, sowie `NSApplication.didBecomeActive/didResignActive` und `NSWorkspace.didActivateApplication` (nur Bundle-ID).
2. Fälle herbeiführen statt warten: eigener Workflow (workflow_dispatch, beliebiger Ref) „Mac Panel Wiederholung“,
   der nur die beiden Wiederöffnungstests mit `-test-iterations N -run-tests-until-failure` im echten Sandbox-Bau
   fährt und Panel-Protokoll + xcresult hochlädt. Ein Lauf liefert so einen Fall, statt 35-min-Jobs zu wiederholen.
3. Mit dem ersten Fall: Ursache benennen (Ereignisquelle = XCTest-Runner-PID vs. WindowServer/SystemUIServer),
   dann Fix oder Testumbau in Schnitt 3; Test wieder hart, dreimal grün (DoD).

### Alternativen
- B: Test klickt per Koordinate oder `AXPress` statt `statusItem.click()` – ohne Ursache wäre das Raten und
  verwässert womöglich den Nutzerweg; erst nach Beleg für Ursache 1.
- C: App hält das Panel bei `resign` ohne Nutzerereignis offen – greift in das normale Schließen beim Klick daneben ein, riskant.
- D: `MenuBarExtra(.window)` durch eigenes `NSStatusItem` + `NSPanel` ersetzen (kippt die Bauweise aus #356/#862) – nur,
  falls Ursache 2 belegt ist und SwiftUI selbst schließt.

### Affected Files
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | Protokoll: Stapel, CGEvent-Felder, Ereignismonitor, Aktivierungszeilen (~60 LoC) |
| `.github/workflows/mac-panel-repeat.yml` | CREATE | Wiederholungslauf der beiden Tests bis zum ersten Fehlschlag (kein App-Code) |
| `.github/workflows/ci.yml` | MODIFY (evtl.) | `log show`-Filter um neue Zeilen, falls Kategorie gleich bleibt: keine Änderung |
| `docs/artifacts/fix-978-s2-panel-ernte/` | CREATE | Belege (gefilterte Protokolle, Fall-Tabelle) |

### Scope Assessment
- Dateien: 2–3, App-Code ~+60 LoC; Risiko: niedrig (nur Protokoll, Mac-only, keine Geräteliste-Pfade außer keinem).
- Stufe 3: kein Pfad der Geräteliste berührt (`LooseEnds/Mac/` steht nicht darin).

### Offene Fragen
- keine an den PO; Wiederholung Versuch 2 von 45138541451 steht noch in der Warteschlange (wird mit ausgewertet).

### Gegenprüfung (analysis-challenger, 2026-11-23) und Übernahme
- Ursache 3 (Aktivierung) ist durch die Tabelle **nicht** ausgeschlossen, nur nicht gestützt; Ursachen 1–3 bleiben offen.
- „Panel key, App nicht aktiv“ allein erklärt es nicht: auch die erfolgreichen Wiederöffnungen (27233, 30812) haben
  `key` ev=13 mit front Finder/accessory. Trotzdem wird `NSApp.isActive` und `isKeyWindow` bei `key`/`resign` mitgeschrieben.
- Die konstante Lücke 0,8–1,0 s `key`→`resign` ist das stärkste Merkmal (Timer/Aktivierungs-/Space-Übergang?):
  Zeitstempel des Klicks, des `key`, des Ereignisses 21 und des Synthese-Endes werden in einer Zeitachse geführt.
- Nenner fehlt: der Wiederholungslauf zählt alle Wiederöffnungen, nicht nur die Fehlschläge (Rate statt Einzelfälle).
  Grob bisher: S1 2 von 15, heute 3 Fehlschläge in ~6 Wiederöffnungen über drei Läufe.
- Ergänzungen fürs Protokoll: `NSApplication.didResignActive/didBecomeActive/didHide`,
  `NSWorkspace.activeSpaceDidChangeNotification`, `NSWorkspace.didActivateApplication` (nur Bundle-ID);
  Ereignisfelder nur über `event.cgEvent` (kann nil sein), `subtype`/`data1` nie lesen (werfen bei unbekannten Typen);
  lokaler Monitor gibt das Ereignis unverändert zurück und wird nach 3 s entfernt; zusätzlich ein globaler Monitor (nur Mausereignisse, keine Berechtigung nötig).
- `-run-tests-until-failure` startet je Iteration neu; das ist richtig so, weil jeder Test selbst startet, schließt
  und im selben Prozess wieder öffnet.
- Kontrollarm im selben Wiederholungslauf: eine Testvariante mit anderer Klickart (Koordinatenklick auf das Symbol);
  gleiche Fehlerrate → App/System, Rate null → Prüfwerkzeug. Die Variante bleibt Diagnose, der Pflichttest klickt weiter wie ein Nutzer.
