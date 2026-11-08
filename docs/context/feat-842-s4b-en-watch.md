# Context: feat-842-s4b-en-watch

## Request Summary
#842 Schnitt 4b-1: englische App-Store-Bilder der Apple Watch (416×496, `01-jetzt`, `02-gespeichert`) nach
`docs/store/screenshots/en/watch/`, ins englische Manifest (`en-US`) eingetragen, mit englischen Beispielaufgaben.
Die deutschen Watch-Bilder bleiben unverändert. Mac ist Schnitt 4b-2, Hochladen 4c.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsWatch/LooseEndsWatchApp.swift:10-24` | `seedStoreSample`: drei feste deutsche Texte („Steuerbescheid prüfen“, „Anna wegen Geburtstag anrufen“, „Blumen gießen“), Fälligkeit von Hand auf heute; nur unter `--ui-testing` + `--ui-testing-store-sample`. **Geräteliste (Stufe 3).** |
| `LooseEndsUITests/Watch/WatchCaptureUITests.swift:72-84` | `testPhotographStoreScreens`: Start fest mit `-AppleLanguages (de)`, `-AppleLocale de_DE`; erfasst „Steuerbescheid heute prüfen“; Bestätigung wird an „Saved“ oder „Gespeichert“ erkannt (:112) |
| `LooseEndsUITests/LaunchLanguage.swift` | seit 4a `arguments(for:)`, `phrase(_:in:)` je Sprache; die Watch-UI-Tests liegen im selben Ordner, gehören aber zum Ziel `LooseEndsWatchUITests` (prüfen, ob die Datei dort mitkompiliert wird) |
| `scripts/sim.sh:695-702` | `cmd_store_watch`: Ziel fest `docs/store/screenshots/de`, ruft `cmd_watch_test` → `cmd_test` → `run_xcodebuild` (reicht `LOOSEENDS_UI_LANG` als `TEST_RUNNER_LOOSEENDS_UI_LANG` durch, :318) |
| `scripts/sim.sh:1171-1235` | 4a: `store_set_lang`/`store_restore_lang` stellen die Systemsprache eines Simulators um und per EXIT-Trap zurück; Sprachprüfung de/en vor jedem Start |
| `scripts/store_screenshots.py:249-260` | `main_watch(out_root, export)`: schreibt `watch/`, ersetzt nur den Watch-Eintrag im Manifest; Sprache steckt im Zielordner |
| `scripts/test_store_screenshots.py` | Tests für `--watch` und die Sprache (4a) |
| `docs/store/screenshots/de/watch/` | Vorbild: „Jetzt“ mit Erfassen und zwei sichtbaren Aufgaben, Uhrzeit 06:44 (echte Zeit, Simulator kann sie nicht setzen, #742); „Gespeichert“ mit Haken |
| `docs/store/screenshots/en/manifest.json` | Ziel des neuen Watch-Eintrags (heute nur iPhone, iPad) |

## Existing Patterns
- 4a (PR #872): Sprache als Parameter `LOOSEENDS_UI_LANG` (de Standard, en, sonst Abbruch vor dem Simulatorstart), Ziel `docs/store/screenshots/<lang>`, Simulator-Systemsprache für den Lauf umgestellt und zurückgesetzt.
- Beispielaufgaben iPhone/iPad liegen im Test (`LaunchLanguage`), weil die App dort per UI erfasst; auf der Watch legt die App sie selbst an (kein Regelweg auf der Uhr: `LooseEndsWatch/` ruft weder `EnrichmentCoordinator` noch `DueDateRule`, eine Fälligkeit „heute“ entsteht nicht aus dem Text).
- Englischer Wortlaut der iPhone-Bilder (freigegeben in 4a): „Check the tax notice today“, „Call Anna today about Sunday“, „Water the flowers“.

## Dependencies
- Upstream: `CaptureService.save(_:via:in:)`, `ModelContainerFactory.isUITesting`, Watch-Simulator „Apple Watch Series 12 (46mm)“, `xcresulttool export attachments`.
- Downstream: keine Produktnutzer des Seeds; der Fototest läuft nur von Hand (`store-watch`), in keiner CI-Datei.

## Existing Specs
- `docs/specs/feat-842-schnitt-4a-en-bilder-iphone-ipad.md` — Sprache als Parameter, Manifest/README je Sprache
- #742 Schnitt 2 (PR #771) — Watch-Bilder deutsch

## Risks & Considerations
- **Geräteliste:** Jede Änderung an `LooseEndsWatch/` löst Stufe 3 aus (TestFlight). Alternative ohne Produktänderung prüfen (z. B. Texte über Startargument/Umgebung statt fester Liste — braucht aber einmalig eine Produktänderung; Erfassen per UI scheidet aus, weil die Uhr keine Fälligkeit aus dem Text setzt).
- **Uhrzeit:** echte Zeit, in Englisch 12-Stunden-Format (Systemsprache des Watch-Simulators); Statusleiste der Uhr lässt sich nicht setzen.
- **Zeilenumbruch:** englische Titel können auf 416 px anders umbrechen; zwei Aufgaben müssen unter „Now“ sichtbar sein.
- **Manifest:** `main_watch` muss in `en/manifest.json` den Watch-Eintrag ergänzen, ohne iPhone/iPad zu verlieren; README `en` nicht überschreiben.
- **Wortlaut:** englische Beispielaufgaben brauchen Hennings Freigabe in der Spec (wie 4a).

## Analysis

### Type
Feature (Store-Material, englische Watch-Bilder)

### Recherche (2026-11-08)
- watchOS-Simulator: `simctl status_bar override` wird nicht unterstützt („Operation not supported“), die Uhrzeit bleibt echte Zeit (Apple-Forum 784568, FB11859744). In `en_US` erscheint sie im 12-Stunden-Format.
- App Store Connect führt Watch-Bilder je Lokalisierung; ohne eigene `en-US`-Watch-Bilder zeigt die englische Seite keine Watch-Bilder bzw. die der Hauptsprache (aso.dev „Primary Locale“, Apple-Forum 658988).

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsWatch/LooseEndsWatchApp.swift` | MODIFY | `seedStoreSample` nimmt die Beispieltexte aus dem Startargument `--ui-testing-store-sample-texts <a|b|c>`; ohne Argument die heutige deutsche Liste (deutsche Bilder bleiben gleich). Nur unter `--ui-testing` + `--ui-testing-store-sample`. |
| `LooseEndsUITests/Watch/WatchCaptureUITests.swift` | MODIFY | `testPhotographStoreScreens` liest `LOOSEENDS_UI_LANG` (Standard de), setzt `-AppleLanguages`/`-AppleLocale`, Beispieltexte und den erfassten Satz je Sprache (kleine eigene Tabelle: `LaunchLanguage.swift` gehört nicht zum Watch-Testziel). |
| `scripts/sim.sh` | MODIFY | `cmd_store_watch`: Sprache de|en wie `cmd_store_screenshots` (sonst Abbruch vor dem Simulatorstart), Ziel `docs/store/screenshots/$lang`, Systemsprache des Watch-Simulators per `store_set_lang`/`store_restore_lang` mit EXIT-Trap. Durchreichen von `LOOSEENDS_UI_LANG` an den Test besteht schon (`run_xcodebuild test`, :318). |
| `scripts/test_store_screenshots.py` | MODIFY | Test: `main_watch` ergänzt in `en/manifest.json` den Watch-Eintrag, iPhone/iPad bleiben, README unberührt. |
| `docs/store/screenshots/en/watch/*.png`, `en/manifest.json` | CREATE/MODIFY | Ergebnis des Laufs |

### Scope Assessment
- Files: 4 Code/Test + Bilder/Manifest
- Estimated LoC: ca. +60/-5
- Risk Level: LOW (Produktcode nur hinter `--ui-testing`), aber **Stufe 3 greift** (Pfad `LooseEndsWatch/`): nach dem Merge TestFlight-Bau, Henning prüft, dass die Uhr-App normal startet.

### Technical Approach
Weg E: Texte per Startargument aus dem Test, Deutsch als Rückfall. Danach beide Läufe: `store-watch` (de) muss die deutschen Bilder inhaltlich gleich lassen (Uhrzeit ausgenommen, die ist echte Zeit — deutsche Bilder werden deshalb NICHT neu geschrieben, nur der Lauf geprüft), `LOOSEENDS_UI_LANG=en store-watch` schreibt `en/watch/`.

Alternativen (Plan-Bewertung):
| Weg | `LooseEndsWatch/` berührt | trägt? | Haken |
|---|---|---|---|
| A Erfassen per Oberfläche | nein | nein | Uhr setzt keine Fälligkeit aus dem Text → nichts unter „Now“ |
| B Seed in `Shared/` | ja (Aufruf bleibt in der App) | teilweise | gleiche Stufe 3, mehr Code |
| C Store vom Test vorbefüllen | nein | zweifelhaft | Testprozess kommt nicht in die Sandbox der App |
| D Bilder nachbearbeiten | nein | nein | zeigt nicht die echte App |
| E Startargument (Empfehlung) | ja | ja | Stufe 3 |
| F Sprache aus `Locale.current` in der App, Texte in der App | ja | ja | Testdaten im Produktcode, sonst gleich |

### Dependencies
`CaptureService.save`, `ModelContainerFactory.isUITesting`, `ViewRules.nowRows`, `store_set_lang`/`store_restore_lang`, `store_screenshots.py main_watch`, `xcresulttool export attachments`.

### Open Questions
- [ ] Englischer Wortlaut (Freigabe in der Spec): Vorschlag als Gegenstück zum deutschen Watch-Seed — „Check the tax notice“, „Call Anna about her birthday“, „Water the flowers“; erfasst wird „Check the tax notice today“ (wie iPhone 4a).
- [ ] Deutsche Watch-Bilder neu schreiben oder stehen lassen? Vorschlag: stehen lassen (Uhrzeit ändert sich sonst).
