---
entity_id: fix-978-panel-schliesst
type: bugfix
created: 2026-11-22
updated: 2026-11-22
status: draft
workflow: fix-978-panel-schliesst
---

# Spec: #978 Schnitt 1 — Ursache des selten schließenden Menüleisten-Panels im echten CI-Job ernten

## Approval

- [ ] Approved (Henning)

## Purpose

Nach „Open Loose Ends“ und ⌘W geht das Menüleisten-Panel der Mac-App beim Klick aufs Symbol in seltenen Fällen auf und
schließt sich binnen etwa 5 Sekunden von selbst wieder (CI-Lauf 44877016605, Versuche 3 und 4, immer nur dieser Test). Ob die
App oder das Prüfwerkzeug (XCUITest-Klicksynthese) schuld ist, ist offen. Schnitt 1 ändert kein Produktverhalten: Er macht den
Test wieder aktiv, ohne die Ampel zu gefährden, lässt die App knappe Protokollzeilen schreiben und sammelt sie im echten
Mac-Galerie-Job, damit die Ursache beim nächsten Auftreten belegt ist. Schnitt 2 (Fix oder Testumbau) folgt nach dem Befund.

**Hat es bisher funktioniert?** Ja, überwiegend: gepoolt 2 rote von 15 vollen Galerie-Durchläufen (etwa 13 %), 0 von 36
gezielten Läufen. Ob Nutzer das Verhalten sehen, ist nicht belegt. Analyse und Belege: `docs/context/fix-978-panel-schliesst.md`,
Chronik der Diagnoseläufe in `docs/artifacts/fix-862-menubar-panel/stand.md`.

## Source

- **File:** `LooseEnds/Mac/MenuBarCapture.swift`
- **Identifier:** `MacAppDelegate` (Fensterbeobachter für `didBecomeKey`/`willClose`), `MacWindows.applyDockPolicy`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| SwiftUI `MenuBarExtra(.window)` (`LooseEnds/App/LooseEndsApp.swift`) | API | Panel und Symbol, unverändert |
| AppKit `NSStatusItem` (macOS 27, `expandedInterfaceSession`) | System | Sitzung des Panels; mögliche Ursache (f) |
| `NSApp.setActivationPolicy`, `NSApp.currentEvent`, `NSWorkspace`/`NSRunningApplication` | API | Werte, die der Logger liest |
| `os.Logger` (Subsystem `com.henning.looseends`) | API | Protokollzeilen, Kategorie `MenuBarPanel` |
| XCUITest-Klicksynthese (`MacGalleryTests`, `MacUITestSupport`) | Test-Werkzeug | Kandidat (e) der Ursache |
| `/usr/bin/log show` auf dem CI-Runner | CI | Auslesen der Zeilen nach dem Lauf |
| `.github/workflows/ci.yml`, Job „Mac Gallery (macOS)“ | CI | einziger Ort der Mac-UI-Tests |
| `diag-862.yml` auf Zweig `diag/862-panel-schliesst` | Vorlage | erprobtes `log show`, danach überflüssig |
| `docs/specs/fix-862-menubar-panel.md` | Spec | Vorgänger, Known Limitation verweist auf #978 |

Keine neue externe Abhängigkeit.

## Scope

### Affected Files

| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | `Logger`-Zeilen (Kategorie `MenuBarPanel`, Notice) im vorhandenen Fensterbeobachter bei Panel wird Key und Panel schließt |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `XCTSkip` raus, Klickprüfung in `XCTExpectFailure("#978 …", options: .nonStrict())` |
| `.github/workflows/ci.yml` | MODIFY | Schritt nach der Galerie: `log show` Kategorie `MenuBarPanel`, Upload Artefakt `MacGalleryPanelLog` |

### Estimated Changes

- Files: 3
- LoC: App-Code +~30; Testcode ca. ±10 (zählt nicht gegen ±250); CI +~15

Keine Änderung an `project.yml`, `Info.plist`, Entitlements oder AppStorage-Schlüsseln. **Geräteliste:** berührt werden
`LooseEnds/Mac/`, `LooseEndsUITests/` und `ci.yml`, keiner steht auf der Liste. Kein Pfad der Geräteliste berührt.

## Implementation Details

1. **Protokollzeilen (`MenuBarCapture.swift`).** Im vorhandenen Beobachter auf `NSWindow.didBecomeKeyNotification` und
   `willCloseNotification` schreibt eine kleine Hilfsfunktion (≤ 50 LoC) nur für das Panelfenster eine Zeile
   `Logger(subsystem: "com.henning.looseends", category: "MenuBarPanel")` auf Stufe Notice, immer aktiv, nicht nur unter Tests.
   Inhalt: Ereignis (`key` oder `close`), gekürzter Aufrufstapel (`Thread.callStackSymbols`, wenige Rahmen), Typ von
   `NSApp.currentEvent` (nur der Typname, nil gesondert), Bundle-ID der aktiven App, Aktivierungsrichtlinie. Keine Nutzerdaten,
   kein Aufgabentext, kein Fenstertitel. Kein `print`, kein `try?`, Swift 6 strict concurrency (Beobachter laufen auf dem
   Main-Actor). Das Verhalten der App bleibt unverändert; `applyDockPolicy`, `dismiss()` und `showMain` werden nicht angefasst.
2. **Test (`MacGalleryTests.swift`).** In `testMenuBarReopensAfterOpenAppWithOneClick` entfällt `XCTSkip`. Der Aufbau (Open
   Loose Ends, ⌘W) bleibt hart geprüft; nur der Aufruf von `assertSymbolOpensPanelWithOneClick` steht in
   `XCTExpectFailure("#978: Panel schließt selten von selbst, Ursache wird geerntet", options: .nonStrict())`. Tritt der
   Fehler nicht auf, bleibt der Test grün (nicht strikt); tritt er auf, erscheint er als erwarteter Fehler im Ergebnis, die
   Ampel bleibt grün.
3. **CI (`ci.yml`).** Im Job „Mac Gallery (macOS)“ ein Schritt nach der Galerie (`if: always()`): `log show --style compact
   --predicate 'subsystem == "com.henning.looseends" AND category == "MenuBarPanel"'` über die Laufzeit des Jobs in eine Datei,
   dann `actions/upload-artifact` als `MacGalleryPanelLog` (`if-no-files-found: warn`, `continue-on-error: true`). Ein
   fehlender Log oder Upload macht den Job nicht rot. Vorlage: `git show origin/diag/862-panel-schliesst:.github/workflows/diag-862.yml`
   und dort der Logger (`git diff origin/main...origin/diag/862-panel-schliesst -- LooseEnds/Mac/MenuBarCapture.swift`);
   die Gegenprobe dort zeigte, dass der Logger die Zeilen nicht maskiert.
4. **Aufräumen.** Nach dem Merge: Diagnose-Draft-PR #975 schließen und Zweig `diag/862-panel-schliesst` löschen.
5. **Ernte.** Nach mindestens 15 Läufen des Mac-Galerie-Jobs auf `main` (etwa 1 bis 2 Tage normaler CI-Verkehr, bei 13 %
   Trefferrate im Mittel 2 erwartete Fehler) liest Claude zu jedem erwarteten Fehler die Zeilen aus `MacGalleryPanelLog`
   selbst. Der Stichtag steht als Kommentar im Issue #978. Das Issue bleibt offen; der PR trägt `Refs #978`, nicht `Closes`.

## Test Plan

Mac-UI-Tests laufen nur im CI-Job „Mac Gallery (macOS)“ (macOS 27, App Sandbox), nie auf Hennings Mac.

### Automated Tests (TDD RED)

- [ ] Test 1: GIVEN die ausgesetzte Fassung mit `XCTSkip` WHEN der Job vor der Änderung läuft THEN meldet
  `testMenuBarReopensAfterOpenAppWithOneClick` „skipped“ (RED-Ausgangslage: der Test prüft nichts).
- [ ] Test 2: GIVEN die geänderte Fassung WHEN der Job „Mac Gallery (macOS)“ läuft THEN ist der Test ausgeführt (nicht
  übersprungen) und grün; tritt das Schließen auf, steht es als erwarteter Fehler („#978 …“) im Ergebnis, die Ampel bleibt grün.
- [ ] Test 3: GIVEN ein Lauf des Jobs WHEN der Schritt nach der Galerie endet THEN enthält das Artefakt `MacGalleryPanelLog`
  mindestens je eine `key`-Zeile der Kategorie `MenuBarPanel` (das Panel wird in der Galerie geöffnet), und `close`-Zeilen tragen
  Stapel, Ereignistyp, aktive App und Richtlinie.
- [ ] Test 4: GIVEN der Schritt „Collect panel log“ WHEN `log show` oder der Upload fehlschlägt THEN bleibt der Job „Mac Gallery
  (macOS)“ grün (`continue-on-error`).
- [ ] Test 5: GIVEN die Protokollzeilen im App-Code WHEN der Diff und ein Log eines Laufs geprüft werden THEN enthalten sie
  keinen Aufgabentext, keinen Fenstertitel und kein Token.

### Abnahme (Stufen)

1. **Tests:** Unit-Tests und iOS-Bau bleiben grün (`./scripts/sim.sh sim-unit`, `./scripts/sim.sh build`;
   `MenuBarCapture.swift` ist `#if os(macOS)`); Mac-Job grün.
2. **Simulator / Benutzung:** Die Mac-Klassen laufen nur im Job „Mac Gallery (macOS)“; dort öffnet die echte Mac-App, das ist
   die Stufe. Beleg: Artefakte `MacGallery`, `MacGalleryResults` und `MacGalleryPanelLog` des PR-Laufs, geöffnet und beschrieben.
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `testMenuBarReopensAfterOpenAppWithOneClick` / When der Diff geprüft und der Job „Mac Gallery (macOS)“ auf dem
  PR-Zweig gelaufen ist / Then enthält der Test kein `XCTSkip` mehr, der Test steht im Ergebnis als ausgeführt, und die Klickprüfung
  steht in `XCTExpectFailure(…, options: .nonStrict())` mit Verweis `#978`. Belegt durch Diff und Ergebnisbündel des PR-Laufs.
- **AC-2:** Given der Mac-Galerie-Job / When der Test das Panel öffnen kann oder das Schließen auftritt / Then ist der Job grün
  (ein Auftreten erscheint als erwarteter Fehler, kein roter Test). Belegt durch den Lauf auf dem PR-Zweig, beim ersten Versuch grün.
- **AC-3:** Given `MenuBarCapture.swift` / When das Panelfenster Key wird oder schließt / Then schreibt die App immer (auch ohne
  Testflags) eine Zeile der Kategorie `MenuBarPanel` auf Stufe Notice mit Ereignis, gekürztem Aufrufstapel, Typ von
  `NSApp.currentEvent`, Bundle-ID der aktiven App und Aktivierungsrichtlinie. Belegt durch `log show`-Zeilen im Artefakt
  `MacGalleryPanelLog` des PR-Laufs, geöffnet und beschrieben.
- **AC-4:** Given der Diff von `MenuBarCapture.swift` / When er geprüft wird / Then ändert er kein Verhalten (`applyDockPolicy`,
  `dismiss()`, `showMain` unberührt), enthält kein `print`, kein `try?`, keinen Aufgabentext, Fenstertitel oder Token in den
  Zeilen, jede Funktion ≤ 50 LoC; Unit-Tests und iOS-Bau sind grün. Belegt durch Diff-Prüfung und die Läufe.
- **AC-5:** Given `ci.yml` / When der Job „Mac Gallery (macOS)“ läuft / Then sammelt ein Schritt nach der Galerie
  (`if: always()`) die Kategorie `MenuBarPanel` per `log show` und lädt sie als `MacGalleryPanelLog` hoch; schlägt Log oder Upload
  fehl, bleibt der Job grün. Belegt durch das Artefakt im PR-Lauf und Diff-Prüfung (`continue-on-error`).
- **AC-6:** Given der Diff / When er geprüft wird / Then berührt er nur die drei genannten Dateien, kein Eintrag in `project.yml`,
  `Info.plist` oder Entitlements, App-Code ≤ 250 LoC. Belegt durch `git diff --stat`.

## Alternativen

- **A2 — Prüfwerkzeug annehmen, Test ohne Beleg umbauen** (prüft nur „Panel erschien“ statt „nach 6 s offen“): schnell, erfüllt
  aber „Ursache mit Beleg“ nicht und könnte einen echten Nutzerfehler verdecken. Es fällt keine ADR, nur die Definition of Done
  von #978.
- **A3 — weitere Diagnoseläufe auf dem Wegwerfzweig:** je Lauf etwa 30 min, bei etwa 13 % im Mittel rund 8 Durchläufe je Treffer,
  bisher 0 von 11. Teurer und langsamer als die Ernte im ohnehin laufenden Job. Es fällt keine ADR.
- **A4 — Panel selbst über `expandedInterfaceSession` steuern** (öffentliche macOS-27-API): ginge Kandidat (f) direkt an, ist
  aber ohne Befund spekulativ; das Statusitem ist aus SwiftUI nur über private Wege erreichbar. Es fällt keine ADR; erst ein
  Fix in Schnitt 2 könnte die Entscheidung für `MenuBarExtra` (#356) berühren.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine
- **Rationale:** Schnitt 1 fügt nur Protokollzeilen, eine Testklammer und einen CI-Schritt hinzu; Speicherort, Datenmodell,
  Plattformzuschnitt und Abgleich bleiben, und keine der Alternativen A2 bis A4 kippt eine bestehende ADR.

## Known Limitations

- **Ursache bleibt offen:** Schnitt 1 beweist nichts über Ursache (e) Prüfwerkzeug oder (f) App/System; er liefert nur das
  Material. Schnitt 2 (Fix oder Testumbau je nach Befund, `XCTExpectFailure` raus, drei aufeinanderfolgende grüne Läufe beim
  ersten Versuch) bekommt eine eigene Spec.
- **Selten, daher Wartezeit:** Bei etwa 13 % je Lauf ist nach 15 Läufen ein Auftreten wahrscheinlich, aber nicht sicher; bleibt
  es aus, steht das im Issue, und die Ernte läuft weiter.
- **Erwarteter Fehler verdeckt die Ampel:** Solange `XCTExpectFailure` steht, wird ein Auftreten nicht rot; deshalb liest Claude
  die Ergebnisse zu jedem Lauf selbst aus, statt sich auf die Ampel zu verlassen.
- **Unbewiesen für Nutzer:** Ob Henning oder andere Nutzer das Schließen je sehen, ist nicht belegt.

## Definition of Done

- [ ] AC-1 bis AC-6 erfüllt; Unit-Tests, iOS-Bau und Mac-Job grün; Artefakte des PR-Laufs geöffnet und beschrieben.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ PR mit `Refs #978` (nicht `Closes`).
- [ ] Nach dem Merge (kein AC, das QA-Gate kennt keinen Aufschub): Draft-PR #975 geschlossen, Zweig `diag/862-panel-schliesst`
  gelöscht, Issue #978 trägt einen Kommentar mit dem Stichtag der Ernte.
- [ ] Ernte nach mindestens 15 Läufen des Mac-Galerie-Jobs auf `main`: im Issue je erwartetem Fehler die Auswertung der Log-Zeilen
  (Stapel, Ereignistyp, aktive App, Richtlinie) samt Lauf-Nummer, oder „kein Auftreten in N Läufen“; Claude holt das selbst nach,
  #978 bleibt bis Schnitt 2 offen.

## Changelog

- 2026-11-22: Initiale Spec für #978 Schnitt 1 (Ernte der Ursache im echten Mac-Galerie-Job).
- 2026-11-22 (Phase 7): Zusätzlich das Prüfskript `scripts/test_menubar_panel_log.py` (Testcode aus Phase 4, TDD-RED; prüft Diff und Panel-Log). AC-6 meint App- und Konfigurationsdateien; Testcode zählt nach Scoping-Regel nicht mit. App-Code tatsächlich +68/−3 statt ~30 (resign/hide-Zeilen aus Adversary-Runde 3).
