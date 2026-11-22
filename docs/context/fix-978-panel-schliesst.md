# Context: fix-978-panel-schliesst

## Request Summary
Klären, warum das Menüleisten-Panel der Mac-App nach „Open Loose Ends“ + ⌘W auf das Hauptfenster und einem Klick
aufs Symbol selten aufgeht und binnen ≤ 5 s von selbst wieder zugeht (CI `ci.yml`, Job „Mac Gallery (macOS)“,
2 von 4 Läufen rot, Diagnose-Workflow 0 von 47). Ergebnis: Ursache mit Beleg (App oder Prüfwerkzeug), dann Fix bzw.
Testumbau, `XCTSkip` weg, drei grüne Galerie-Läufe.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/Mac/MenuBarCapture.swift` | `MenuBarCaptureView` (Panel, `dismiss()` vor `MacWindows.showMain`), `MacWindows.applyDockPolicy`/`showMain`, `MacAppDelegate` (Beobachter `didBecomeKey`/`willClose` → `applyDockPolicy` async) |
| `LooseEnds/App/LooseEndsApp.swift` (o. ä.) | Szene `MenuBarExtra(.window)` mit `MenuBarCaptureView` |
| `LooseEndsUITests/MacGalleryTests.swift:463` | `testMenuBarReopensAfterOpenAppWithOneClick` (mit `XCTSkip("#978 …")`), `assertSymbolOpensPanelWithOneClick` (:480), `openPanel` (:312) |
| `LooseEndsUITests/MacUITestSupport.swift` | `macLaunch`, Panel-Hilfe (Zeile 43, kein Zweitklick seit #862) |
| `.github/workflows/ci.yml` | Job „Mac Gallery (macOS)“: `xcodebuild test -only-testing:LooseEndsUITests/MacGalleryTests`, danach Klick-/Tastaturtests im Sandbox-Bau |
| `docs/artifacts/fix-862-menubar-panel/` | `stand.md` (Chronik aller Diagnoseläufe), Zeitachsen `ci-44877016605-a3-*`, Video-Bilder |
| `docs/specs/fix-862-menubar-panel.md` | Spec des Vorgängers, Known Limitations verweisen auf #978 |

## Existing Patterns
- Panel schließt nur über SwiftUI `dismiss()` (#862), damit das Statusitem seine Sitzung beendet und ein Klick reicht.
- Dock-Richtlinie folgt den Hauptfenstern (`DockPolicy`), umgeschaltet aus Fenster-Benachrichtigungen, einen Lauf später.
- Mac-UI-Belege nur aus der CI (Anhänge `mac-gallery-*`), nie von Hennings Mac.
- Diagnose geschah auf einem Wegwerfzweig `diag/862-panel-schliesst` mit eigenem Workflow `diag-862.yml` (Draft-PR #975),
  Logger-Kategorie `Mac862`, Aufrufstapel bei `willClose`.

## Befund bisher (aus #862, Details in `stand.md`)
- Rot: `ci.yml`-Lauf 44877016605 Versuche 3 und 4, immer nur dieser Test; Panel erscheint ~1 s nach Klickbeginn, ist
  bei der ersten Abfrage weg; Hierarchie ohne Dialog.
- Grün: 36 gezielte + 11 volle Galerie-Durchläufe im Diagnose-Workflow, davon 4 mit App-Code exakt wie ausgeliefert.
- Widerlegt: (a) späte Aktivierung (Finder/Loose Ends) bei offenem Panel, (b) verspätete Richtlinienumschaltung.
- Auffällig in der Zeitachse: die Klick-Synthese aufs Statusitem dauert ~5,5 s (z. B. 358,22 → 363,72), ein
  Knopfklick 0,6 s; im roten Versuch 4 lief die Synthese 489,58–495,16, das Panel war bei 496,17 schon weg.
  Panel erscheint also **während** der laufenden Synthese (Maus gedrückt?) — Kandidat (e): Maus-Hoch lange nach
  Maus-Runter wirkt wie „Drücken-Halten-Loslassen“ und schließt das Fenster des Statusitems.
- Offene Kandidaten: (d) Umfeld/Vorzustand des `ci.yml`-Jobs (nur erste Iteration gleicht `ci.yml`), (e) Klicksynthese,
  (f) echter App-Fehler (Statusitem-Sitzung nach `dismiss()`+`openWindow`).
- Ob Nutzer das Verhalten sehen, ist nicht belegt; Henning meldete es nicht.

## Dependencies
- Upstream: SwiftUI `MenuBarExtra` (`.window`-Stil), AppKit `NSStatusItem`, `NSApp.setActivationPolicy`, XCUITest-Klicksynthese auf macOS 27.
- Downstream: nur der Mac-Galerie-Job und das Menüleisten-Erfassen der Mac-App.

## Existing Specs
- `docs/specs/fix-862-menubar-panel.md`

## Risks & Considerations
- Selten (≈ 2 von 51 Durchläufen insgesamt): Nachweis „Fehler da → weg“ braucht viele Läufe; jeder volle Galerie-Lauf ~30 min CI.
- Jobgrenze 40 min (#974) begrenzt Wiederholungen im echten Job.
- Diagnose nur auf Wegwerfzweig, nie mergen; Diagnose-PR #975 danach schließen.
- Verhältnismäßigkeit: Henning fragte bei #862 bereits danach; Aufwand begrenzen, Zwischenstand berichten.
- Recherche zuerst (Apple-Foren 836113, 836619 schon gelesen); offen: Statusitem/MenuBarExtra + lange Maus-Hoch-Verzögerung.

## Analysis

### Type
Bug (selten, Ursache offen: App oder Prüfwerkzeug)

### Recherche (2026-11-22)
- macOS 27 führt `NSStatusItem.expandedInterfaceSession` und `NSStatusItemExpandedInterfaceDelegate` (Beginn/Ende einer
  Sitzung) ein; SwiftUI-`MenuBarExtra(.window)` öffnet sein Panel darüber, die Schaltfläche hat kein target/action mehr
  (WWDC26 Session 289 „Modernize your AppKit app“, https://developer.apple.com/videos/play/wwdc2026/289/;
  https://miniswift.run/whats-new/appkit/; Fallberichte https://github.com/Zihao-Qi/Clew/pull/93,
  https://github.com/Heckscheibe/SimpleSimulatorManager/pull/127). Schließen öffentlich nur per
  `expandedInterfaceSession.cancel()`. Passt zu #862 (Sitzung muss enden, `dismiss()`).
- Keine Quelle zu „Panel öffnet und schließt sich unter XCUITest von selbst“. Forum 773715: Statusitem-Klick in
  XCUITest bewegt die echte Maus; Forum 836113: Statusitem-Ereignisse auf macOS 27 teils nicht weitergereicht.

### Neubewertung der Statistik
- Vorbefund „0/7 bei 50 % = 0,8 %“ nahm 50 % an. Gepoolt sind es 2 rote von 15 vollen Galerie-Durchläufen (≈ 13 %),
  dazu 0 von 36 gezielten Läufen. Bei 13 % sind 0 von 11 Diagnose-Durchläufen zu ~21 % Zufall. Ein Umfeld-Unterschied
  `ci.yml` ↔ `diag-862.yml` (Kandidat d) ist damit **nicht belegt**; beide Befehle sind identisch (Vergleich gelesen).
  Wahrscheinlichste Lesart: seltenes Ereignis (~1 von 8) nur im vollen Galerie-Ablauf, nie in Einzeltests.
- Folge: eigens angestoßene Diagnoseläufe (je ~30 min) sind teuer und statistisch schwach. `ci.yml` läuft aber
  ~13-mal am Tag (90 Läufe seit 2026-11-15) — der Fehler käme dort von selbst, wenn der Test aktiv wäre.

### Mögliche Ursachen (offen)
- (e) Prüfwerkzeug: XCUITests Statusitem-Klick „Synthesize event“ blockiert ~5,5 s (Knopfklick 0,6 s); das Panel
  erscheint mitten darin. Auch ⌘W braucht 5,5 s. Mausereignisfolge während der Synthese unbekannt.
- (f) App/System: die Statusitem-Sitzung (macOS 27) wird nach `dismiss()` + `openWindow` + ⌘W + Richtlinienwechsel
  `.regular → .accessory` gleich nach dem Beginn wieder beendet (von AppKit/SwiftUI, nicht von unserem Code).
- (d) Vorzustand aus den 16 vorherigen Galerie-Tests (nicht widerlegt, nicht belegt).
- Widerlegt: (a) späte Aktivierung, (b) verspätete Richtlinienumschaltung (Diagnoseläufe, `stand.md`).

### Technical Approach (Empfehlung)
Zwei Schnitte, Schnitt 1 jetzt:
- **Schnitt 1 — Ursache im echten Job ernten:** Test wieder aktiv, die Klickprüfung in
  `XCTExpectFailure(…, options: .nonStrict())` mit Verweis auf #978 (Ampel bleibt grün, ein Auftreten erscheint als
  „erwarteter Fehler“ im Ergebnis). Die App schreibt immer (nicht nur unter Tests) knappe `Logger`-Zeilen
  (Kategorie `MenuBarPanel`, Notice) für Panel-Key/Schließen samt gekürztem Aufrufstapel, `NSApp.currentEvent`-Typ,
  aktiver App und Aktivierungsrichtlinie; `ci.yml` sammelt sie nach der Galerie per `log show` als Artefakt
  `MacGalleryPanelLog` (wie `diag-862.yml`, dort erprobt; Gegenprobe zeigte: Logger maskiert nicht).
  Ernte: nach ≥ 15 Läufen des Mac-Galerie-Jobs (≈ 1–2 Tage) die Logs zu jedem erwarteten Fehler lesen.
- **Schnitt 2 — nach Befund:** Stapel zeigt AppKit/SwiftUI-Sitzungsende ohne Nutzerereignis → App-Fix (z. B. Richtlinie
  oder `openWindow` anders takten) bzw. Apple-Feedback; zeigt er ein Ereignis des Prüfwerkzeugs → Test klickt anders
  (Koordinatenklick) oder prüft das Öffnen über eine App-Meldung statt über die Abfrage nach 6 s. Dann
  `XCTExpectFailure` raus, drei grüne Läufe (DoD).
- Diagnosezweig `diag/862-panel-schliesst` und Draft-PR #975 werden damit überflüssig und in Schnitt 1 geschlossen.

### Alternativen
- **A2 — Prüfwerkzeug annehmen, Test umbauen ohne Beleg:** Test prüft nur „Panel erschien“ statt „Panel ist nach 6 s
  offen“. Schnell, erfüllt aber die DoD „Ursache mit Beleg“ nicht und könnte einen echten Nutzerfehler verdecken.
  Fällt: keine ADR, nur die DoD von #978.
- **A3 — weitere Diagnoseläufe auf dem Wegwerfzweig:** ~30 min je Lauf, bei 13 % im Mittel ~8 Durchläufe je Treffer;
  bisher 0 von 11. Teurer und langsamer als die Ernte im ohnehin laufenden Job.
- **A4 — Panel selbst über `expandedInterfaceSession` steuern** (öffentliche macOS-27-API): ginge Kandidat (f) direkt an,
  ohne Befund aber spekulativ; das Statusitem ist aus SwiftUI nur über private Wege erreichbar.

### Affected Files (Schnitt 1)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MenuBarCapture.swift` | MODIFY | `Logger`-Zeilen bei Panel-Key/Schließen (Stapel gekürzt, Ereignis, aktive App, Richtlinie) im vorhandenen Beobachter |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | `XCTSkip` raus, Klickprüfung in nicht-strenges `XCTExpectFailure` (#978) |
| `.github/workflows/ci.yml` | MODIFY | Schritt „Collect panel log“ (`log show`, Kategorie `MenuBarPanel`) + Upload `MacGalleryPanelLog` |

### Scope Assessment
- Files: 3 (App-Code 1)
- Estimated LoC: App +~30, Test ~±10, CI +~15
- Risk Level: LOW — nur Protokollzeilen im App-Code, Verhalten unverändert; Testampel bleibt grün.
- Geräteliste: kein Pfad berührt (Mac-Code in `LooseEnds/Mac/`, `ci.yml`).

### Dependencies
- Schnitt 2 hängt am Ernteergebnis; Wartezeit ≈ 1–2 Tage normaler CI-Verkehr. Claude prüft die Läufe selbst,
  Stichtag im Issue vermerken.

### Open Questions
- keine an den PO (rein technisch; in Schnitt 1 ändert sich kein Produktverhalten).
