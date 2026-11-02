---
entity_id: fix-772-upload-api
type: bugfix
created: 2026-11-02
updated: 2026-11-02
status: draft
workflow: fix-772-upload-api
tags: [store, app-store-connect, kopfbild]
---

# Spec: #772 — Kopfbild-Upload nach Apples dokumentierter Schnittstelle

## Approval

- [ ] Approved (Henning)

## Purpose

Der Upload der vier Kopfbilder in Apples Asset-Bibliothek (#772 Teil B, PR #808) scheiterte im ersten echten Lauf
(Run 41497087136: „Keine Spec für hell-16x9 (5244x2950); vorhanden: keine“). `lesen` (Run 41496975945) zeigte dieselbe Lücke:
Bibliothek erreichbar, aber keine Spec-Zeile. Das Skript hat die Schnittstelle geraten; die Attrappe in den Tests bildet dieselbe
erfundene Form nach, deshalb waren die Tests grün. Das Skript wird an Apples dokumentierte Form angepasst. Es platziert weiterhin
nie und reicht nie ein.

**Hat es bisher funktioniert?** Nein. Es war der erste echte Lauf. `hochladen` brach vor jedem Schreiben ab (AC-6 des ersten
Schnitts hielt): bei Apple wurde nichts angelegt.

### Root Cause

Sechs Abweichungen von Apples App Store Connect API (4.5.0), Quelle developer.apple.com:

1. Referenzdaten sind ein Einzeldatensatz: `GET /v1/appAssetLibraryRefData/1`. Das Skript fragt den Listenpfad ohne id; der Client
   macht daraus `{"items": …}`, `imageSpecs` fehlt.
2. Spec-Maße stehen als Spannen in `dimensions.minWidth/maxWidth/minHeight/maxHeight` (dazu `specId`, `compatiblePlacementTypes`).
   Das Skript liest `width`/`height` und `category`.
3. Die Kategorie (`CREATIVE_ASSETS` für Kopfbilder) steht je Platzierungstyp in `placementTypes[].acceptsAssetCategories`,
   nicht in der Spec.
4. Die Bibliothek hat eine eigene id: `GET /v1/apps/{id}/assetLibrary`. Das Skript behandelt die App-id als Bibliothek.
5. Bilder und Platzierungen sind Unterpfade: `GET /v1/appAssetLibraries/{libraryId}/images`,
   `GET /v1/appAssetLibraryImages/{imageId}/placements`. Das Skript erwartet sie als `included` der Bibliothek.
6. Anlegen hängt an der Beziehung `assetLibrary` (`type: appAssetLibraries`), nicht `app`; und `FAILED` (mit `stateDetails`) ist
   ein eigener Zustand, den das Skript nicht erkennt.

### Recherche und Regelweg

Apples Dokumentation ist die Quelle (Tabelle in `docs/context/fix-772-upload-api.md`). Praxisbericht eines Dritten (ObjectGraph,
kein Apple): Kopfbild 3840 × 1646, Suchbild 3840 × 2560. Ob Apple 5244 × 2950 für `PRODUCT_PAGE_HEADER_ASSET` annimmt, ist
aus der Doku nicht entscheidbar; es zeigt nur der Spec-Abgleich im echten `lesen`. Reine Schnittstellenarbeit, kein Sprachverstehen,
kein Modell.

## Source

- **Identifier:** `match_specs`, `upload`, `wait_ready`, `check_state`, `Client`, `main` in `scripts/asc_header_upload.py`
- **Geändert:** `scripts/asc_header_upload.py`
- **Geändert:** `scripts/test_asc_header_upload.py` (Attrappe liefert Apples dokumentierte Antwortform)
- **Unverändert:** `.github/workflows/asc-header-upload.yml`, `docs/store/header/*` (Bilder, Manifest), `scripts/asc_wait_build.py`

## Dependencies

| Entity | Type | Purpose |
|--------|------|---------|
| `scripts/asc_wait_build.py` | Skript | Token (`make_token`), Konfiguration (`read_config`), `find_app_id`, `Fatal`; unverändert |
| `docs/store/header/manifest.json` | Daten | Dateien und Maße der vier Bilder; unverändert |
| `.github/workflows/asc-header-upload.yml` | Workflow | einziger Aufrufer (Hand-Workflow); unverändert |
| App Store Connect API 4.5.0 | extern | Asset-Bibliothek; Form laut developer.apple.com |

## Scope

### Affected Files

| Datei | Änderung | Beschreibung |
|---|---|---|
| `scripts/asc_header_upload.py` | MODIFY | Refdaten per id 1; Spec-Abgleich über `dimensions` und Platzierungstyp; Bibliothek-id; Bilder und Platzierungen über Unterpfade; POST mit `assetLibrary`; `FAILED` erkennen; `lesen` gibt rohe Spec-Daten aus |
| `scripts/test_asc_header_upload.py` | MODIFY | Attrappe in Apples Form (Einzeldatensatz, Unterpfade, `FAILED`), Tests je AC |

Zwei Dateien, geschätzt ±~210 LoC (Skript +70/−50, Tests ±90). Unter dem Limit.

**Geräteliste berührt:** nein. Kein App-Code. Kein Pfad der Geräteliste berührt. Abnahme endet nach Stufe 2.

**Side-Effects:** keine Änderung an `project.yml`, Info.plist, Entitlements, Katalogen, AppStorage, Schema. Das Skript schreibt
bei Apple wie bisher nur Bilder in die Asset-Bibliothek des Kontos; nichts wird platziert oder eingereicht.

### Nicht in diesem Ticket

- Maße der Bilder ändern (Entwurf Teil A, von Henning freigegeben). Zeigt `lesen`, dass 5244 × 2950 unzulässig ist, ist das eine
  eigene Entscheidung.
- Platzieren oder Einreichen.

## Implementation Details

**Referenzdaten.** Ein Abruf `GET /v1/appAssetLibraryRefData/1` ohne `fields`-Einschränkung (alle Attribute, damit `lesen` auch
`placementTypes` sieht). Der Client behandelt einen Einzeldatensatz bereits (`flat`); Listen kommen weiter als `{"items": …}`.

**Spec-Abgleich (vorab, kein Raten).** Eine Spec passt zu einer Datei, wenn Breite in `[minWidth, maxWidth]` und Höhe in
`[minHeight, maxHeight]` liegen und `PRODUCT_PAGE_HEADER_ASSET` in `compatiblePlacementTypes` steht. Die Kategorie der Datei ist
die erste von diesem Platzierungstyp akzeptierte (`placementTypes[].acceptsAssetCategories`, erwartet `CREATIVE_ASSETS`).
Passt keine Datei: Abbruch vor jedem Schreiben, Meldung nennt alle vorhandenen Specs (`specId`, Maße, Platzierungstypen). Passen nur
einige: die passenden gehen durch, die übrigen werden je mit Namen und Maß als `::warning::` gemeldet und nicht hochgeladen
(kein stilles Weglassen). **Abweichung vom ersten Schnitt**, dessen AC-6 bei jeder fehlenden Spec abbrach.

**Ablauf `hochladen`.** Bibliothek holen (`/v1/apps/{app}/assetLibrary`, daraus `libraryId`) → vorhandene Bilder über
`/v1/appAssetLibraries/{libraryId}/images` lesen (gleiche `referenceName` wird nicht neu angelegt) → je neues Bild
`POST /v1/appAssetLibraryImages` mit Attributen `fileName`, `fileSize`, `referenceName`, `category` und Beziehung
`assetLibrary` → Bytes über `uploadOperations` → `PATCH` `uploaded: true` → warten auf `PREPARE_FOR_SUBMISSION`
(Zwischenzustände `AWAITING_UPLOAD`, `UPLOAD_COMPLETE`); `FAILED` bricht mit `stateDetails` ab.

**Zustandscheck.** Für jedes unserer Bilder `GET …/images/{id}/placements`; „bereit“ nur, wenn alle `PREPARE_FOR_SUBMISSION` tragen
und keine Platzierung existiert.

**`lesen`.** Nur GET. Gibt je Spec eine Zeile mit `specId`, den vier Maßgrenzen und `compatiblePlacementTypes` aus, je
Platzierungstyp eine Zeile mit akzeptierten Kategorien, dann die Bilder der Bibliothek mit Zustand, die Zahl der Platzierungen und
die Attributnamen des Datensatzes. So ist der nächste Lauf nicht wieder blind. Token und Schlüssel werden nie ausgegeben.

## Expected Behavior

- **Input:** `lesen` oder `hochladen`, ASC-Secrets, `docs/store/header/manifest.json`.
- **Output `lesen`:** rohe Spec-Daten und Bibliothekszustand, keine Schreibaufrufe.
- **Output `hochladen`:** je zulässigem Bild ein Bild im Zustand `PREPARE_FOR_SUBMISSION`, Meldung für jedes nicht zulässige Bild.
- **Side effects:** Bilder im Konto bei Apple (nicht öffentlich). Version 1.0 und ihre Prüfung bleiben unberührt.

## Known Limitations

- Die Antwortform stammt aus der Dokumentation, nicht aus einem echten Lauf. Deshalb beginnt die Abnahme mit `lesen`; weicht die
  Form ab, wird die Spec nachgeschärft statt geraten.
- Ob `category` beim Anlegen als Attribut verlangt wird, zeigt erst der echte Lauf.
- Ob 16:9 (5244 × 2950) für den Kopf zulässig ist, ungeklärt bis zum echten `lesen`.

## Definition of Done

- [ ] Jede Acceptance Criterion unten ist durch einen automatischen Test belegt
- [ ] Die Attrappe bildet Apples dokumentierte Form ab (Einzeldatensatz, Unterpfade, `FAILED`)
- [ ] Echter Lauf `aktion=lesen` zeigt Specs und Platzierungstypen (Beleg im Workflow-Protokoll)
- [ ] Echter Lauf `aktion=hochladen` legt die zulässigen Bilder an oder meldet ausdrücklich, welche nicht passen; nichts platziert
- [ ] Bestehende Tests grün (Regressionslauf)

## Acceptance Criteria

- **AC-1:** Given der Aufruf von `lesen` oder `hochladen` / When Referenzdaten geholt werden / Then geschieht das mit `GET /v1/appAssetLibraryRefData/1` und nicht über den Listenpfad
  - Test: `scripts/test_asc_header_upload.py::test_refdata_read_as_single_record`
- **AC-2:** Given Specs mit `dimensions` als Spannen und `compatiblePlacementTypes` / When der Abgleich läuft / Then passt eine Spec nur, wenn Breite und Höhe in den Spannen liegen und `PRODUCT_PAGE_HEADER_ASSET` kompatibel ist; die Kategorie kommt aus `placementTypes[].acceptsAssetCategories`
  - Test: `scripts/test_asc_header_upload.py::test_match_by_dimension_range_and_placement`
- **AC-3:** Given keine Spec passt zu irgendeiner Datei / When `upload` läuft / Then bricht es vor dem ersten Schreibaufruf ab und nennt die vorhandenen Specs
  - Test: `scripts/test_asc_header_upload.py::test_stops_without_matching_spec`
- **AC-4:** Given nur ein Teil der Dateien passt (z. B. nur 21:9) / When `upload` läuft / Then werden nur die passenden angelegt, jede übrige wird mit Namen und Maß gemeldet und nie angelegt
  - Test: `scripts/test_asc_header_upload.py::test_partial_match_uploads_fitting_and_reports_rest`
- **AC-5:** Given die Antwort von `/v1/apps/{id}/assetLibrary` mit eigener Bibliothek-id / When Bilder gelesen und angelegt werden / Then geschieht das über `/v1/appAssetLibraries/{libraryId}/images` und das POST trägt die Beziehung `assetLibrary` (`appAssetLibraries`, Bibliothek-id), keine Beziehung `app`
  - Test: `scripts/test_asc_header_upload.py::test_uses_library_id_and_relationship`
- **AC-6:** Given ein Bild mit gleicher `referenceName` ist schon in der Bibliothek / When `upload` läuft / Then wird es nicht noch einmal angelegt
  - Test: `scripts/test_asc_header_upload.py::test_skips_existing_reference_name`
- **AC-7:** Given ein vollständiger Lauf gegen die Attrappe / When `upload` endet / Then gab es je zulässiger Datei Anlegen, Hochladen und `uploaded: true`, aber keinen Aufruf an `appAssetLibraryPlacements` (Schreibzugriff) und keine Einreichung
  - Test: `scripts/test_asc_header_upload.py::test_never_places_or_submits`
- **AC-8:** Given ein Bild wechselt über `AWAITING_UPLOAD`/`UPLOAD_COMPLETE` zu `PREPARE_FOR_SUBMISSION`, ein zweites meldet `FAILED` mit `stateDetails` / When gewartet wird / Then endet das Warten beim ersten erfolgreich und bricht beim zweiten sofort mit den `stateDetails` ab
  - Test: `scripts/test_asc_header_upload.py::test_wait_reaches_ready_and_stops_on_failed`
- **AC-9:** Given Bilder der Bibliothek und ihre Platzierungen über `…/images/{id}/placements` / When der Zustandscheck läuft / Then meldet er „bereit“ nur bei `PREPARE_FOR_SUBMISSION` aller unserer Bilder ohne Platzierung; ein anderer Zustand oder eine Platzierung ist ein Fehler
  - Test: `scripts/test_asc_header_upload.py::test_state_check_reads_ready_state`
- **AC-10:** Given `lesen` / When es läuft / Then gibt es `specId`, Maßgrenzen und `compatiblePlacementTypes` je Spec, die akzeptierten Kategorien je Platzierungstyp, die Bilder mit Zustand und die Zahl der Platzierungen aus, und es setzt keinen Schreibaufruf ab
  - Test: `scripts/test_asc_header_upload.py::test_lesen_prints_raw_specs_and_never_writes`

## Test Plan

Automatisch: `python3 -m unittest scripts/test_asc_header_upload.py` (AC-1 bis AC-10), dazu der Regressionslauf der übrigen
Skript-Tests. Vor dem Anpassen läuft die neue Attrappe gegen das alte Skript und muss fehlschlagen (RED).

Abnahme Stufe 2 heißt hier: Hand-Workflow `asc-header-upload.yml` mit `aktion=lesen` (Beleg: rohe Specs), danach `hochladen`.
„Kein Pfad der Geräteliste berührt.“ Henning bekommt nichts zu tun.

## Architektur-Entscheidung (ADR)

- **ADR-Nr.:** keine — Hand-Skript für ein Store-Asset, keine Änderung der App-Architektur; Regelweg, kein Modell.
- **Rationale:** Schnittstellenkorrektur nach Apples Dokumentation, kein Sprachverstehen beteiligt.
- **Alternative geprüft:** Hochladen und Apples `specId` danach lesen (einfacher, legt aber unpassende Bilder in der Bibliothek an) — verworfen. Händisch im Web hochladen (kein Skript, Aufgabe läge bei Henning) — verworfen.

## Changelog

- 2026-11-02: Initial spec created
