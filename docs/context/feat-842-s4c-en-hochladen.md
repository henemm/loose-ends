# Context: feat-842-s4c-en-hochladen

## Request Summary
#842 Schnitt 4c: die englischen Store-Bilder aus `docs/store/screenshots/en/` (iPhone 5, iPad 5, Watch 2) per CI-Handlauf
in App Store Connect an die en-US-Lokalisierung der iOS-Version 1.0.1 hängen, belegt mit der Store-Probe. Die englischen
Mac-Bilder (4) liegen bereit, haben aber heute kein Ziel (siehe Risiken).

## Stand bei Apple (Store-Probe, Lauf 42515431363, 2026-11-08 19:31Z, main 472ac7e)
- iOS 1.0.1 `PREPARE_FOR_SUBMISSION`. en-US-Versionslokalisierung existiert mit Beschreibung (1493), Schlüsselwörtern (94),
  Support-URL, Werbetext (125) aus Schnitt 3. en-US: `platzierung keine`, `bildsatz keine`.
- de-DE derselben Version: Platzierungen `APP_SCREENSHOT` in `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE` (5),
  `IPAD_13_PROFILE` (5), `WATCH_SERIES_10_PROFILE` (2), dazu `PRODUCT_PAGE_HEADER_ASSET` und `APP_STORE_SEARCH_RESULTS_ASSET`
  (`DEFAULT_PROFILE`); die klassischen Bildsätze zeigen dieselben Bilder als `APP_IPHONE_61`, `APP_IPAD_PRO_3GEN_129`,
  `APP_WATCH_SERIES_10`, alle `COMPLETE`. Henning lud de per Claude Desktop hoch (#742); Platzierung erzeugt also den Bildsatz.
- App-Info 2 `PREPARE_FOR_SUBMISSION` hat en-US (Name „Loose Ends: Voice Tasks“, Untertitel „Say it. Clear your head.“).
- macOS: nur 1.0 `READY_FOR_SALE` (de-DE, 4 Bilder `APP_DESKTOP`) — keine bearbeitbare Mac-Version, kein en-US.
- Referenzdaten: 37 Platzierungsprofil-Gruppen.

## Related Files
| File | Relevance |
|------|-----------|
| scripts/asc_header_upload.py (Z.54-118, 143-183) | einziger Upload-Code: Asset-Bibliothek `POST /v1/appAssetLibraryImages`, `put_bytes` über `uploadOperations`, PATCH `uploaded: true`, `wait_ready` auf PREPARE_FOR_SUBMISSION, eigene `Client`-Klasse; platziert nie |
| .github/workflows/asc-header-upload.yml | Muster für Handlauf mit `aktion` lesen/hochladen, Secrets ASC_KEY_ID/ASC_ISSUER_ID |
| scripts/test_asc_header_upload.py (Z.42-103, 187-201) | `FakeClient` im Prozess, prüft „nie Platzierung, nie Einreichen“ |
| scripts/asc_version_texts.py (Z.100-123, 157-193) | `editable_version` je Plattform (genau eine PREPARE_FOR_SUBMISSION, sonst Meldung/Fatal), `localizations()`, `verify`-Gegenprobe |
| scripts/test_asc_version_texts.py | echter lokaler HTTP-Server über `ASC_API_BASE` |
| scripts/asc_store_probe.py (Z.14-24, 48-65, 79-100, 153-154) | Beleg-Lauf: Bildsätze, Platzierungen, Referenzdaten (nur GET) |
| scripts/test_asc_store_probe.py (Z.137-142, 246) | Fixtures mit veralteten Gruppennamen (IPHONE_67 usw.) |
| scripts/asc_wait_build.py | `Fatal`, `find_app_id`, `make_token`, `read_config` |
| scripts/asc_what_to_test.py (Z.40-63) | `send_json` mit Wiederholung bei 5xx/408/429, `get_data` |
| scripts/asc_locales.py (Z.9) | `ASC_LOCALES = {"de": "de-DE", "en": "en-US"}` |
| docs/store/screenshots/en/manifest.json | Quelle: `sprache`, `geraete[]` mit `geraet`, `anzeige`, `pixel`, `ordner`, `dateien` (Reihenfolge = Store-Reihenfolge) |
| docs/context/feat-842-s4-en-bilder.md (Z.52-84, 128-150) | frühere Recherche: klassische `appScreenshotSets` laut Apple deprecated (verworfen), Weg = Asset-Bibliothek + `POST /v1/appAssetLibraryPlacements` (Relation `appStoreVersionLocalization`, Platzierung unveränderlich, Eltern muss bearbeitbar sein, max. 10 je Gruppe), Kategorie `APP_SCREENSHOTS_AND_PREVIEWS` |
| docs/specs/feat-772-kopfbild.md, feat-842-schnitt-3-texte-schreiben.md | Grenzen: nie einreichen, `lesen` zuerst, nur eigene Locale, gesperrte Versionen nie anfassen |

## Existing Patterns
- Handlauf je Aufgabe (`workflow_dispatch`, Eingabe `aktion` mit `lesen` als Standard), Python-Skript ohne Abhängigkeiten,
  Schlüssel nur in der CI, nie ausgegeben.
- Version wählen wie `editable_version`: genau eine bearbeitbare je Plattform, sonst Meldung statt Schreiben.
- Gegenprobe nach dem Schreiben im selben Lauf, Beleg zusätzlich per Store-Probe.
- Tests ohne Netzwerk (FakeClient oder lokaler HTTP-Server); Lehre #842 S2: der Nachbau darf Apples Form nicht erraten,
  Pfade und Antwortformen aus Doku/Handlauf belegen.

## Dependencies
- Upstream: ASC-API (Asset-Bibliothek, Platzierungen, Referenzdaten), `asc_wait_build`, `asc_what_to_test.send_json`, Manifest.
- Downstream: Store-Probe als Beleg; die Einreichung von 1.0.1 (Henning, nicht dieser Schnitt).

## Existing Specs
- docs/specs/feat-842-schnitt-1..4b-2 (keine 4c-Spec), docs/specs/feat-772-kopfbild.md

## Risks & Considerations
- Schreibt in die echte Store-Seite: Platzierungen sind unveränderlich (nur löschen); falsche Gruppe/Reihenfolge = löschen und neu. Doppellauf darf nichts doppelt anlegen (idempotent über Dateiname/Bestand).
- Dateinamen in der Bibliothek: de- und en-Bilder heißen gleich (01-start.png …) — Bibliothek ist app-weit, Zuordnung nicht über den Namen allein.
- Max. 10 je Gruppe; en hat 5/5/2.
- Mac: keine bearbeitbare Mac-Version → Mac-Bilder bleiben offen, bis eine neue Mac-Version existiert (Anlegen einer Version ist Hennings Release-Entscheidung).
- Store-Probe-Fixtures nennen veraltete Gruppennamen; echte Namen stehen oben.
- Kein Gerät berührt; Geräteliste nicht betroffen.

## Analysis

### Type
Feature (Store-Inhalt + Werkzeug), kein Produktcode, kein Pfad der Geräteliste.

### Recherche (2026-11-08, Apple-Doku per JSON-Quelle der Seite gelesen)
- „Placing assets on your App Store surfaces“ bestätigt die Recherche vom 2026-11-07 wörtlich:
  `POST /v1/appAssetLibraryPlacements` mit `placementType` `APP_SCREENSHOT`, `placementGroup` (Bezeichner aus den
  Referenzdaten, keine Aufzählung), Relation `image` und genau einer Ziel-Relation `appStoreVersionLocalization`.
  Antwort trägt `state` (`ASSET_PROCESSING` … `PARENT_PREPARE_FOR_SUBMISSION` … `PARENT_APPROVED`).
  Fehler: 409 `ENTITY_ERROR.ATTRIBUTE.INVALID` (Typ/Gruppe/Kategorie passen nicht), 409 `STATE_ERROR.INVALID_STATE`
  (Eltern nicht bearbeitbar), Höchstzahl je Gruppe in `features[].placementPolicies[].groupLimits[].maxCount` (10 Bilder).
  Lesen: `GET /v1/appStoreVersionLocalizations/{id}/placements?filter[placementType]=APP_SCREENSHOT&filter[placementGroup]=…&sort=placementGroupPosition&include=image`
  — die Reihenfolge der Antwort ist die Anzeigereihenfolge (kein Positionsfeld).
  Reihenfolge setzen: `POST /v1/appAssetLibraryPlacementOrderingRequests` (`placementGroup`, `orderedPlacements`,
  Relation Lokalisierung), je Gruppe einzeln.
  Platzierung unveränderlich; Austausch = löschen + neu + ordnen; Bild löschen erst nach seinen Platzierungen.
  https://developer.apple.com/documentation/appstoreconnectapi/placing-assets-on-your-app-store-surfaces
- Die übrigen Quellen (Migration, Upload, Fremdbericht) stehen in `docs/context/feat-842-s4-en-bilder.md`, Abschnitt Recherche.

### Affected Files (with changes)
| File | Change Type | Schnitt | Description |
|------|-------------|---------|-------------|
| `scripts/asc_store_images.py` | CREATE | 4c-1/4c-2 | `lesen` (nur GET), `hochladen` (Bibliothek), `platzieren` (Platzierung + Reihenfolge + Gegenprobe); nutzt `Client`, `put_bytes`, `wait_ready` aus `asc_header_upload.py` und `editable_version` aus `asc_version_texts.py` |
| `scripts/test_asc_store_images.py` | CREATE | 4c-1/4c-2 | FakeClient wie `test_asc_header_upload.py`, Antwortformen aus Apples Beispielen |
| `.github/workflows/asc-store-images.yml` | CREATE | 4c-1 | Handlauf `aktion` = lesen (Standard) / hochladen / platzieren, `sprache` = en (Standard), Secrets wie Header-Upload |
| `docs/store/screenshots/en/manifest.json` | READ | — | Quelle der Dateien und Reihenfolge |

### Technischer Ansatz (Empfehlung)
1. **Namen eindeutig:** `referenceName` = `<sprache>-<gerät>-<datei ohne .png>` (z. B. `en-iphone-01-start`), weil die
   Bibliothek app-weit ist und de/en gleich heißen. Bestand mit diesem Namen wird übersprungen (Doppellauf legt nichts doppelt an).
2. **Gruppe je Gerät fest, aber geprüft:** iphone → `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`, ipad → `IPAD_13_PROFILE`,
   watch → `WATCH_SERIES_10_PROFILE` (dieselben, die de-DE heute trägt). Vor jedem Schreiben: Gruppe in den Referenzdaten
   vorhanden und für `APP_SCREENSHOT` zulässig, Anzahl ≤ `maxCount`; sonst Abbruch ohne Schreiben. Mac wird übersprungen
   und als `::warning::` gemeldet, solange `editable_version(MAC_OS)` keine Version liefert.
3. **Ziel:** genau die en-US-Lokalisierung der einen bearbeitbaren iOS-Version (`editable_version(IOS)`); keine oder mehrere
   → Meldung/Abbruch, nichts geschrieben. Nie de-DE, nie eine gesperrte Version, nie einreichen, nie löschen.
4. **Idempotent platzieren:** je Gruppe vorhandene en-US-Platzierungen lesen. Sind dort nur eigene Bilder (Namen mit
   `en-<gerät>-`), fehlende anlegen; ein fremdes Bild in der Gruppe → Abbruch ohne Schreiben (kein automatisches Löschen).
   Danach ein Ordnungsauftrag je Gruppe in Manifest-Reihenfolge.
5. **Gegenprobe im selben Lauf:** je Gruppe mit `sort=placementGroupPosition&include=image` lesen; Namen und Reihenfolge
   müssen dem Manifest entsprechen, sonst roter Lauf. Beleg zusätzlich per `asc-store-probe.yml` (en-US: Platzierungen
   und daraus erzeugte Bildsätze `COMPLETE`) — das ist, was Henning in App Store Connect sieht.

### Scope Assessment
- 3 neue Dateien, geschätzt +380 LoC inkl. Tests → über 250. **Teilung (technische Entscheidung):**
  - **4c-1** `lesen` + `hochladen` in die Bibliothek + Handlauf (≈ 200 LoC). Schreibt bei Apple nur Bibliotheksbilder,
    sichtbar auf keiner Store-Seite, folgenlos.
  - **4c-2** `platzieren` + Ordnen + Gegenprobe (≈ 180 LoC), Beleg Store-Probe. Erst hier ändert sich die englische Store-Seite.
- Risk Level: MEDIUM — 4c-2 schreibt in die echte Store-Seite von 1.0.1 (vor der Einreichung, also noch nicht öffentlich);
  Fehlplatzierung ist umkehrbar (löschen + neu), aber nicht durch ein Ändern.

### Befunde gegen den Plan
- Die Store-Probe-Fixtures nennen veraltete Gruppennamen (`IPHONE_67` …); der neue Test nimmt die echten Namen aus dem Lauf
  42515431363, sonst rät der Nachbau Apples Form (Lehre #842 S2).
- Ob Apple aus einer Platzierung sofort den klassischen Bildsatz (`APP_IPHONE_61` …) baut, ist nur aus de-DE erschlossen
  (Henning lud per Claude Desktop, beides erschien). Die Gegenprobe verlangt daher die Platzierungen; die Bildsätze zeigt die
  Store-Probe als Beleg, nicht als Bedingung im Skript.

### Alternativen
1. **Henning lädt per Hand/Claude Desktop hoch** (wie #742): spart beide Schnitte, kostet ihn Zeit, nicht wiederholbar, nicht
   prüfbar vor dem Lauf. Widerspricht „Henning bekommt nichts zu tun“.
2. **Klassischer Bildsatz-Weg** (`appScreenshotSets`/`appScreenshots`): deprecated laut Apple, verworfen.
3. **Ein Schnitt mit Überhang (~380 LoC)** statt Teilung: schneller, aber Platzierung und Upload gemeinsam ungeprüft;
   verworfen, weil die Bibliotheksstufe folgenlos vorab belegt werden kann.
4. **de-Platzierungen als Vorlage lesen** (Gruppe aus de-DE übernehmen statt fest): koppelt en an Hennings Handstand; fällt,
   sobald de anders platziert ist. Feste Zuordnung + Prüfung gegen Referenzdaten ist robuster.
Keine ADR fällt; kein Ansatz berührt Produktcode.

### Nicht in diesem Schnitt
- Mac-Bilder: keine bearbeitbare Mac-Version; das Skript meldet es und lädt sie hoch, sobald eine existiert (gleicher Lauf).
- Kopfbilder (`PRODUCT_PAGE_HEADER_ASSET`, Suchergebnis-Bild) für en-US: nicht Teil der DoD von #842, nicht nötig zur Einreichung.

### Open Questions
- keine an den PO (rein technische Entscheidungen; die Bilder hat Henning in 4a/4b freigegeben).

## Umfangsfreigabe (Henning, 2026-11-08, /60-validate)

Endstand 611 LoC: Skript 171, Workflow 54 (zusammen 225, unter 250), Tests 386. Henning wählte per AskUserQuestion
„So übernehmen“; die Alternative „Prüfungen kürzen“ wurde verworfen, weil die Tests die Grenzen „nie platzieren, nie
einreichen, nie löschen“ und den Abbruch vor dem ersten Schreiben absichern.
