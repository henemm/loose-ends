---
entity_id: fix-593-mac-fenster-bildschirm
type: bugfix
created: 2026-10-23
updated: 2026-10-23
status: draft
workflow: fix-593-mac-fenster-bildschirm
---

# Spec: #593 Mac-Hauptfenster passt auf den Bildschirm

## Approval

- [ ] Approved (Henning)

## Purpose

Das Mac-Hauptfenster öffnet mit einer Startgröße von 1200 × 780 pt (`.defaultSize`, #514). Auf dem CI-Bildschirm
(1024 × 768 pt) war es in manchen Läufen 1200 pt breit und damit breiter als der Bildschirm: Die Galerie-Bilder schneiden
am Bildschirmrand ab, ein Teil des Fensters fehlt. Ein Test, der das bemerkt, gibt es nicht. Ziel: Das Fenster liegt beim
Öffnen immer ganz auf dem sichtbaren Bildschirm, und jeder Mac-UI-Test prüft das.

**Hat es bisher funktioniert?** Ja, bis zur schwankenden CI-Maschine. Analyse und Belege in
`docs/context/fix-593-mac-fenster-bildschirm.md`:

| Lauf | Zeit (UTC) | Fenster beim Start (hell / dunkel) |
|---|---|---|
| 39463321124 (Fehlerbericht, Commit 8840d3f) | 10-20 17:07 | 1200 × 674 / 1200 × 674 |
| 39477923559 | 10-20 18:48 | 1200 × 674 / 1200 × 674 |
| 39509123547 (e074c0a) | 10-20 22:34 | 1200 × 674 / 1200 × 674 |
| 39526995560 (ebafd62) | 10-21 01:23 | 1024 × 674 / 1024 × 674 (dunkel über die Menüleiste) |
| fünf weitere Läufe | 10-21 bis 10-23 | 1024 × 674 / 1024 × 674 |

Zwischen den Ständen e074c0a und ebafd62 liegen nur #598 und #594; beide berühren weder Fenstergröße noch Fensteröffnung.
Beide Läufe nutzten dasselbe Abbild (`xcode-27-arm64` 20261012.0260.1, macOS 27.0.1, Xcode 27.0). Der Wechsel kommt nicht vom
Code, sondern schwankt zwischen den CI-Maschinen. Ursache: `.defaultSize` ist nur ein Wunsch; ob macOS ihn auf den Bildschirm
begrenzt, ist nicht dokumentiert. Die Höhe wird offenbar immer eingepasst (780 → 674), die Breite nicht immer. Nichts im Code
legt die Größe am sichtbaren Bildschirm fest. Der Fehler ist seit neun Läufen nicht mehr aufgetreten, kann aber jederzeit
wiederkommen.

Regelweg-Vermerk (Regeln vor Modell): Kein Modell beteiligt; es ist eine reine Rechenregel (Minimum und Mitte) und eine
Testprüfung.

## Source

- **File:** `LooseEnds/Mac/MainWindowPlacement.swift` (neu), angewendet in `LooseEnds/App/LooseEndsApp.swift`
- **Identifier:** `MainWindowPlacement` (reine Funktion), `macAssertWindowFitsScreen(_:)` in `LooseEndsUITests/MacUITestSupport.swift`

## Lösung

Weg B (Produkt + Prüfung), gewählt in der Analyse:

1. **`LooseEnds/Mac/MainWindowPlacement.swift` (neu).** Eine reine, plattformneutrale Funktion, die aus gewünschter Größe,
   Mindestgröße und sichtbarem Bereich (`visibleRect`) das Rechteck des Fensters liefert:
   - Größe = `min(gewünscht, sichtbare Größe)` je Achse, danach nie unter der Mindestgröße (760 × 520, #480; die Mindestgröße
     gewinnt, auch wenn der Bildschirm kleiner ist).
   - Lage = Mitte des `visibleRect`; ragt das Fenster wegen der Mindestgröße hinaus, beginnt es an der oberen linken Ecke des
     `visibleRect` statt außerhalb davon.
   - Aufbau wie `LooseEnds/Mac/MenuBarThreadImage.swift`: Die Datei importiert nur `CoreGraphics`/`Foundation` und steht ohne
     `#if os(macOS)`. Die Hauptapp-Quelle `LooseEnds` (`project.yml`, `sources: LooseEnds`) wird ganz in die iOS-App übersetzt,
     `LooseEndsTests` testet sie per `@testable import LooseEnds` im iOS-Simulator, wie `MenuBarThreadRaster`. Kein Eintrag in
     `project.yml` nötig.
2. **`LooseEnds/App/LooseEndsApp.swift`.** Am `WindowGroup(id: "main")` (innerhalb des bestehenden `#if os(macOS)`) kommt
   `.defaultWindowPlacement { content, context in ... }` hinzu (`Scene.defaultWindowPlacement(_:)`, macOS 15+; das Target 27
   trägt es). Der Block liest `context.defaultDisplay.visibleRect`, ruft die reine Funktion mit 1200 × 780 und 760 × 520 und
   gibt `WindowPlacement(position, size)` zurück. `.defaultSize(width: 1200, height: 780)` bleibt als Rückfall stehen.
   `.frame(minWidth: 760, minHeight: 520)` und `.windowResizability(.contentMinSize)` bleiben unverändert.
3. **`LooseEndsUITests/MacUITestSupport.swift`.** Neue Hilfe `macAssertWindowFitsScreen(_:)`: wartet per `macWait` (Rahmen setzen
   sich erst), liest die Bildschirmgröße in Punkten (`NSScreen.main?.frame`, Rückfall `XCUIScreen.main.screenshot().image.size`,
   wie schon in `MacKeyboardTests`) und schlägt an, wenn `window.frame` breiter ist als der Bildschirm oder rechts bzw. unten
   hinausragt. `macMainWindow(of:)` ruft sie nach dem Finden des Fensters auf, damit jeder Mac-UI-Test sie durchläuft.
   Weil `macMainWindow` auf das Fenster wartet (`waitForExistence`), greift die Prüfung auch, wenn das Fenster erst über die
   Menüleiste öffnet (`macOpenMainWindowIfNeeded` kehrt vorher zurück).
4. **`LooseEndsUITests/MacGalleryTests.swift`.** Die Notiz `mac-gallery-<hell|dunkel>-window-size` nennt Fenster- und
   Bildschirmgröße (z. B. „1024 x 674 pt on screen 1024 x 768 pt; window at launch: yes“), damit Henning und die CI-Belege beide
   Größen sehen.

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `LooseEnds/Mac/MainWindowPlacement.swift` | CREATE | reine Funktion: Größe auf `visibleRect` begrenzt, Mindestgröße gewinnt, Lage mittig |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `.defaultWindowPlacement` am `WindowGroup(id: "main")` (nur macOS), `.defaultSize` bleibt |
| `LooseEndsTests/MainWindowPlacementTests.swift` | CREATE | Regelfälle der reinen Funktion (RED zuerst) |
| `LooseEndsUITests/MacUITestSupport.swift` | MODIFY | `macAssertWindowFitsScreen(_:)`, Aufruf aus `macMainWindow` |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | Notiz `window-size` nennt Fenster und Bildschirm |

### Estimated Changes

- Dateien: 5 (Limit 4–5 gehalten)
- LoC: ca. +110 / −5, jede Funktion ≤ 50 LoC

**Geräteliste (CLAUDE.md):** Berührt werden `LooseEnds/App/LooseEndsApp.swift`, `LooseEnds/Mac/`, `LooseEndsTests/` und
`LooseEndsUITests/`. Keiner dieser Pfade steht auf der Liste (`Shared/Enrichment/…`, `Shared/Persistence/`, `LooseEndsWatch*/`,
`LooseEndsWidgets/`, `LooseEndsShare/`, `Shared/Intents/`, `LooseEnds/Speech/`, `LooseEnds/Notifications/`, `project.yml`,
`*.entitlements`, `Info.plist`). Kein Eintrag in `project.yml`, keine Berechtigung, kein AppStorage-Schlüssel, keine Audio-Datei.

### Nicht in diesem Ticket

- Entfernen von `zoomWindow(of:)` in `MacDetailClickTests` (bleibt als Rückfall; eigener Schritt nach grünen Läufen).
- Änderung der Mindestgröße (#480) oder der Startgröße 1200 × 780 (#514).
- Fensterwiederherstellung des Systems (überschreibt das Placement, für Nutzer ein Randfall).
- Alle anderen Fenster (Einstellungen, Menüleisten-Panel).

## Test Plan

### Automated Tests (TDD RED)

`LooseEndsTests/MainWindowPlacementTests.swift` (Swift Testing, im iOS-Simulator), zuerst rot, weil die Funktion fehlt:

- [ ] Test 1: GIVEN `visibleRect` 1024 × 737 WHEN gewünscht 1200 × 780 THEN Größe 1024 × 737.
- [ ] Test 2: GIVEN ein großer Bildschirm (z. B. 2056 × 1329) WHEN gewünscht 1200 × 780 THEN Größe 1200 × 780.
- [ ] Test 3: GIVEN ein Bildschirm kleiner als die Mindestgröße (z. B. 700 × 480) THEN Größe 760 × 520 (Mindestgröße gewinnt).
- [ ] Test 4: GIVEN ein `visibleRect` mit Ursprung ≠ (0, 0) (Dock/Menüleiste) THEN das Fenster ist in diesem Rechteck zentriert.
- [ ] Test 5: GIVEN Größe = `visibleRect` (1024 × 737) THEN das Fenster liegt ganz im `visibleRect` (Ursprung = Ursprung des Rechtecks).
- [ ] Test 6: GIVEN Mindestgröße größer als das `visibleRect` THEN beginnt das Fenster an dessen oberer linker Ecke.

UI-Prüfung (`macAssertWindowFitsScreen`) läuft in den bestehenden Klassen `MacGalleryTests`, `MacDetailClickTests`,
`MacKeyboardTests` über `macMainWindow`. Ein eigener Test, der die Prüfung durchfallen lässt, wäre ein absichtlich roter CI-Test
und wird nicht geschrieben; ihre Wirkung belegen AC-5 (Code-Prüfung am Diff: Vergleich, Meldung) und AC-6 (Galerie-Notiz).

### Abnahme (Stufen)

1. **Tests:** `./scripts/sim.sh generate`, dann `./scripts/sim.sh sim-unit` (nie `unit`, nie Mac als Host): neue Tests rot vor,
   grün nach der Funktion. Der 1200-pt-Fall ist lokal nicht nachstellbar (größerer Bildschirm); er wird durch Test 1 als Regel
   belegt, das Verhalten im echten Fenster in der CI.
2. **Simulator / Benutzung:** `./scripts/sim.sh test-proof` fährt UI-Tests im iOS-Simulator; die Mac-Klassen laufen nur im
   CI-Job „Mac Gallery (macOS)“ auf macOS (App Sandbox, `.github/workflows/ci.yml`). Für diese Änderung greift `test-proof`
   deshalb nicht; die iOS-App bleibt unberührt (`./scripts/sim.sh build` muss weiter grün sein). Beleg der Benutzung ist der
   grüne CI-Lauf „Mac Gallery (macOS)“: Dort öffnet die echte Mac-App, die Galerie-Notiz zeigt Fenster ≤ Bildschirm in beiden
   Öffnungswegen (Start und Menüleiste), und die Bilder `mac-gallery-*` werden geöffnet und beschrieben (vollständiges Fenster,
   nichts am rechten Rand abgeschnitten).
3. **Gerät:** Kein Pfad der Geräteliste berührt.

## Acceptance Criteria

- **AC-1:** Given `visibleRect` 1024 × 737 und gewünschte Größe 1200 × 780 / When `MainWindowPlacement` die Größe berechnet / Then
  ist sie 1024 × 737. Belegt durch Unit-Test (Test 1, zuerst rot).
- **AC-2:** Given ein Bildschirm, größer als 1200 × 780 / When die Größe berechnet wird / Then ist sie 1200 × 780 (auf Hennings Mac
  unverändert). Belegt durch Unit-Test (Test 2).
- **AC-3:** Given ein sichtbarer Bereich kleiner als 760 × 520 / When die Größe berechnet wird / Then ist sie 760 × 520
  (Mindestgröße gewinnt), und das Fenster beginnt an der oberen linken Ecke des Bereichs. Belegt durch Unit-Tests (Test 3 und 6).
- **AC-4:** Given ein `visibleRect` beliebigen Ursprungs, in das das Fenster passt / When die Lage berechnet wird / Then ist das
  Fenster in diesem Rechteck zentriert und liegt ganz darin. Belegt durch Unit-Tests (Test 4 und 5).
- **AC-5:** Given `macAssertWindowFitsScreen` / When das Hauptfenster breiter ist als der Bildschirm (oder rechts bzw. unten
  hinausragt) / Then schlägt der Test mit einer Meldung an, die beide Größen nennt; `macMainWindow(of:)` ruft die Prüfung auf, so
  dass jeder Mac-UI-Test sie durchläuft. Belegt durch Code-Prüfung am Diff (Vergleich, Meldung, Aufruf in `macMainWindow`) und
  den grünen CI-Lauf, in dem sie alle drei Mac-Testklassen durchläuft.
- **AC-6:** Given die Galerie `MacGalleryTests` in der CI / When sie läuft, beim Start und über die Menüleiste geöffnet / Then
  enthält die Notiz `mac-gallery-<hell|dunkel>-window-size` Fenster- und Bildschirmgröße, und das Fenster ist nicht breiter als
  der Bildschirm. Belegt durch die Artefakte `MacGallery` des grünen Laufs „Mac Gallery (macOS)“.
- **AC-7:** Given `LooseEndsApp.swift` / When der Diff geprüft wird / Then trägt `WindowGroup(id: "main")` `.defaultWindowPlacement`
  (unter `#if os(macOS)`), `.defaultSize(width: 1200, height: 780)`, `.frame(minWidth: 760, minHeight: 520)` und
  `.windowResizability(.contentMinSize)` bleiben unverändert, und `MacKeyboardTests.testWindowMinimumSize` läuft im CI-Lauf
  weiter grün. Belegt durch Diff-Prüfung und den grünen CI-Job.
- **AC-8:** Given der Diff / When er geprüft wird / Then berührt er nur die fünf genannten Dateien, kein Pfad der Geräteliste;
  kein `try?`, kein `print`, jede Funktion ≤ 50 LoC; alle bestehenden Unit-Tests und der iOS-Bau sind grün.

## Dependencies

| Entity | Type | Purpose |
|---|---|---|
| SwiftUI `Scene.defaultWindowPlacement(_:)` | API (macOS 15+) | Startgröße und -lage aus `context.defaultDisplay.visibleRect` (WWDC24 10148, „Tailor macOS windows with SwiftUI“); Target 27 trägt sie |
| XCUITest (`XCUIApplication`, `XCUIScreen`) | Framework | Fensterrahmen und Bildschirmgröße in den Mac-UI-Tests |
| `LooseEnds/Mac/MenuBarThreadImage.swift` (`MenuBarThreadRaster`) | Vorbild | plattformneutrale reine Funktion, im iOS-Unit-Test-Target getestet |
| `macWait(timeout:until:)` (#596) | Test-Hilfe | wartet auf sich setzende Rahmen |
| #480 (Mindestgröße 760 × 520), #514 (Startgröße 1200 × 780), #511 (Galerie), #544 (geteilte Mac-Hilfen) | Vorarbeit | bleiben unverändert bzw. werden genutzt |
| `MacKeyboardTests.testWindowMinimumSize` | Test | muss weiter laufen (erwartet eine Startgröße, die um > 100 pt schrumpfen kann) |

Keine neue externe Abhängigkeit.

## Risiken

- **Nachweis nur in der CI (mittel):** Der 1200-pt-Fall ist lokal nicht nachstellbar und auf der CI seit neun Läufen nicht mehr
  erzwingbar. Die Regel ist durch Unit-Tests belegt; das Zusammenspiel mit dem Fenster zeigt nur der CI-Lauf. Ob
  `defaultWindowPlacement` die Größe gegenüber `defaultSize` durchsetzt, ist erst dort sichtbar.
- **`testWindowMinimumSize` (niedrig):** Startgröße auf der CI bleibt 1024 × ~674 wie in den letzten Läufen; Schrumpfen um mehr
  als 100 pt (1024 → 760, 674 → 520) bleibt möglich. Die mittige Lage verschiebt die Fenstergriffe; nur in der CI prüfbar.
- **Fensterwiederherstellung (niedrig):** Gespeicherte Fensterlage überschreibt das Placement; in der CI frischer Zustand, für
  Nutzer ein Randfall.
- **Punkte statt Pixel (niedrig):** Die Bildschirmgröße kommt in Punkten aus `NSScreen`; der Screenshot-Rückfall kann auf
  Retina-Bildschirmen in Pixeln messen und wird nur genutzt, wenn `NSScreen` fehlt.
- **Koordinatenursprung (geklärt):** Apples Beispiel zu `defaultWindowPlacement(_:)` setzt ein Fenster „140 points from the bottom“
  mit `y: displayBounds.maxY - size.height - 140`. Die Lage ist also die obere linke Ecke des Fensters, y wächst nach unten.
  Die reine Funktion rechnet genau so: „obere linke Ecke“ = `visibleRect.minX`, `visibleRect.minY`
  (https://developer.apple.com/documentation/swiftui/scene/defaultwindowplacement(_:)).
- **Prüfung zu früh (niedrig):** `macOpenMainWindowIfNeeded` kehrt vor dem Öffnen des Fensters zurück; die Prüfung wartet deshalb
  per `macWait` auf einen gesetzten Rahmen.

## Alternativen

- **A, nur Tests (Zoom nach dem Öffnen):** Fenster ▸ Zoomen und Prüfung. Passt in der CI, verdeckt aber das Produktverhalten, kostet
  einen Menüklick je Test, macht das Fenster bildschirmfüllend und verändert die Ausgangsgröße für `testWindowMinimumSize`;
  Nutzer mit kleinem Bildschirm bleiben ungeschützt. Verworfen.
- **C, kleinere `defaultSize` (< 1024):** Passt auf die CI, aber die Startseite mit rechter Spalte braucht etwa 1120 pt (#473):
  kippt die Festlegung aus #514. Verworfen.
- **Nur Prüfung ohne Produktänderung:** meldet den Fehler, behebt ihn aber nicht. Verworfen.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Grund: Reine Startgrößen-Regel und Testprüfung; weder Speicherort, Datenmodell, Plattformzuschnitt noch
  Abgleich ändern sich. Startgröße (#514) und Mindestgröße (#480) bleiben, es kommt nur die Begrenzung auf den sichtbaren
  Bildschirm hinzu.

## Offene Fragen

- Keine. Produktwirkung nur auf Bildschirmen mit weniger als 1200 pt sichtbarer Breite (oder 780 pt Höhe): Das Fenster passt,
  statt überzustehen.

## Definition of Done

- [ ] AC-1 bis AC-8 erfüllt; die Unit-Tests zuerst rot, dann grün; `./scripts/sim.sh sim-unit` und `./scripts/sim.sh build` grün.
- [ ] CI-Job „Mac Gallery (macOS)“ grün (Galerie, Sandbox-Klick-Tests, Tastatur-Tests); Galerie-Notizen zeigen Fenster ≤ Bildschirm
  in beiden Öffnungswegen, Bilder geöffnet und beschrieben.
- [ ] Abschlussbericht: „Kein Pfad der Geräteliste berührt.“ Das Mac-Fenster öffnet nie breiter als der sichtbare Bildschirm; die
  Mac-Tests melden es, falls doch. PR mit `Closes #593`.

## Changelog

- 2026-10-23: Initiale Spec für #593 (Weg B: Produkt + Prüfung).
