# Context: feat-842-s4-en-bilder

## Request Summary
#842 Schnitt 4: englische App-Store-Bilder (iPhone, iPad, Apple Watch, Mac) aus der App auf Englisch erzeugen und in die
en-US-Lokalisierung der bearbeitbaren Version (heute iOS 1.0.1, `PREPARE_FOR_SUBMISSION`) bringen. Beleg = Store-Probe zeigt
en-US mit Bildsätzen (DoD #842).

## Stand vor diesem Schnitt (2026-11-07)
- S1–S3 gemergt (PR #857, Fix Platzierungspfad, PR #861). Englische Texte am 2026-11-07 geschrieben: Lauf 42344072666,
  iOS 1.0.1 en-US Beschreibung, Schlüsselwörter, Support-URL, Werbetext, `gegenprobe gleich=ja`. Mac: keine bearbeitbare
  Version (macOS 1.0 `READY_FOR_SALE`), nichts geschrieben.
- Deutsche Bilder: von Henning per Hand hochgeladen (#742, 2026-10-31), belegt durch `asc-store-probe.yml`. Ein
  Hochlade-Werkzeug für Store-Bilder gibt es **nicht**; nur `asc_header_upload.py` lädt Kopfbilder in die Asset-Bibliothek.
- Probe 42270571558: iOS 1.0.1 de-DE hat Bildsätze (`APP_IPHONE_61`, `APP_IPAD_PRO_3GEN_129`, `APP_WATCH_SERIES_10`) **und**
  „Platzierungen“ (`/placements`, Gruppen `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`, `IPAD_13_PROFILE`, `WATCH_SERIES_10_PROFILE`,
  Typ `APP_SCREENSHOT`, plus `APP_STORE_SEARCH_RESULTS_ASSET`). Apple führt beide Modelle parallel.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/StoreScreenshotsTests.swift` | iPhone/iPad-Bilder; Sprache hart `-AppleLanguages (de)`, deutsche Aufgabentexte, deutsche Labels in Abfragen („30 Min.“, „Computer“, „Zurück“, „ausblenden“, „Seitenleiste ausblenden“) |
| `LooseEndsUITests/MacStoreScreenshotsTests.swift` | Mac-Bilder, `macLaunch(locale: "de_DE")`, deutsche Aufgaben |
| `LooseEndsUITests/Watch/WatchCaptureUITests.swift` | `testPhotographStoreScreens` der Watch |
| `LooseEndsWatch/LooseEndsWatchApp.swift` | `seedStoreSample`: drei deutsche Beispielaufgaben unter `--ui-testing-store-sample` (Produktcode, nur Testmodus) |
| `LooseEndsUITests/LaunchLanguage.swift` | Sprache der UI-Tests aus `LOOSEENDS_UI_LANG` (Standard en), `phrase(_:)` je Sprache |
| `scripts/sim.sh` (`cmd_store_screenshots`, `cmd_store_watch`) | Erzeugung; Ziel fest `docs/store/screenshots/de`; reicht `LOOSEENDS_UI_LANG` als `TEST_RUNNER_…` durch (Zeile ~318) |
| `scripts/store_screenshots.py` (273 Z.) | Export → Ordner + `manifest.json`; `"sprache": "de-DE"` und README-Text fest verdrahtet |
| `.github/workflows/store-mac.yml` | Mac-Bilder nur in der CI (nie auf Hennings Mac), Artefakt `StoreMac` |
| `docs/store/screenshots/de/` | Ablage + README + manifest; englisch käme nach `docs/store/screenshots/en/` |
| `scripts/asc_store_probe.py` | Lese-Beleg (Bildsätze, Bilder, Platzierungen) |
| `scripts/asc_header_upload.py` | Vorbild Hochladen: POST mit `fileSize`/`fileName`, `uploadOperations` (PUT der Bytes), PATCH `uploaded: true`, Warten auf Zustand |
| `scripts/asc_version_texts.py` | Vorbild Versionswahl `editable_version` (genau eine `PREPARE_FOR_SUBMISSION` je Plattform) |
| `Shared/Models/TaskContext.swift`, `Shared/Language/EnglishPack.swift` | englische Standard-Tags (Computer, Phone, Home, Garden, Errands, …) — „Computer“ gleich in beiden Sprachen |

## Existing Patterns
- Bilder entstehen nur aus echten UI-Tests (`test-proof`/CI), nie von Hand; Statusleiste 9:41 per `simctl status_bar`.
- Aufgaben nur im Speicher (`--ui-testing`), kein Modell (`ModelOffEnricher`).
- ASC-Handläufe: `workflow_dispatch`, Aktion `lesen` (nur GET) vs. schreibende Aktion, Unit-Tests mit API-Nachbau vorweg,
  Gegenprobe nach dem Schreiben, Schlüssel nur im Lauf.
- Sprachmatrix der UI-Tests (#761): `LaunchLanguage.code`, CI-Job `ui-smoke-lang`.

## Dependencies
- Upstream: englische Lokalisierung der App (`Localizable.xcstrings`, `EnglishPack`), UI-Test-Hilfen (`MacUITestSupport.swift`),
  ASC-API (App Screenshot Sets / App Screenshots, oder Asset-Bibliothek + Placements), ASC-Schlüssel im Secret.
- Downstream: Einreichung iOS 1.0.1 (Henning), Store-Probe als Beleg; spätere Mac-Version braucht dieselben Bilder.

## Existing Specs
- `docs/specs/feat-842-schnitt-1-probe-texte.md`, `feat-842-schnitt-2-platzierungspfad.md`, `feat-842-schnitt-3-texte-schreiben.md`
- `docs/specs/feat-837-schnitt-2-schreibweg.md` (App-Info-Schreibweg)
- #742 (deutsche Bilder) und #772 (Kopfbilder-Upload)

## Risks & Considerations
- **Zwei Bildmodelle bei Apple:** klassische `appScreenshotSets`/`appScreenshots` und neue Asset-Bibliothek mit Platzierungen
  (API 4.5). Welcher Weg für eine neue Lokalisierung gilt bzw. ob das eine das andere speist, muss die Analyse mit Apples Doku
  klären (Recherche zuerst).
- Umfang: Test-Umbau auf Sprache (4 Geräte) + Ablage/Manifest je Sprache + neues Hochladeskript mit Tests sprengt 250 LoC →
  Teilung erwartet (a: Bilder erzeugen, b: hochladen).
- Englische Beispielaufgaben sind sichtbarer Store-Inhalt → Wortlaut braucht Hennings Freigabe (Spec), ggf. Vorschau.
- Deutsche Bilder dürfen sich nicht ändern (gleiche Tests, Sprache als Parameter; Standard bleibt de für Store-Tests).
- Mac-Bilder: keine bearbeitbare Mac-Version; Bilder erzeugen ja, hochladen erst mit der nächsten Mac-Version.
- Watch-Beispieldaten stehen im Watch-Produktcode: Änderung in `LooseEndsWatch/` löst laut Geräteliste Stufe 3 aus
  (nur Testmodus betroffen; ggf. Daten in den Test verlagern).
- iPad-Tastatur/Seitenleisten-Labels sind sprachabhängig („ausblenden“/„dismiss“, „Seitenleiste ausblenden“/„Hide Sidebar“) —
  teilweise schon zweisprachig abgefragt.

## Analysis

### Type
Feature (Store-Inhalt + Werkzeug), kein Produktcode außer ggf. Watch-Testmodus.

### Recherche (2026-11-07, Apple-Doku)
- „Uploading Assets to App Store Connect“: `appScreenshotSets`/`appScreenshots` sind **deprecated**; Bilder laufen über
  App Asset Library + Placements. https://developer.apple.com/documentation/appstoreconnectapi/uploading-assets-to-app-store-connect
- „Migrating to the App Asset Library“: GET `/v1/apps/{id}/assetLibrary` → POST `/v1/appAssetLibraryImages`
  (`fileName`, `fileSize`, `category` = `APP_SCREENSHOTS_AND_PREVIEWS`, `referenceName`, rel `assetLibrary`) → PUT
  `uploadOperations` → PATCH `uploaded: true` (keine Prüfsumme) → warten auf `PREPARE_FOR_SUBMISSION` → POST
  `/v1/appAssetLibraryPlacements`. Gruppen-IDs aus den Referenzdaten lesen, nicht fest verdrahten.
  https://developer.apple.com/documentation/appstoreconnectapi/migrating-to-the-app-asset-library
- „Placing assets on your App Store surfaces“: Platzierung = `placementType` `APP_SCREENSHOT` + `placementGroup` + rel
  `image` + rel `appStoreVersionLocalization`; unveränderlich (nur löschen + neu); Eltern muss editierbar sein (409
  `STATE_ERROR.INVALID_STATE` sonst); max. 10 Screenshots je Gruppe; Reihenfolge per POST
  `/v1/appAssetLibraryPlacementOrderingRequests` (`placementGroup`, `orderedPlacements`, rel Lokalisierung); Lesen
  `GET /v1/appStoreVersionLocalizations/{id}/placements?sort=placementGroupPosition`. Platzierung geht mit der Version
  durch die Prüfung; das Bild braucht keine eigene Freigabe vor dem Platzieren.
  https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces
- „Uploading and managing image assets“: Zustände `AWAITING_UPLOAD` → `UPLOAD_COMPLETE` → `PREPARE_FOR_SUBMISSION` | `FAILED`;
  `specId` nach Verarbeitung gegen Referenzdaten prüfen; Bild löschen erst nach seinen Platzierungen.
  https://developer.apple.com/documentation/appstoreconnectapi/uploading-and-managing-image-assets
- Fremdbericht: rorkai/App-Store-Connect-CLI PR #3271 nennt dieselbe Deprecation (API 4.5.1), Bibliotheksweg dort nur
  mit Attrappen geprüft. https://github.com/rorkai/App-Store-Connect-CLI/pull/3271

### Befunde Code
- `StoreScreenshotsTests.swift` (251 Z.): Sprache fest L27; deutsche Aufgaben L10–15; sprachabhängige Abfragen L97
  „30 Min.“, L203 `complete("Blumen")`, L232 „Steuerbescheid“; Zurück/ausblenden/Seitenleiste schon zweisprachig;
  „Computer“ gleich in beiden Sprachen. Nutzt `LaunchLanguage` nicht (Standard dort ist `en`!).
- `MacStoreScreenshotsTests.swift` (58 Z.): `macLaunch(locale: "de_DE")` L18, Aufgaben L9–10; Mac-Bilder nur in CI
  (`store-mac.yml`, ohne Sprache).
- Watch: `WatchCaptureUITests.testPhotographStoreScreens` L74 Sprache fest, L81 getippter Text; Beispielaufgaben im
  Produktcode `LooseEndsWatch/LooseEndsWatchApp.swift` `seedStoreSample` L17 (nur unter `--ui-testing-store-sample`).
  Watch-UI-Test-Target kompiliert `LaunchLanguage.swift` nicht (`project.yml` L366–370).
- `sim.sh` `cmd_store_screenshots` (L1165–1187) / `cmd_store_watch` (L696–704): Ziel `docs/store/screenshots/de` fest;
  Belege `store-proof-$device.txt` würden je Sprache überschrieben; `LOOSEENDS_UI_LANG` wird schon als `TEST_RUNNER_…`
  durchgereicht (L317–318).
- `store_screenshots.py`: `"sprache": "de-DE"` L95, README L28–30 fest; `test_store_screenshots.py` L113.
- `asc_header_upload.py` (211 Z.) kann Bibliotheks-Upload schon (`Client`, `put_bytes`, `wait_ready`, `upload`), platziert
  nie; `asc_version_texts.py` hat `editable_version`/`localizations`; `asc_locales.py` `en` → `en-US`.
- `EnglishPack`: „call“ → Phone, „lawn“/„mow“ → Garden — englische Beispiele bekommen dieselben Etiketten wie die deutschen.

### Affected Files (with changes)
| File | Change Type | Schnitt | Description |
|------|-------------|---------|-------------|
| `LooseEndsUITests/StoreScreenshotsTests.swift` | MODIFY | 4a | Sprache aus `LaunchLanguage`, Aufgaben/Abfragen je Sprache |
| `LooseEndsUITests/LaunchLanguage.swift` | MODIFY | 4a | Store-Phrasen de/en |
| `scripts/sim.sh` | MODIFY | 4a/4b | Ziel `docs/store/screenshots/<lang>`, Belege je Sprache, `LOOSEENDS_UI_LANG` Standard `de` für Store-Läufe |
| `scripts/store_screenshots.py` + `scripts/test_store_screenshots.py` | MODIFY | 4a | Sprache als Argument (Manifest, README) |
| `LooseEndsUITests/Watch/WatchCaptureUITests.swift` | MODIFY | 4b | Sprache + getippter Text |
| `LooseEndsWatch/LooseEndsWatchApp.swift` | MODIFY | 4b | Beispielaufgaben je Sprache (Testmodus) — Geräteliste |
| `LooseEndsUITests/MacStoreScreenshotsTests.swift` + `.github/workflows/store-mac.yml` | MODIFY | 4b | Sprache als Eingabe |
| `scripts/asc_store_images.py` + `scripts/test_asc_store_images.py` | CREATE | 4c | Bibliothek-Upload (Import aus `asc_header_upload`), Platzierung, Reihenfolge, Gegenprobe |
| `.github/workflows/asc-store-images.yml` | CREATE | 4c | Handlauf `lesen` / `platzieren` |
| `docs/store/screenshots/en/**` | CREATE | 4a/4b | erzeugte Bilder + Manifest |

### Scope Assessment
- Gesamt ≈ 11 Dateien, ≈ +600–800 LoC inkl. Tests → **drei Teilschnitte** (je ≤ 250 LoC):
  - **4a** iPhone + iPad englisch erzeugen (≈ 4 Dateien, ≈ 150–200 LoC)
  - **4b** Watch + Mac englisch erzeugen (≈ 4 Dateien, ≈ 120 LoC)
  - **4c** Hochladen + Platzieren in en-US iOS 1.0.1 (≈ 3 Dateien, ≈ 250 LoC; ggf. 4c-1 Skript, 4c-2 Workflow)
- Risk Level: MEDIUM — 4a/4b lokal und umkehrbar; 4c schreibt bei Apple (Platzierungen nur löschbar, nicht änderbar).

### Technical Approach (Empfehlung)
- Bilder aus denselben UI-Tests, Sprache als Parameter; Store-Läufe setzen `LOOSEENDS_UI_LANG` ausdrücklich (Standard `de`,
  damit die deutschen Bilder unverändert bleiben; Vergleich der de-Bilder/Manifest vorher/nachher gehört in den Beleg).
- Hochladen über App Asset Library + Placements (Apples aktueller Weg), aufbauend auf `asc_header_upload.py`:
  Gruppen aus der deutschen Lokalisierung bzw. Referenzdaten (`IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`, `IPAD_13_PROFILE`,
  `WATCH_SERIES_10_PROFILE`), idempotent (vorhandene Platzierungen lesen), `lesen` vor jedem Schreiben, nie einreichen,
  Beleg = Store-Probe zeigt en-US mit Platzierungen.
- Mac: Bilder in 4b erzeugen, Upload erst mit der nächsten bearbeitbaren Mac-Version (eigenes Ticket bei Bedarf).
- Reihenfolge: 4a → 4b → 4c (4c braucht die fertigen Dateien aller iOS-Geräte).

### Alternativen
1. **Henning lädt die englischen Bilder per Hand hoch** (wie #742): spart 4c (~250 LoC + Tests), kostet ihn Zeit, nicht
   wiederholbar. Kippt nichts; widerspricht „Henning bekommt nichts zu tun“.
2. **Alter Bildsatz-Weg** (`appScreenshotSets`): von Apple deprecated, verworfen.
3. **Watch-Beispiele in den Test verlagern** (Launch-Argument mit Texten statt `seedStoreSample` im Produktcode): vermeidet
   die Geräteliste `LooseEndsWatch/`, kostet ~50 LoC. Entscheidung in Spec 4b.
4. **Mac ganz zurückstellen**: spart ~40 LoC; DoD verlangt Mac erst „mit der nächsten Mac-Version“.

### Englische Beispielaufgaben (Vorschlag, Freigabe durch Henning in der Spec)
| Deutsch | Englisch |
|---|---|
| Steuerbescheid heute prüfen | Check the tax notice today |
| Anna heute wegen Sonntag anrufen | Call Anna about Sunday today |
| Blumen heute gießen | Water the flowers today |
| Rasen mähen | Mow the lawn |
| Fahrrad zur Inspektion bringen (getippt) | Take the bike in for a service |
| Watch: Anna wegen Geburtstag anrufen | Call Anna about her birthday |

### Open Questions
- [ ] Wortlaut der englischen Beispielaufgaben → Freigabe mit der Spec 4a (keine Vorab-Frage nötig).
