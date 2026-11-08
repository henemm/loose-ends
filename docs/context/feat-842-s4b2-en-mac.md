# Context: feat-842-s4b2-en-mac

## Request Summary
#842 Schnitt 4b-2: englische App-Store-Bilder des Mac (1280×800, 16:10) unter `docs/store/screenshots/en/mac/` und als
Mac-Eintrag im englischen Manifest (`en-US`), aus demselben Fototest wie die deutschen. Die deutschen Mac-Bilder bleiben unverändert.

## Related Files
| File | Relevance |
|------|-----------|
| `LooseEndsUITests/MacStoreScreenshotsTests.swift` | Fototest (`#if os(macOS)`), heute fest deutsch: `macLaunch(locale: "de_DE")` und vier deutsche Aufgaben im Code |
| `LooseEndsUITests/LaunchLanguage.swift` | gleiches Testziel `LooseEndsUITests` (nur `Watch/**` ausgenommen): `arguments(for:)`, `locale(for:)`, `phrase(_:in:)` mit `storeTask1…4` de/en, Wortlaut seit 4a freigegeben |
| `LooseEndsUITests/MacUITestSupport.swift` | `macLaunch(dark:locale:extra:)` setzt `-AppleLanguages (xx)` aus dem Locale-Präfix und `-AppleLocale` |
| `LooseEndsUITests/StoreScreenshotsTests.swift` | Muster aus 4a: eigene Standardsprache `de` aus `LOOSEENDS_UI_LANG`, Phrasen per `LaunchLanguage.phrase(_:in:)` |
| `.github/workflows/store-mac.yml` | einziger Weg zu Mac-Bildern (CI, nie Hennings Mac, #742 S2b): `workflow_dispatch` oder Push auf `store/mac`, Artefakt `StoreMac`; heute ohne Sprachwahl |
| `scripts/store_screenshots.py` | `main_mac(out_root, export)`: schreibt `mac/` und ersetzt nur den Mac-Eintrag im Manifest; sprachneutral (Sprache steckt im Zielordner), `MAC["order"]` = 01-start, 03-neu, 04-detail, 05-erledigt |
| `scripts/test_store_screenshots.py` | Tests für `main_watch` en (4b-1, `WatchLanguageTests`); **kein Test für `main_mac`** bisher |
| `docs/store/screenshots/en/manifest.json`, `en/README.md` | Ziel; README nennt bisher nur iPhone/iPad (auch Watch fehlt dort, 4b-1 ließ sie unberührt) |

## Existing Patterns
- Sprache als Testparameter: `LOOSEENDS_UI_LANG`, Standard je Klasse (Store-Klassen: `de`); `sim.sh` reicht sie als `TEST_RUNNER_LOOSEENDS_UI_LANG` durch. In der CI setzt man die Variable `TEST_RUNNER_LOOSEENDS_UI_LANG` direkt im Schritt (wie `ui-smoke-lang`).
- Bilder entstehen nur aus echten UI-Tests, nie nachbearbeitet (4a Alternative C).
- Mac-Bilder: CI-Lauf → Artefakt herunterladen (`gh run download`) → `python3 scripts/store_screenshots.py --mac docs/store/screenshots/<lang> <export>` (so entstanden die deutschen, 6078716).
- Fälligkeit „heute“ der Aufgaben kommt aus dem Satztext über `DueDateRule` (EnglishPack kennt „today“, 4a-Bilder belegen es).

## Dependencies
- Upstream: `LaunchLanguage`, `macLaunch`, `macCapture`, `macMainWindow`; Accessibility-IDs `startCaptureField`, `viewRow_new`, `taskRow_*`, `detailRawTextMarker`, `detailCompleteButton`, `viewRow_done` (sprachunabhängig).
- Downstream: Schnitt 4c lädt `en/mac/*` nach App Store Connect hoch; `store-mac.yml` wird nur von Hand/`store/mac` ausgelöst, sonst nichts.

## Existing Specs
- `docs/specs/feat-842-schnitt-4a-en-bilder-iphone-ipad.md` (Wortlaut der englischen Aufgaben, Standardsprache de)
- `docs/specs/feat-842-schnitt-4b-1-en-watch.md` (Watch-Muster, Manifest-Tests)

## Risks & Considerations
- Nur in der CI prüfbar (Mac-Runner `xcode-27`); jeder Versuch = ein CI-Lauf (~15–30 min).
- Englische Titel/Seitenleisten-Wörter können im 1280×800-Fenster anders umbrechen; die Bilder werden geöffnet und beschrieben.
- Kein Pfad der Geräteliste (`.github/` und `LooseEndsUITests/` stehen nicht darin) → Abnahme endet nach Stufe 2.
- Standardsprache muss `de` bleiben (ein Lauf ohne Eingabe darf die deutschen Bilder nicht englisch machen).
- en-README nennt Watch und Mac nicht; ob ergänzen, ist in der Analyse zu klären (Scope 4b-2 oder 4c).
- Alternative zum CI-Weg: lokal `LOOSEENDS_MAC_HOST`-artig auf diesem Mac — verboten (Mac-Bilder nie von Hennings Mac).

## Analysis

### Type
Feature (Schnitt 4b-2 von #842, keine Produktänderung an der App)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `LooseEndsUITests/MacStoreScreenshotsTests.swift` | MODIFY | Sprache aus `LOOSEENDS_UI_LANG`, Standard `de` (wie `StoreScreenshotsTests`); Locale `LaunchLanguage.locale(for:)`, Aufgaben `LaunchLanguage.phrase("storeTask1…4", in:)`; Klassenkommentar „German or English“ (~20 LoC) |
| `.github/workflows/store-mac.yml` | MODIFY | `workflow_dispatch.inputs.language` (choice de/en, Standard de); Testschritt `env: TEST_RUNNER_LOOSEENDS_UI_LANG: ${{ inputs.language \|\| 'de' }}` (Push hat keine Eingaben); Artefakt `StoreMac-<sprache>` (~10 LoC) |
| `scripts/test_store_screenshots.py` | MODIFY | `MacLanguageTests` nach Muster `WatchLanguageTests`: Mac-Eintrag im en-Manifest ergänzt, Wiederholung ersetzt nur ihn, README und `de/` byte-gleich, falsche Größe bricht ab; schließt die Lücke „kein Test für `main_mac`“ (~50 LoC) |
| `docs/store/screenshots/en/README.md` | MODIFY | 2–3 Zeilen für Watch (`watch/`, 416×496, seit 4b-1 fehlend) und Mac (`mac/`, 1280×800, `store-mac.yml` mit language en); Skript überschreibt die README nie |
| `docs/store/screenshots/en/mac/*.png`, `en/manifest.json` | CREATE/MODIFY (erzeugt) | erst nach dem Merge aus dem CI-Lauf mit `language=en`: `gh run download` → `python3 scripts/store_screenshots.py --mac docs/store/screenshots/en <export>`; eigener zweiter PR |

Nicht betroffen (geprüft): `scripts/sim.sh` (kein Mac-Store-Befehl), `ci.yml`, `docs/reference/*`, CI-Wächter (`test_ci_*.py` lesen `store-mac.yml` nicht), `LaunchLanguage.swift` (Schlüssel und `locale(for:)` vorhanden, kompiliert ins Mac-UI-Testziel, `project.yml` schließt nur `Watch/**` aus), `MacUITestSupport.swift` (`macCapture` prüft das Leeren über `placeholderValue`, sprachneutral).

### Scope Assessment
- Files: 4 Code-/Doku-Dateien (PR 1) + erzeugte Bilder und Manifest (PR 2)
- Estimated LoC: ~+85/−5
- Risk Level: LOW — die deutschen `storeTask`-Texte in `LaunchLanguage` sind wortgleich mit den bisherigen Literalen (geprüft), also bleiben die deutschen Mac-Bilder gleich; Standard `de` auf allen Wegen (leere Eingabe, Push auf `store/mac`).

### Technical Approach
Umgebungsvariable wie 4a/4b-1 statt zweiter Testklasse. Reihenfolge, weil eine neue Dispatch-Eingabe erst nach dem Merge auf `main` wählbar ist und ein Push keine Eingaben trägt:
1. PR 1 (Test, Workflow, Python-Test, README) → CI grün → Merge.
2. `gh workflow run store-mac.yml -f language=en` auf `main`, zusätzlich ein `de`-Lauf als Gegenprobe (deutsche Bilder unverändert im Inhalt; „heute“ hängt am Lauftag, daher kein Pixelvergleich).
3. Artefakt `StoreMac-en` laden, alle vier Bilder öffnen und beschreiben (Umbruch englischer Titel bei 1280×800), `--mac` nach `en/`.
4. PR 2 mit Bildern und Manifest. Bei Umbruchproblem: Testkorrektur als neuer Durchgang.
Abnahme: kein Pfad der Geräteliste berührt → endet nach Stufe 2; der „Benutzen“-Beleg ist der echte CI-Fotolauf mit geöffneten Bildern.

### Alternativen (verworfen)
- **Eigene englische Testklasse** `MacStoreScreenshotsEnTests`: kein Eingabeparameter nötig, Push könnte beide liefern; aber ~40 LoC doppelter Ablauf, beide Klassen laufen auseinander.
- **Matrix de+en in einem Lauf**: beide Sprachen auf einmal, aber doppelte Runner-Zeit bei jedem Lauf und deutsche Bilder ohne Anlass neu; nur sinnvoll, wenn 4c beide Sprachen aus einem Lauf braucht (tut es nicht, 4c lädt Dateien aus dem Repo).
- **Eigene Datei `store-mac-en.yml`**: ~50 Zeilen dupliziert.
Gekippt würde keine ADR.

### Dependencies
`LaunchLanguage` (Phrasen, Locale), `macLaunch`/`macCapture`/`macMainWindow`, sprachneutrale Accessibility-IDs, `DueDateRule` mit EnglishPack „today“, `store_screenshots.main_mac`. Downstream: Schnitt 4c lädt `en/mac/*` hoch.

### Open Questions
- keine PO-Frage: Wortlaut der englischen Aufgaben ist seit 4a freigegeben; ob die Bilder taugen, zeigt die Sichtprüfung in Schritt 3.
