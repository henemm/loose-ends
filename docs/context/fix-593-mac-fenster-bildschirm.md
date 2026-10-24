# Context: fix-593-mac-fenster-bildschirm

## Request Summary
Jeder Mac-UI-Test soll mit einem Hauptfenster arbeiten, das ganz auf dem CI-Bildschirm (1024 × 768 pt) liegt, gleich ob es
beim Start oder über das Menüleisten-Symbol öffnet. Die Galerie schreibt Fenster- und Bildschirmgröße mit und schlägt an,
wenn das Fenster breiter ist als der Bildschirm (#593).

## Befund aus der CI (2026-10-23, Galerie-Artefakte `MacGallery`, Notiz `mac-gallery-<hell|dunkel>-window-size.txt`)

| Lauf | Zeit (UTC) | Commit | hell | dunkel |
|---|---|---|---|---|
| 39463321124 (Fehlerbericht) | 10-20 17:07 | 8840d3f | 1200 × 674, beim Start | 1200 × 674, beim Start |
| 39477923559 | 10-20 18:48 | | 1200 × 674, beim Start | 1200 × 674, beim Start |
| 39509123547 | 10-20 22:34 | e074c0a | 1200 × 674, beim Start | 1200 × 674, beim Start |
| 39526995560 | 10-21 01:23 | ebafd62 | 1024 × 674, beim Start | 1024 × 674, über die Menüleiste |
| 39634635242, 39753273008, 39868764980, 39903937444, 39936157273 | 10-21 … 10-23 | | 1024 × 674 | 1024 × 674 |

- Die Bilder sind immer 1024 px breit (`window.screenshot()` schneidet am Bildschirmrand): bei 1200 pt fehlt ein Teil des Fensters.
- Zwischen e074c0a und ebafd62 liegen nur #598 (Testschwelle Panel-Feld) und #594 (Info.plist-Abbild, CI-Schritt). Nichts davon
  berührt Fenstergröße oder Fensteröffnung. Beide Läufe: dasselbe Abbild `xcode-27-arm64` 20261012.0260.1, macOS 27.0.1 (26A434),
  Xcode 27.0 (27A266a). Der Wechsel kommt also nicht vom Code, sondern schwankt zwischen den CI-Maschinen. Der Fehler ist seit
  neun Läufen nicht aufgetreten, kann aber jederzeit wiederkommen. Ein Test, der das bemerkt, gibt es heute nicht.
- `MacKeyboardTests.testWindowMinimumSize` vermerkt dasselbe Bild für Lauf 39776539157: Fenster (0, 31, 1024, 674) auf 1024 × 768.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEnds/App/LooseEndsApp.swift:103-120` | `WindowGroup(id: "main")`, `.defaultSize(width: 1200, height: 780)` (#514), `.frame(minWidth: 760, minHeight: 520)` und `.windowResizability(.contentMinSize)` (#480) |
| `LooseEndsUITests/MacUITestSupport.swift` | gemeinsame Hilfen aller Mac-UI-Tests: `macLaunch`, `macOpenMainWindowIfNeeded`, `macMainWindow`, `macShot`, `macWait` |
| `LooseEndsUITests/MacGalleryTests.swift:20-65` | `photograph(dark:)` schreibt `window-size.txt` (nur Fenster, kein Bildschirm), prüft nur die Mindestbreite 700 |
| `LooseEndsUITests/MacDetailClickTests.swift:52-60, 236-239` | `zoomWindow(of:)` (Fenster ▸ Zoomen) als Einzelfall-Hilfe, nur vor „Mehr“ |
| `LooseEndsUITests/MacKeyboardTests.swift:528-566` | `testWindowMinimumSize`: zieht das Fenster, liest Bildschirmgröße über `XCUIScreen.main.screenshot().image.size` |
| `.github/workflows/ci.yml:333-480` | Job „Mac Gallery (macOS)“: MacGalleryTests, MacDetailClickTests (Sandbox), MacKeyboardTests; exportiert `.png`/`.txt` als `MacGallery` |

## Existing Patterns
- Mac-Hilfen sind `XCTestCase`-Erweiterungen mit Präfix `mac` in `MacUITestSupport.swift` (geteilt seit #544).
- Größen werden als `XCTAttachment(string:)` mit Namen `mac-gallery-*` angehängt; CI exportiert sie mit den Bildern.
- Bildschirmgröße im Test: `XCUIScreen.main.screenshot().image.size` (bereits in `MacKeyboardTests` benutzt).
- Wartet auf sich setzende Rahmen mit `macWait(timeout:until:)` (#596).
- Fenster passend machen: Menü „Window“ ▸ „Zoom“ (`MacDetailClickTests.zoomWindow`).

## Dependencies
- Upstream: XCUITest (`XCUIApplication`, `XCUIScreen`, Menüleiste), SwiftUI-Szene des Hauptfensters.
- Downstream: alle drei Mac-Testklassen über `macMainWindow`/`macOpenDetail`; die Bilder in `MacGallery`, aus denen Henning
  Mac-Entwürfe und Belege sieht; `testWindowMinimumSize` (zieht und verkleinert das Fenster, darf durch ein vorheriges Zoomen
  nicht kaputtgehen: es erwartet eine Startgröße, die um > 100 pt schrumpfen kann).

## Existing Specs
- Keine Spec zu Fenstergrößen in `docs/specs/`; Bezug: #514 (Startgröße 1200 × 780), #480 (Mindestgröße 760 × 520), #511 (Galerie).

## Recherche
- Apple, `Scene.defaultWindowPlacement(_:)` (macOS 15+): Startgröße und -lage eines Fensters aus `context.defaultDisplay.visibleRect`
  (ohne Menüleiste und Dock) bestimmen; WWDC24 „Tailor macOS windows with SwiftUI“ (10148) zeigt genau das Einpassen zu großer
  Inhalte. Ob `.defaultSize` allein vom System auf den Bildschirm begrenzt wird, ist nicht dokumentiert — die CI zeigt: mal ja, mal nein.
  https://developer.apple.com/documentation/swiftui/scene/defaultwindowplacement(_:)
  https://developer.apple.com/videos/play/wwdc2024/10148/

## Risks & Considerations
- Nicht lokal nachstellbar: Hennings/dieser Mac hat einen größeren Bildschirm. Nachweis nur in der CI oder über eine erzwungene Größe.
- Zwei Wege: (A) nur Tests: nach dem Öffnen Fenster einpassen (Zoom) + Prüfung „Fenster ≤ Bildschirm“; (B) Produkt: Hauptfenster
  per `defaultWindowPlacement` nie größer als der sichtbare Bildschirm — hilft auch Nutzern mit kleinem Bildschirm, ändert aber die App.
- Zoom macht das Fenster bildschirmfüllend; `testWindowMinimumSize` und Bilder mit Annahmen über die Startgröße prüfen.
- Kein Pfad der Geräteliste berührt (weder Weg A noch `LooseEndsApp.swift` in Weg B).

## Analysis

### Type
Bug (Produkt + Testaufbau): Das Hauptfenster kann breiter öffnen als der sichtbare Bildschirm; kein Test bemerkt es.

### Root Cause
`.defaultSize(width: 1200, height: 780)` ist nur ein Wunsch. Ob macOS ihn auf den Bildschirm begrenzt, ist undokumentiert und
schwankt in der CI zwischen Maschinen (gleiches Abbild, gleicher Code: 1200 × 674 vs. 1024 × 674 auf 1024 × 768). Die Höhe wird
offenbar immer eingepasst (780 → 674), die Breite nicht immer. Nichts im Code legt die Größe am sichtbaren Bildschirm fest.

### Varianten
| Weg | Was | Wirkung CI | Wirkung Nutzer | Gegen |
|---|---|---|---|---|
| A nur Tests | nach dem Öffnen Fenster ▸ Zoomen + Prüfung | passt, Fenster immer bildschirmfüllend | keine, kleines Display bleibt zu breit | verdeckt das Produktverhalten, ein Menüklick je Test, Zoom verändert die Ausgangsgröße für `testWindowMinimumSize` |
| **B Produkt + Prüfung** | `defaultWindowPlacement`: Größe = min(1200, visible.width) × min(780, visible.height), mittig im `visibleRect`; geteilte Prüfung „Fenster passt auf den Bildschirm“ in jedem Mac-UI-Test | deterministisch 1024 × ≤ 737 | Fenster nie größer als der Bildschirm; auf Hennings Mac unverändert 1200 × 780 | neue API (Target 27 trägt sie), Nachweis nur in der CI |
| C kleinere Startgröße | `defaultSize` < 1024 | passt | Startseite ohne rechte Spalte | kippt #514 (braucht ~1120 pt) |

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEnds/Mac/MainWindowPlacement.swift` | CREATE | reine Funktion `size(preferred:visible:)` + Position, plattformneutral (Vorbild `MenuBarThreadRaster`) |
| `LooseEnds/App/LooseEndsApp.swift` | MODIFY | `.defaultWindowPlacement` am `WindowGroup(id: "main")`, `.defaultSize` bleibt als Rückfall |
| `LooseEndsTests/MainWindowPlacementTests.swift` | CREATE | großer Bildschirm → 1200 × 780; 1024 × 737 → 1024 × 737; nie unter 760 × 520 (Mindestgröße gewinnt) |
| `LooseEndsUITests/MacUITestSupport.swift` | MODIFY | `macAssertWindowFitsScreen(_:)` (wartet per `macWait`, Bildschirm in Punkten über `NSScreen.main.visibleFrame`/`frame` des Testprozesses, Rückfall `XCUIScreen`); aufgerufen aus `macMainWindow`, damit jeder Mac-Test sie durchläuft |
| `LooseEndsUITests/MacGalleryTests.swift` | MODIFY | Notiz `window-size` nennt Fenster- und Bildschirmgröße |

### Scope Assessment
- Files: 5, Estimated LoC: ~+110/-5 (Limit 4–5 Dateien gehalten: `zoomWindow` in `MacDetailClickTests` bleibt als Rückfall, wird mit der Prüfung nur nie mehr gebraucht; Entfernen ist ein eigener Schritt nach grünen Läufen)
- Risk Level: LOW — nur Startgröße neuer Hauptfenster; Mindestgröße (`.frame` + `.contentMinSize`) unverändert
- Kein Pfad der Geräteliste berührt.

### Technical Approach
Weg B. Reihenfolge: Unit-Test RED → reine Funktion → Placement in der App → geteilte Prüfung + Galerie-Notiz. Die Prüfung schlägt in jedem Mac-UI-Test an, wenn `window.frame.width > Bildschirm.width` (oder Fenster ragt hinaus).

### Risiken
- `testWindowMinimumSize`: Startgröße auf der CI bleibt 1024 × ~674 wie in den letzten neun Läufen; Schrumpfen > 100 pt weiter
  möglich (1024→760, 674→520). Mittige Lage kann die Griffe sogar erleichtern; nur in der CI prüfbar.
- Fensterwiederherstellung überschreibt das Placement; in der CI frischer Zustand, für Nutzer Randfall.
- Pixel vs. Punkte bei der Bildschirmgröße: daher `NSScreen` (Punkte) statt Screenshot-Bildgröße.
- `macOpenMainWindowIfNeeded` kehrt vor dem Öffnen des Fensters zurück → Prüfung wartet auf das Fenster.

### Nachweis
- RED: Unit-Test der reinen Funktion (lokal im iOS-Simulator).
- Der 1200-pt-Fall ist auf der CI nicht erzwingbar (seit neun Läufen weg) und lokal nicht nachstellbar (größerer Bildschirm).
  Beleg: CI-Job „Mac Gallery (macOS)“ grün, Galerie-Notiz zeigt Fenster ≤ Bildschirm in beiden Öffnungswegen, Bilder vollständig.

### Open Questions
- keine (Produktwirkung nur auf Bildschirmen < 1200 pt sichtbarer Breite: Fenster passt statt überzustehen).
