# Context: 342-s2-komplikation-de

## Request Summary
#342 Schnitt 2 (Teil 4, Deutsch und Englisch): Die Uhr-Komplikation zeigt auf einem deutschen Gerät ihren Namen
„Capture“ und die Beschreibung „Opens capture.“ englisch. Beide Texte sollen auf Deutsch erscheinen, und ein Test soll
das festhalten.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsWatchWidgets/CaptureComplication.swift:55,67,96,97` | Die vier Literale: `accessibilityLabel("Capture")`, `widgetLabel("Capture")`, `configurationDisplayName("Capture")`, `description("Opens capture.")` |
| `project.yml:179-194` | Ziel `LooseEndsWatchWidgets` bindet den ganzen Ordner `LooseEndsWatchWidgets` als Quelle ein; ein Katalog dort wird ohne `project.yml`-Änderung mitgebündelt |
| `LooseEndsWidgets/Localizable.xcstrings` | Vorbild: Katalog je Ziel; enthält „Capture“ → „Erfassen“, gilt aber nur für die iPhone-Widgets |
| `LooseEnds/Resources/Localizable.xcstrings:209` | „Capture“ → „Erfassen“ im App-Katalog; das Watch-Widget bündelt ihn nicht |
| `scripts/test_infoplist_languages.py` | `CATALOGS` (4 Dateien) und `CODE_FOLDERS` (`LooseEnds`, `Shared`); der Code→Katalog-Scan sieht nur `Text(`, `Button(`, `Label(`, `LabeledContent(`, `navigationTitle(`, `String(localized:`, nicht `accessibilityLabel`, `configurationDisplayName`, `description`, `widgetLabel` |
| `LooseEndsTests/CaptureComplicationTests.swift` | Rendert die Ansicht; kompiliert `CaptureComplication.swift` in das Testziel (Texte lösen dort gegen den App-Katalog auf) |

## Existing Patterns
- Ein Katalog je Ziel (`LooseEndsWidgets`, `LooseEndsShare`), Quelle `en`, Zustand `translated` mit `de`-Wert.
- Vollständigkeit der Kataloge hält `test_infoplist_languages.py` seit #708, Code→Katalog seit #711.

## Dependencies
- Upstream: WidgetKit/SwiftUI lösen String-Literale als `LocalizedStringKey` gegen den Katalog des Ziels auf.
- Downstream: `CaptureComplicationTests` (nur Rendern, keine Textprüfung), Archivprüfung in `testflight.yml` (prüft Ziele, nicht Kataloge).

## Existing Specs
- `docs/specs/intents/feat-355-s3-komplikation.md` — Komplikation, Ziel und Dateien.
- `docs/reference/modell-verfuegbarkeit.md` — nicht betroffen.

## Risks & Considerations
- `LooseEndsWatchWidgets/` steht in der Geräteliste (Stufe 3): Die Zifferblatt-Galerie ist im Simulator nicht prüfbar. Gerätelauf nur über TestFlight und nach Hennings wörtlichem „jetzt ist ein Test möglich“.
- Ob die Texte im gebauten Watch-Widget wirklich deutsch aufgelöst werden, zeigt nur der Bau (Paket enthält `de.lproj/Localizable.strings`); das ist der Nachweis neben dem Test.
- Die Scan-Lücke (Modifier ohne `Text(`) erklärt, warum der Fehler durch #711 nicht auffiel; der Scan sollte die Modifier der Komplikation einschließen.
- Alternative zum eigenen Katalog: App-Katalog per `includes` einbinden (wie `LooseEndsWatch`), ändert `project.yml` und damit das Gate; verworfen.

## Analysis

### Type
Feature (Fehlerbehebung an der Lokalisierung, kein Verhalten wird geändert)

### Recherche (zuerst, Quellen)
- Apple-Doku: `configurationDisplayName(_:)` und `description(_:)` nehmen `LocalizedStringKey`; die Literale werden gegen den
  Katalog des Widget-Ziels aufgelöst (https://developer.apple.com/documentation/swiftui/widgetconfiguration/configurationdisplayname(_:)-4v9q).
- Forum: bekannter Fehler nur für `@Parameter`-Titel einer `WidgetConfigurationIntent` auf der echten Uhr
  (https://origin-devforums.apple.com/forums/thread/823545, FB22509406). Die Komplikation ist statisch ohne Intent: nicht betroffen.
- Keine Apple-Quelle zum genauen Katalogaufbau im Watch-Widget gefunden: der Bau (Paket enthält `de.lproj`) ist der Nachweis.

### Ursache (am Code belegt)
`LooseEndsWatchWidgets/` hat keinen Katalog. Die vier Literale (`accessibilityLabel("Capture")`, `widgetLabel("Capture")`,
`configurationDisplayName("Capture")`, `description("Opens capture.")`) finden nichts und zeigen Englisch. Der Scan aus #711 sieht
weder diesen Ordner noch diese Modifier. Reproduktion: Bau des Watch-Widgets, `de.lproj` fehlt im Paket (wird in Phase 5 vor dem Fix gezeigt).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsWatchWidgets/Localizable.xcstrings` | CREATE | „Capture“ → „Erfassen“, „Opens capture.“ → „Öffnet die Erfassung.“ |
| `scripts/test_infoplist_languages.py` | MODIFY | Katalog in `CATALOGS`; Ordner `LooseEndsWatchWidgets` und Modifier (`accessibilityLabel`, `widgetLabel`, `configurationDisplayName`, `description`) in den Scan |
| `LooseEndsWatchWidgets/CaptureComplication.swift` | UNCHANGED | Literale bleiben, nur der Katalog fehlt |
| `project.yml` | UNCHANGED | Ordner ist schon Quelle, Katalog wird mitgebündelt |

### Scope Assessment
- Files: 2 (1 neu, 1 geändert), LoC ca. +40
- Risk Level: LOW (nur Texte; Gerätestufe 3 greift, weil `LooseEndsWatchWidgets/` auf der Liste steht)

### Technical Approach
Regelweg, kein Modell. Eigener Katalog je Ziel wie bei `LooseEndsWidgets`/`LooseEndsShare`. Test: Python-Test erweitert (Katalog vollständig
deutsch; jedes Literal der Komplikation hat einen Eintrag, auch über die vier Modifier). Dazu ein Bau-Nachweis, dass das gebaute Paket
`de.lproj` mit beiden Schlüsseln enthält. Keine UI-Änderung, daher kein Entwurf nötig.

### Alternativen
- App-Katalog per `includes` einbinden (wie `LooseEndsWatch`): ändert `project.yml` und damit das Gerätegate; verworfen.
- Texte im Swift-Code per `Locale` wählen: umgeht den Katalog, bricht die Ein-Katalog-Regel; verworfen.

### Dependencies
WidgetKit/SwiftUI-Auflösung gegen Zielkatalog; `CaptureComplicationTests` bleibt unberührt.

### Open Questions
- [ ] Keine für Henning. Gerätepunkt (Zifferblatt-Galerie zeigt Deutsch) erst nach TestFlight und seinem wörtlichen „jetzt ist ein Test möglich“.
