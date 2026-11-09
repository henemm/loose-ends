# Context: feat-842-s4c2-platzieren

## Request Summary
#842 Schnitt 4c-2: Die 12 englischen Bilder, die seit 4c-1 als `en-iphone-…`, `en-ipad-…`, `en-watch-…` unplatziert in
Apples Asset-Bibliothek liegen, werden auf der englischen Store-Seite (Lokalisierung en-US der bearbeitbaren iOS-Version
1.0.1) platziert, in Manifest-Reihenfolge geordnet und im selben Lauf gegengeprüft. Danach zeigt die englische Store-Seite
Bilder für iPhone, iPad und Watch; de-DE bleibt unberührt, nichts wird eingereicht.

## Related Files
| File | Relevance |
|------|-----------|
| `scripts/asc_store_images.py` | 4c-1: `plan`, `preflight` (nur GET), `upload`, `lesen`, `main`; wird um `platzieren` erweitert. `ACTIONS = ("lesen", "hochladen")` |
| `scripts/test_asc_store_images.py` | 12 Tests, `FakeClient` mit Zustand (`get`, `post`, `put`, `patch`, `delete`, `writes()`, `posts()`), Referenzdaten mit echten Gruppennamen, `EN_NAMES`, `ready_library()` |
| `.github/workflows/asc-store-images.yml` | Handlauf `aktion` (lesen/hochladen), `sprache` (en/de), `pull_request`-Auslöser registriert die Datei für den Lauf vom Zweig (`--ref`); keine `concurrency` (F004) |
| `scripts/asc_header_upload.py` | `Client` (`get` flacht `data` ab und **verwirft `included` und `relationships`**; `api(method, path, body)` gibt die Rohantwort), `IMAGES`, `REFDATA`, `check_state` (verlangt „ohne Platzierung“ — passt nach dem Platzieren nicht mehr), `wait_ready` |
| `scripts/asc_version_texts.py` | `app_versions`, `editable_version(versions, platform)`, `localizations(config, version_id)` → `{locale: Datensatz mit id}` |
| `scripts/asc_store_probe.py` | Beleg: `report_placements` liest `/v1/appStoreVersionLocalizations/{id}/placements` (ohne Bildnamen), `bildsatz …` je klassischem Bildsatz |
| `docs/store/screenshots/en/manifest.json` | Reihenfolge = Store-Reihenfolge (iPhone 5, iPad 5, Watch 2, Mac 4) |
| `docs/artifacts/feat-842-s4c-en-hochladen/run-42519049719-probe.log` | Ist-Stand: en-US `platzierung keine`, `bildsatz keine`; de-DE 5 iPhone + 5 iPad + 2 Watch + Kopf- und Suchbild, Zustand `ACTIVE`; Bildsätze `APP_IPHONE_61` 5, `APP_IPAD_PRO_3GEN_129` 5, `APP_WATCH_SERIES_10` 2 |

## Existing Patterns
- Ein Skript je Store-Thema, Aktionen als erstes Argument, `lesen` nur GET; Vorabprüfungen vor dem ersten Schreiben,
  `::error::` und Ausgang 1 bei `Fatal`; Gegenprobe im selben Lauf; Beleg zusätzlich per Store-Probe.
- Idempotenz über Bestand (4c-1: vorhandener `referenceName` → „schon vorhanden, übersprungen“).
- Tests ohne Netz mit zustandsbehaftetem `FakeClient`, Prüfung der Aufrufliste („nie DELETE“, „nur GET“).
- Handläufe vor dem Merge vom Zweig (`gh workflow run … --ref <zweig>`), Protokolle unter `docs/artifacts/<workflow>/`.

## Recherche (2026-11-09, Apple „Placing assets on your App Store surfaces“, JSON-Quelle der Seite)
- Anlegen: `POST /v1/appAssetLibraryPlacements`, Attribute `placementType` (`APP_SCREENSHOT`), `placementGroup`;
  Relationen genau ein `image` (`appAssetLibraryImages`) und genau ein Ziel `appStoreVersionLocalization`. Antwort mit
  `state` (`ASSET_PROCESSING` … `PARENT_PREPARE_FOR_SUBMISSION` … `PARENT_APPROVED`), `stateDetails`, `mediaType`.
- Ordnen: `POST /v1/appAssetLibraryPlacementOrderingRequests`, Attribut `placementGroup`, Relationen `orderedPlacements`
  (Liste von `appAssetLibraryPlacements`-IDs, Reihenfolge = Anzeige) und `appStoreVersionLocalization`; je Gruppe einzeln.
- Lesen in Anzeigereihenfolge: `GET /v1/appStoreVersionLocalizations/{id}/placements?filter[placementType]=APP_SCREENSHOT
  &filter[placementGroup]=…&sort=placementGroupPosition&include=image&fields[appAssetLibraryImages]=referenceName,state,imageAsset`;
  kein Positionsfeld, die Reihenfolge der Antwort ist die Ordnung.
- Fehler: 409 `ENTITY_ERROR.ATTRIBUTE.INVALID` (Typ/Gruppe passt nicht), 409 `STATE_ERROR.INVALID_STATE` (Eltern nicht
  bearbeitbar). Höchstzahl 10 Screenshots je Gruppe. Platzierung unveränderlich; Austausch = `DELETE` + neu + ordnen.
- Nicht in der Doku: der Zustand `ACTIVE` (so stehen die de-DE-Platzierungen in der Probe) und ob Apple die klassischen
  Bildsätze automatisch erzeugt (bei de-DE erschienen sie, Henning lud per Claude Desktop).
- Quelle: https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces;
  frühere Quellen in `docs/context/feat-842-s4c-en-hochladen.md` und `feat-842-s4-en-bilder.md`.

## Dependencies
- Upstream: ASC-API (Platzierungen, Ordnungsaufträge, Bibliothek, Referenzdaten), `Client`, `editable_version`,
  `localizations`, Manifest. Der Lesepfad mit Bildnamen braucht `included` → `client.api("GET", …)` statt `client.get`.
- Downstream: Store-Probe als Beleg; die Einreichung von 1.0.1 (Hennings Entscheidung, nicht dieser Schnitt).

## Existing Specs
- `docs/specs/feat-842-schnitt-4c-1-en-bibliothek.md` (Bibliothek, Namensschema, Vorabprüfungen, Handlauf vom Zweig)
- `docs/specs/feat-842-schnitt-2-platzierungspfad.md` (Store-Probe liest Platzierungen), `feat-772-kopfbild.md`

## Risks & Considerations
- **Erster Schreibzugriff auf die echte Store-Seite** von 1.0.1 (noch nicht eingereicht, also nicht öffentlich). Eine
  Fehlplatzierung lässt sich nur durch Löschen und Neuanlegen beheben; dieser Schnitt löscht nie automatisch.
- **Fremde Platzierungen in einer en-US-Gruppe** (etwa von Hand) → Abbruch ohne Schreiben, nicht überschreiben.
- **Idempotenz:** ein zweiter Lauf darf keine zweite Platzierung desselben Bildes anlegen (Bestand je Gruppe lesen, nach
  Bildname abgleichen); nur ordnen, wenn die Reihenfolge abweicht, oder immer ordnen (folgenlos) — Analyse.
- **Bildzustand:** nur Bilder in `PREPARE_FOR_SUBMISSION` platzieren; fehlt eins → Abbruch vor dem ersten Schreiben.
- **`check_state` aus 4c-1** verlangt „ohne Platzierung“; nach 4c-2 meldet ein erneutes `hochladen` die en-Bilder als
  Fehler. Muss in diesem Schnitt mitgedacht werden (Gegenprobe des Uploads auf „bereit“ ohne Platzierungsbedingung oder
  nur für neu angelegte Bilder).
- **`Client.get` verwirft `included`** → Bildnamen der Platzierungen nur über die Rohantwort oder über den Umweg je Bild.
- **Pagination:** Platzierungslisten ggf. mit `limit` lesen (maxCount 10, Standardseite reicht, aber ausdrücklich setzen).
- **Kleinbefunde aus 4c-1:** F004 (keine `concurrency`-Gruppe; zwei gleichzeitige Läufe könnten doppelt anlegen) wird
  mit dem Platzieren gewichtiger; F002 (`de`-Lauf legt `de-…`-Duplikate an) — `platzieren` mit `de` darf de-DE nie
  berühren, nur `en` zulassen oder ausdrücklich abweisen; F003 (Nicht-PNG-Test) nachrangig.
- **Mac:** keine bearbeitbare Mac-Version → Mac bleibt mit `::warning::` aus, wie in 4c-1.
- **Umfang:** 4c-1 schätzte 4c-2 auf ≈ 180 LoC; nach den Lehren aus 4c-1 (Tests ≈ 30 Zeilen je AC plus Attrappe) sind
  eher ≈ 100 Code + ≈ 250 Tests zu erwarten → über 250; vor `/40-tdd-red` per AskUserQuestion fragen, nicht erst in 6/7.
- Kein Pfad der Geräteliste berührt; kein Produktcode.

## Analysis

### Type
Feature (Betriebsskript gegen die ASC-API, kein Produktcode)

### Affected Files (with changes)
| File | Change Type | Description |
|------|-------------|-------------|
| `scripts/asc_store_images.py` | MODIFY | Aktion `platzieren` (nur `en`; `de` abgewiesen, F002): Vorabprüfung (12 Bilder bereit, keine fremde Platzierung in en-US), Anlegen fehlender Platzierungen, Warten, Ordnen nur bei Abweichung, Gegenprobe; `lesen` zeigt en-US-Platzierungen je Gruppe mit Bildnamen in Anzeigereihenfolge; eigene Bereitschaftsprüfung statt `check_state` (ca. 110–130 LoC) |
| `scripts/test_asc_store_images.py` | MODIFY | `FakeClient` um Platzierungen je Lokalisierung, `POST appAssetLibraryPlacements`, Ordnungsaufträge erweitert; Tests je AC (ca. 280–320 LoC) |
| `scripts/asc_header_upload.py` | MODIFY | `Client.send` meldet bei HTTPError zusätzlich `errors[].code` (ohne Token, ohne URL-Abfrage) — sonst ist ein 409 beim ersten Schreiben blind (ca. 8 LoC) |
| `scripts/test_asc_header_upload.py` | MODIFY | ein Test für den Fehlercode (ca. 20 LoC) |
| `.github/workflows/asc-store-images.yml` | MODIFY | Option `platzieren`, `concurrency`-Gruppe ohne Abbruch (F004), Kopfkommentar (ca. 6 LoC) |

### Scope Assessment
- Files: 5 (Grenze eingehalten)
- Estimated LoC: ≈ +430/−10 (Code ≈ 130, Tests ≈ 300) — **über 250**, Frage an Henning vor der Spec (unten)
- Risk Level: MEDIUM — erster Schreibzugriff auf die en-US-Store-Seite von 1.0.1 (nicht eingereicht, nicht öffentlich); Platzierungen sind unveränderlich, Korrektur nur per Löschen, das dieser Schnitt nie tut

### Technical Approach
- **Weg:** Bibliotheksplatzierung (`POST /v1/appAssetLibraryPlacements`, `POST /v1/appAssetLibraryPlacementOrderingRequests`) für die schon hochgeladenen Bilder aus 4c-1.
- **Zuordnung Platzierung → Bildname ohne `included`:** Liste der Lokalisierung `GET /v1/appStoreVersionLocalizations/{en-US}/placements?…&sort=placementGroupPosition` (Reihenfolge, `placementGroup` als Attribut — beides im Probe-Lauf 42519049719 belegt) geschnitten mit `GET /v1/appAssetLibraryImages/{id}/placements` je Plan-Bild (in 4c-1 `lesen` belegt, 200). Beides über `client.get`, keine Annahme über die Form von `include`/`relationships` nötig. Abweichung von der Plan-Bewertung (die `include=image` vorschlug und deshalb teilen wollte): dieser Abgleich nutzt nur bereits am echten Konto belegte Antwortformen.
- **Idempotenz:** Bestand je Gruppe; vorhandene eigene Platzierung übersprungen, fehlende angelegt; Ordnen nur, wenn die gelesene Reihenfolge vom Manifest abweicht. Abgebrochener Lauf → Wiederholung legt nur Fehlendes an.
- **Abbruch vor jedem Schreiben:** keine/mehrere bearbeitbare iOS-Versionen, en-US fehlt, Plan-Bild fehlt oder nicht `PREPARE_FOR_SUBMISSION`, fremde Platzierung (Bild nicht aus dem Plan) oder Doppelplatzierung in einer en-US-Gruppe, Gruppe über `maxCount`, `sprache` ≠ `en`.
- **Warten:** Platzierungszustand pollen (injiziertes `sleep`), `ASSET_PROCESSING` = warten, `ACTIVE`/`PARENT_*` = gut (ACTIVE undokumentiert, aus der de-DE-Probe), alles andere mit `stateDetails` → Fatal.
- **Gegenprobe im selben Lauf:** je Gruppe Namen und Reihenfolge = Manifest; de-DE wird nur gelesen und mit unveränderter Anzahl (5/5/2) gemeldet. Beleg zusätzlich per Store-Probe.
- **`check_state`:** bleibt für das Kopfbild strikt; `asc_store_images.upload` bekommt eine eigene Prüfung „da und bereit“ (Platzierung erlaubt), damit ein späteres `hochladen en` nach dem Platzieren nicht fälschlich scheitert.
- **Mac:** weiter `::warning::`, keine bearbeitbare Mac-Version.
- **Ablauf am echten Konto:** vom Zweig zuerst `lesen en` (zeigt Bestand und Plan), dann `platzieren en`, dann Store-Probe; erst danach Merge.

### Alternativen
- **A — klassische `appScreenshotSets`/`appScreenshots`:** bewährt, aber lädt die Bilder ein zweites Mal hoch, lässt die 12 Bibliotheksbilder verwaist und weicht vom Weg der de-DE-Seite ab (dort Bibliotheksplatzierungen). Fällt: Entscheidung aus 4c-1 „Bibliothek vor Platzierung“ (Spec 4c-1, keine ADR-Nummer). Nicht empfohlen.
- **B — zwei Schnitte** (4c-2a Lesepfad + Fehlercode + Bereitschaftsprüfung, ≈ 180 LoC; 4c-2b Anlegen, Ordnen, Gegenprobe, ≈ 280 LoC): jede Hälfte näher an der Grenze; Hauptgrund der Plan-Bewertung (Form von `include` erst belegen) entfällt mit dem Abgleich oben; die Schreibwege bleiben auch nach 2a unerprobt. Kostet einen zweiten Durchlauf ohne sichtbaren Unterschied für Henning.
- **C — Henning platziert in App Store Connect selbst:** widerspricht „nie Arbeit an den PO“. Verworfen.

### Dependencies
`Client` (`api`, `get`, `post`), `editable_version`, `localizations`, `ASC_LOCALES`, Manifest, `REFDATA`; Downstream Store-Probe, später die Einreichung von 1.0.1 (Hennings Entscheidung).

### Open Questions
- [x] Umfang ≈ 430 LoC in einem Schnitt: **Henning 2026-11-09 per AskUserQuestion „Ein Schritt (Empfohlen)“ — angenommen.** Meldeschwelle für /60-validate: ≈ 520 LoC; darüber erneut fragen.
